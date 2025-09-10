import 'package:flutter/material.dart';
import 'package:safe_travel_app/screens/splash/welcome_screen.dart';

void main() {
  runApp(SafeTravelApp());
}

class SafeTravelApp extends StatelessWidget {
  const SafeTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Travel App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomeScreen(),
    );
  }
}