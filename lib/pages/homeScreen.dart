import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'package:fl_chart/fl_chart.dart';
import 'package:major_project/pages/app_drawer.dart';
import 'package:major_project/pages/detail_screens/co2Analysis.dart';
import 'package:major_project/pages/detail_screens/humidityAnalysis.dart';
import 'package:major_project/pages/detail_screens/smokeAnalysis.dart';
import 'package:major_project/pages/detail_screens/temperatureAnalysis.dart';

import 'package:major_project/pages/seprate_charts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('sensor_readings');
  bool _isConnected = false;
  String _locationText = "Location";
  bool _isLoading = true;

  // Data storage for chart
  List<Map<String, dynamic>> sensorHistory = [];
  final int maxDataPoints = 10; // Number of data points to show in chart

  // Current sensor values
  double currentCO2 = 0.0;
  double currentHumidity = 0.0;
  double currentTemperature = 0.0;
  double currentSmoke = 0.0;
  DateTime lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadChartData();
    _setupRealtimeListener();
    developer.log(
        'HomeScreen initialized, connecting to Firebase path: ${_database.path}');

    FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
      bool connected = event.snapshot.value as bool? ?? false;
      setState(() {
        _isConnected = connected;
      });
      developer.log(
          'Firebase connection status: ${connected ? "CONNECTED" : "DISCONNECTED"}');
    });

    _database.get().then((snapshot) {
      if (snapshot.exists) {
        developer.log(
            'Firebase data exists! Value type: ${snapshot.value.runtimeType}');
      } else {
        developer
            .log('No data available in Firebase at path: ${_database.path}');
      }
    }).catchError((error) {
      developer.log('Error fetching initial data: $error', error: error);
    });
  }

  // Setup a separate listener for real-time updates
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
                (double.tryParse(sensorData['co2']?.toString() ?? '0') ?? 0.0);
            double humidity =
                double.tryParse(sensorData['humidity']?.toString() ?? '0') ??
                    0.0;
            double temperature =
                double.tryParse(sensorData['temperature']?.toString() ?? '0') ??
                    0.0;
            double smoke =
                (double.tryParse((sensorData['smoke'])?.toString() ?? '0') ?? 0.0);
            int timestamp =
                int.tryParse(sensorData['timestamp']?.toString() ?? '0') ?? 0;

            // Update the current sensor values and chart history
            setState(() {
              currentCO2 = co2;
              currentHumidity = humidity;
              currentTemperature = temperature;
              currentSmoke = smoke;
              lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);

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
              }
            });
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
        });

        developer.log('Loaded ${sensorHistory.length} data points for chart');
      }
    } catch (e) {
      developer.log('Error loading chart data: $e', error: e);
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationText = 'Location services are disabled.';
        _isLoading = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationText = 'Location permissions are denied';
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationText = 'Location permissions are permanently denied';
        _isLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _locationText =
                '${place.subLocality} ${place.locality}, ${place.postalCode}, ${place.country}';
            _isLoading = false;
          });
        } else {
          setState(() {
            _locationText = 'Address not found';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _locationText = 'Error getting address: $e';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _locationText = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  String _getAirQualityStatus(double co2) {
    if (co2 < 700) return 'Excellent';
    if (co2 < 1000) return 'Good';
    if (co2 < 1500) return 'Fair';
    if (co2 < 2000) return 'Poor';
    return 'Dangerous';
  }

  Color _getColorForAirQuality(double co2) {
    if (co2 < 700) return Colors.green;
    if (co2 < 1000) return const Color(0xFF8BC34A);
    if (co2 < 1500) return Colors.teal;
    if (co2 < 2000) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Air Quality Monitor'),
            const SizedBox(width: 8),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      drawer: AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 18.0),
              child: InkWell(
                onTap: () {
                  _getCurrentLocation();
                },
                child: Text(
                  _locationText,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // No StreamBuilder anymore, just use the current values directly
            _buildBodyContent(currentCO2, currentHumidity, currentTemperature,
                currentSmoke, lastUpdated),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _loadChartData(); // Refresh chart data
          developer.log('Manual Firebase data check');
          _database.get().then((snapshot) {
            if (snapshot.exists) {
              developer.log('Data exists! Sample: ${snapshot.value}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Firebase data found: ${snapshot.children.length} entries')),
              );
            } else {
              developer.log('No data available in path: ${_database.path}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No data found in Firebase')),
              );
            }
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBodyContent(double co2, double humidity, double temperature,
      double smoke, DateTime lastUpdated) {
    developer.log(
        'Building UI with values - CO2: $co2, Humidity: $humidity, Temperature: $temperature, smoke: $smoke');
    String airQuality = _getAirQualityStatus(co2);
    Color airQualityColor = _getColorForAirQuality(co2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [airQualityColor, airQualityColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: airQualityColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Air Quality',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  airQuality,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1000),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    'CO₂ level: ${co2.toStringAsFixed(1)} ppm',
                    key: ValueKey(co2.toStringAsFixed(1)), // Very important!
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSensorChartCard(),
          const SizedBox(height: 20),
          const Text(
            'Air Parameters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              InkWell(
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=> TemperatureAnalysisScreen()));
                },
                child: _buildParameterCard(
                  'Temperature',
                  '${temperature.toStringAsFixed(1)}°C',
                  Icons.thermostat,
                  Colors.orange,
                ),
              ),
              InkWell(
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=> HumidityAnalysisScreen()));
                },
                child: _buildParameterCard(
                  'Humidity',
                  '${humidity.toStringAsFixed(1)}%',
                  Icons.water_drop,
                  Colors.cyan,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CO2AnalysisScreen()));
                },
                child: _buildParameterCard(
                  'CO₂',
                  '${co2.toStringAsFixed(1)} ppm',
                  Icons.air,
                  Colors.blue,
                ),
              ),
              InkWell(
                onTap: (){
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SmokeAnalysisScreen()));
                },
                child: _buildParameterCard(
                  'CH₄',
                  '${(smoke).toStringAsFixed(1)} ppm',
                  Icons.grain,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Last Updated: ${DateFormat('HH:mm:ss').format(lastUpdated)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorChartCard() {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sensor Data Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.fullscreen,
                    color: Theme.of(context).primaryColor),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context)=> SensorChartsScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLegend(),
          const SizedBox(height: 15),
          SizedBox(
            height: 250,
            child: _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem('Temperature', Colors.orange),
        _legendItem('Humidity', Colors.cyan),
        _legendItem('CO₂', Colors.blue),
        _legendItem('Smoke', Colors.purple),
      ],
    );
  }

  Widget _legendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    if (sensorHistory.isEmpty) {
      return const Center(
        child: Text('No historical data available'),
      );
    }

    // Fixed Y-axis maximum
    const double maxY = 2000;
    const double yInterval = 200;

    // Default starting values if no data available
    double defaultTemp = 28;
    double defaultHumidity = 60;
    double defaultCO2 = 700;
    double defaultSmoke = 450;

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
          // Temperature line (actual values)
          LineChartBarData(
            spots: List.generate(sensorHistory.length, (index) {
              // Use actual temperature value, starting from default if no history
              double value = sensorHistory.isNotEmpty
                  ? sensorHistory[index]['temperature']
                  : defaultTemp;
              return FlSpot(index.toDouble(), value);
            }),
            isCurved: true,
            color: Colors.orange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withOpacity(0.1),
            ),
          ),

          // Humidity line (actual values)
          LineChartBarData(
            spots: List.generate(sensorHistory.length, (index) {
              double value = sensorHistory.isNotEmpty
                  ? sensorHistory[index]['humidity']
                  : defaultHumidity;
              return FlSpot(index.toDouble(), value);
            }),
            isCurved: true,
            color: Colors.cyan,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.cyan.withOpacity(0.1),
            ),
          ),

          // CO2 line (actual values)
          LineChartBarData(
            spots: List.generate(sensorHistory.length, (index) {
              double value = sensorHistory.isNotEmpty
                  ? sensorHistory[index]['co2']
                  : defaultCO2;
              return FlSpot(index.toDouble(), value);
            }),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),

          // Smoke line (actual values)
          LineChartBarData(
            spots: List.generate(sensorHistory.length, (index) {
              double value = sensorHistory.isNotEmpty
                  ? sensorHistory[index]['smoke']
                  : defaultSmoke;
              return FlSpot(index.toDouble(), value);
            }),
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // tooltipBgColor: Colors.black.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                String title;
                String value;
                Color color;
                int index = spot.x.toInt();

                if (index >= sensorHistory.length) {
                  return null;
                }

                switch (spot.barIndex) {
                  case 0:
                    title = 'Temperature';
                    value =
                        '${sensorHistory[index]['temperature'].toStringAsFixed(1)}°C';
                    color = Colors.orange;
                    break;
                  case 1:
                    title = 'Humidity';
                    value =
                        '${sensorHistory[index]['humidity'].toStringAsFixed(1)}%';
                    color = Colors.cyan;
                    break;
                  case 2:
                    title = 'CO₂';
                    value =
                        '${sensorHistory[index]['co2'].toStringAsFixed(1)} ppm';
                    color = Colors.blue;
                    break;
                  case 3:
                    title = 'Smoke';
                    value =
                        '${sensorHistory[index]['smoke'].toStringAsFixed(1)} ppm';
                    color = Colors.purple;
                    break;
                  default:
                    title = '';
                    value = '';
                    color = Colors.black;
                }

                return LineTooltipItem(
                  '$title\n$value',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '\n',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                  textAlign: TextAlign.center,
                );
              }).toList();
            },
            tooltipPadding: const EdgeInsets.all(8),
            tooltipRoundedRadius: 8,
          ),
          touchCallback:
              (FlTouchEvent event, LineTouchResponse? touchResponse) {},
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  Widget _buildParameterCard(
      String title, String value, IconData icon, Color color) {
    return Container(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
