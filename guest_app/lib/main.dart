import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/sos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[Offline Mode] Firebase init failed or timed out: $e');
  }
  runApp(const CrisisNetApp());
}

class CrisisNetApp extends StatelessWidget {
  const CrisisNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisNet',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Roboto', // Modern, clean default for accessibility
      ),
      debugShowCheckedModeBanner: false,
      home: const SosScreen(),
    );
  }
}
