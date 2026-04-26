import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:shared/models/alert.dart';

/// CrisisNet BLE Mesh — Gossip Protocol (Peripheral / Advertiser)
///
/// Role: Peripheral (Android only — iOS limitation per architecture §6).
/// The Guest App broadcasts a compact SOS beacon when Firebase is unreachable.
/// Any nearby device running the app picks it up via BleScannerService and
/// relays it to Firebase once connectivity returns.
///
/// Beacon payload (fits within BLE 31-byte advertising limit):
///   [shortId:8][type:1][severity:1][floor:1-2]  → max ~12 bytes
///
/// Gossip deduplication: Set<alertId> prevents rebroadcasting seen alerts.
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;
  final Set<String> _seenAlertIds = {};

  // CrisisNet custom service UUID
  static const String _serviceUuid = '0000CCA1-0000-1000-8000-00805F9B34FB';
  static const int _manufacturerId = 0xCCA1;

  bool get isAdvertising => _isAdvertising;

  /// Start broadcasting SOS alert as a BLE beacon. Android only.
  Future<void> startMeshAdvertising(Alert alert) async {
    if (!Platform.isAndroid) {
      print('[BleService] BLE advertising is Android only (iOS limitation per architecture §6).');
      return;
    }
    if (_isAdvertising) {
      print('[BleService] Already advertising — skipping duplicate start.');
      return;
    }

    try {
      // Encode compact payload: [shortId(8)][type(1)][severity(1)][floor(1-2)]
      final String shortId = alert.id.length > 8 ? alert.id.substring(0, 8) : alert.id;
      final int typeIndex = alert.type?.index ?? EmergencyType.other.index;
      final int severity  = alert.severity ?? 3;
      final int floor     = alert.floor;
      final String payloadStr = '$shortId$typeIndex$severity$floor';
      final List<int> payloadBytes = utf8.encode(payloadStr);

      // Build AdvertiseData using the flutter_ble_peripheral 0.3.0 API
      final advertiseData = AdvertiseData()
        ..uuid = _serviceUuid
        ..manufacturerId = _manufacturerId
        ..manufacturerData = payloadBytes
        ..includeDeviceName = false;

      await _peripheral.start(advertiseData);
      _seenAlertIds.add(alert.id);
      _isAdvertising = true;

      print('[BleService] ✅ BLE beacon LIVE. Payload: $payloadStr (${payloadBytes.length} bytes)');

    } catch (e) {
      print('[BleService] ❌ Failed to start BLE advertising: $e');
      _isAdvertising = false;
    }
  }

  /// Stop broadcasting.
  Future<void> stopMeshAdvertising() async {
    if (!_isAdvertising) return;
    try {
      await _peripheral.stop();
      _isAdvertising = false;
      print('[BleService] BLE beacon stopped.');
    } catch (e) {
      print('[BleService] Error stopping BLE advertising: $e');
    }
  }

  /// Gossip deduplication helpers (used by BleScannerService).
  bool hasSeenAlert(String alertId) => _seenAlertIds.contains(alertId);
  void markSeen(String alertId) => _seenAlertIds.add(alertId);
}
