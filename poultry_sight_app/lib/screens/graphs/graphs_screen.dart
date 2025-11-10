import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:poultry_app/models/sensor_reading.dart';
import 'package:poultry_app/services/api/api_service.dart';
import 'package:poultry_app/services/api/prediction_history_service.dart';
import 'package:poultry_app/services/egg_prediction_service_hybrid.dart';
import 'package:poultry_app/services/user_profile_service.dart';
import 'package:poultry_app/screens/dashboard/dashboard_screen.dart';
import 'package:poultry_app/screens/history/history_screen.dart';
import 'package:poultry_app/screens/profile/profile_screen.dart';
import 'package:poultry_app/screens/prediction/manual_prediction_screen.dart';
import 'package:poultry_app/screens/profit/profit_screen.dart';

class GraphsScreen extends StatefulWidget {
  const GraphsScreen({super.key});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();

  // Static method to refresh graphs from other screens
  static void refreshGraphsIfActive() {
    // This will be set by the state when it's active
    _activeGraphsState?.refreshGraphs();
  }
}

// Static reference to active graphs state for cross-screen updates
_GraphsScreenState? _activeGraphsState;

class _GraphsScreenState extends State<GraphsScreen> {
  final ApiService _apiService = ApiService();
  final EggPredictionServiceHybrid _predictionService = EggPredictionServiceHybrid();
  final PredictionHistoryService _historyService = PredictionHistoryService();

  bool _isLoading = true;
  String? _errorMessage;
  List<List<FlSpot>> _chartData = [];
  String selectedTimePeriod = '1D';

  // Prediction data - stored continuously
  List<Map<String, dynamic>> _predictionHistory = [];
  bool _isPredicting = false;
  double _chickenCount = 0.0;
  double _avgConfidence = 0.0;
  int _totalPredictions = 0;

  @override
  void initState() {
    super.initState();
    _activeGraphsState = this;
    _initializePredictionModel();
    _loadChickenCount();
    _loadGraphData();
  }

  // Method to refresh graphs when manual prediction is made
  void refreshGraphs() {
    _loadPredictionHistory();
  }

  Future<void> _loadChickenCount() async {
    try {
      final UserProfileService profileService = UserProfileService();
      final count = await profileService.getChickenCount();
      setState(() {
        _chickenCount = count.toDouble();
      });
      debugPrint('✓ Loaded chicken count: ${_chickenCount.toInt()}');
    } catch (e) {
      debugPrint('⚠️ Error loading chicken count: $e');
      setState(() {
        _chickenCount = 100.0; // Default fallback
      });
    }
  }

  Future<void> _initializePredictionModel() async {
    try {
      await _predictionService.loadModel();
      debugPrint('✓ Prediction service ready');
    } catch (e) {
      debugPrint('❌ Failed to load prediction service: $e');
    }
  }

  Future<void> _loadPredictionHistory() async {
    try {
      final history = await _historyService.getPredictionHistory(limit: 50);

      if (history.isNotEmpty) {
        List<Map<String, dynamic>> formattedHistory = [];
        List<double> confidenceScores = [];

        for (var prediction in history) {
          final predictedEggs = (prediction['predicted_eggs'] as int?) ?? 0;
          final confidence = (prediction['prediction_confidence'] as double?) ?? 0.0;

          formattedHistory.add({
            'timestamp': prediction['created_at'],
            'eggs': predictedEggs,
            'confidence': confidence,
            'temperature': (prediction['temperature'] as num?)?.toDouble() ?? 0.0,
            'humidity': (prediction['humidity'] as num?)?.toDouble() ?? 0.0,
            'ammonia': (prediction['ammonia'] as num?)?.toDouble() ?? 0.0,
            'light': (prediction['light_intensity'] as num?)?.toDouble() ?? 0.0,
          });

          confidenceScores.add(confidence);
        }

        setState(() {
          _predictionHistory = formattedHistory;
          _totalPredictions = _predictionHistory.length;

          // Calculate average confidence from all stored predictions
          if (_predictionHistory.isNotEmpty) {
            _avgConfidence = _predictionHistory
                .map((p) => p['confidence'] as double)
                .reduce((a, b) => a + b) / _predictionHistory.length;
          }
        });

        debugPrint('✓ Loaded ${_predictionHistory.length} predictions from history');
      }
    } catch (e) {
      debugPrint('❌ Error loading prediction history: $e');
    }
  }

  Future<void> _loadGraphData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load prediction history first
      await _loadPredictionHistory();

      // Try to load sensor data for environmental metrics chart
      try {
        final readingsData = await _apiService.getSensorReadings(
          selectedTimePeriod,
        );

        if (readingsData.isNotEmpty) {
          final readings = readingsData
              .map((data) => SensorReading.fromMap(data))
              .toList();

          List<FlSpot> tempData = [];
          List<FlSpot> humidityData = [];
          List<FlSpot> ammoniaData = [];
          List<FlSpot> lightData = [];

          for (int i = 0; i < readings.length; i++) {
            final reading = readings[i];
            tempData.add(FlSpot(i.toDouble(), reading.temperature));
            humidityData.add(FlSpot(i.toDouble(), reading.humidity));
            ammoniaData.add(FlSpot(i.toDouble(), reading.ammonia));
            lightData.add(FlSpot(i.toDouble(), reading.lightIntensity));
          }

          setState(() {
            _chartData = [tempData, humidityData, ammoniaData, lightData];
          });
        } else {
          // No sensor data, but we still have prediction history
          setState(() {
            _chartData = [];
          });
        }
      } catch (sensorError) {
        debugPrint('⚠️ Could not load sensor data: $sensorError');
        // Continue without sensor data - prediction history is still available
        setState(() {
          _chartData = [];
        });
      }

      setState(() {
        _isLoading = false;
      });

      // Wait for prediction service to be ready
      int retries = 0;
      while (!_predictionService.isModelLoaded && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      if (_predictionService.isModelLoaded && _chartData.isNotEmpty) {
        await _generatePredictions(_chartData.isNotEmpty ?
          _chartData[0].map((spot) => SensorReading(
            temperature: spot.y,
            humidity: _chartData[1][spot.x.toInt()].y,
            ammonia: _chartData[2][spot.x.toInt()].y,
            lightIntensity: _chartData[3][spot.x.toInt()].y,
          )).toList() : []);
      } else {
        debugPrint('⚠️ Prediction service not ready or no sensor data for live predictions');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
      debugPrint('❌ Error loading graph data: $e');
    }
  }

  Future<void> _generatePredictions(List<SensorReading> readings) async {
    debugPrint('\n🔍 === GRAPH SCREEN PREDICTION DEBUG ===');
    debugPrint('Model loaded: ${_predictionService.isModelLoaded}');
    debugPrint('Readings count: ${readings.length}');
    debugPrint('Chicken count: $_chickenCount');

    // Don't skip if model not loaded - try anyway since dashboard works
    setState(() {
      _isPredicting = true;
    });

    try {
      List<Map<String, dynamic>> newPredictions = [];
      List<double> confidenceScores = [];

      // Use chicken count or default
      final chickenCount = _chickenCount > 0 ? _chickenCount : 100.0;

      debugPrint(
        '📊 Generating predictions for ${readings.length} readings...',
      );
      debugPrint('🐔 Using chicken count: ${chickenCount.toInt()}\n');

      // Limit to last 20 readings to avoid timeout
      final readingsToProcess = readings.length > 20
          ? readings.sublist(readings.length - 20)
          : readings;

      debugPrint(
        'Processing ${readingsToProcess.length} readings (limited from ${readings.length})',
      );

      for (int i = 0; i < readingsToProcess.length; i++) {
        final reading = readingsToProcess[i];

        try {
          debugPrint(
            '📤 Prediction ${i + 1}/${readingsToProcess.length}: Calling API...',
          );

          final predictedEggs = await _predictionService.predictEggProduction(
            temperature: reading.temperature,
            humidity: reading.humidity,
            ammonia: reading.ammonia,
            lightIntensity: reading.lightIntensity,
            chickenCount: chickenCount,
          );

          double confidence = _predictionService.lastConfidenceScore;

          debugPrint(
            '✅ Prediction ${i + 1}: $predictedEggs eggs (${(confidence * 100).toStringAsFixed(1)}% confidence)',
          );

          newPredictions.add({
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'eggs': predictedEggs,
            'confidence': confidence,
            'temperature': reading.temperature,
            'humidity': reading.humidity,
            'ammonia': reading.ammonia,
            'light': reading.lightIntensity,
          });

          confidenceScores.add(confidence);
        } catch (e) {
          debugPrint('❌ Prediction ${i + 1} failed: $e');
          // Continue with next prediction instead of stopping
        }
      }

      // Add new predictions to history (keep last 50 predictions)
      setState(() {
        _predictionHistory.addAll(newPredictions);
        if (_predictionHistory.length > 50) {
          _predictionHistory = _predictionHistory.sublist(
            _predictionHistory.length - 50,
          );
        }

        // Calculate average confidence from all stored predictions
        if (_predictionHistory.isNotEmpty) {
          _avgConfidence =
              _predictionHistory
                  .map((p) => p['confidence'] as double)
                  .reduce((a, b) => a + b) /
              _predictionHistory.length;
        }

        _totalPredictions = _predictionHistory.length;
        _isPredicting = false;
      });

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ Generated ${newPredictions.length} new predictions');
      debugPrint('📊 Total stored predictions: $_totalPredictions');
      debugPrint(
        '📊 Average Confidence: ${(_avgConfidence * 100).toStringAsFixed(1)}%',
      );
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    } catch (e) {
      debugPrint('❌ Error generating predictions: $e');
      setState(() {
        _isPredicting = false;
      });
    }
  }

  Map<String, double> _getChartBoundaries() {
    if (_chartData.isEmpty) {
      return {'minX': 0, 'maxX': 5, 'minY': 0, 'maxY': 30};
    }

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    double maxX = 0;

    for (var series in _chartData) {
      for (var spot in series) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
        if (spot.x > maxX) maxX = spot.x;
      }
    }

    double range = maxY - minY;
    double padding = range * 0.1;

    return {
      'minX': 0,
      'maxX': maxX > 0 ? maxX : 5,
      'minY': (minY - padding).clamp(0, double.infinity),
      'maxY': maxY + padding,
    };
  }

  @override
  void dispose() {
    _activeGraphsState = null;
    _predictionService.dispose();
    super.dispose();
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
              child: RefreshIndicator(
                onRefresh: _loadGraphData,
                color: Colors.white,
                backgroundColor: const Color(0xFF4CAF50),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'lib/assets/images/poultry_app_logo.png',
                          width: 100,
                        ),
                      ),
                      const SizedBox(height: 25),

                      const Text(
                        'Metrics/Graphs',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Historical Production & Metrics Analysis',
                        style: TextStyle(
                          fontFamily: 'Urbanist',
                          fontSize: 15,
                          color: Color(0xFF5A5A5A),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4CAF50),
                          ),
                        )
                      else if (_errorMessage != null && _predictionHistory.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadGraphData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _buildSectionBadge('Model Performance'),
                        const SizedBox(height: 16),
                        _buildModelMetricsCard(),
                        const SizedBox(height: 32),

                        _buildSectionBadge('Egg Production Predictions'),
                        const SizedBox(height: 16),
                        _buildPredictionLineChart(),
                        const SizedBox(height: 32),

                        _buildSectionBadge('Environmental Metric'),
                        const SizedBox(height: 16),
                        _buildCombinedMetricsChart(),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            BottomNavigationBar(
              currentIndex: 3,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF4CAF50),
              unselectedItemColor: Colors.grey,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              type: BottomNavigationBarType.fixed,
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
                if (index == 3) return; // Current page

                switch (index) {
                  case 0:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardScreen(),
                      ),
                    );
                    break;
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

  Widget _buildSectionBadge(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Lexend',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildModelMetricsCard() {
    int confidencePercent = (_avgConfidence * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assessment,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prediction Performance',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Model Confidence: ${(_avgConfidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _predictionService.isModelLoaded
                      ? const Color(0xFF4CAF50)
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _predictionService.isModelLoaded
                          ? Icons.check_circle
                          : Icons.hourglass_empty,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _predictionService.isModelLoaded ? 'Active' : 'Loading',
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Predictions',
                  '$_totalPredictions',
                  Icons.trending_up,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                  'Confidence',
                  '$confidencePercent%',
                  Icons.verified,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 9,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionLineChart() {
    if (_predictionHistory.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isPredicting)
                const CircularProgressIndicator(color: Color(0xFF4CAF50))
              else
                const Text(
                  'No prediction data available yet',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      );
    }

    // Prepare data for line chart
    List<FlSpot> predictionSpots = [];
    for (int i = 0; i < _predictionHistory.length; i++) {
      predictionSpots.add(
        FlSpot(i.toDouble(), (_predictionHistory[i]['eggs'] as int).toDouble()),
      );
    }

    final maxEggs = _predictionHistory
        .map((e) => e['eggs'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prediction Trend',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.api, size: 14, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Text(
                      'Live Updates',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: predictionSpots,
                    color: const Color(0xFF4CAF50),
                    isCurved: true,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF4CAF50),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => const Color(0xFF4CAF50),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final prediction = _predictionHistory[spot.x.toInt()];
                        final confidence =
                            (prediction['confidence'] as double) * 100;
                        return LineTooltipItem(
                          '${spot.y.toInt()} eggs\n${confidence.toStringAsFixed(0)}% confidence',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxEggs / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _predictionHistory.length > 10
                          ? (_predictionHistory.length / 5).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < _predictionHistory.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '#${value.toInt() + 1}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                minX: 0,
                maxX: (_predictionHistory.length - 1).toDouble(),
                minY: 0,
                maxY: maxEggs * 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Showing last ${_predictionHistory.length} predictions',
              style: const TextStyle(
                fontFamily: 'Lexend',
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedMetricsChart() {
    if (_chartData.isEmpty || _chartData.length < 3) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No data available for combined metrics',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final boundaries = _getChartBoundaries();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metrics Evolution',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: ['1D', '1W', '1M', 'Max'].map((period) {
              final isSelected = selectedTimePeriod == period;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedTimePeriod = period;
                    });
                    _loadGraphData();
                  },
                  child: Text(
                    period,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? const Color(0xFF4CAF50) : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData[0],
                    color: const Color(0xFF4A90E2),
                    isCurved: true,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: _chartData[1],
                    color: const Color(0xFFFF8C42),
                    isCurved: true,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: _chartData[2],
                    color: const Color(0xFFC77DFF),
                    isCurved: true,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  if (_chartData.length > 3)
                    LineChartBarData(
                      spots: _chartData[3],
                      color: const Color(0xFF8B7355),
                      isCurved: true,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        String tooltipText = '';
                        Color textColor;
                        if (spot.barIndex == 0) {
                          tooltipText = 'Temp: ${spot.y.toStringAsFixed(1)}°C';
                          textColor = const Color(0xFF4A90E2);
                        } else if (spot.barIndex == 1) {
                          tooltipText =
                              'Humidity: ${spot.y.toStringAsFixed(1)}%';
                          textColor = const Color(0xFFFF8C42);
                        } else if (spot.barIndex == 2) {
                          tooltipText = 'CO2: ${spot.y.toStringAsFixed(1)} ppm';
                          textColor = const Color(0xFFC77DFF);
                        } else {
                          tooltipText =
                              'Light: ${spot.y.toStringAsFixed(1)} lux';
                          textColor = const Color(0xFF8B7355);
                        }
                        return LineTooltipItem(
                          tooltipText,
                          TextStyle(
                            fontFamily: 'Lexend',
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      (boundaries['maxY']! - boundaries['minY']!) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      reservedSize: 22,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            color: Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      reservedSize: 32,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: boundaries['minX']!,
                maxX: boundaries['maxX']!,
                minY: boundaries['minY']!,
                maxY: boundaries['maxY']!,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Temperature', const Color(0xFF4A90E2)),
              _buildLegendItem('Humidity', const Color(0xFFFF8C42)),
              _buildLegendItem('CO2/Ammonia', const Color(0xFFC77DFF)),
              _buildLegendItem('Lights Intensity', const Color(0xFF8B7355)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 11,
            color: Color(0xFF3A3A3A),
          ),
        ),
      ],
    );
  }
}
