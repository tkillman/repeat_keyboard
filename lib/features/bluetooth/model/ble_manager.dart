import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager {
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String cmdCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String statusCharUuid = '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e';

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? cmdCharacteristic;
  BluetoothCharacteristic? statusCharacteristic;

  bool isScanning = false;
  List<ScanResult> scanResults = [];

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _statusSub;

  Function(Map<String, dynamic> data)? onTelemetry;

  bool get isConnected => connectedDevice != null;

  static bool isRepeatAduDevice(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.advertisementData.advName;
    final hasName = name.toLowerCase().contains('repeatadu');
    final hasService = result.advertisementData.serviceUuids.any(
      (uuid) => uuid.str128.toLowerCase().contains('4fafc201'),
    );
    return hasName || hasService;
  }

  void init(VoidCallback onUpdate) {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results.where(isRepeatAduDevice).toList();
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

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      debugPrint('[BLE] Discovered ${services.length} services');
      for (final service in services) {
        final sUuid = service.uuid.str128.toLowerCase();
        debugPrint('[BLE] Service found: $sUuid');
        if (sUuid == serviceUuid.toLowerCase()) {
          debugPrint('[BLE] >>> Autoclicker Service Matched! <<<');
          for (final c in service.characteristics) {
            final cUuid = c.uuid.str128.toLowerCase();
            debugPrint('[BLE] Characteristic found: $cUuid');
            if (cUuid == cmdCharUuid.toLowerCase()) {
              cmdCharacteristic = c;
              debugPrint('[BLE] >>> CMD Characteristic Ready! <<<');
            } else if (cUuid == statusCharUuid.toLowerCase()) {
              statusCharacteristic = c;
              debugPrint('[BLE] >>> STATUS Characteristic Ready! <<<');
              try {
                await c.setNotifyValue(true);
                _statusSub?.cancel();
                _statusSub = c.lastValueStream.listen((value) {
                  if (value.isNotEmpty) {
                    try {
                      final jsonStr = utf8.decode(value);
                      debugPrint('[BLE RX Telemetry] $jsonStr');
                      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
                      onTelemetry?.call(map);
                    } catch (e) {
                      debugPrint('Telemetry parse error: $e');
                    }
                  }
                });
              } catch (e) {
                debugPrint('setNotifyValue error: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('discoverServices error: $e');
    }
  }

  Future<void> connect(BluetoothDevice device, VoidCallback onUpdate) async {
    await stopScan();
    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;

      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Device disconnected');
          connectedDevice = null;
          cmdCharacteristic = null;
          statusCharacteristic = null;
          _statusSub?.cancel();
          onUpdate();
        }
      });

      // Discover Services & Characteristics
      await _discoverServices(device);
      onUpdate();
    } catch (e) {
      debugPrint('Connect error: $e');
    }
  }

  Future<void> sendCommand(Map<String, dynamic> jsonMap) async {
    if (connectedDevice == null) {
      debugPrint('[BLE ERROR] No connected device to send command');
      return;
    }
    if (cmdCharacteristic == null) {
      debugPrint('[BLE WARN] cmdCharacteristic is null, attempting discovery...');
      await _discoverServices(connectedDevice!);
    }
    if (cmdCharacteristic != null) {
      try {
        final jsonStr = jsonEncode(jsonMap);
        await cmdCharacteristic!.write(
          utf8.encode(jsonStr),
          withoutResponse: cmdCharacteristic!.properties.writeWithoutResponse && !cmdCharacteristic!.properties.write,
        );
        debugPrint('[BLE TX] Successfully sent command: $jsonStr');
      } catch (e) {
        debugPrint('[BLE ERROR] sendCommand write error: $e');
      }
    } else {
      debugPrint('[BLE ERROR] Could not find CMD characteristic');
    }
  }

  Future<void> disconnect(VoidCallback onUpdate) async {
    try {
      await connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
    connectedDevice = null;
    cmdCharacteristic = null;
    statusCharacteristic = null;
    _statusSub?.cancel();
    onUpdate();
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _statusSub?.cancel();
  }
}
