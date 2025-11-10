import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for saving and retrieving prediction history
class PredictionHistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Save a prediction to the history table
  Future<void> savePrediction({
    required double temperature,
    required double humidity,
    required double ammonia,
    required double lightIntensity,
    required int chickenCount,
    required int predictedEggs,
    required int predictionScore,
    required String predictionQuality,
    required double predictionConfidence,
    required List<String> optimizationTips,
    bool isFallback = false,
    String? deviceId,
    String? sensorTimestamp,
    String? notes,
    double? feedingAmount,
    double? noiseDecibels,
    double? profit,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in, skipping prediction save');
      return;
    }

    try {
      final Map<String, dynamic> insertData = {
        'user_id': user.id,
        'temperature': temperature,
        'humidity': humidity,
        'ammonia': ammonia,
        'light_intensity': lightIntensity,
        'chicken_count': chickenCount,
        'predicted_eggs': predictedEggs,
        'prediction_score': predictionScore,
        'prediction_quality': predictionQuality,
        'prediction_confidence': predictionConfidence,
        'optimization_tips': optimizationTips,
        'is_fallback': isFallback,
        'device_id': deviceId,
        'sensor_timestamp': sensorTimestamp,
        'notes': notes,
      };

      // Add optional fields if provided
      // Note: Column names must match the database schema
      if (feedingAmount != null) {
        insertData['amount_of_feeding'] = feedingAmount;
      }
      if (noiseDecibels != null) {
        insertData['noise_decibels'] = noiseDecibels;
      }
      if (profit != null) {
        insertData['profit_score'] = profit;
      }

      await _supabase.from('prediction_history').insert(insertData);

      debugPrint('✅ Prediction saved to history');
    } catch (error) {
      debugPrint('❌ Error saving prediction: $error');
      
      // If error is due to missing columns, try saving without optional fields
      if (error.toString().contains('feeding_amount') ||
          error.toString().contains('amount_of_feeding') ||
          error.toString().contains('noise_decibels') ||
          error.toString().contains('noise') ||
          error.toString().contains('profit_score')) {
        debugPrint('⚠️ Retrying without optional fields (amount_of_feeding, noise_decibels, profit_score)...');
        try {
          final Map<String, dynamic> insertDataWithoutOptional = {
            'user_id': user.id,
            'temperature': temperature,
            'humidity': humidity,
            'ammonia': ammonia,
            'light_intensity': lightIntensity,
            'chicken_count': chickenCount,
            'predicted_eggs': predictedEggs,
            'prediction_score': predictionScore,
            'prediction_quality': predictionQuality,
            'prediction_confidence': predictionConfidence,
            'optimization_tips': optimizationTips,
            'is_fallback': isFallback,
            'device_id': deviceId,
            'sensor_timestamp': sensorTimestamp,
            'notes': notes,
          };
          
          await _supabase.from('prediction_history').insert(insertDataWithoutOptional);
          debugPrint('✅ Prediction saved to history (without optional fields)');
        } catch (retryError) {
          debugPrint('❌ Error saving prediction (retry failed): $retryError');
        }
      }
    }
  }

  /// Get prediction history for the current user
  Future<List<Map<String, dynamic>>> getPredictionHistory({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to fetch prediction history');
    }

    try {
      var query = _supabase
          .from('prediction_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      // Note: Date range filtering can be added later using .or() or dedicated queries
      // For now, we retrieve recent records and filter in memory if needed

      var response = await query;

      // Optional: Filter by date range in memory
      if (startDate != null || endDate != null) {
        response =
            response.where((item) {
                  final createdAt = item['created_at'];
                  if (createdAt == null) return true;

                  final date = DateTime.parse(createdAt as String);
                  if (startDate != null && date.isBefore(startDate))
                    return false;
                  if (endDate != null && date.isAfter(endDate)) return false;
                  return true;
                }).toList()
                as List<Map<String, dynamic>>;
      }

      return response;
    } catch (error) {
      debugPrint('Database error fetching prediction history: $error');
      rethrow;
    }
  }

  /// Get prediction statistics
  Future<Map<String, dynamic>> getPredictionStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final history = await getPredictionHistory(
      limit: 1000,
      startDate: startDate,
      endDate: endDate,
    );

    if (history.isEmpty) {
      return {
        'total_predictions': 0,
        'avg_predicted_eggs': 0,
        'avg_score': 0,
        'quality_distribution': {},
      };
    }

    final totalPredictions = history.length;
    final avgPredictedEggs =
        history
            .map((p) => (p['predicted_eggs'] as int?) ?? 0)
            .reduce((a, b) => a + b) /
        totalPredictions;
    final avgScore =
        history
            .map((p) => (p['prediction_score'] as int?) ?? 0)
            .reduce((a, b) => a + b) /
        totalPredictions;

    final qualityDistribution = <String, int>{};
    for (var prediction in history) {
      final quality = prediction['prediction_quality'] as String? ?? 'Unknown';
      qualityDistribution[quality] = (qualityDistribution[quality] ?? 0) + 1;
    }

    return {
      'total_predictions': totalPredictions,
      'avg_predicted_eggs': avgPredictedEggs.round(),
      'avg_score': avgScore.round(),
      'quality_distribution': qualityDistribution,
    };
  }

  /// Delete prediction history for the current user
  Future<void> clearPredictionHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in');
    }

    try {
      await _supabase
          .from('prediction_history')
          .delete()
          .eq('user_id', user.id);
    } catch (error) {
      debugPrint('Database error clearing prediction history: $error');
      rethrow;
    }
  }

  /// Get most recent prediction
  Future<Map<String, dynamic>?> getMostRecentPrediction() async {
    final history = await getPredictionHistory(limit: 1);
    if (history.isEmpty) return null;
    return history.first;
  }
}
