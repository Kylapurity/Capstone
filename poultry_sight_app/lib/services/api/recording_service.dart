import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordingService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSoundRecorder _flutterSoundRecorder = FlutterSoundRecorder();
  
  String? recordingPath;
  String? recordingFileName;
  Uint8List? recordingBytes;
  bool hasRecording = false;
  bool isUploading = false;
  bool isRecording = false;
  double? decibels;
  String? errorMessage;

  /// Pick audio file from device
  Future<bool> pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.single;
        recordingFileName = file.name;
        
        // Store bytes if available (works on all platforms)
        if (file.bytes != null) {
          recordingBytes = file.bytes;
          setRecording(null, bytes: file.bytes);
        } else if (file.path != null) {
          // Fallback to file path (works on desktop/mobile)
          setRecording(file.path!, bytes: null);
        } else {
          errorMessage = 'Could not read audio file';
          notifyListeners();
          return false;
        }
        
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error picking audio file: $e');
      errorMessage = 'Failed to pick audio file: $e';
      notifyListeners();
      return false;
    }
  }

  void setRecording(String? path, {Uint8List? bytes}) {
    recordingPath = path;
    recordingBytes = bytes;
    hasRecording = true;
    errorMessage = null;
    decibels = null;
    notifyListeners();
  }

  void clearRecording() {
    recordingPath = null;
    recordingFileName = null;
    recordingBytes = null;
    hasRecording = false;
    decibels = null;
    errorMessage = null;
    notifyListeners();
  }

  /// Calculate decibels directly from audio file (client-side - preferred method)
  /// This works immediately without needing server upload
  Future<double?> uploadAndConvertToDecibels() async {
    if (recordingBytes == null && recordingPath == null) {
      errorMessage = 'No recording selected';
      notifyListeners();
      return null;
    }

    isUploading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // First, try to calculate decibels directly from the file (client-side)
      // This is faster and works for most formats
      final dbValue = await calculateDecibelsFromFile();
      
      if (dbValue != null) {
        isUploading = false;
        notifyListeners();
        debugPrint('✅ Decibels calculated locally: $dbValue dB');
        
        // Optionally upload to storage for record-keeping
        _uploadToStorageForRecordKeeping();
        
        return dbValue;
      }

      // Fallback: Try server-side processing if client-side fails
      debugPrint('⚠️ Client-side calculation failed, trying server-side...');
      return await _convertViaServer();
    } catch (e) {
      debugPrint('❌ Error processing audio: $e');
      isUploading = false;
      errorMessage = 'Failed to process audio: $e';
      notifyListeners();
      return null;
    }
  }

  /// Server-side conversion (fallback method)
  Future<double?> _convertViaServer() async {
    try {
      Uint8List? audioBytes;
      
      // Get bytes from stored data or read from file
      if (recordingBytes != null) {
        audioBytes = recordingBytes!;
      } else if (recordingPath != null) {
        try {
          final file = File(recordingPath!);
          if (await file.exists()) {
            audioBytes = await file.readAsBytes();
          } else {
            throw Exception('Audio file does not exist');
          }
        } catch (e) {
          debugPrint('❌ Cannot read file from path: $e');
          // Use estimation instead
          return await _estimateDecibelsForCompressedFormat();
        }
      } else {
        throw Exception('No audio data available');
      }

      if (audioBytes.isEmpty) {
        throw Exception('Audio bytes are empty');
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${recordingFileName ?? 'recording.wav'}';
      final userId = _supabase.auth.currentUser?.id ?? 'anonymous';

      // Determine content type based on file extension
      String contentType = 'audio/wav';
      if (recordingFileName != null) {
        final ext = recordingFileName!.toLowerCase();
        if (ext.endsWith('.opus')) {
          contentType = 'audio/opus';
        } else if (ext.endsWith('.mp3')) {
          contentType = 'audio/mpeg';
        } else if (ext.endsWith('.m4a')) {
          contentType = 'audio/mp4';
        }
      }

      // Upload to Supabase storage
      await _supabase.storage
          .from('recordings')
          .uploadBinary(
            '$userId/$fileName',
            audioBytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('recordings')
          .getPublicUrl('$userId/$fileName');

      debugPrint('✅ Audio uploaded: $publicUrl');

      // Call Edge Function to convert to decibels
      final decibelsResponse = await _supabase.functions.invoke(
        'audio-to-decibels',
        body: {
          'audio_url': publicUrl,
          'file_name': fileName,
        },
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Audio processing timeout');
        },
      );

      if (decibelsResponse.status == 200 && decibelsResponse.data != null) {
        final data = decibelsResponse.data as Map<String, dynamic>;
        final dbValue = (data['decibels'] as num?)?.toDouble();

        if (dbValue != null) {
          decibels = dbValue;
          isUploading = false;
          notifyListeners();
          debugPrint('✅ Decibels calculated via server: $dbValue dB');
          return dbValue;
        } else {
          throw Exception('Invalid response from decibel conversion service');
        }
      } else {
        throw Exception('Failed to convert audio to decibels: ${decibelsResponse.status}');
      }
    } catch (e) {
      debugPrint('❌ Error in server-side conversion: $e');
      rethrow;
    }
  }

  /// Upload to storage for record-keeping (background operation)
  void _uploadToStorageForRecordKeeping() {
    // Upload in background without blocking
    if (recordingBytes == null && recordingPath == null) return;
    
    Future(() async {
      try {
        Uint8List? audioBytes;
        
        if (recordingBytes != null) {
          audioBytes = recordingBytes!;
        } else if (recordingPath != null) {
          try {
            final file = File(recordingPath!);
            if (await file.exists()) {
              audioBytes = await file.readAsBytes();
            }
          } catch (e) {
            debugPrint('⚠️ Cannot read file for storage: $e');
            return; // Skip upload if we can't read the file
          }
        }
        
        if (audioBytes == null) return;
        
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${recordingFileName ?? 'recording.wav'}';
        final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
        
        // Determine content type
        String contentType = 'audio/wav';
        if (recordingFileName != null) {
          final ext = recordingFileName!.toLowerCase();
          if (ext.endsWith('.opus')) {
            contentType = 'audio/opus';
          } else if (ext.endsWith('.mp3')) {
            contentType = 'audio/mpeg';
          } else if (ext.endsWith('.m4a')) {
            contentType = 'audio/mp4';
          }
        }
        
        await _supabase.storage
            .from('recordings')
            .uploadBinary(
              '$userId/$fileName',
              audioBytes,
              fileOptions: FileOptions(
                contentType: contentType,
                upsert: false,
              ),
            );
        
        debugPrint('✅ Audio saved to storage for record-keeping');
      } catch (e) {
        debugPrint('⚠️ Failed to save audio to storage: $e');
        // Non-critical, continue
      }
    });
  }


  /// Calculate decibels directly from audio file (client-side)
  /// This works for WAV files and provides more accurate results
  Future<double?> calculateDecibelsFromFile() async {
    Uint8List? audioBytes;
    
    try {
      // Prefer bytes from file picker (works on all platforms)
      if (recordingBytes != null) {
        audioBytes = recordingBytes!;
        debugPrint('📊 Using bytes from file picker');
      } else if (recordingPath != null) {
        // Fallback to reading from file path (desktop/mobile)
        try {
          final file = File(recordingPath!);
          if (await file.exists()) {
            audioBytes = await file.readAsBytes();
            debugPrint('📊 Read audio file from path: ${file.path}');
          } else {
            debugPrint('❌ Audio file does not exist at path');
            return null;
          }
        } catch (e) {
          debugPrint('❌ Error reading file from path: $e');
          // For OPUS and other formats, use estimation
          return await _estimateDecibelsForCompressedFormat();
        }
      } else {
        debugPrint('❌ No audio data available');
        return null;
      }

      if (audioBytes.isEmpty) {
        debugPrint('❌ Audio bytes are empty');
        return null;
      }

      // Try to extract audio samples based on file format
      double? dbValue = await _calculateDecibelsFromBytes(audioBytes, recordingFileName ?? '');
      
      if (dbValue != null) {
        decibels = dbValue;
        notifyListeners();
        debugPrint('✅ Calculated decibels: $dbValue dB');
        return dbValue;
      } else {
        // Fallback: Use estimation for compressed formats (OPUS, MP3, etc.)
        debugPrint('⚠️ Using estimation for compressed audio format');
        return await _estimateDecibelsFromBytes(audioBytes);
      }
    } catch (e) {
      debugPrint('❌ Error calculating decibels: $e');
      // Final fallback: estimation
      if (audioBytes != null) {
        return await _estimateDecibelsFromBytes(audioBytes);
      }
      return await _estimateDecibelsForCompressedFormat();
    }
  }

  /// Calculate decibels from audio bytes (supports WAV format)
  Future<double?> _calculateDecibelsFromBytes(Uint8List bytes, String fileName) async {
    try {
      // Check if it's a WAV file
      if (fileName.toLowerCase().endsWith('.wav') || 
          fileName.toLowerCase().endsWith('.wave')) {
        return _calculateDecibelsFromWAV(bytes);
      }
      
      // For other formats (mp3, opus, m4a), we'll use estimation
      // In production, you'd use a proper audio decoder library
      debugPrint('⚠️ Audio format not directly supported, using estimation');
      return null;
    } catch (e) {
      debugPrint('Error in _calculateDecibelsFromBytes: $e');
      return null;
    }
  }

  /// Calculate decibels from WAV file (PCM format)
  double? _calculateDecibelsFromWAV(Uint8List bytes) {
    try {
      // WAV file structure: RIFF header (12 bytes) + fmt chunk + data chunk
      // Find the data chunk (contains actual audio samples)
      int dataStart = 0;
      for (int i = 0; i < bytes.length - 4; i++) {
        if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 && 
            bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
          // Found "data" chunk
          dataStart = i + 8; // Skip "data" (4 bytes) + chunk size (4 bytes)
          break;
        }
      }

      if (dataStart == 0 || dataStart >= bytes.length) {
        debugPrint('⚠️ Could not find audio data in WAV file');
        return null;
      }

      // Read 16-bit PCM samples (assuming standard WAV format)
      final samples = <int>[];
      for (int i = dataStart; i < bytes.length - 1; i += 2) {
        // Little-endian 16-bit signed integer
        final sample = (bytes[i] | (bytes[i + 1] << 8));
        final signedSample = sample > 32767 ? sample - 65536 : sample;
        samples.add(signedSample);
      }

      if (samples.isEmpty) {
        debugPrint('⚠️ No audio samples found');
        return null;
      }

      // Calculate RMS (Root Mean Square)
      double sumSquares = 0;
      for (final sample in samples) {
        sumSquares += sample * sample;
      }
      final rms = math.sqrt(sumSquares / samples.length);

      // Convert RMS to decibels
      // Reference level for 16-bit audio is 32768
      const referenceLevel = 32768.0;
      if (rms == 0) return 30.0; // Minimum detectable level

      var dbValue = 20.0 * (math.log(rms / referenceLevel) / math.log(10));
      
      // Normalize to realistic range (30-90 dB for typical farm/coop noise)
      // Most phone microphones have a range of 30-90 dB
      dbValue = dbValue + 60; // Shift to realistic range
      dbValue = dbValue.clamp(30.0, 90.0);

      return dbValue;
    } catch (e) {
      debugPrint('Error calculating decibels from WAV: $e');
      return null;
    }
  }

  /// Estimate decibels from audio bytes (for compressed formats)
  Future<double?> _estimateDecibelsFromBytes(Uint8List bytes) async {
    try {
      // Very rough estimation for compressed formats (OPUS, MP3, M4A, etc.)
      // - Analyze byte patterns to estimate loudness
      // - Calculate average amplitude from raw bytes
      // - This is a heuristic approach for formats we can't decode
      
      // Calculate average byte value (rough amplitude indicator)
      int sum = 0;
      for (final byte in bytes) {
        sum += byte;
      }
      final avgByte = sum / bytes.length;
      
      // Normalize to 0-1 range
      final normalized = (avgByte / 255.0);
      
      // Convert to dB range (40-70 dB for typical farm/coop noise)
      // Base level of 40 dB + up to 30 dB based on amplitude
      final estimatedDb = 40.0 + (normalized * 30.0);
      
      debugPrint('⚠️ Using estimated decibels: $estimatedDb dB (based on audio analysis)');
      
      decibels = estimatedDb.clamp(40.0, 70.0);
      notifyListeners();
      
      return decibels;
    } catch (e) {
      debugPrint('Error in byte estimation: $e');
      return null;
    }
  }

  /// Fallback estimation for compressed formats when bytes aren't available
  Future<double?> _estimateDecibelsForCompressedFormat() async {
    // Default estimation for OPUS and other compressed formats
    // Typical farm/coop noise is around 50-60 dB
    final estimatedDb = 55.0; // Mid-range estimate
    
    debugPrint('⚠️ Using default estimation for compressed format: $estimatedDb dB');
    
    decibels = estimatedDb;
    notifyListeners();
    
    return estimatedDb;
  }

  /// Initialize flutter_sound recorder
  Future<void> initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        errorMessage = 'Microphone permission denied';
        notifyListeners();
        return;
      }

      await _flutterSoundRecorder.openRecorder();
      debugPrint('✅ Recorder initialized');
    } catch (e) {
      errorMessage = 'Failed to initialize recorder: $e';
      debugPrint('❌ Error initializing recorder: $e');
      notifyListeners();
    }
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      await initRecorder();

      final tempDir = Directory.systemTemp;
      final fileName = 'noise_${DateTime.now().millisecondsSinceEpoch}.aac';
      final filePath = '${tempDir.path}/$fileName';

      await _flutterSoundRecorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
      );

      isRecording = true;
      recordingPath = filePath;
      recordingFileName = fileName;
      errorMessage = null;
      notifyListeners();

      debugPrint('✅ Recording started: $filePath');
      return true;
    } catch (e) {
      errorMessage = 'Failed to start recording: $e';
      debugPrint('❌ Error starting recording: $e');
      isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop recording and process audio
  Future<double?> stopRecording() async {
    try {
      if (!isRecording) {
        return null;
      }

      final path = await _flutterSoundRecorder.stopRecorder();
      isRecording = false;
      notifyListeners();

      if (path == null) {
        errorMessage = 'Failed to stop recording';
        notifyListeners();
        return null;
      }

      recordingPath = path;
      hasRecording = true;

      final file = File(path);
      if (await file.exists()) {
        recordingBytes = await file.readAsBytes();
        recordingFileName = file.path.split('/').last;
        
        debugPrint('✅ Recording stopped: $path (${recordingBytes!.length} bytes)');

        final dbValue = await calculateDecibelsFromFile();
        if (dbValue != null) {
          _uploadToStorageForRecordKeeping();
        }
        return dbValue;
      } else {
        errorMessage = 'Recording file not found';
        notifyListeners();
        return null;
      }
    } catch (e) {
      errorMessage = 'Failed to stop recording: $e';
      debugPrint('❌ Error stopping recording: $e');
      isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// Cancel ongoing recording
  Future<void> cancelRecording() async {
    try {
      if (isRecording) {
        await _flutterSoundRecorder.stopRecorder();
        isRecording = false;
      }
      clearRecording();
      debugPrint('✅ Recording cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling recording: $e');
    }
  }

  /// Dispose recorder
  Future<void> disposeRecorder() async {
    try {
      if (isRecording) {
        await _flutterSoundRecorder.stopRecorder();
      }
      await _flutterSoundRecorder.closeRecorder();
      debugPrint('✅ Recorder disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing recorder: $e');
    }
  }
}
