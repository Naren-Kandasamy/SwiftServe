import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum ConnectivityTier { online, limited, offline }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityTier> _tierController = StreamController<ConnectivityTier>.broadcast();
  
  ConnectivityTier _currentTier = ConnectivityTier.online;
  ConnectivityTier get currentTier => _currentTier;
  Stream<ConnectivityTier> get tierStream => _tierController.stream;

  bool _initialized = false;

  void initialize() {
    if (_initialized) return; // Guard against duplicate listener registration
    _initialized = true;

    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // In connectivity_plus > 6.0, it returns a List<ConnectivityResult>
      _handleConnectivityResults(results);
    });
    
    // Initial check
    _connectivity.checkConnectivity().then(_handleConnectivityResults);
  }

  /// Manually triggers a re-evaluation of the connectivity tier.
  Future<void> forceUpdate() async {
    final results = await _connectivity.checkConnectivity();
    await _handleConnectivityResults(results);
  }

  Future<void> _handleConnectivityResults(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) {
      _updateTier(ConnectivityTier.offline);
      return;
    }

    if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile)) {
      bool canReachFirebase = await _canReachFirebase();
      if (canReachFirebase) {
        _updateTier(ConnectivityTier.online);
      } else {
        _updateTier(ConnectivityTier.limited);
      }
    } else {
      _updateTier(ConnectivityTier.offline);
    }
  }

  void _updateTier(ConnectivityTier newTier) {
    if (_currentTier != newTier) {
      _currentTier = newTier;
      _tierController.add(_currentTier);
      print('[ConnectivityService] Tier updated to: \${newTier.name.toUpperCase()}');
    }
  }

  Future<bool> _canReachFirebase() async {
    try {
      if (kIsWeb) {
        // Use a lightweight check for Web
        final dio = Dio();
        final response = await dio.head(
          'https://www.google.com',
          options: Options(receiveTimeout: const Duration(seconds: 2), sendTimeout: const Duration(seconds: 1)),
        );
        return response.statusCode == 200;
      } else {
        // Simple ping to Google DNS for Mobile
        final result = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (_) {
      return false;
    }
  }
}
