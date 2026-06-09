import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() => runApp(const SoViCutApp());

class SoViCutApp extends StatelessWidget {
  const SoViCutApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoViCut',
      theme: ThemeData.dark().copyWith(primaryColor: Colors.orange),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}