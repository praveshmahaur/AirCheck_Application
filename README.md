# 🌬️ AirCheck - Air Quality Monitoring System

[![Flutter Version](https://img.shields.io/badge/Flutter-3.13.0-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime%20Database-orange.svg)](https://firebase.google.com/)
[![ESP32](https://img.shields.io/badge/Hardware-ESP32-red.svg)](https://www.espressif.com/)

A comprehensive air quality monitoring system developed as a B.Tech major project, combining hardware sensors with a real-time Flutter application to track, visualize, and analyze environmental parameters.

## 📷 Screenshots
[Add screenshots of your application here]

## 📱 Application Features

- **Real-time Air Quality Monitoring**: Track CO₂, humidity, temperature, and smoke levels
- **Visual Analytics**: Interactive charts and graphs for data visualization
- **Location Tracking**: Automatically detects and displays the user's current location
- **Historical Data**: View trends and patterns in air quality parameters
- **Detailed Analysis**: Dedicated screens for in-depth analysis of each parameter
- **Beautiful UI**: Modern, intuitive interface with color-coded indicators

## 🔧 Hardware Components

- **ESP32 Microcontroller**: Central processing unit for sensor data
- **DHT11 Sensor**: Measures temperature and humidity
- **MQ135 Sensor**: Detects CO₂ levels
- **MQ5 Gas Sensor**: Measures smoke/methane concentration
- **Firebase Integration**: Transmits sensor data to cloud database

## 📊 Data Visualization

- **Real-time Graphs**: Monitor changes in air quality parameters over time
- **Color-coded Indicators**: Visual representation of air quality status
- **Multi-parameter Charts**: View all parameters simultaneously
- **Individual Parameter Analysis**: Dedicated screens for detailed analysis

## 🛠️ Technical Implementation

### Frontend (Flutter)
- **State Management**: Real-time data synchronization with Firebase
- **Geolocation**: Integration with device location services
- **Interactive Charts**: Using fl_chart and syncfusion_flutter_charts
- **Material Design**: Modern UI with custom theming

### Backend
- **Firebase Realtime Database**: Cloud storage for sensor readings
- **Node.js**: Server for development and testing with dummy data
- **ESP32 Programming**: Embedded C code for hardware sensors

## 📦 Dependencies

```yaml
dependencies:
  firebase_core: ^3.13.0
  firebase_database: ^11.3.5
  flutter_spinkit: ^5.2.1
  google_fonts: ^6.2.1
  intl: ^0.20.2
  geolocator: ^13.0.4
  geocoding: ^3.0.0
  fl_chart: ^0.70.2
  syncfusion_flutter_gauges: ^29.1.38
  syncfusion_flutter_charts: ^29.1.38
```
## 🚀 Getting Started

### Prerequisites
* Flutter SDK
* Firebase account
* Android Studio or VS Code with Flutter plugins

### Installation
1. Clone the repository

```bash
git clone https://github.com/praveshmahaur/AirCheck_Application.git


2. Install dependencies

```bash
flutter pub get
```

3. Create a `.env` file in the project root with your Firebase configuration

```
DATABASE_URL=your-firebase-database-url
```

4. Configure Firebase
   * Create a Firebase project
   * Add your application to the project
   * Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
   * Place them in the respective platform directories

5. Run the application

```bash
flutter run
```

## 🧪 Hardware Setup

### Components Required
* ESP32 Development Board
* DHT11 Temperature & Humidity Sensor
* MQ135 CO₂ Sensor
* MQ5 Gas/Smoke Sensor
* Connecting wires
* Power supply

### Connections
1. Connect DHT11 data pin to ESP32 GPIO pin (e.g., GPIO4)
2. Connect MQ135 analog output to ESP32 ADC pin
3. Connect MQ5 analog output to ESP32 ADC pin
4. Power all components with appropriate voltage

### ESP32 Programming
1. Install Arduino IDE and ESP32 board support
2. Install required libraries (WiFi, Firebase, DHT sensor)
3. Upload the code to ESP32 with your WiFi and Firebase credentials

## 🔮 Future Enhancements
* Air quality prediction using machine learning
* Push notifications for dangerous air quality levels
* Integration with smart home systems
* Support for additional sensors (PM2.5, ozone, etc.)
* Cloud-based data analytics

## 👨‍💻 Developer
PRAVESH MAHAUR - praveshmahaur328024@gmail.com
