import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
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
      home: const _AuthGate(),
    );
  }
}

/// Listens to Firebase auth state and routes accordingly.
/// - Email-authenticated → DashboardScreen (staff)
/// - Not signed in → LoginScreen
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for Firebase to return auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          );
        }

        final user = snapshot.data;

        // Only allow email-authenticated staff — anonymous users are guests only
        if (user != null && !user.isAnonymous) {
          return const DashboardScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
