import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:poultry_app/services/api/prediction_history_service.dart';

// Only import TFLite on non-web platforms
import 'package:tflite_flutter/tflite_flutter.dart' if (dart.library.html) '';

/// Hybrid prediction service: TFLite on mobile, API on web
class EggPredictionServiceHybrid {
  dynamic _interpreter;
  bool _isModelLoaded = false;
  double _lastConfidenceScore = 0.0;
  static const String _apiUrl = 'https://capstone-335z.onrender.com/predict';
  final PredictionHistoryService _historyService = PredictionHistoryService();

  // Scaler parameters
  List<double> _inputMeans = [];
  List<double> _inputScales = [];
  List<double> _outputMeans = [];
  List<double> _outputScales = [];
  List<String> _featureOrder = [];

  /// Initialize the prediction service
  Future<void> loadModel() async {
    if (_isModelLoaded) {
      print('Model already loaded');
      return;
    }

    try {
      if (kIsWeb) {
        print('🌐 Running on web - using API predictions');
        _isModelLoaded = true;
      } else {
        print('📱 Running on mobile - loading TFLite model');
        
        // Load scaler parameters
        await _loadScalerParameters();
        
        // Load TFLite model
        _interpreter = await Interpreter.fromAsset('lib/assets/model.tflite');
        _isModelLoaded = true;
        
        // print('✅ TFLite model loaded successfully');
        print('   Input shape: ${_interpreter!.getInputTensor(0).shape}');
        print('   Output shape: ${_interpreter!.getOutputTensor(0).shape}');
        print('   Number of features: ${_inputMeans.length}');
        print('   Feature order: $_featureOrder');
      }
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoaded = false;
      rethrow;
    }
  }

  /// Load scaler parameters from JSON file
  Future<void> _loadScalerParameters() async {
    try {
      final String jsonString = await rootBundle.loadString('lib/assets/scalers/scaler_params.json');
      final Map<String, dynamic> scalerData = json.decode(jsonString);
      
      _inputMeans = List<double>.from(scalerData['input']['mean']);
      _inputScales = List<double>.from(scalerData['input']['scale']);
      _outputMeans = List<double>.from(scalerData['output']['mean']);
      _outputScales = List<double>.from(scalerData['output']['scale']);
      _featureOrder = List<String>.from(scalerData['input']['feature_order']);
      
      print('✅ Scaler parameters loaded from JSON');
      print('   Features: ${_featureOrder.length}');
    } catch (e) {
      // Fallback to hardcoded values with YOUR exact values
      print('⚠️ Could not load scaler JSON, using hardcoded values');
      _inputMeans = [20.47, 62.51, 17.37, 457.50, 981.53, 239.57, 175.28];
      _inputScales = [6.59, 9.89, 7.75, 140.76, 1575.64, 97.69, 91.01];
      _outputMeans = [0.0];
      _outputScales = [1.0];
      _featureOrder = [
        'Temperature',
        'Humidity',
        'Ammonia',
        'Light_Intensity',
        'Amount_of_chicken',
        'Noise',
        'Amount_of_Feeding'
      ];
    }
  }

  bool get isModelLoaded => _isModelLoaded;
  double get lastConfidenceScore => _lastConfidenceScore;

  /// Predict egg production using TFLite (mobile) or API (web)
  Future<int> predictEggProduction({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
    required double chickenCount,
    double? feedingAmount,
    double? noiseDecibels,
  }) async {
    if (!_isModelLoaded) {
      await loadModel();
    }

    if (kIsWeb) {
      return _predictViaAPI(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: lightIntensity,
        chickenCount: chickenCount,
        feedingAmount: feedingAmount,
        noiseDecibels: noiseDecibels,
      );
    } else {
      return _predictViaTFLite(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: lightIntensity,
        chickenCount: chickenCount,
        feedingAmount: feedingAmount ?? 175.28,  // Use mean as default
        noiseDecibels: noiseDecibels ?? 239.57,  // Use mean as default
      );
    }
  }

  /// TFLite prediction for mobile with preprocessing
  Future<int> _predictViaTFLite({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
    required double chickenCount,
    required double feedingAmount,
    required double noiseDecibels,
  }) async {
    try {
      print('🔮 Running TFLite prediction...');

      // Step 1: Prepare input data in EXACT order as training
      // Order: Temperature, Humidity, Ammonia, Light_Intensity, Amount_of_chicken, Noise, Amount_of_Feeding
      List<double> rawInput = [
        temperature,      // Index 0: Temperature
        humidity,         // Index 1: Humidity
        ammonia,          // Index 2: Ammonia
        lightIntensity,   // Index 3: Light_Intensity
        chickenCount,     // Index 4: Amount_of_chicken
        noiseDecibels,    // Index 5: Noise
        feedingAmount,    // Index 6: Amount_of_Feeding
      ];

      print('   Raw input (${rawInput.length} features):');
      print('     Temperature: ${rawInput[0]}°C');
      print('     Humidity: ${rawInput[1]}%');
      print('     Ammonia: ${rawInput[2]} ppm');
      print('     Light: ${rawInput[3]} lux');
      print('     Chickens: ${rawInput[4].toInt()}');
      print('     Noise: ${rawInput[5]} dB');
      print('     Feeding: ${rawInput[6]} kg');

      // Verify feature count matches
      if (rawInput.length != _inputMeans.length) {
        throw Exception(
          'Feature count mismatch! Input has ${rawInput.length} features, '
          'but scaler expects ${_inputMeans.length} features'
        );
      }

      // Step 2: Normalize using StandardScaler formula: (x - mean) / scale
      List<double> normalizedInput = [];
      for (int i = 0; i < rawInput.length; i++) {
        double normalized = (rawInput[i] - _inputMeans[i]) / _inputScales[i];
        normalizedInput.add(normalized);
      }

      print('   Normalized input:');
      for (int i = 0; i < normalizedInput.length; i++) {
        print('     ${_featureOrder[i]}: ${normalizedInput[i].toStringAsFixed(4)}');
      }

      // Step 3: Reshape for model input
      var input = [normalizedInput]; // Shape: [1, 7]

      // Step 4: Prepare output buffer
      var output = List.filled(1, List<double>.filled(1, 0.0));

      // Step 5: Run inference
      _interpreter!.run(input, output);

      print('   Model output (normalized): ${output[0][0]}');

      // Step 6: Inverse transform output if it was scaled
      double prediction = output[0][0];
      if (_outputScales[0] != 1.0) {
        prediction = (prediction * _outputScales[0]) + _outputMeans[0];
      }

      print('   Denormalized prediction: $prediction');

      // Step 7: Round to nearest integer and ensure non-negative
      int eggCount = math.max(0, prediction.round());

      // Calculate confidence
      _lastConfidenceScore = _calculateConfidence(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: lightIntensity,
      );

      // print('✅ TFLite Prediction: $eggCount eggs');
      print('   Confidence: ${(_lastConfidenceScore * 100).toStringAsFixed(1)}%');

      return eggCount;
    } catch (e) {
      print('❌ TFLite prediction error: $e');
      rethrow;
    }
  }

  /// API prediction for web
  Future<int> _predictViaAPI({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
    required double chickenCount,
    double? feedingAmount,
    double? noiseDecibels,
  }) async {
    try {
      print('🌐 Running API prediction...');

      final clampedLightIntensity = math.min(lightIntensity, 929.2);
      final clampedNoise = noiseDecibels != null ? math.max(noiseDecibels, 64.4) : null;

      var payload = {
        'ammonia': ammonia,
        'amount_of_chicken': chickenCount,
        'temperature': temperature,
        'humidity': humidity,
        'light_intensity': clampedLightIntensity,
      };

      if (feedingAmount != null) payload['amount_of_feeding'] = feedingAmount;
      if (clampedNoise != null) payload['noise'] = clampedNoise;

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        double prediction = 0.0;
        double confidence = 0.0;

        if (responseData is Map) {
          if (responseData.containsKey('predicted_egg_production')) {
            prediction = (responseData['predicted_egg_production'] as num).toDouble();
          }
          if (responseData.containsKey('confidence_score')) {
            confidence = (responseData['confidence_score'] as num?)?.toDouble() ?? 0.0;
            _lastConfidenceScore = confidence;
          }
        }

        int eggCount = math.max(0, prediction.round());
        print('✅ API Prediction: $eggCount eggs');
        return eggCount;
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ API prediction error: $e');
      rethrow;
    }
  }

  /// Calculate confidence score
  double _calculateConfidence({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
  }) {
    int score = 100;

    if (temperature < 20 || temperature > 27) score -= 15;
    if (humidity < 55 || humidity > 65) score -= 15;
    if (ammonia > 15) score -= 25;
    if (lightIntensity < 300 || lightIntensity > 600) score -= 15;

    return score / 100.0;
  }

  /// Get prediction quality metrics
  Map<String, dynamic> getPredictionQuality({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
  }) {
    final Map<String, Map<String, dynamic>> optimalRanges = {
      'Temperature': {'min': 18.0, 'max': 30.0, 'optimal': <double>[20.0, 27.0]},
      'Humidity': {'min': 50.0, 'max': 70.0, 'optimal': <double>[55.0, 65.0]},
      'Ammonia': {'min': 0.0, 'max': 25.0, 'optimal': <double>[0.0, 15.0]},
      'Light_Intensity': {'min': 100.0, 'max': 800.0, 'optimal': <double>[300.0, 600.0]},
    };

    int score = 100;
    List<String> warnings = [];

    final tempOptimal = optimalRanges['Temperature']!['optimal'] as List<double>;
    if (temperature < tempOptimal[0] || temperature > tempOptimal[1]) {
      score -= 15;
      warnings.add('Temperature not optimal');
    }

    final humidityOptimal = optimalRanges['Humidity']!['optimal'] as List<double>;
    if (humidity < humidityOptimal[0] || humidity > humidityOptimal[1]) {
      score -= 15;
      warnings.add('Humidity not optimal');
    }

    final ammoniaOptimal = optimalRanges['Ammonia']!['optimal'] as List<double>;
    if (ammonia > ammoniaOptimal[1]) {
      score -= 25;
      warnings.add('Ammonia level too high');
    }

    final lightOptimal = optimalRanges['Light_Intensity']!['optimal'] as List<double>;
    if (lightIntensity < lightOptimal[0] || lightIntensity > lightOptimal[1]) {
      score -= 15;
      warnings.add('Light intensity not optimal');
    }

    String quality = score >= 80 ? 'Excellent' : score >= 60 ? 'Good' : score >= 40 ? 'Fair' : 'Poor';

    return {
      'score': score,
      'quality': quality,
      'warnings': warnings,
      'confidence': score / 100.0,
    };
  }

  /// Save prediction to history
  Future<void> savePredictionToHistory({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
    required int chickenCount,
    required int predictedEggs,
    required Map<String, dynamic> quality,
    double? feedingAmount,
    double? noiseDecibels,
    double? profit,
  }) async {
    try {
      await _historyService.savePrediction(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: lightIntensity,
        chickenCount: chickenCount,
        predictedEggs: predictedEggs,
        predictionScore: quality['score'] as int? ?? 0,
        predictionQuality: quality['quality'] as String? ?? 'Unknown',
        predictionConfidence: quality['confidence'] as double? ?? 0.0,
        optimizationTips: quality['warnings'] as List<String>? ?? [],
        feedingAmount: feedingAmount,
        noiseDecibels: noiseDecibels,
        profit: profit,
      );
      print('✅ Prediction saved to history');
    } catch (e) {
      print('❌ Error saving prediction: $e');
      rethrow;
    }
  }

  void dispose() {
    if (!kIsWeb && _interpreter != null) {
      _interpreter!.close();
    }
    _isModelLoaded = false;
    print('Prediction service disposed');
  }
}