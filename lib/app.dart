import 'package:flutter/material.dart';
import 'screens/entry_screen.dart';

class WaterMarkApp extends StatelessWidget {
  const WaterMarkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaterMark',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const EntryScreen(),
    );
  }
}

