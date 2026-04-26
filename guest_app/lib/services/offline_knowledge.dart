// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared/models/alert.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../main.dart'; // To access appLocale

class OfflineKnowledgeService {
  static final Map<EmergencyType, String> _assetMap = {
    EmergencyType.fire: 'assets/knowledge/fire.html',
    EmergencyType.medical: 'assets/knowledge/medical_cpr.html',
    EmergencyType.security: 'assets/knowledge/security.html',
    EmergencyType.infrastructure: 'assets/knowledge/gas_leak.html',
    EmergencyType.other: 'assets/knowledge/other.html',
    // P2 additions — curated pages now correctly reachable
    // (these map in _getExtendedPath for sub-type routing)
  };

  /// Extra mappings for non-primary emergency sub-types.
  static final Map<String, String> _extendedMap = {
    'choking': 'assets/knowledge/choking.html',
    'cardiac': 'assets/knowledge/cardiac.html',
    'burns': 'assets/knowledge/burns.html',
    'wounds': 'assets/knowledge/wounds.html',
    'flood': 'assets/knowledge/flood.html',
    'earthquake': 'assets/knowledge/earthquake.html',
  };

  static String getAssetPath(EmergencyType type) {
    return _assetMap[type] ?? 'assets/knowledge/other.html';
  }

  static String? getExtendedPath(String subType) {
    return _extendedMap[subType.toLowerCase()];
  }

  static void showKnowledgeScreen(BuildContext context, EmergencyType type) {
    final assetPath = getAssetPath(type);

    // Flutter Web cannot render native InAppWebView — open as a new tab from asset URL
    if (kIsWeb) {
      // Construct a relative path the browser can reach from the Flutter Web asset bundle
      html.window.open('$assetPath?lang=${appLocale.value.languageCode}', '_blank');
      return;
    }

    // Native (Android / iOS) — use InAppWebView
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Emergency Guide: ${type.name.toUpperCase()}'),
            backgroundColor: Colors.red[900],
          ),
          body: InAppWebView(
            initialFile: assetPath,
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: "window.appLang = '${appLocale.value.languageCode}';",
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              )
            ]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true, // Enabled for TTS and Checklist
              transparentBackground: true,
            ),
          ),
        ),
      ),
    );
  }

  static void showCustomKnowledgeScreen(BuildContext context, String title, String assetPath) {
    if (kIsWeb) {
      html.window.open('$assetPath?lang=${appLocale.value.languageCode}', '_blank');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.red[900],
          ),
          body: InAppWebView(
            initialFile: assetPath,
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: "window.appLang = '${appLocale.value.languageCode}';",
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              )
            ]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
            ),
          ),
        ),
      ),
    );
  }
}
