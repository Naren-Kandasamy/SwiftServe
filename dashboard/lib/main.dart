import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));

    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('[Offline Mode] Firebase init failed or timed out on Dashboard: $e');
  }
  runApp(const CrisisNetDashboardApp());
}

class CrisisNetDashboardApp extends StatelessWidget {
  const CrisisNetDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisNet Command Dashboard',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardScreen(),
    );
  }
}
