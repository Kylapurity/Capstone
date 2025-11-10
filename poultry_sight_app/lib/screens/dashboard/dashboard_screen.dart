import 'package:poultry_app/models/sensor_reading.dart';
import 'package:poultry_app/services/api/api_service.dart';
import 'package:poultry_app/services/notifications/notifications_service.dart';
import 'package:poultry_app/services/email_notification_service.dart';
import 'package:poultry_app/services/egg_prediction_service_hybrid.dart';
import 'package:poultry_app/services/user_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:poultry_app/screens/history/history_screen.dart';
import 'package:poultry_app/screens/graphs/graphs_screen.dart';
import 'package:poultry_app/screens/prediction/manual_prediction_screen.dart';
import 'package:poultry_app/screens/profile/profile_screen.dart';
import 'package:poultry_app/screens/profit/profit_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();
  final EmailNotificationService _emailService = EmailNotificationService();
  final EggPredictionServiceHybrid _predictionService = EggPredictionServiceHybrid();
  final UserProfileService _profileService = UserProfileService();

  bool _isLoading = true;
  String? _errorMessage;
  SensorReading? _latestReading;
  List<List<FlSpot>> _chartData = [];
  bool _isConnected = true;


  // Chicken count (loaded from user profile)
  double _chickenCount = 100.0;

  // Health metrics
  String _mortalityRate = 'Low';
  String _weightGain = 'High';

  // Threshold values for egg production monitoring
  final Map<String, Map<String, double>> thresholds = {
    'temperature': {'min': 18.0, 'max': 30.0},
    'humidity': {'min': 50.0, 'max': 70.0},
    'ammonia': {'min': 0.0, 'max': 25.0},
    'light_intensity': {
      'min': 50.0,
      'max': 800.0,
    }, // Updated: 0-50 lux is critical
  };

  final Map<String, Map<String, String>> activityThreshold = {
    'activity': {'min': "Low Activity", 'max': "High Activity"},
  };

  // Track last alert to prevent spam
  String? _lastAlertMessage;
  DateTime? _lastAlertTime;

  @override
  void initState() {
    super.initState();
    _notificationService.init();
    _initializeApp();
  }

  // Initialize app components in correct order
  Future<void> _initializeApp() async {
    // Load all data (sensor data only)
    await _loadAllData();

    // Subscribe to realtime updates
    _subscribeToRealtimeUpdates();
  }

  /// Subscribe to realtime sensor data updates
  void _subscribeToRealtimeUpdates() {
    // Skip realtime on web - Supabase Realtime works better on native platforms
    if (kIsWeb) {
      print('⚠️ Realtime subscriptions disabled on web platform');
      return;
    }

    _apiService.subscribeToRealtimeUpdates((newData) {
      print('🔄 Realtime environmental data received!');
      print(
        '   📊 New readings - Temp: ${newData['temperature']}°C, Humidity: ${newData['humidity']}%',
      );
      print(
        '   📊 Ammonia: ${newData['ammonia']}ppm, Light: ${newData['light_intensity']}lux',
      );

      // Update sensor reading immediately
      setState(() {
        _latestReading = SensorReading.fromMap(newData);
      });

      // Check thresholds for alerts
      _checkThresholds();
    });
  }


  // Calculate health metrics based on environmental conditions
  void _calculateHealthMetrics() {
    if (_latestReading == null) return;

    final temp = _latestReading!.temperature;
    final humidity = _latestReading!.humidity;
    final ammonia = _latestReading!.ammonia;
    final light = _latestReading!.lightIntensity;

    // Calculate Mortality Rate (lower is better)
    // High mortality when conditions are poor
    int mortalityScore = 0;

    // CRITICAL: Light intensity is essential for chicken survival and behavior
    // 0 lux = complete darkness = severe stress and inability to function
    if (light <= 0.0) {
      mortalityScore += 100; // EMERGENCY - complete darkness
    } else if (light < 50.0) {
      mortalityScore += 60; // CRITICAL - insufficient light
    } else if (light < 100.0) {
      mortalityScore += 30; // Suboptimal light
    }

    // Temperature impact (critical factor)
    if (temp < 18.0 || temp > 30.0) {
      mortalityScore += 40; // Critical temperature = high mortality
    } else if (temp < 20.0 || temp > 28.0) {
      mortalityScore += 20; // Suboptimal temperature
    }

    // Ammonia impact (very critical)
    if (ammonia > 25.0) {
      mortalityScore += 50; // Dangerous ammonia = very high mortality
    } else if (ammonia > 20.0) {
      mortalityScore += 30;
    } else if (ammonia > 15.0) {
      mortalityScore += 10;
    }

    // Humidity impact
    if (humidity < 50.0 || humidity > 70.0) {
      mortalityScore += 15;
    }

    setState(() {
      // Determine mortality rate with critical threshold
      if (mortalityScore >= 60) {
        _mortalityRate = 'Critical ⚠️';
      } else if (mortalityScore > 30) {
        _mortalityRate = 'High';
      } else {
        _mortalityRate = 'Low';
      }
    });

    // Calculate Weight Gain (higher is better)
    // Good weight gain when conditions are optimal
    int weightGainScore = 100;

    // CRITICAL: Light is essential for feeding, activity, and circadian rhythm
    // Complete darkness prevents normal feeding behavior
    if (light <= 0.0) {
      weightGainScore -= 100; // EMERGENCY - no feeding possible
    } else if (light < 50.0) {
      weightGainScore -= 70; // CRITICAL - severely reduced feeding
    } else if (light < 100.0) {
      weightGainScore -= 40; // Suboptimal light reduces feeding
    } else if (light >= 300.0 && light <= 600.0) {
      weightGainScore += 15; // Optimal light boosts weight gain and activity
    }

    // Temperature impact on weight gain
    if (temp < 18.0 || temp > 30.0) {
      weightGainScore -= 40;
    } else if (temp < 20.0 || temp > 28.0) {
      weightGainScore -= 20;
    }

    // Ammonia reduces appetite and weight gain
    if (ammonia > 25.0) {
      weightGainScore -= 50;
    } else if (ammonia > 20.0) {
      weightGainScore -= 30;
    } else if (ammonia > 15.0) {
      weightGainScore -= 15;
    }

    // Humidity impact
    if (humidity < 50.0 || humidity > 70.0) {
      weightGainScore -= 15;
    }

    setState(() {
      // Determine weight gain with critical threshold
      if (weightGainScore <= 20) {
        _weightGain = 'Critical ⚠️';
      } else if (weightGainScore >= 60) {
        _weightGain = 'High';
      } else {
        _weightGain = 'Low';
      }
    });

    print('📊 Health Metrics Updated:');
    print('   Mortality Rate: $_mortalityRate (Score: $mortalityScore)');
    print('   Weight Gain: $_weightGain (Score: $weightGainScore)');
    print('   🌞 Light Intensity: ${light.toStringAsFixed(1)} lux');
  }

  void _checkThresholds() {
    if (_latestReading == null) return;

    // Update health metrics
    _calculateHealthMetrics();

    String? alertMessage;
    Color? alertColor = Colors.red;
    String? alertType;
    String? severity;

    // CHECK LIGHT INTENSITY FIRST - It's the most critical factor
    final light = _latestReading!.lightIntensity;
    if (light <= 0.0) {
      alertMessage =
          '🚨 EMERGENCY: Complete darkness (0.0 lux). Turn on lights immediately!';
      alertColor = Colors.red;
      alertType = 'light';
      severity = 'critical';

      _notificationService.showNotification(
        '🚨 EMERGENCY: No Light!',
        'Light intensity is 0 lux. Chickens cannot see, eat, or move. Turn on lights immediately!',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'light',
        currentValue: light,
        thresholdValue: 50.0,
        severity: severity,
      );
    } else if (light < 50.0 && alertMessage == null) {
      alertMessage =
          '⚠️ Light intensity is critical (${light.toStringAsFixed(1)} lux). Turn on lights urgently.';
      alertColor = Colors.orange;
      alertType = 'light';
      severity = 'critical';

      _notificationService.showNotification(
        '⚠️ Critical Light Level',
        'Light intensity is ${light.toStringAsFixed(1)} lux. Insufficient for normal chicken behavior.',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'light',
        currentValue: light,
        thresholdValue: 50.0,
        severity: severity,
      );
    }

    // Check all conditions and find the most critical issue
    final temp = _latestReading!.temperature;
    final tempThreshold = thresholds['temperature']!;
    if (temp > tempThreshold['max']! && alertMessage == null) {
      alertMessage =
          '⚠️ Temperature is too high (${temp.toStringAsFixed(1)}°C). Adjust ventilation.';
      alertType = 'temperature';
      severity = 'high';

      // Send notifications
      _notificationService.showNotification(
        'Temperature Alert',
        'Temperature too high: ${temp.toStringAsFixed(1)}°C. Adjust ventilation immediately.',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'temperature',
        currentValue: temp,
        thresholdValue: tempThreshold['max']!,
        severity: severity,
      );
    } else if (temp < tempThreshold['min']! && alertMessage == null) {
      alertMessage =
          '⚠️ Temperature is too low (${temp.toStringAsFixed(1)}°C). Add heating.';
      alertType = 'temperature';
      severity = 'low';

      _notificationService.showNotification(
        'Temperature Alert',
        'Temperature too low: ${temp.toStringAsFixed(1)}°C. Add heating immediately.',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'temperature',
        currentValue: temp,
        thresholdValue: tempThreshold['min']!,
        severity: severity,
      );
    }

    final humidity = _latestReading!.humidity;
    final humidityThreshold = thresholds['humidity']!;
    if (humidity > humidityThreshold['max']! && alertMessage == null) {
      alertMessage =
          '⚠️ Humidity is too high (${humidity.toStringAsFixed(1)}%). Improve ventilation.';
      alertType = 'humidity';
      severity = 'high';

      _notificationService.showNotification(
        'Humidity Alert',
        'Humidity too high: ${humidity.toStringAsFixed(1)}%. Improve ventilation.',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'humidity',
        currentValue: humidity,
        thresholdValue: humidityThreshold['max']!,
        severity: severity,
      );
    } else if (humidity < humidityThreshold['min']! && alertMessage == null) {
      alertMessage =
          '⚠️ Humidity is too low (${humidity.toStringAsFixed(1)}%). Add moisture.';
      alertType = 'humidity';
      severity = 'low';

      _notificationService.showNotification(
        'Humidity Alert',
        'Humidity too low: ${humidity.toStringAsFixed(1)}%. Add moisture.',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'humidity',
        currentValue: humidity,
        thresholdValue: humidityThreshold['min']!,
        severity: severity,
      );
    }

    final ammonia = _latestReading!.ammonia;
    final ammoniaThreshold = thresholds['ammonia']!;
    if (ammonia > ammoniaThreshold['max']! && alertMessage == null) {
      alertMessage =
          '🚨 Ammonia level is critical (${ammonia.toStringAsFixed(1)} ppm). Clean coop immediately!';
      alertColor = Colors.deepOrange;
      alertType = 'ammonia';
      severity = 'critical';

      _notificationService.showNotification(
        '🚨 CRITICAL: High Ammonia',
        'Ammonia level is ${ammonia.toStringAsFixed(1)} ppm. Clean coop immediately!',
      );
      _emailService.sendEnvironmentalAlert(
        alertType: 'ammonia',
        currentValue: ammonia,
        thresholdValue: ammoniaThreshold['max']!,
        severity: severity,
      );
    }

    final activity = _latestReading?.activity;
    if (activity == activityThreshold['activity']?['max'] &&
        alertMessage == null) {
      alertMessage = '✅ Egg Production is High ($activity)!';
      alertColor = Colors.green;
    } else if (activity == activityThreshold['activity']?['min'] &&
        alertMessage == null) {
      alertMessage = '⚠️ Egg Production is Low ($activity).';
    }

    // Show notification snackbar if there's an alert
    if (alertMessage != null && mounted) {
      _showAlertSnackBar(alertMessage, alertColor);
    }
  }

  void _showAlertSnackBar(String message, Color color) {
    // Prevent duplicate alerts (show same message only once per minute)
    final now = DateTime.now();
    if (_lastAlertMessage == message &&
        _lastAlertTime != null &&
        now.difference(_lastAlertTime!) < const Duration(minutes: 1)) {
      return; // Skip duplicate alert
    }

    // Update tracking
    _lastAlertMessage = message;
    _lastAlertTime = now;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green
                  ? Icons.check_circle
                  : color == Colors.deepOrange
                  ? Icons.error
                  : Icons.warning,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _loadChickenCount() async {
    try {
      final count = await _profileService.getChickenCount();
      setState(() {
        _chickenCount = count.toDouble();
      });
    } catch (e) {
      debugPrint('⚠️ Error loading chicken count: $e');
      // Keep default value
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load chicken count first
      await _loadChickenCount();

      final hasConnection = await _apiService.hasInternetConnection();
      final dataMap = await _apiService.getSensorData(context: context);
      final reading = SensorReading.fromMap(dataMap);
      final historicalData = await _apiService.getHistoricalData('1D');

      setState(() {
        _latestReading = reading;
        _chartData = _prepareChartData(historicalData);
        _isLoading = false;
        _isConnected = hasConnection;
      });

      _checkThresholds();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data. Please pull to refresh.';
        _isLoading = false;
      });
    }
  }

  List<List<FlSpot>> _prepareChartData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];

    final List<FlSpot> tempData = [];
    final List<FlSpot> humidityData = [];
    final List<FlSpot> ammoniaData = [];
    final List<FlSpot> lightData = [];

    for (int i = 0; i < data.length; i++) {
      final record = data[i];
      final xValue = i.toDouble();
      tempData.add(FlSpot(xValue, record['temperature']?.toDouble() ?? 0));
      humidityData.add(FlSpot(xValue, record['humidity']?.toDouble() ?? 0));
      ammoniaData.add(FlSpot(xValue, record['ammonia']?.toDouble() ?? 0));
      lightData.add(FlSpot(xValue, record['light_intensity']?.toDouble() ?? 0));
    }

    return [tempData, humidityData, ammoniaData, lightData];
  }

  @override
  void dispose() {
    // Unsubscribe from realtime updates
    _apiService.unsubscribeFromRealtimeUpdates();

    _predictionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAllData,
                    color: Colors.white,
                    backgroundColor: const Color(0xFF5E4935),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22.0, 8.0, 22.0, 22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with logo and connection status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Center(
                                child: Image.asset(
                                  'lib/assets/images/Background.png',
                                  width: 100,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isConnected
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isConnected
                                        ? Colors.green
                                        : Colors.red,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _isConnected
                                            ? Colors.green
                                            : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isConnected ? 'Connected' : 'Offline',
                                      style: TextStyle(
                                        fontFamily: 'Lexend',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _isConnected
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Dashboard title
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 2),

                          const Text(
                            'Total Production and Metrics',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 15,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Environmental Conditions badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Environmental Conditions',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Temperature and Humidity cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleCard(
                                  icon: Icons.thermostat,
                                  label: 'TEMPERATURE',
                                  value: _isLoading
                                      ? '24.5'
                                      : (_latestReading?.temperature
                                                .toStringAsFixed(1) ??
                                            '24.5'),
                                  unit: '°C',
                                  valueColor:
                                      _latestReading != null &&
                                          _latestReading!.temperature >
                                              thresholds['temperature']!['max']!
                                      ? Colors.red
                                      : const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleCard(
                                  icon: Icons.water_drop,
                                  label: 'HUMIDITY',
                                  value: _isLoading
                                      ? '62.3'
                                      : (_latestReading?.humidity
                                                .toStringAsFixed(1) ??
                                            '62.3'),
                                  unit: '%',
                                  valueColor:
                                      _latestReading != null &&
                                          _latestReading!.humidity >
                                              thresholds['humidity']!['max']!
                                      ? Colors.red
                                      : const Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Ammonia and Light Intensity cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSimpleCard(
                                  icon: Icons.cloud,
                                  label: 'AMMONIA/CO₂',
                                  value: _isLoading
                                      ? '18.7'
                                      : (_latestReading?.ammonia
                                                .toStringAsFixed(1) ??
                                            '18.7'),
                                  unit: 'ppm',
                                  valueColor:
                                      _latestReading != null &&
                                          _latestReading!.ammonia >
                                              thresholds['ammonia']!['max']!
                                      ? Colors.red
                                      : const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSimpleCard(
                                  icon: Icons.wb_sunny,
                                  label: 'LIGHT INTENSITY',
                                  value: _isLoading
                                      ? '450.2'
                                      : (_latestReading?.lightIntensity
                                                .toStringAsFixed(1) ??
                                            '450.2'),
                                  unit: 'lux',
                                  valueColor: const Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Health Metrics badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Health Metrics',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Mortality Rate and Weight Gain cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildHealthMetricCard(
                                  label: 'MORTALITY RATE',
                                  value: _mortalityRate,
                                  isHigh: _mortalityRate == 'High',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildHealthMetricCard(
                                  label: 'WEIGHT GAIN',
                                  value: _weightGain,
                                  isHigh: _weightGain == 'High',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
                // Bottom Navigation Bar
                BottomNavigationBar(
                  currentIndex: 0,
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
                    if (index == 0) return;

                    switch (index) {
                      case 1:
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManualPredictionScreen(),
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
            // Floating Prediction Button
            Positioned(
              right: 20,
              bottom: 90,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManualPredictionScreen(),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF4CAF50),
                child: const Icon(
                  Icons.calculate,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard({
    required IconData icon,
    required String label,
    required String value,
    String unit = '',
    Color valueColor = const Color(0xFF4CAF50),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 22, color: Colors.black),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: valueColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 2.0),
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetricCard({
    required String label,
    required String value,
    required bool isHigh,
  }) {
    // High = Green (trending up), Low = Red (trending down)
    final displayColor = isHigh ? const Color(0xFF4CAF50) : Colors.red;
    final bgColor = isHigh ? Colors.green.shade50 : Colors.red.shade50;
    final icon = isHigh ? Icons.trending_up : Icons.trending_down;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 26, color: displayColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: displayColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isHigh ? Icons.check_circle : Icons.warning,
                        size: 14,
                        color: displayColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
