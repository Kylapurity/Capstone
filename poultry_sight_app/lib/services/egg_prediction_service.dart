import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:poultry_app/services/api/prediction_history_service.dart';

/// Platform-aware service that uses TFLite on mobile and API on web
class EggPredictionService {
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  double _lastConfidenceScore = 0.0;
  static const String _apiUrl = 'https://capstone-335z.onrender.com/predict';
  final PredictionHistoryService _historyService = PredictionHistoryService();

  // Scaler parameters from your Kaggle training
  final List<double> _meanValues = [20.47, 62.51, 17.37, 457.50, 981.53];
  final List<double> _stdValues = [6.59, 9.89, 7.75, 140.76, 1575.64];

  // Feature order: Temperature, Humidity, Ammonia, Light_Intensity, Amount_of_chicken
  final List<String> _featureOrder = [
    'Temperature',
    'Humidity',
    'Ammonia',
    'Light_Intensity',
    'Amount_of_chicken',
  ];

  /// Initialize the prediction service
  Future<void> loadModel() async {
    if (_isModelLoaded) {
      print('Model already loaded');
      return;
    }

    try {
      if (kIsWeb) {
        // Web: Use API
        print('🌐 Running on web - using API predictions');
        _isModelLoaded = true;
      } else {
        // Mobile: Load TFLite model
        print('📱 Running on mobile - loading TFLite model');
        _interpreter = await Interpreter.fromAsset('assets/models/model.tflite');
        _isModelLoaded = true;
        print('✅ TFLite model loaded successfully');
        print('   Input shape: ${_interpreter!.getInputTensor(0).shape}');
        print('   Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      }
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoaded = false;
      rethrow;
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
      // Use API prediction
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
      // Use TFLite prediction
      return _predictViaTFLite(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: lightIntensity,
        chickenCount: chickenCount,
      );
    }
  }

  /// TFLite prediction for mobile
  Future<int> _predictViaTFLite({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
    required double chickenCount,
  }) async {
    try {
      print('🔮 Running TFLite prediction...');

      // Prepare input data in correct order
      List<double> rawInput = [
        temperature,
        humidity,
        ammonia,
        lightIntensity,
        chickenCount,
      ];

      // Normalize input using scaler parameters
      List<double> normalizedInput = [];
      for (int i = 0; i < rawInput.length; i++) {
        double normalized = (rawInput[i] - _meanValues[i]) / _stdValues[i];
        normalizedInput.add(normalized);
      }

      // Reshape input based on your model's expected shape
      // Adjust this based on your model's input shape from print statement
      // Example: [1, 5] for batch_size=1, features=5
      var input = [normalizedInput];

      // Prepare output buffer
      // Adjust based on your model's output shape
      var output = List.filled(1, List<double>.filled(1, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Get prediction and round to nearest integer
      double prediction = output[0][0];
      int eggCount = math.max(0, prediction.round());

      // Calculate confidence score (simple heuristic)
      _lastConfidenceScore = _calculateConfidence(
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        lightIntensity: lightIntensity,
      );

      print('✅ TFLite Prediction: $eggCount eggs');
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

      // Clamp values to API constraints
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

  /// Calculate confidence score based on optimal ranges
  double _calculateConfidence({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
  }) {
    int score = 100;

    // Temperature: 20-27°C optimal
    if (temperature < 20 || temperature > 27) score -= 15;

    // Humidity: 55-65% optimal
    if (humidity < 55 || humidity > 65) score -= 15;

    // Ammonia: 0-15 ppm optimal
    if (ammonia > 15) score -= 25;

    // Light: 300-600 lux optimal
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
      'Temperature': {
        'min': 18.0,
        'max': 30.0,
        'optimal': <double>[20.0, 27.0],
      },
      'Humidity': {
        'min': 50.0,
        'max': 70.0,
        'optimal': <double>[55.0, 65.0],
      },
      'Ammonia': {
        'min': 0.0,
        'max': 25.0,
        'optimal': <double>[0.0, 15.0],
      },
      'Light_Intensity': {
        'min': 100.0,
        'max': 800.0,
        'optimal': <double>[300.0, 600.0],
      },
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

    String quality = score >= 80
        ? 'Excellent'
        : score >= 60
            ? 'Good'
            : score >= 40
                ? 'Fair'
                : 'Poor';

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
    _interpreter?.close();
    _isModelLoaded = false;
    print('Prediction service disposed');
  }
}