import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  BluetoothDevice? connectedDevice;
  bool isScanning = false;
  List<ScanResult> scanResults = [];

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  void init(VoidCallback onUpdate) {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
      onUpdate();
    });
    FlutterBluePlus.isScanning.listen((scanning) {
      isScanning = scanning;
      onUpdate();
    });
  }

  Future<void> startScan() async {
    scanResults.clear();
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Scan error: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Stop scan error: $e');
    }
  }

  Future<void> connect(BluetoothDevice device, VoidCallback onUpdate) async {
    await stopScan();
    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          onUpdate();
        }
      });
      onUpdate();
    } catch (e) {
      debugPrint('Connect error: $e');
    }
  }

  Future<void> disconnect(VoidCallback onUpdate) async {
    try {
      await connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
    connectedDevice = null;
    onUpdate();
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
  }
}
