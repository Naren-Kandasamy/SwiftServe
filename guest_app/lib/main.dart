import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/sos_screen.dart';
import 'screens/status_screen.dart';
import 'l10n/app_localizations.dart';

// ── Global locale controller ─────────────────────────────────────────────────
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables (API keys, etc.) — never committed to git
  await dotenv.load(fileName: '.env');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('[Offline Mode] Firebase init failed or timed out: $e');
  }
  runApp(const CrisisNetApp());
}

class CrisisNetApp extends StatelessWidget {
  const CrisisNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (_, locale, __) => MaterialApp(
        title: 'CrisisNet',
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
          Locale('fr'),
          Locale('hi'),
          Locale('ta'),
        ],
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.red,
          scaffoldBackgroundColor: Colors.black,
          fontFamily: 'Roboto',
        ),
        debugShowCheckedModeBanner: false,
        home: const _StartupRouter(),
      ),
    );
  }
}

/// Checks SharedPreferences for an active alert session and routes accordingly.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();
  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveStartScreen(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          );
        }
        return snap.data ?? const SosScreen();
      },
    );
  }

  Future<Widget> _resolveStartScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertId = prefs.getString('active_alert_id');
      if (alertId == null) return const SosScreen();

      final snap = await FirebaseDatabase.instance
          .ref('venues/mockVenue123/alerts/$alertId/status')
          .get()
          .timeout(const Duration(seconds: 3));

      if (snap.exists && snap.value != 'resolved') {
        return StatusScreen(alertId: alertId);
      } else {
        await prefs.remove('active_alert_id');
      }
    } catch (_) { /* offline — go to SOS home */ }
    return const SosScreen();
  }
}
