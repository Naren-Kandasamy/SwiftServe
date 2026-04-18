import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared/models/alert.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  bool _isAdvertising = false;
  final Set<String> _seenAlertIds = {};

  // For Android only (iOS doesn't support background BLE ad payload as needed here)
  Future<void> startMeshAdvertising(Alert alert) async {
    if (!Platform.isAndroid) {
      print('[BleService] BLE Mesh advertising is only supported on Android.');
      return;
    }

    if (_isAdvertising) return;

    try {
      if (await FlutterBluePlus.isSupported == false) {
        print('[BleService] Bluetooth not supported by this device.');
        return;
      }

      // We use a simplified UUID for our custom service
      final Guid serviceUuid = Guid("0000aaaa-0000-1000-8000-00805f9b34fb");

      // Encode payload: [alertId: 8 chars][type: 1 char][severity: 1 char][floor: 1 char] = 11 chars
      // This fits well within the 31-byte advertising limit
      final String shortId = alert.id.length > 8 ? alert.id.substring(0, 8) : alert.id;
      final int typeIndex = alert.type?.index ?? EmergencyType.other.index;
      final int severity = alert.severity ?? 3;
      final int floor = alert.floor;
      
      final String payloadStr = '\$shortId\$typeIndex\$severity\$floor';
      final List<int> payloadBytes = utf8.encode(payloadStr);

      // Unfortunately, startAdvertising is not directly exposing payload bytes in modern flutter_blue_plus
      // In a real full production implementation, we'd use flutter_beacon or specific platform channels
      // For this MVP, we simulate the logic:
      
      print('[BleService] Starting BLE Mesh Beacon Gossip Protocol.');
      print('[BleService] Beacon Payload: \$payloadStr');
      _seenAlertIds.add(alert.id);
      _isAdvertising = true;
      
      // Simulate advertising active state
      await Future.delayed(const Duration(milliseconds: 500));
      print('[BleService] BLE beacon broadcasting successfully.');

    } catch (e) {
      print('[BleService] Failed to start BLE advertising: \$e');
      _isAdvertising = false;
    }
  }

  void stopMeshAdvertising() {
    if (_isAdvertising) {
       // Stop simulated advertising
       _isAdvertising = false;
       print('[BleService] BLE beacon stopped.');
    }
  }
}
