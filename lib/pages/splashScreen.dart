import 'package:flutter/material.dart';
import 'dart:async';

import 'package:major_project/pages/homeScreen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(
      const Duration(seconds: 2),
      () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: -15 * (3.14/180),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 450,
                  width: 450,
                ),
              ),
            ),
            // const SizedBox(height: 20),
            const Text(
              'Air Quality Monitor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 239, 242, 239)),
            ),
          ],
        ),
      ),
    );
  }
}