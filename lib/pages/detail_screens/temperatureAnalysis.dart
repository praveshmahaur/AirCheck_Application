import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class TemperatureAnalysisScreen extends StatefulWidget {
  const TemperatureAnalysisScreen({Key? key}) : super(key: key);

  @override
  _TemperatureAnalysisScreenState createState() => _TemperatureAnalysisScreenState();
}

class _TemperatureAnalysisScreenState extends State<TemperatureAnalysisScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('sensor_readings');
  List<TemperatureData> temperatureReadings = [];
  bool _isLoading = true;
  
  // Current temperature value for speedometer
  double currentTemp = 0;
  
  // Zoom level for time series chart
  double _zoomLevel = 1.0;
  
  // For animation purpose
  double _previousTemp = 0;

  @override
  void initState() {
    super.initState();
    _loadAllTemperatureData();
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
            
            double temperature = double.tryParse(sensorData['temperature']?.toString() ?? '0') ?? 0.0;
            int timestamp = int.tryParse(sensorData['timestamp']?.toString() ?? '0') ?? 0;
            
            TemperatureData newReading = TemperatureData(
              temperature: temperature,
              timestamp: timestamp,
              dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
            );
            
            setState(() {
              _previousTemp = currentTemp;
              currentTemp = temperature;
              
              // Only add if it's a new data point
              if (temperatureReadings.isEmpty || temperatureReadings.last.timestamp != timestamp) {
                temperatureReadings.add(newReading);
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

  Future<void> _loadAllTemperatureData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final snapshot = await _database.get();
      
      if (snapshot.exists) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        List<TemperatureData> tempData = [];
        
        values.forEach((key, value) {
          double temp = double.tryParse(value['temperature']?.toString() ?? '0') ?? 0.0;
          int timestamp = int.tryParse(value['timestamp']?.toString() ?? '0') ?? 0;
          
          tempData.add(TemperatureData(
            temperature: temp,
            timestamp: timestamp,
            dateTime: DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        });
        
        // Sort by timestamp
        tempData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        setState(() {
          temperatureReadings = tempData;
          if (temperatureReadings.isNotEmpty) {
            _previousTemp = currentTemp;
            currentTemp = temperatureReadings.last.temperature;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading temperature data: $e');
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
        title: const Text('Temperature Analysis'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : temperatureReadings.isEmpty
              ? const Center(child: Text('No temperature data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Temperature Gauge Card
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
                                'Current Temperature',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 250,
                                child: _buildTemperatureGauge(),
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
                            'Temperature History',
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
                        child: temperatureReadings.isNotEmpty ? Text(
                          'Last Updated: ${DateFormat('HH:mm:ss, dd MMM').format(
                            temperatureReadings.last.dateTime,
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
        onPressed: _loadAllTemperatureData,
        tooltip: 'Refresh Data',
        child: const Icon(Icons.refresh),
      ),
    );
  }
  
  Widget _buildTemperatureGauge() {
    return SfRadialGauge(
      animationDuration: 1000,
      enableLoadingAnimation: true,
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 100,
          startAngle: 150,
          endAngle: 30,
          interval: 10,
          radiusFactor: 0.9,
          showLabels: true,
          showTicks: true,
          labelsPosition: ElementsPosition.outside,
          labelFormat: '{value}°C',
          minorTicksPerInterval: 4,
          axisLineStyle: const AxisLineStyle(
            thickness: 30,
            // cornerStyle: CornerStyle.bothFlat,  // Changed from bothCurve to bothFlat
            color: Colors.grey,
            thicknessUnit: GaugeSizeUnit.logicalPixel,
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: 30,
              color: Colors.blue,
              startWidth: 30,
              endWidth: 30,
            ),
            GaugeRange(
              startValue: 30,
              endValue: 70,
              color: Colors.green,
              startWidth: 30,
              endWidth: 30,
            ),
            GaugeRange(
              startValue: 70,
              endValue: 100,
              color: Colors.red,
              startWidth: 30,
              endWidth: 30,
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: _normalizeTemperature(currentTemp),
              enableAnimation: true,
              // Removed animationType: AnimationType.easeOutBack
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
                    '${currentTemp.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getTemperatureStatus(currentTemp),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getStatusColor(currentTemp),
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
  
  // Normalize temperature to fit within 0-100 range for gauge
  double _normalizeTemperature(double temp) {
    // Simple mapping - can be adjusted based on your expected temperature range
    if (temp < 0) return 0;
    if (temp > 100) return 100;
    return temp;
  }
  
  String _getTemperatureStatus(double temp) {
    if (temp < 10) return 'Very Cold';
    if (temp < 20) return 'Cold';
    if (temp < 25) return 'Cool';
    if (temp < 30) return 'Comfortable';
    if (temp < 35) return 'Warm';
    if (temp < 40) return 'Hot';
    return 'Very Hot';
  }
  
  Color _getStatusColor(double temp) {
    if (temp < 20) return Colors.blue;
    if (temp < 30) return Colors.green;
    return Colors.red;
  }
  
  Widget _buildTimeSeriesChart() {
    // Determine the range of visible data based on zoom level
    int dataPoints = temperatureReadings.length;
    int visiblePoints = (dataPoints / _zoomLevel).round();
    int startIndex = dataPoints - visiblePoints;
    if (startIndex < 0) startIndex = 0;
    
    List<TemperatureData> visibleData = temperatureReadings.sublist(startIndex);
    
    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0.5),
        title: AxisTitle(text: 'Time'),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Temperature (°C)'),
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
      series: <CartesianSeries>[  // Changed from ChartSeries to CartesianSeries
        LineSeries<TemperatureData, DateTime>(
          name: 'Temperature',
          dataSource: visibleData,
          xValueMapper: (TemperatureData data, _) => data.dateTime,
          yValueMapper: (TemperatureData data, _) => data.temperature,
          markerSettings: const MarkerSettings(isVisible: true),
          color: Colors.redAccent,
          width: 2.5,
          animationDuration: 1500,
          dataLabelSettings: const DataLabelSettings(
            isVisible: false,
            alignment: ChartAlignment.center,  // Changed from labelAlignment: ChartDataLabelAlignment.auto
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

// Data model for temperature readings
class TemperatureData {
  final double temperature;
  final int timestamp;
  final DateTime dateTime;
  
  TemperatureData({
    required this.temperature,
    required this.timestamp,
    required this.dateTime,
  });
}