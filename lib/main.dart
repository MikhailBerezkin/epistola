import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: FirebaseAuth.instance.currentUser != null
          ? const HomeScreen()
          : const WelcomeScreen(),
    );
  }
}
