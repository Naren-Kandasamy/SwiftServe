import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/sos_screen.dart';
import 'l10n/app_localizations.dart';

// ── Global locale controller ─────────────────────────────────────────────────
// Any screen can call appLocale.value = Locale('es') to switch live.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        // ── Localisation ────────────────────────────────────────────────
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'), // English  (default)
          Locale('es'), // Spanish
          Locale('fr'), // French
          Locale('hi'), // Hindi
          Locale('ta'), // Tamil
        ],
        // ── Theme ───────────────────────────────────────────────────────
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.red,
          scaffoldBackgroundColor: Colors.black,
          fontFamily: 'Roboto',
        ),
        debugShowCheckedModeBanner: false,
        home: const SosScreen(),
      ),
    );
  }
}
