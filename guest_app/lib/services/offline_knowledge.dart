import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
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
    final title = 'Emergency Guide: ${type.name.toUpperCase()}';
    showCustomKnowledgeScreen(context, title, assetPath);
  }

  static void showCustomKnowledgeScreen(BuildContext context, String title, String assetPath) {
    // Flutter Web cannot render native InAppWebView — open as a new tab
    if (kIsWeb) {
      launchUrl(Uri.parse('$assetPath?lang=${appLocale.value.languageCode}'), webOnlyWindowName: '_blank');
      return;
    }

    final langCode = appLocale.value.languageCode;

    // Native (Android / iOS) — load HTML via rootBundle to avoid asset:/// issues
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _HtmlGuideScreen(title: title, assetPath: assetPath, langCode: langCode),
      ),
    );
  }
}

/// Stateful screen that loads asset HTML via rootBundle to avoid the
/// broken asset:/// URL scheme on Android devices.
class _HtmlGuideScreen extends StatefulWidget {
  final String title;
  final String assetPath;
  final String langCode;

  const _HtmlGuideScreen({
    required this.title,
    required this.assetPath,
    required this.langCode,
  });

  @override
  State<_HtmlGuideScreen> createState() => _HtmlGuideScreenState();
}

class _HtmlGuideScreenState extends State<_HtmlGuideScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.red[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          InAppWebView(
            onWebViewCreated: (controller) async {
              _controller = controller;
              try {
                // Load the raw HTML string via rootBundle — works on all Android versions
                final htmlString = await rootBundle.loadString(widget.assetPath);
                // Inject the language var right after <head>
                final injected = htmlString.replaceFirst(
                  '<head>',
                  '<head><script>window.appLang = "${widget.langCode}";</script>',
                );
                // Derive the folder containing this HTML file so relative
                // paths (css/, js/, img/) resolve correctly on Android.
                final assetFolder = widget.assetPath.substring(0, widget.assetPath.lastIndexOf('/') + 1);
                final baseUrl = WebUri('file:///android_asset/flutter_assets/$assetFolder');
                await _controller?.loadData(
                  data: injected,
                  mimeType: 'text/html',
                  encoding: 'utf8',
                  baseUrl: baseUrl,
                );
              } catch (e) {
                debugPrint('[KnowledgeScreen] Failed to load ${widget.assetPath}: $e');
                if (mounted) setState(() => _error = 'Could not load guide: $e');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              allowFileAccess: true,
              allowContentAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
        ],
      ),
    );
  }
}
