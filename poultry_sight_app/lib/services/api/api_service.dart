import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ApiService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;
  
  static const Map<String, dynamic> fallbackSensorData = {
    'id': 'fallback-id',
    'device_id': 'offline-device',
    'egg_production': 0.0,
    'temperature': 0.0,
    'humidity': 0.0,
    'light_intensity': 0.0,
    'amount_of_chicken': 0.0,
    'ammonia': 0.0,
    'received_at': null,
  };

  /// Sensor Data Methods

  /// Fetches data from the Supabase database.
  Future<Map<String, dynamic>> getSensorData({BuildContext? context}) async {
    try {
      // Check internet connectivity first
      final bool hasConnection = await hasInternetConnection();

      if (!hasConnection) {
        // Try to get stored sensor data when offline
        final storedData = await _getStoredSensorData();
        if (storedData != null) {
          if (context != null) {
            showSnackBar(
              context,
              'No internet connection. Using last stored sensor data.',
              isError: false,
            );
          }
          return storedData;
        } else {
          if (context != null) {
            showSnackBar(
              context,
              'No internet connection. Showing default values.',
              isError: true,
            );
          }
          return fallbackSensorData;
        }
      }

      // Attempt to fetch data from Supabase
      final response = await _supabase
          .from('environmental_data') // Fixed table name
          .select()
          .order('created_at', ascending: false) // Fixed column name
          .limit(1)
          .maybeSingle();

      if (response == null) {
        if (context != null) {
          showSnackBar(
            context,
            'No sensor data available. Showing default values.',
            isError: true,
          );
        }
        return fallbackSensorData;
      }

      // Store the fetched data locally for offline use
      await _storeSensorData(response);

      // Success - show success message if context provided
      if (context != null) {
        showSnackBar(context, 'Sensor data updated successfully!');
      }

      return response;
    } catch (e) {
      debugPrint('Error fetching sensor data: $e');

      String errorMessage = 'Failed to fetch sensor data';

      if (e is PostgrestException) {
        errorMessage = 'Database error: ${e.message}';
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        errorMessage = 'Network error: Please check your connection';
      }

      if (context != null) {
        showSnackBar(context, errorMessage, isError: true);
      }

      // Try to return stored data if available, otherwise fallback
      final storedData = await _getStoredSensorData();
      if (storedData != null) {
        return storedData;
      }

      // Return fallback data instead of throwing exception
      return fallbackSensorData;
    }
  }

  // Method specifically for pull-to-refresh
  Future<Map<String, dynamic>> refreshSensorData(BuildContext context) async {
    try {
      showSnackBar(context, 'Refreshing sensor data...');
      return await getSensorData(context: context);
    } catch (e) {
      showSnackBar(context, 'Failed to refresh data', isError: true);
      return fallbackSensorData;
    }
  }

  /// Store sensor data locally for offline use
  Future<void> _storeSensorData(Map<String, dynamic> sensorData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sensorDataJson = jsonEncode(sensorData);
      await prefs.setString('last_sensor_data', sensorDataJson);
      await prefs.setString('last_sensor_data_timestamp', DateTime.now().toIso8601String());
      debugPrint('✅ Sensor data stored locally for offline use');
    } catch (e) {
      debugPrint('❌ Error storing sensor data locally: $e');
    }
  }

  /// Retrieve stored sensor data for offline use
  Future<Map<String, dynamic>?> _getStoredSensorData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sensorDataJson = prefs.getString('last_sensor_data');
      if (sensorDataJson != null) {
        final sensorData = jsonDecode(sensorDataJson) as Map<String, dynamic>;
        debugPrint('✅ Retrieved stored sensor data for offline use');
        return sensorData;
      }
    } catch (e) {
      debugPrint('❌ Error retrieving stored sensor data: $e');
    }
    return null;
  }

  /// Chart fetch
  Future<List<Map<String, dynamic>>> getHistoricalData(
    String timePeriod,
  ) async {
    DateTime startTime;
    final now = DateTime.now();

    switch (timePeriod) {
      case '1M':
        startTime = now.subtract(const Duration(days: 30));
        break;
      case '1Y':
        startTime = now.subtract(const Duration(days: 365));
        break;
      case 'Max':
        // Fetch all data (or up to a reasonable limit)
        startTime = DateTime(2000);
        break;
      case '1D':
      default:
        startTime = now.subtract(const Duration(days: 1));
        break;
    }

    final response = await _supabase
        .from('environmental_data')
        .select()
        .gte('created_at', startTime.toIso8601String())
        .order('created_at', ascending: true);

    return response;
  }

  /// Get sensor readings for graphs (returns List<Map<String, dynamic>>)
  Future<List<Map<String, dynamic>>> getSensorReadings(
    String timePeriod,
  ) async {
    return await getHistoricalData(timePeriod);
  }

  /// History Data Table Methods

  Future<List<Map<String, dynamic>>> getHistoryData() async {
    try {
      final response = await _supabase
          .from('history')
          .select()
          .order('timestamp', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch history data: $e');
    }
  }

  /// Utilities

  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Try to verify actual internet connection
      try {
        final bool hasInternet =
            await InternetConnectionChecker().hasConnection;
        return hasInternet;
      } catch (e) {
        // If InternetConnectionChecker fails (e.g., InternetAddress not available),
        // fall back to connectivity check only
        debugPrint(
          'Warning: InternetConnectionChecker failed, using connectivity only: $e',
        );
        return connectivityResult != ConnectivityResult.none;
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      // Assume connected if we can't determine
      return true;
    }
  }

  // Show snackbar helper method
  void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Ensures the user is authenticated before making API calls.
  void ensureAuthenticated() {
    if (_supabase.auth.currentUser == null) {
      throw Exception('User not authenticated. Please sign in.');
    }
  }

  /// Subscribe to realtime updates for sensor data
  /// This will automatically update the UI when new sensor readings are inserted
  void subscribeToRealtimeUpdates(Function(Map<String, dynamic>) onUpdate) {
    // Unsubscribe from previous channel if exists
    unsubscribeFromRealtimeUpdates();

    print('🔄 Subscribing to realtime sensor data updates...');

    // Create a channel for environmental_data table
    _realtimeChannel = _supabase
        .channel('environmental_data_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'environmental_data',
          callback: (payload) {
            print('📊 New sensor data received via realtime!');
            print('   Temperature: ${payload.newRecord['temperature']}°C');
            print('   Humidity: ${payload.newRecord['humidity']}%');
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();

    print('✅ Realtime subscription active');
  }

  /// Unsubscribe from realtime updates
  void unsubscribeFromRealtimeUpdates() {
    if (_realtimeChannel != null) {
      print('🔌 Unsubscribing from realtime updates...');
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      print('✅ Realtime subscription closed');
    }
  }

  /// Check if currently subscribed to realtime updates
  bool get isSubscribedToRealtime => _realtimeChannel != null;
}
