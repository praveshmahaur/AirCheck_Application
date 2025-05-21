import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:developer' as developer;

class SensorChartsScreen extends StatefulWidget {
  const SensorChartsScreen({Key? key}) : super(key: key);

  @override
  _SensorChartsScreenState createState() => _SensorChartsScreenState();
}

class _SensorChartsScreenState extends State<SensorChartsScreen> {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('sensor_readings');
  
  // Data storage for chart
  List<Map<String, dynamic>> sensorHistory = [];
  final int maxDataPoints = 10; // Number of data points to show in chart
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChartData();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    // Clean up any listeners when the widget is disposed
    super.dispose();
  }

  // Setup a listener for real-time updates
  void _setupRealtimeListener() {
    _database.limitToLast(1).onValue.listen((event) {
      try {
        if (event.snapshot.value != null) {
          var snapshotValue = event.snapshot.value;

          if (snapshotValue is Map) {
            Map<dynamic, dynamic> dataMap =
                Map<dynamic, dynamic>.from(snapshotValue);
            String entryKey = dataMap.keys.first.toString();
            Map<dynamic, dynamic> sensorData = dataMap[entryKey];

            double co2 =
                (double.tryParse(sensorData['co2']?.toString() ?? '0') ?? 0.0) - 800;
            double humidity =
                double.tryParse(sensorData['humidity']?.toString() ?? '0') ??
                    0.0;
            double temperature =
                double.tryParse(sensorData['temperature']?.toString() ?? '0') ??
                    0.0;
            double smoke =
                double.tryParse(sensorData['smoke']?.toString() ?? '0') ?? 0.0;
            int timestamp =
                int.tryParse(sensorData['timestamp']?.toString() ?? '0') ?? 0;

            // Update the chart history
            setState(() {
              // Only add to history if it's a new data point
              if (sensorHistory.isEmpty ||
                  sensorHistory.last['timestamp'] != timestamp) {
                sensorHistory.add({
                  'co2': co2,
                  'humidity': humidity,
                  'temperature': temperature,
                  'smoke': smoke,
                  'timestamp': timestamp,
                });

                // Keep only the latest data points
                if (sensorHistory.length > maxDataPoints) {
                  sensorHistory.removeAt(0);
                }
                
                // Sort by timestamp to ensure correct order
                sensorHistory.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
              }
            });
            
            developer.log('Real-time update received: CO2=$co2, Humidity=$humidity, Temperature=$temperature, Smoke=$smoke');
          }
        }
      } catch (e) {
        developer.log('Error processing real-time data: $e',
            error: e, stackTrace: StackTrace.current);
      }
    }, onError: (error) {
      developer.log('Error in real-time listener: $error', error: error);
    });
  }

  // Load historical data for chart
  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final snapshot = await _database.limitToLast(maxDataPoints).get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> tempList = [];
        values.forEach((key, value) {
          tempList.add({
            'co2': double.tryParse(value['co2']?.toString() ?? '0') ?? 0.0,
            'humidity':
                double.tryParse(value['humidity']?.toString() ?? '0') ?? 0.0,
            'temperature':
                double.tryParse(value['temperature']?.toString() ?? '0') ?? 0.0,
            'smoke': double.tryParse(value['smoke']?.toString() ?? '0') ?? 0.0,
            'timestamp':
                int.tryParse(value['timestamp']?.toString() ?? '0') ?? 0,
          });
        });

        // Sort by timestamp
        tempList.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

        setState(() {
          sensorHistory = tempList;
          _isLoading = false;
        });

        developer.log('Loaded ${sensorHistory.length} data points for charts');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading chart data: $e', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Sensor Charts'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Temperature Chart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildChartCard(
                  'Temperature', 
                  Colors.orange, 
                  'temperature', 
                  100, 
                  10, 
                  '°C'
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Humidity Chart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildChartCard(
                  'Humidity', 
                  Colors.cyan, 
                  'humidity', 
                  100, 
                  10, 
                  '%'
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'CO₂ Chart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildChartCard(
                  'CO₂', 
                  Colors.blue, 
                  'co2', 
                  2000, 
                  200, 
                  'ppm'
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Smoke Chart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildChartCard(
                  'Smoke', 
                  Colors.purple, 
                  'smoke', 
                  1000, 
                  100, 
                  'ppm'
                ),
                
                // Last updated text
                const SizedBox(height: 16),
                Center(
                  child: sensorHistory.isNotEmpty ? Text(
                    'Last Updated: ${DateFormat('HH:mm:ss').format(
                      DateTime.fromMillisecondsSinceEpoch(sensorHistory.last['timestamp'])
                    )}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ) : const SizedBox(),
                ),
              ],
            ),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadChartData,
        tooltip: 'Refresh Data',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildChartCard(String title, Color color, String dataKey, double maxY, double yInterval, String unit) {
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: sensorHistory.isEmpty
        ? const Center(child: Text('No data available'))
        : _buildLineChart(title, color, dataKey, maxY, yInterval, unit),
    );
  }

  Widget _buildLineChart(String title, Color color, String dataKey, double maxY, double yInterval, String unit) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text(
              'Time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 22,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < sensorHistory.length) {
                  final time = DateTime.fromMillisecondsSinceEpoch(
                      sensorHistory[index]['timestamp']);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('HH:mm').format(time),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              '$title ($unit)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            axisNameSize: 40,
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        minX: 0,
        maxX: sensorHistory.length - 1.0,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(sensorHistory.length, (index) {
              double value = sensorHistory[index][dataKey];
              return FlSpot(index.toDouble(), value);
            }),
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // tooltipBgColor: Colors.black.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                int index = spot.x.toInt();
                if (index >= sensorHistory.length) {
                  return null;
                }
                
                double value = sensorHistory[index][dataKey];
                final time = DateTime.fromMillisecondsSinceEpoch(
                    sensorHistory[index]['timestamp']);
                
                return LineTooltipItem(
                  '$title: ${value.toStringAsFixed(1)} $unit\n${DateFormat('HH:mm:ss').format(time)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
            tooltipPadding: const EdgeInsets.all(8),
            tooltipRoundedRadius: 8,
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}