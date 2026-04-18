import 'package:flutter/material.dart';
import 'package:shared/models/alert.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class OfflineKnowledgeService {
  static final Map<EmergencyType, String> _assetMap = {
    EmergencyType.fire: 'assets/knowledge/fire.html',
    EmergencyType.medical: 'assets/knowledge/medical_cpr.html',
    EmergencyType.security: 'assets/knowledge/security.html',
    EmergencyType.infrastructure: 'assets/knowledge/gas_leak.html',
    EmergencyType.other: 'assets/knowledge/other.html',
  };

  static String getAssetPath(EmergencyType type) {
    return _assetMap[type] ?? 'assets/knowledge/other.html';
  }

  static void showKnowledgeScreen(BuildContext context, EmergencyType type) {
    final assetPath = getAssetPath(type);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Emergency Guide: \${type.name.toUpperCase()}'),
            backgroundColor: Colors.red[900],
          ),
          body: InAppWebView(
            initialFile: assetPath,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: false, // Security: static HTML only
              transparentBackground: true,
            ),
          ),
        ),
      ),
    );
  }
}
