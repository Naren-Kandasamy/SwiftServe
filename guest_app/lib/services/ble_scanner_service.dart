import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'ble_service.dart';

/// CrisisNet BLE Mesh — Gossip Scanner (Central Role)
///
/// Any device running the Guest App (or a staff relay device) scans for
/// CrisisNet beacons from other devices. When it sees an alert it hasn't
/// processed before, it:
///   1. Parses the payload
///   2. Writes it to Firebase (if online)
///   3. Re-broadcasts it via BleService to extend the mesh range
///
/// This makes every Android phone in the venue a relay node, extending
/// effective range far beyond a single BLE hop (~50m).
class BleScannerService {
  static final BleScannerService _instance = BleScannerService._internal();
  factory BleScannerService() => _instance;
  BleScannerService._internal();

  static const String _serviceUuid = '0000CCA1-0000-1000-8000-00805F9B34FB';
  static const int _manufacturerId = 0xCCA1;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;

  bool get isScanning => _isScanning;

  /// Start scanning for nearby CrisisNet BLE beacons.
  /// [venueId] is used to write discovered alerts to the correct Firebase path.
  Future<void> startScanning({required String venueId}) async {
    if (!Platform.isAndroid) {
      print('[BleScannerService] BLE scan available on Android only.');
      return;
    }
    if (_isScanning) return;

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        print('[BleScannerService] Bluetooth not supported.');
        return;
      }

      _isScanning = true;
      print('[BleScannerService] 📡 Scanning for CrisisNet BLE beacons...');

      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 0), // Continuous scan
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          _handleScanResult(result, venueId: venueId);
        }
      });

    } catch (e) {
      print('[BleScannerService] Failed to start scan: $e');
      _isScanning = false;
    }
  }

  void _handleScanResult(ScanResult result, {required String venueId}) {
    final mfData = result.advertisementData.manufacturerData;
    if (!mfData.containsKey(_manufacturerId)) return;

    try {
      final bytes = mfData[_manufacturerId]!;
      final payloadStr = utf8.decode(bytes);

      // Payload format: [shortId(8)][type(1)][severity(1)][floor(1-2)]
      if (payloadStr.length < 10) return;

      final shortId  = payloadStr.substring(0, 8);
      final typeIdx  = int.tryParse(payloadStr[8]) ?? 4;
      final severity = int.tryParse(payloadStr[9]) ?? 3;
      final floor    = int.tryParse(payloadStr.substring(10)) ?? 1;

      // Gossip deduplication — ignore if we've seen this alert before
      if (BleService().hasSeenAlert(shortId)) return;
      BleService().markSeen(shortId);

      print('[BleScannerService] 📥 Received BLE relay beacon: ID=$shortId type=$typeIdx sev=$severity fl=$floor');

      // Write to Firebase so dashboard receives it
      _relayToFirebase(
        shortId: shortId,
        typeIndex: typeIdx,
        severity: severity,
        floor: floor,
        venueId: venueId,
      );

    } catch (e) {
      print('[BleScannerService] Failed to parse beacon payload: $e');
    }
  }

  Future<void> _relayToFirebase({
    required String shortId,
    required int typeIndex,
    required int severity,
    required int floor,
    required String venueId,
  }) async {
    try {
      final alertId = 'ble_$shortId';
      final alertMap = {
        'id': alertId,
        'userId': 'ble_relay',
        'venueId': venueId,
        'roomNumber': 'Unknown (BLE relay)',
        'floor': floor,
        'description': '[BLE Relay] Alert received via offline mesh. Severity $severity.',
        'type': _typeNames[typeIndex] ?? 'other',
        'severity': severity,
        'status': 'pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'assignedTo': <String>[],
        'location': {'lat': 0.0, 'lng': 0.0},
      };

      await FirebaseDatabase.instance
          .ref('venues/$venueId/alerts/$alertId')
          .set(alertMap)
          .timeout(const Duration(seconds: 10));

      print('[BleScannerService] ✅ BLE alert relayed to Firebase: $alertId');
    } catch (e) {
      print('[BleScannerService] Failed to relay to Firebase: $e');
    }
  }

  static const List<String> _typeNames = [
    'fire', 'medical', 'security', 'infrastructure', 'other'
  ];

  Future<void> stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      print('[BleScannerService] Scan stopped.');
    }
  }
}
