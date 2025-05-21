import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class HumidityAnalysisScreen extends StatefulWidget {
  const HumidityAnalysisScreen({Key? key}) : super(key: key);

  @override
  _HumidityAnalysisScreenState createState() => _HumidityAnalysisScreenState();
}

class _HumidityAnalysisScreenState extends State<HumidityAnalysisScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('sensor_readings');
  List<HumidityData> humidityReadings = [];
  bool _isLoading = true;
  
  // Current humidity value for pie chart
  double currentHumidity = 0;
  
  // Zoom level for time series chart
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _loadAllHumidityData();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _database.limitToLast(1).onValue.listen((event) {
      try {
        if (event.snapshot.value != null) {
          var snapshotValue = event.snapshot.value;
          
          if (snapshotValue is Map) {
            Map<dynamic, dynamic> dataMap = Map<dynamic, dynamic>.from(snapshotValue);
            String entryKey = dataMap.keys.first.toString();
            Map<dynamic, dynamic> sensorData = dataMap[entryKey];
            
            double humidity = double.tryParse(sensorData['humidity']?.toString() ?? '0') ?? 0.0;
            int timestamp = int.tryParse(sensorData['timestamp']?.toString() ?? '0') ?? 0;
            
            HumidityData newReading = HumidityData(
              humidity: humidity,
              timestamp: timestamp,
              dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
            );
            
            setState(() {
              currentHumidity = humidity;
              
              // Only add if it's a new data point
              if (humidityReadings.isEmpty || humidityReadings.last.timestamp != timestamp) {
                humidityReadings.add(newReading);
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error processing real-time humidity data: $e');
      }
    }, onError: (error) {
      debugPrint('Error in real-time listener: $error');
    });
  }

  Future<void> _loadAllHumidityData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final snapshot = await _database.get();
      
      if (snapshot.exists) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        List<HumidityData> tempData = [];
        
        values.forEach((key, value) {
          double humidity = double.tryParse(value['humidity']?.toString() ?? '0') ?? 0.0;
          int timestamp = int.tryParse(value['timestamp']?.toString() ?? '0') ?? 0;
          
          tempData.add(HumidityData(
            humidity: humidity,
            timestamp: timestamp,
            dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        });
        
        // Sort by timestamp
        tempData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        setState(() {
          humidityReadings = tempData;
          if (humidityReadings.isNotEmpty) {
            currentHumidity = humidityReadings.last.humidity;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading humidity data: $e');
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
        title: const Text('Humidity Analysis'),
        backgroundColor: const Color(0xFF4CAF50), // Blue color for humidity
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : humidityReadings.isEmpty
              ? const Center(child: Text('No humidity data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Humidity Pie Chart Card
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Current Humidity',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 250,
                                child: _buildHumidityPieChart(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Time Series Chart Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Humidity History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Zoom Controls
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.zoom_in),
                                onPressed: () {
                                  setState(() {
                                    _zoomLevel = _zoomLevel * 1.5;
                                    if (_zoomLevel > 5) _zoomLevel = 5;
                                  });
                                },
                                tooltip: 'Zoom In',
                              ),
                              IconButton(
                                icon: const Icon(Icons.zoom_out),
                                onPressed: () {
                                  setState(() {
                                    _zoomLevel = _zoomLevel / 1.5;
                                    if (_zoomLevel < 1) _zoomLevel = 1;
                                  });
                                },
                                tooltip: 'Zoom Out',
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    _zoomLevel = 1.0;
                                  });
                                },
                                tooltip: 'Reset Zoom',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            height: 300,
                            child: _buildTimeSeriesChart(),
                          ),
                        ),
                      ),
                      
                      // Last updated text
                      const SizedBox(height: 16),
                      Center(
                        child: humidityReadings.isNotEmpty ? Text(
                          'Last Updated: ${DateFormat('HH:mm:ss, dd MMM').format(
                            humidityReadings.last.dateTime,
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
        // backgroundColor: const Color(0xFF4CAF50),
        onPressed: _loadAllHumidityData,
        tooltip: 'Refresh Data',
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildHumidityPieChart() {
    // For pie chart, we need to display humidity percentage and remaining percentage
    final List<HumidityPieData> pieData = [
      HumidityPieData('Humidity', currentHumidity, const Color(0xFF4CAF50)),
      HumidityPieData('Dry', 100 - currentHumidity, Colors.grey[300]!),
    ];
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SfCircularChart(
          annotations: <CircularChartAnnotation>[
            CircularChartAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentHumidity.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getHumidityStatus(currentHumidity),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getStatusColor(currentHumidity),
                    ),
                  ),
                ],
              ),
            ),
          ],
          series: <CircularSeries>[
            DoughnutSeries<HumidityPieData, String>(
              dataSource: pieData,
              xValueMapper: (HumidityPieData data, _) => data.category,
              yValueMapper: (HumidityPieData data, _) => data.value,
              pointColorMapper: (HumidityPieData data, _) => data.color,
              innerRadius: '60%',
              radius: '80%',
              animationDuration: 1000,
              dataLabelSettings: const DataLabelSettings(
                isVisible: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  String _getHumidityStatus(double humidity) {
    if (humidity < 20) return 'Very Dry';
    if (humidity < 30) return 'Dry';
    if (humidity < 40) return 'Slightly Dry';
    if (humidity < 60) return 'Comfortable';
    if (humidity < 70) return 'Slightly Humid';
    if (humidity < 80) return 'Humid';
    return 'Very Humid';
  }
  
  Color _getStatusColor(double humidity) {
    if (humidity < 30) return Colors.orange;
    if (humidity < 60) return Colors.green;
    return Color(0xFF4CAF50);
  }
  
  Widget _buildTimeSeriesChart() {
    // Determine the range of visible data based on zoom level
    int dataPoints = humidityReadings.length;
    int visiblePoints = (dataPoints / _zoomLevel).round();
    int startIndex = dataPoints - visiblePoints;
    if (startIndex < 0) startIndex = 0;
    
    List<HumidityData> visibleData = humidityReadings.sublist(startIndex);
    
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0.5),
        title: AxisTitle(text: 'Time'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Humidity (%)'),
        minimum: 0,
        maximum: 100,
        axisLine: const AxisLine(width: 0.5),
        majorTickLines: const MajorTickLines(size: 6),
      ),
      zoomPanBehavior: ZoomPanBehavior(
        enablePanning: true,
        enablePinching: true,
        enableDoubleTapZooming: true,
        enableSelectionZooming: true,
        enableMouseWheelZooming: true,
        zoomMode: ZoomMode.x,
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
      ),
      series: <CartesianSeries>[
        LineSeries<HumidityData, DateTime>(
          name: 'Humidity',
          dataSource: visibleData,
          xValueMapper: (HumidityData data, _) => data.dateTime,
          yValueMapper: (HumidityData data, _) => data.humidity,
          markerSettings: const MarkerSettings(isVisible: true),
          color: Colors.grey,
          width: 2.5,
          animationDuration: 1500,
          dataLabelSettings: const DataLabelSettings(
            isVisible: false,
            alignment: ChartAlignment.center,
          ),
        ),
      ],
      crosshairBehavior: CrosshairBehavior(
        enable: true,
        lineType: CrosshairLineType.both,
      ),
    );
  }
}

// Data model for humidity readings
class HumidityData {
  final double humidity;
  final int timestamp;
  final DateTime dateTime;
  
  HumidityData({
    required this.humidity,
    required this.timestamp,
    required this.dateTime,
  });
}

// Data model for pie chart
class HumidityPieData {
  final String category;
  final double value;
  final Color color;
  
  HumidityPieData(this.category, this.value, this.color);
}