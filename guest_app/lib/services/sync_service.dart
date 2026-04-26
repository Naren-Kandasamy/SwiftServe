import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/models/alert.dart';
import 'package:flutter/foundation.dart';

/// Monitoring service that queues SOS alerts when offline
/// and flushes them to Firebase Realtime Database upon reconnection.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _dbRef = FirebaseDatabase.instance.ref();
  
  /// Reactive state for UI indicators
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);
  final ValueNotifier<int> pendingSyncCount = ValueNotifier(0);

  static const String _offlineQueueKey = 'offline_sos_queue';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initializes connectivity listener and checks for pending alerts.
  void init() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      // If any interface is connected, attempt a sync
      if (results.any((r) => r != ConnectivityResult.none)) {
        _onReconnected();
      }
    });

    _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_offlineQueueKey) ?? [];
    pendingSyncCount.value = queue.length;
  }

  /// Queues an alert locally for future synchronization.
  Future<void> queueAlert(Alert alert) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_offlineQueueKey) ?? [];
    queue.add(jsonEncode(alert.toMap()));
    await prefs.setStringList(_offlineQueueKey, queue);
    _updatePendingCount();
    debugPrint('[SyncService] Alert queued locally. Total pending: ${queue.length}');
  }

  /// Attempts to upload all locally queued alerts.
  Future<void> _onReconnected() async {
    if (isSyncing.value) return;
    
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_offlineQueueKey) ?? [];
    
    if (queue.isEmpty) return;

    isSyncing.value = true;
    debugPrint('[SyncService] Online: starting sync flush for ${queue.length} alerts...');

    final List<String> failedToSync = [];

    for (final alertJson in queue) {
      try {
        final Map<String, dynamic> map = jsonDecode(alertJson);
        final Alert alert = Alert.fromMap(map);
        
        // Push to the correct Firebase path used by the dashboard
        await _dbRef.child('venues/mockVenue123/alerts/${alert.id}').set(alert.toMap());
        debugPrint('[SyncService] Successfully synced alert: ${alert.id}');
      } catch (e) {
        debugPrint('[SyncService] Sync failure for alert: $e');
        failedToSync.add(alertJson);
      }
    }

    // Update queue with only those that failed (usually empty if all good)
    await prefs.setStringList(_offlineQueueKey, failedToSync);
    isSyncing.value = false;
    _updatePendingCount();
    debugPrint('[SyncService] Sync cycle ended. Remaining: ${failedToSync.length}');
  }

  /// Returns all locally queued alerts (not yet synced) from SharedPreferences.
  Future<List<Alert>> getQueuedAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_offlineQueueKey) ?? [];
    final alerts = <Alert>[];
    for (final json in queue) {
      try {
        alerts.add(Alert.fromMap(Map<String, dynamic>.from(jsonDecode(json))));
      } catch (_) {}
    }
    return alerts;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
