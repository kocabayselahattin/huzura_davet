import 'package:flutter/material.dart';
import 'pages/splash_screen.dart';

void main() {
  runApp(const HuzurVaktiApp());
}

class HuzurVaktiApp extends StatelessWidget {
  const HuzurVaktiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Huzur Vakti',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}