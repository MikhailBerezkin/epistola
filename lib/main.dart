import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const EpistolaApp());
}

class EpistolaApp extends StatelessWidget {
  const EpistolaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epistola',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
