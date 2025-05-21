import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class CO2AnalysisScreen extends StatefulWidget {
  const CO2AnalysisScreen({Key? key}) : super(key: key);

  @override
  _CO2AnalysisScreenState createState() => _CO2AnalysisScreenState();
}

class _CO2AnalysisScreenState extends State<CO2AnalysisScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('sensor_readings');
  List<CO2Data> co2Readings = [];
  bool _isLoading = true;
  
  // Current CO2 value for gauge
  double currentCO2 = 0;
  
  // Zoom level for time series chart
  double _zoomLevel = 1.0;
  
  // For animation purpose
  double _previousCO2 = 0;

  @override
  void initState() {
    super.initState();
    _loadAllCO2Data();
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
            
            double co2Level = (double.tryParse(sensorData['co2']?.toString() ?? '0') ?? 0.0) -800;
            int timestamp = int.tryParse(sensorData['timestamp']?.toString() ?? '0') ?? 0;
            
            CO2Data newReading = CO2Data(
              co2Level: co2Level,
              timestamp: timestamp,
              dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
            );
            
            setState(() {
              _previousCO2 = currentCO2;
              currentCO2 = co2Level;
              
              // Only add if it's a new data point
              if (co2Readings.isEmpty || co2Readings.last.timestamp != timestamp) {
                co2Readings.add(newReading);
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

  Future<void> _loadAllCO2Data() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final snapshot = await _database.get();
      
      if (snapshot.exists) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        List<CO2Data> tempData = [];
        
        values.forEach((key, value) {
          double co2 = double.tryParse(value['co2']?.toString() ?? '0') ?? 0.0;
          int timestamp = int.tryParse(value['timestamp']?.toString() ?? '0') ?? 0;
          
          tempData.add(CO2Data(
            co2Level: co2,
            timestamp: timestamp,
            dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        });
        
        // Sort by timestamp
        tempData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        setState(() {
          co2Readings = tempData;
          if (co2Readings.isNotEmpty) {
            _previousCO2 = currentCO2;
            currentCO2 = co2Readings.last.co2Level;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading CO2 data: $e');
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
        title: const Text('CO2 Analysis'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : co2Readings.isEmpty
              ? const Center(child: Text('No CO2 data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CO2 Gauge Card
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
                                'Current CO2 Level',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 250,
                                child: _buildCO2Gauge(),
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
                            'CO2 History',
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
                        child: co2Readings.isNotEmpty ? Text(
                          'Last Updated: ${DateFormat('HH:mm:ss, dd MMM').format(
                            co2Readings.last.dateTime,
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
        onPressed: _loadAllCO2Data,
        tooltip: 'Refresh Data',
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildCO2Gauge() {
    return SfRadialGauge(
      animationDuration: 1000,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 2000,
          startAngle: 150,
          endAngle: 30,
          interval: 400,
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
              endValue: 800,
              color: Colors.green,
              startWidth: 30,
              endWidth: 30,
            ),
            GaugeRange(
              startValue: 800,
              endValue: 1200,
              color: Colors.yellow,
              startWidth: 30,
              endWidth: 30,
            ),
            GaugeRange(
              startValue: 1200,
              endValue: 2000,
              color: Colors.red,
              startWidth: 30,
              endWidth: 30,
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: _normalizeCO2(currentCO2),
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
                    '${currentCO2.toStringAsFixed(0)} ppm',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getCO2Status(currentCO2),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getStatusColor(currentCO2),
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
  
  // Normalize CO2 to fit within 0-2000 range for gauge
  double _normalizeCO2(double co2) {
    if (co2 < 0) return 0;
    if (co2 > 2000) return 2000;
    return co2;
  }
  
  String _getCO2Status(double co2) {
    if (co2 < 400) return 'Excellent';
    if (co2 < 800) return 'Good';
    if (co2 < 1000) return 'Acceptable';
    if (co2 < 1500) return 'Poor';
    return 'Dangerous';
  }
  
  Color _getStatusColor(double co2) {
    if (co2 < 800) return Colors.green;
    if (co2 < 1200) return Colors.orangeAccent;
    return Colors.red;
  }
  
  Widget _buildTimeSeriesChart() {
    // Determine the range of visible data based on zoom level
    int dataPoints = co2Readings.length;
    int visiblePoints = (dataPoints / _zoomLevel).round();
    int startIndex = dataPoints - visiblePoints;
    if (startIndex < 0) startIndex = 0;
    
    List<CO2Data> visibleData = co2Readings.sublist(startIndex);
    
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0.5),
        title: AxisTitle(text: 'Time'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'CO2 (ppm)'),
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
        LineSeries<CO2Data, DateTime>(
          name: 'CO2 Level',
          dataSource: visibleData,
          xValueMapper: (CO2Data data, _) => data.dateTime,
          yValueMapper: (CO2Data data, _) => data.co2Level,
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

// Data model for CO2 readings
class CO2Data {
  final double co2Level;
  final int timestamp;
  final DateTime dateTime;
  
  CO2Data({
    required this.co2Level,
    required this.timestamp,
    required this.dateTime,
  });
}