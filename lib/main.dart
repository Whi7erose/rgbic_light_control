import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'screens/scan_screen.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.info, color: true);
  runApp(const RgbicApp());
}

class RgbicApp extends StatefulWidget {
  const RgbicApp({super.key});

  @override
  State<RgbicApp> createState() => _RgbicAppState();
}

class _RgbicAppState extends State<RgbicApp> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;

  @override
  void initState() {
    super.initState();
    _adapterSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      setState(() => _adapterState = state);
    });
  }

  @override
  void dispose() {
    _adapterSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RGBIC Light Control',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: _adapterState == BluetoothAdapterState.on
          ? const ScanScreen()
          : BluetoothOffScreen(adapterState: _adapterState),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({super.key, required this.adapterState});

  final BluetoothAdapterState adapterState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.bluetooth_disabled, size: 96),
              const SizedBox(height: 24),
              Text(
                'Bluetooth is not ready',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Current state: ${adapterState.name}\nTurn on Bluetooth and allow Nearby Devices permission.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await FlutterBluePlus.turnOn();
                  } catch (_) {
                    // Some phones do not allow apps to turn Bluetooth on directly.
                  }
                },
                icon: const Icon(Icons.bluetooth),
                label: const Text('Turn Bluetooth On'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
