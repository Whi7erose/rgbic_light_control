import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'led_protocol.dart';

class BleService {
  BleService._();

  static final BleService instance = BleService._();

  final List<BluetoothDevice> connectedDevices = [];
  final Map<String, BluetoothCharacteristic> writeCharacteristics = {};
  final LedProtocol protocol = LedProtocol();

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> startScan() async {
    await requestPermissions();
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    
    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
      );
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (!message.contains('already connected')) {
        rethrow;
      }
    }

    await _findWriteCharacteristic(device);
    
    if (!connectedDevices.any((d) => d.remoteId == device.remoteId)) {
      connectedDevices.add(device);
    }
  }

  Future<void> disconnect() async {
    for (final device in connectedDevices) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    connectedDevices.clear();
    writeCharacteristics.clear();
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
    connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
    writeCharacteristics.remove(device.remoteId.str);
  }

  Future<void> _findWriteCharacteristic(BluetoothDevice device) async {
    final services = await device.discoverServices();

    // Prefer common ELK-BLEDOM/Lotus style write characteristics first.
    final preferredUuidFragments = <String>['fff3', 'ffe1'];

    for (final fragment in preferredUuidFragments) {
      for (final service in services) {
        for (final c in service.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          if (uuid.contains(fragment) &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            writeCharacteristics[device.remoteId.str] = c;
            return;
          }
        }
      }
    }

    // Fallback: choose the first writable characteristic.
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          writeCharacteristics[device.remoteId.str] = c;
          return;
        }
      }
    }

    throw Exception('No writable BLE characteristic found for ${device.remoteId.str}.');
  }

  Future<void> writeBytes(List<int> bytes) async {
    if (connectedDevices.isEmpty) {
      throw Exception('No lights are connected.');
    }

    for (final device in connectedDevices) {
      final characteristic = writeCharacteristics[device.remoteId.str];
      if (characteristic != null) {
        try {
          await characteristic.write(
            bytes,
            withoutResponse: characteristic.properties.writeWithoutResponse,
          );
        } catch (e) {
          print('Failed to write to ${device.remoteId.str}: $e');
        }
      }
    }
  }

  Future<void> powerOn() => writeBytes(protocol.powerOn());

  Future<void> powerOff() => writeBytes(protocol.powerOff());

  Future<void> setColor(Color color) async {
    await writeBytes(protocol.setColor(color));
  }

  Future<void> setBrightness(int percent) async {
    await writeBytes(protocol.setBrightness(percent));
  }

  String? get connectedDeviceName {
    if (connectedDevices.isEmpty) return null;
    return connectedDevices.map((device) {
      final name = device.platformName.trim();
      return name.isEmpty ? device.remoteId.str : name;
    }).join(', ');
  }

  String? get writeCharacteristicId {
    if (writeCharacteristics.isEmpty) return null;
    return writeCharacteristics.values.first.uuid.toString();
  }
}
