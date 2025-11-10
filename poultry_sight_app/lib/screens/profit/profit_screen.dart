import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:poultry_app/services/api/prediction_history_service.dart';
import 'package:poultry_app/screens/dashboard/dashboard_screen.dart';
import 'package:poultry_app/screens/prediction/manual_prediction_screen.dart';
import 'package:poultry_app/screens/graphs/graphs_screen.dart';
import 'package:poultry_app/screens/history/history_screen.dart';
import 'package:poultry_app/screens/profile/profile_screen.dart';
import 'package:intl/intl.dart';

class ProfitScreen extends StatefulWidget {
  const ProfitScreen({super.key});

  @override
  State<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends State<ProfitScreen> {
  final PredictionHistoryService _historyService = PredictionHistoryService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _profitData = [];
  double _totalProfit = 0.0;
  double _averageProfit = 0.0;
  int _totalDays = 0;
  static const double _eggPrice = 120.0; // Average price per egg in RWF

  @override
  void initState() {
    super.initState();
    _loadProfitData();
  }

  Future<void> _loadProfitData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get prediction history
      final predictions = await _historyService.getPredictionHistory(limit: 1000);
      
      // Group predictions by date and calculate profit per day
      final Map<String, DailyProfit> dailyProfits = {};
      
      for (var prediction in predictions) {
        final createdAt = prediction['created_at'] as String?;
        if (createdAt == null) continue;
        
        final date = DateTime.parse(createdAt);
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        final predictedEggs = (prediction['predicted_eggs'] as int?) ?? 0;
        final profit = predictedEggs * _eggPrice;
        
        if (dailyProfits.containsKey(dateKey)) {
          dailyProfits[dateKey]!.eggs += predictedEggs;
          dailyProfits[dateKey]!.profit += profit;
        } else {
          dailyProfits[dateKey] = DailyProfit(
            date: date,
            eggs: predictedEggs,
            profit: profit,
          );
        }
      }
      
      // Convert to list and sort by date (newest first for display)
      final sortedData = dailyProfits.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      
      // Calculate statistics
      double totalProfit = 0.0;
      for (var daily in sortedData) {
        totalProfit += daily.profit;
      }
      
      setState(() {
        _profitData = sortedData.map((daily) => {
          'date': daily.date,
          'eggs': daily.eggs,
          'profit': daily.profit,
        }).toList();
        _totalProfit = totalProfit;
        _totalDays = sortedData.length;
        _averageProfit = _totalDays > 0 ? totalProfit / _totalDays : 0.0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profit data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAllProfitsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Profit Records',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Dialog Content
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _profitData.length,
                  itemBuilder: (context, index) {
                    return _buildDailyProfitCard(_profitData[index], index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                onRefresh: _loadProfitData,
                color: Colors.white,
                backgroundColor: const Color(0xFF4CAF50),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22.0, 8.0, 22.0, 22.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
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
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Active',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      const Text(
                        'Profit Insights',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Daily profit analysis based on egg production',
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 15,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        )
                      else if (_profitData.isEmpty)
                        _buildEmptyState()
                      else ...[
                        // Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Total Profit',
                                'RWF ${_totalProfit.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                'Avg Daily',
                                'RWF ${_averageProfit.toStringAsFixed(0)}',
                                Icons.trending_up,
                                Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                'Total Days',
                                '$_totalDays days',
                                Icons.calendar_today,
                                Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                'Egg Price',
                                'RWF $_eggPrice',
                                Icons.egg_outlined,
                                Colors.purple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Profit Chart
                        Container(
                          width: double.infinity,
                          height: 300,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily Profit Trend',
                                style: TextStyle(
                                  fontFamily: 'Lexend',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3A3A3A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _buildProfitChart(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Recent Activity Section - Show only latest 3
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Recent Activity',
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3A3A3A),
                              ),
                            ),
                            if (_profitData.length > 3)
                              TextButton.icon(
                                onPressed: _showAllProfitsDialog,
                                icon: const Icon(
                                  Icons.visibility,
                                  size: 18,
                                  color: Color(0xFF4CAF50),
                                ),
                                label: const Text(
                                  'View All',
                                  style: TextStyle(
                                    fontFamily: 'Lexend',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Show only the latest 3 entries
                        ...List.generate(
                          _profitData.length > 3 ? 3 : _profitData.length,
                          (index) => _buildDailyProfitCard(_profitData[index], index),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom Navigation Bar
            BottomNavigationBar(
              currentIndex: 2,
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
                if (index == 2) return; // Current page
                
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Profit Data Available',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make predictions to see your profit insights',
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
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
        ],
      ),
    );
  }

  Widget _buildProfitChart() {
    if (_profitData.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    // Use data in chronological order for chart (oldest to newest)
    final chartData = _profitData.reversed.toList();
    final maxProfit = chartData.map((d) => d['profit'] as double).reduce((a, b) => a > b ? a : b);
    final minProfit = chartData.map((d) => d['profit'] as double).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxProfit / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
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
              interval: chartData.length > 10 ? (chartData.length / 5).ceil().toDouble() : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                  final date = chartData[value.toInt()]['date'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 10,
                        color: Colors.grey,
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
              reservedSize: 50,
              interval: maxProfit / 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  'RWF ${value.toInt()}',
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 0,
        maxX: (chartData.length - 1).toDouble(),
        minY: minProfit * 0.9,
        maxY: maxProfit * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value['profit'] as double);
            }).toList(),
            isCurved: true,
            color: const Color(0xFF4CAF50),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF4CAF50).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProfitCard(Map<String, dynamic> data, int index) {
    final date = data['date'] as DateTime;
    final eggs = data['eggs'] as int;
    final profit = data['profit'] as double;
    final dayNumber = _profitData.length - index; // Count from most recent

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.egg_outlined,
              color: Color(0xFF4CAF50),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day $dayNumber',
                  style: const TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM dd, yyyy').format(date),
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$eggs eggs produced',
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RWF ${profit.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
              ),
              Text(
                'Profit',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DailyProfit {
  final DateTime date;
  int eggs;
  double profit;

  DailyProfit({
    required this.date,
    required this.eggs,
    required this.profit,
  });
}