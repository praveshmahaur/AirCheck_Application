import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class SmokeAnalysisScreen extends StatefulWidget {
  const SmokeAnalysisScreen({Key? key}) : super(key: key);

  @override
  _SmokeAnalysisScreenState createState() => _SmokeAnalysisScreenState();
}

class _SmokeAnalysisScreenState extends State<SmokeAnalysisScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('sensor_readings');
  List<SmokeData> smokeReadings = [];
  bool _isLoading = true;
  
  // Current smoke value for gauge
  double currentSmoke = 0;
  
  // Zoom level for time series chart
  double _zoomLevel = 1.0;
  
  // For animation purpose
  double _previousSmoke = 0;

  @override
  void initState() {
    super.initState();
    _loadAllSmokeData();
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
            
            double smokeLevel = (double.tryParse(sensorData['smoke']?.toString() ?? '0') ?? 0.0);
            int timestamp = int.tryParse(sensorData['timestamp']?.toString() ?? '0') ?? 0;
            
            SmokeData newReading = SmokeData(
              smokeLevel: smokeLevel,
              timestamp: timestamp,
              dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
            );
            
            setState(() {
              _previousSmoke = currentSmoke;
              currentSmoke = smokeLevel;
              
              // Only add if it's a new data point
              if (smokeReadings.isEmpty || smokeReadings.last.timestamp != timestamp) {
                smokeReadings.add(newReading);
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error processing real-time data: $e');
      }
    }, onError: (error) {
      debugPrint('Error in real-time listener: $error');
    });
  }

  Future<void> _loadAllSmokeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final snapshot = await _database.get();
      
      if (snapshot.exists) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        List<SmokeData> tempData = [];
        
        values.forEach((key, value) {
          double smoke = double.tryParse(value['smoke']?.toString() ?? '0') ?? 0.0;
          int timestamp = int.tryParse(value['timestamp']?.toString() ?? '0') ?? 0;
          
          tempData.add(SmokeData(
            smokeLevel: smoke,
            timestamp: timestamp,
            dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        });
        
        // Sort by timestamp
        tempData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        setState(() {
          smokeReadings = tempData;
          if (smokeReadings.isNotEmpty) {
            _previousSmoke = currentSmoke;
            currentSmoke = smokeReadings.last.smokeLevel;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading smoke data: $e');
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
        title: const Text('Smoke Analysis'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : smokeReadings.isEmpty
              ? const Center(child: Text('No smoke data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Smoke Gauge Card
                      // Card(
                      //   elevation: 3,
                      //   shape: RoundedRectangleBorder(
                      //     borderRadius: BorderRadius.circular(15),
                      //   ),
                      //   child: Padding(
                      //     padding: const EdgeInsets.all(16.0),
                      //     child: Column(
                      //       children: [
                      //         const Text(
                      //           'Current Smoke Level',
                      //           style: TextStyle(
                      //             fontSize: 18,
                      //             fontWeight: FontWeight.bold,
                      //           ),
                      //         ),
                      //         const SizedBox(height: 8),
                      //         SizedBox(
                      //           height: 250,
                      //           child: _buildSmokeGauge(),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      
                      // const SizedBox(height: 24),
                      
                      // Time Series Chart Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Smoke History',
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
                        child: smokeReadings.isNotEmpty ? Text(
                          'Last Updated: ${DateFormat('HH:mm:ss, dd MMM').format(
                            smokeReadings.last.dateTime,
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
        onPressed: _loadAllSmokeData,
        tooltip: 'Refresh Data',
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildSmokeGauge() {
    return SfRadialGauge(
      animationDuration: 1000,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 1000,
          startAngle: 150,
          endAngle: 30,
          interval: 200,
          radiusFactor: 0.9,
          showLabels: true,
          showTicks: true,
          labelsPosition: ElementsPosition.outside,
          labelFormat: '{value} ppm',
          minorTicksPerInterval: 4,
          axisLineStyle: const AxisLineStyle(
            thickness: 30,
            color: Colors.grey,
            thicknessUnit: GaugeSizeUnit.logicalPixel,
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 200,
              color: Colors.green,
              startWidth: 30,
              endWidth: 30,
            ),
            GaugeRange(
              startValue: 200,
              endValue: 400,
              color: Colors.yellow,
              startWidth: 30,
              endWidth: 30,
            ),
            GaugeRange(
              startValue: 400,
              endValue: 1000,
              color: Colors.red,
              startWidth: 30,
              endWidth: 30,
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: _normalizeSmoke(currentSmoke),
              enableAnimation: true,
              animationDuration: 1000,
              needleLength: 0.7,
              needleStartWidth: 1,
              needleEndWidth: 8,
              knobStyle: const KnobStyle(
                knobRadius: 15,
                sizeUnit: GaugeSizeUnit.logicalPixel,
                color: Colors.white,
                borderColor: Color(0xFF4CAF50),
                borderWidth: 3,
              ),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${currentSmoke.toStringAsFixed(0)} ppm',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getSmokeStatus(currentSmoke),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getStatusColor(currentSmoke),
                    ),
                  ),
                ],
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Normalize smoke to fit within 0-1000 range for gauge
  double _normalizeSmoke(double smoke) {
    if (smoke < 0) return 0;
    if (smoke > 1000) return 1000;
    return smoke;
  }
  
  String _getSmokeStatus(double smoke) {
    if (smoke < 100) return 'Clean Air';
    if (smoke < 200) return 'Good';
    if (smoke < 300) return 'Moderate';
    if (smoke < 500) return 'Unhealthy';
    return 'Hazardous';
  }
  
  Color _getStatusColor(double smoke) {
    if (smoke < 200) return Colors.green;
    if (smoke < 400) return Colors.orangeAccent;
    return Colors.red;
  }
  
  Widget _buildTimeSeriesChart() {
    // Determine the range of visible data based on zoom level
    int dataPoints = smokeReadings.length;
    int visiblePoints = (dataPoints / _zoomLevel).round();
    int startIndex = dataPoints - visiblePoints;
    if (startIndex < 0) startIndex = 0;
    
    List<SmokeData> visibleData = smokeReadings.sublist(startIndex);
    
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0.5),
        title: AxisTitle(text: 'Time'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Smoke (ppm)'),
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
        LineSeries<SmokeData, DateTime>(
          name: 'Smoke Level',
          dataSource: visibleData,
          xValueMapper: (SmokeData data, _) => data.dateTime,
          yValueMapper: (SmokeData data, _) => data.smokeLevel,
          markerSettings: const MarkerSettings(isVisible: true),
          color: const Color(0xFF4CAF50),
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

// Data model for smoke readings
class SmokeData {
  final double smokeLevel;
  final int timestamp;
  final DateTime dateTime;
  
  SmokeData({
    required this.smokeLevel,
    required this.timestamp,
    required this.dateTime,
  });
}