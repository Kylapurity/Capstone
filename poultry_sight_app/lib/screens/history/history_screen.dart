import 'package:flutter/material.dart';
import 'package:poultry_app/screens/dashboard/dashboard_screen.dart';
import 'package:poultry_app/screens/graphs/graphs_screen.dart';
import 'package:poultry_app/screens/prediction/manual_prediction_screen.dart';
import 'package:poultry_app/screens/profile/profile_screen.dart';
import 'package:poultry_app/screens/profit/profit_screen.dart';
import 'package:poultry_app/services/api/api_service.dart';
import 'package:poultry_app/services/api/prediction_history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  final PredictionHistoryService _predictionHistoryService = PredictionHistoryService();
  
  // Track which sections are expanded
  bool isPredictionHistoryExpanded = true;
  bool isPastReadingsExpanded = true;

  // Data holders (will be populated from Supabase)
  List<Map<String, dynamic>> predictionHistoryData = [];
  List<Map<String, dynamic>> pastReadingsData = [];

  // Profit summary data
  double totalProfit = 0.0;
  int totalPredictions = 0;
  double averageProfit = 0.0;

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Load prediction history
      final predictionHistory = await _predictionHistoryService.getPredictionHistory(limit: 50);
      
      // Convert prediction history to display format
      final List<Map<String, dynamic>> formattedPredictions = predictionHistory.map((prediction) {
        final eggs = prediction['predicted_eggs']?.toString() ?? 'N/A';
        final quality = prediction['prediction_quality']?.toString() ?? 'Unknown';
        final temp = prediction['temperature']?.toStringAsFixed(1) ?? 'N/A';
        final humidity = prediction['humidity']?.toStringAsFixed(1) ?? 'N/A';
        final profit = prediction['profit_score'] != null
            ? 'RWF ${(prediction['profit_score'] as num).toStringAsFixed(0)}'
            : 'N/A';
        final createdAt = prediction['created_at'] as String?;

        return {
          'type': 'prediction',
          'title': 'Egg Production Prediction',
          'description': '$eggs eggs predicted (Quality: $quality) - Profit: $profit - Temp: ${temp}°C, Humidity: ${humidity}%',
          'created_at': createdAt,
          'predicted_eggs': eggs,
          'quality': quality,
          'temperature': temp,
          'humidity': humidity,
          'profit': profit,
        };
      }).toList();

      // Load only most recent sensor data (last 5 readings)
      final sensorData = await _apiService.getHistoricalData('1D');
      
      // Convert sensor data to history format
      final List<Map<String, dynamic>> readings = sensorData.map((reading) {
        final temp = reading['temperature']?.toString() ?? 'N/A';
        final humidity = reading['humidity']?.toString() ?? 'N/A';
        final ammonia = reading['ammonia']?.toString() ?? 'N/A';
        final light = reading['light_intensity']?.toString() ?? 'N/A';
        final createdAt = reading['created_at'] as String?;
        
        return {
          'type': 'recording',
          'title': 'Sensor Reading',
          'description': 'Temp: ${temp}°C, Humidity: ${humidity}%, Ammonia: ${ammonia}ppm, Light: ${light}lux',
          'created_at': createdAt,
          'temperature': temp,
          'humidity': humidity,
          'ammonia': ammonia,
          'light_intensity': light,
        };
      }).toList();

      // Calculate profit summary from all predictions (not just the 5 displayed)
      double calculatedTotalProfit = 0.0;
      int predictionCount = 0;

      for (var prediction in predictionHistory) {
        final profitScore = prediction['profit_score'];
        if (profitScore != null) {
          calculatedTotalProfit += (profitScore as num).toDouble();
          predictionCount++;
        }
      }

      final calculatedAverageProfit = predictionCount > 0 ? calculatedTotalProfit / predictionCount : 0.0;

      setState(() {
        // Show only most recent 5 predictions
        predictionHistoryData = formattedPredictions.take(5).toList();

        // Show only most recent 5 sensor readings
        pastReadingsData = readings.take(5).toList();

        // Update profit summary
        totalProfit = calculatedTotalProfit;
        totalPredictions = predictionCount;
        averageProfit = calculatedAverageProfit;

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load history: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Logo
              Center(
                child: Image.asset(
                  'lib/assets/images/poultry_app_logo.png',
                  width: 100,
                ),
              ),
              const SizedBox(height: 25),

              // History Title
              const Text(
                'History',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A3A3A),
                ),
              ),

              // Subtitle with refresh option
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Here is a summary history this week',
                      style: TextStyle(
                        fontFamily: 'Urbanist',
                        fontSize: 15,
                        color: Color(0xFF5A5A5A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadHistoryData,
                    color: const Color(0xFF4CAF50),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Loading indicator
              if (isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
              else if (error != null)
                Center(
                  child: Column(
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: _loadHistoryData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                // Profit Summary Section
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROFIT SUMMARY',
                        style: TextStyle(
                          fontFamily: 'Urbanist',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildProfitMetric(
                            'Total Profit',
                            'RWF ${totalProfit.toStringAsFixed(0)}',
                            Icons.account_balance_wallet,
                          ),
                          _buildProfitMetric(
                            'Predictions',
                            totalPredictions.toString(),
                            Icons.analytics,
                          ),
                          _buildProfitMetric(
                            'Avg Profit',
                            'RWF ${averageProfit.toStringAsFixed(0)}',
                            Icons.trending_up,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Prediction History Section
                _buildSection(
                  title: 'PREDICTION HISTORY',
                  items: predictionHistoryData,
                  isExpanded: isPredictionHistoryExpanded,
                  onToggle: () {
                    setState(() {
                      isPredictionHistoryExpanded = !isPredictionHistoryExpanded;
                    });
                  },
                  itemBuilder: (item) => item['description'] ?? 'No prediction data',
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1, color: Colors.grey),
                ),

                // Sensor Data Section
                _buildSection(
                  title: 'SENSOR DATA',
                  items: pastReadingsData,
                  isExpanded: isPastReadingsExpanded,
                  onToggle: () {
                    setState(() {
                      isPastReadingsExpanded = !isPastReadingsExpanded;
                    });
                  },
                  itemBuilder: (item) => item['description'] ?? 'No data',
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
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
          if (index == 4) return; // Current page

          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ManualPredictionScreen()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfitScreen()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const GraphsScreen()),
              );
              break;
            case 5:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  // Reusable section builder
  Widget _buildSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required bool isExpanded,
    required VoidCallback onToggle,
    required String Function(Map<String, dynamic>) itemBuilder,
  }) {
    if (items.isEmpty) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Urbanist',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A3A3A),
                  letterSpacing: 1.0,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'No data available',
                      style: TextStyle(
                        fontFamily: 'Urbanist',
                        fontSize: 14,
                        color: Color(0xFF8A8A8A),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Urbanist',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A3A3A),
                letterSpacing: 1.0,
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
                color: const Color(0xFF4CAF50),
              ),
              onPressed: onToggle,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // First item (always visible)
        _buildHistoryItem(
          text: itemBuilder(items[0]),
          isExpanded: false,
          onToggle: onToggle,
        ),

        // Expanded items
        if (isExpanded && items.length > 1)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.skip(1).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          itemBuilder(item),
                          style: const TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // Build history item widget
  Widget _buildHistoryItem({
    required String text,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'Urbanist',
                      fontSize: 14,
                      color: Color(0xFF3A3A3A),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build profit metric widget
  Widget _buildProfitMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF4CAF50),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Urbanist',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Urbanist',
              fontSize: 12,
              color: Color(0xFF4CAF50),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}