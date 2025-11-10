import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poultry_app/services/egg_prediction_service_hybrid.dart';
import 'package:poultry_app/services/user_profile_service.dart';
import 'package:poultry_app/services/api/api_service.dart';
import 'package:poultry_app/services/api/recording_service.dart';
import 'package:poultry_app/models/sensor_reading.dart';
import 'package:poultry_app/screens/dashboard/dashboard_screen.dart';
import 'package:poultry_app/screens/history/history_screen.dart';
import 'package:poultry_app/screens/profile/profile_screen.dart';
import 'package:poultry_app/screens/graphs/graphs_screen.dart';
import 'package:poultry_app/screens/profit/profit_screen.dart';

class ManualPredictionScreen extends StatefulWidget {
  const ManualPredictionScreen({super.key});

  @override
  State<ManualPredictionScreen> createState() => _ManualPredictionScreenState();
}

class _ManualPredictionScreenState extends State<ManualPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final EggPredictionServiceHybrid _predictionService = EggPredictionServiceHybrid();
  final UserProfileService _profileService = UserProfileService();
  final ApiService _apiService = ApiService();
  final RecordingService _recordingService = RecordingService();

  // Text controllers for input fields
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _ammoniaController = TextEditingController();
  final TextEditingController _lightController = TextEditingController();
  final TextEditingController _chickenCountController = TextEditingController();
  final TextEditingController _feedingAmountController = TextEditingController();
  final TextEditingController _noiseController = TextEditingController();

  bool _isPredicting = false;
  bool _isLoadingSensorData = false;
  bool _isProcessingAudio = false;
  int? _predictedEggs;
  Map<String, dynamic>? _predictionQuality;
  double? _noiseDecibels;

  @override
  void initState() {
    super.initState();
    _loadChickenCount();
    _loadSensorData();
    _recordingService.addListener(_onRecordingServiceChanged);
    _recordingService.initRecorder();
    _initPredictionService();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _ammoniaController.dispose();
    _lightController.dispose();
    _chickenCountController.dispose();
    _feedingAmountController.dispose();
    _noiseController.dispose();
    _recordingService.removeListener(_onRecordingServiceChanged);
    _recordingService.disposeRecorder();
    _predictionService.dispose();
    super.dispose();
  }

  Future<void> _initPredictionService() async {
    try {
      await _predictionService.loadModel();
      print('✅ Prediction service initialized');
    } catch (e) {
      print('⚠️ Prediction service init failed: $e');
      // Service will still work via API fallback
    }
  }

  void _onRecordingServiceChanged() {
    if (mounted) {
      setState(() {
        _isProcessingAudio = _recordingService.isUploading;
        if (_recordingService.decibels != null) {
          _noiseDecibels = _recordingService.decibels;
          _noiseController.text = _recordingService.decibels!.toStringAsFixed(1);
        }
      });
    }
  }

  Future<void> _loadSensorData() async {
    setState(() {
      _isLoadingSensorData = true;
    });

    try {
      final sensorData = await _apiService.getSensorData();
      final reading = SensorReading.fromMap(sensorData);

      setState(() {
        _temperatureController.text = reading.temperature.toStringAsFixed(1);
        _humidityController.text = reading.humidity.toStringAsFixed(1);
        _ammoniaController.text = reading.ammonia.toStringAsFixed(1);
        _lightController.text = reading.lightIntensity.toStringAsFixed(1);
        _isLoadingSensorData = false;
      });


    } catch (e) {
      debugPrint('Error loading sensor data: $e');
      setState(() {
        _isLoadingSensorData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sensor data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadChickenCount() async {
    try {
      final count = await _profileService.getChickenCount();
      setState(() {
        _chickenCountController.text = count.toString();
      });
    } catch (e) {
      debugPrint('Error loading chicken count: $e');
      _chickenCountController.text = '100';
    }
  }

  Future<void> _pickAndProcessAudio() async {
    final picked = await _recordingService.pickAudioFile();
    if (!picked) return;

    final decibels = await _recordingService.uploadAndConvertToDecibels();
    
    if (decibels == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not calculate decibels. Please try a WAV format recording.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (decibels != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Noise level calculated: ${decibels.toStringAsFixed(1)} dB'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _runPrediction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_noiseDecibels == null && _recordingService.hasRecording) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for audio processing to complete'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isPredicting = true;
      _predictedEggs = null;
      _predictionQuality = null;
    });

    try {
      final temperature = double.parse(_temperatureController.text);
      final humidity = double.parse(_humidityController.text);
      final ammonia = double.parse(_ammoniaController.text);
      final light = double.parse(_lightController.text);
      final chickenCount = double.parse(_chickenCountController.text);
      final feedingAmount = double.parse(_feedingAmountController.text);
      final noise = _noiseDecibels ?? 0.0;

      // Run prediction with new hybrid service
      final prediction = await _predictionService.predictEggProduction(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: light,
        chickenCount: chickenCount,
        feedingAmount: feedingAmount,
        noiseDecibels: noise,
      );

      final quality = _predictionService.getPredictionQuality(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: light,
      );

      setState(() {
        _predictedEggs = prediction;
        _predictionQuality = quality;
        _isPredicting = false;
      });

      // Calculate profit
      const double eggPrice = 120.0;
      final double profit = prediction * eggPrice;

      // Save prediction to history
      await _predictionService.savePredictionToHistory(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: light,
        chickenCount: chickenCount.toInt(),
        predictedEggs: prediction,
        quality: quality,
        feedingAmount: feedingAmount,
        noiseDecibels: noise,
        profit: profit,
      );

      // Refresh graphs if they're currently active
      GraphsScreen.refreshGraphsIfActive();
    } catch (e) {
      setState(() {
        _isPredicting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearFields() {
    setState(() {
      _temperatureController.clear();
      _humidityController.clear();
      _ammoniaController.clear();
      _lightController.clear();
      _feedingAmountController.clear();
      _noiseController.clear();
      _recordingService.clearRecording();
      _noiseDecibels = null;
      _predictedEggs = null;
      _predictionQuality = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22.0, 8.0, 22.0, 22.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with logo
                      Center(
                        child: Image.asset(
                          'lib/assets/images/Background.png',
                          width: 100,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      const Text(
                        'Manual Prediction',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Subtitle
                      const Text(
                        'Enter environmental conditions to predict egg production',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 14,
                          color: Color(0xFF5A5A5A),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingSensorData ? null : _loadSensorData,
                              icon: Icon(
                                _isLoadingSensorData ? Icons.hourglass_empty : Icons.refresh,
                                size: 18,
                              ),
                              label: Text(_isLoadingSensorData ? 'Loading...' : 'Load Sensors'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearFields,
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text('Clear'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Input Fields - Sensor Data
                      _buildInputField(
                        controller: _temperatureController,
                        label: 'Temperature (°C)',
                        hint: '',
                        icon: Icons.thermostat,
                        minValue: -50,
                        maxValue: 60,
                        optimalRange: '18-30°C',
                        isAutoFilled: true,
                      ),
                      const SizedBox(height: 16),

                      _buildInputField(
                        controller: _humidityController,
                        label: 'Humidity (%)',
                        hint: '',
                        icon: Icons.water_drop,
                        minValue: 0,
                        maxValue: 100,
                        optimalRange: '50-70%',
                        isAutoFilled: true,
                      ),
                      const SizedBox(height: 16),

                      _buildInputField(
                        controller: _ammoniaController,
                        label: 'Ammonia/CO₂ (ppm)',
                        hint: '',
                        icon: Icons.cloud,
                        minValue: 0,
                        maxValue: 1000,
                        optimalRange: '0-25 ppm',
                        isAutoFilled: true,
                      ),
                      const SizedBox(height: 16),

                      _buildInputField(
                        controller: _lightController,
                        label: 'Light Intensity (lux)',
                        hint: '',
                        icon: Icons.wb_sunny,
                        minValue: 0,
                        maxValue: 10000,
                        optimalRange: '300-600 lux',
                        isAutoFilled: true,
                      ),
                      const SizedBox(height: 16),

                      // User Input Fields
                      _buildInputField(
                        controller: _feedingAmountController,
                        label: 'Amount of Feeding (kg)',
                        hint: '',
                        icon: Icons.restaurant,
                        minValue: 0,
                        maxValue: 10000,
                        optimalRange: 'Recommended: 40-60 kg',
                      ),
                      const SizedBox(height: 16),

                      // Noise Recording Field
                      _buildNoiseField(),
                      const SizedBox(height: 16),

                      // Chicken Count
                      _buildInputField(
                        controller: _chickenCountController,
                        label: 'Number of Chickens',
                        hint: '',
                        icon: Icons.pets,
                        minValue: 1,
                        maxValue: 100000,
                        isInteger: true,
                        isAutoFilled: true,
                      ),
                      const SizedBox(height: 24),

                      // Predict Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_isPredicting || _isProcessingAudio) ? null : _runPrediction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isPredicting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Predict Egg Production',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Prediction Result
                      if (_predictedEggs != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.egg_outlined,
                                size: 48,
                                color: Color(0xFF4CAF50),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Predicted Egg Production',
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 14,
                                  color: Color(0xFF5A5A5A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$_predictedEggs',
                                    style: const TextStyle(
                                      fontFamily: 'Lexend',
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'eggs',
                                    style: TextStyle(
                                      fontFamily: 'Lexend',
                                      fontSize: 20,
                                      color: Color(0xFF5A5A5A),
                                    ),
                                  ),
                                ],
                              ),
                              if (_predictionQuality != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getQualityColor(_predictionQuality!['quality']),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getQualityIcon(_predictionQuality!['quality']),
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Quality: ${_predictionQuality!['quality']}',
                                        style: const TextStyle(
                                          fontFamily: 'Lexend',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_predictionQuality != null &&
                                  (_predictionQuality!['warnings'] as List).isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Optimization Tips:',
                                            style: TextStyle(
                                              fontFamily: 'Lexend',
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...(_predictionQuality!['warnings'] as List)
                                          .map((warning) => Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '• $warning',
                                                  style: const TextStyle(
                                                    fontFamily: 'Lexend',
                                                    fontSize: 11,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Navigation Bar
            BottomNavigationBar(
              currentIndex: 1,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF4CAF50),
              unselectedItemColor: Colors.grey,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              type: BottomNavigationBarType.fixed,
              elevation: 8,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calculate),
                  label: 'Predict',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.trending_up),
                  label: 'Profits',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Graphs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
              onTap: (index) {
                if (index == 1) return;

                switch (index) {
                  case 0:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    );
                    break;
                  case 2:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfitScreen(),
                      ),
                    );
                    break;
                  case 3:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GraphsScreen(),
                      ),
                    );
                    break;
                  case 4:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                    break;
                  case 5:
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required double minValue,
    required double maxValue,
    String? optimalRange,
    bool isInteger = false,
    bool isAutoFilled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
                if (isAutoFilled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Auto',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
          inputFormatters: isInteger
              ? [FilteringTextInputFormatter.digitsOnly]
              : [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a value';
            }
            final number = double.tryParse(value);
            if (number == null) {
              return 'Please enter a valid number';
            }
            if (number < minValue || number > maxValue) {
              return 'Value must be between $minValue and $maxValue';
            }
            return null;
          },
        ),
        ],
    );
  }

  Future<void> _startRecording() async {
    final success = await _recordingService.startRecording();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording started...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    final dbValue = await _recordingService.stopRecording();
    
    if (mounted) {
      if (dbValue != null) {
        setState(() {
          _noiseDecibels = dbValue;
          _noiseController.text = dbValue.toStringAsFixed(1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Recording completed: ${dbValue.toStringAsFixed(1)} dB'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording saved but could not calculate decibels'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildNoiseField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Noise Level (dB)',
          style: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3A3A3A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _noiseController,
                keyboardType: TextInputType.number,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: _recordingService.isRecording 
                      ? 'Recording in progress...' 
                      : 'Record or upload to calculate',
                  prefixIcon: const Icon(Icons.volume_up, color: Color(0xFF4CAF50)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_recordingService.isRecording)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop_circle, size: 20),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic, size: 20),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
          ],
        ),
        if (_recordingService.hasRecording) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recordingService.recordingFileName ?? 'Recording selected',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_noiseDecibels != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_noiseDecibels!.toStringAsFixed(1)} dB',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_recordingService.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _recordingService.errorMessage!,
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 11,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  Color _getQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return const Color(0xFF4CAF50);
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getQualityIcon(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return Icons.sentiment_very_satisfied;
      case 'good':
        return Icons.sentiment_satisfied;
      case 'fair':
        return Icons.sentiment_neutral;
      case 'poor':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.help_outline;
    }
  }
}