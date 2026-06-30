import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_service.dart';
import '../services/group_service.dart';
import 'control_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleService _bleService = BleService.instance;
  List<ScanResult> _results = [];
  List<DeviceGroup> _savedGroups = [];
  bool _isScanning = false;
  String? _message;
  bool _isConnecting = false;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _scanSub = _bleService.scanResults.listen((results) {
      if (!mounted) return;
      final filtered = [...results]
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      setState(() => _results = filtered);
    });
    _isScanningSub = _bleService.isScanning.listen((value) {
      if (!mounted) return;
      setState(() => _isScanning = value);
    });
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await GroupService.instance.getGroups();
    if (!mounted) return;
    setState(() => _savedGroups = groups);
  }

  Future<void> _startScan() async {
    setState(() => _message = null);
    try {
      await _bleService.startScan();
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  String _deviceName(ScanResult result) {
    final deviceName = result.device.platformName.trim();
    final advName = result.advertisementData.advName.trim();
    if (deviceName.isNotEmpty) return deviceName;
    if (advName.isNotEmpty) return advName;
    return 'Unknown BLE device';
  }

  bool _isLikelyLight(ScanResult result) {
    final text = '${_deviceName(result)} ${result.advertisementData.serviceUuids}'.toLowerCase();
    return text.contains('elk') ||
        text.contains('led') ||
        text.contains('rgb') ||
        text.contains('melk') ||
        text.contains('lotus') ||
        text.contains('fff0') ||
        text.contains('ffe0');
  }

  Future<void> _connect(BluetoothDevice device, {String? displayName}) async {
    setState(() {
      _isConnecting = true;
      _message = 'Connecting to ${displayName ?? device.remoteId.str}...';
    });
    try {
      await _bleService.connect(device);
      if (!mounted) return;
      setState(() => _message = 'Connected to ${displayName ?? device.remoteId.str}');
    } catch (e) {
      setState(() => _message = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect(BluetoothDevice device, {String? displayName}) async {
    setState(() => _message = 'Disconnecting ${displayName ?? device.remoteId.str}...');
    try {
      await _bleService.disconnectDevice(device);
      if (!mounted) return;
      setState(() => _message = 'Disconnected ${displayName ?? device.remoteId.str}');
    } catch (e) {
      setState(() => _message = 'Disconnect failed: $e');
    }
  }

  Future<void> _connectToGroup(DeviceGroup group) async {
    setState(() {
      _isConnecting = true;
      _message = 'Connecting to group ${group.name}...';
    });
    int successCount = 0;
    for (var id in group.deviceIds) {
      try {
        final device = BluetoothDevice.fromId(id);
        await _bleService.connect(device);
        successCount++;
      } catch (e) {
        print('Failed to connect to $id: $e');
      }
    }
    if (mounted) {
      setState(() {
        _isConnecting = false;
        _message = 'Connected to $successCount/${group.deviceIds.length} devices in ${group.name}';
      });
      if (successCount > 0) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ControlScreen()),
        ).then((_) => setState(() {}));
      }
    }
  }

  Future<void> _saveCurrentGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Group Name (e.g. Living Room)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (name != null && name.trim().isNotEmpty) {
      final ids = _bleService.connectedDevices.map((d) => d.remoteId.str).toList();
      final group = DeviceGroup(name: name.trim(), deviceIds: ids);
      await GroupService.instance.saveGroup(group);
      await _loadGroups();
      setState(() => _message = 'Saved group: ${group.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final likelyLights = _results.where(_isLikelyLight).toList();
    final otherDevices = _results.where((r) => !_isLikelyLight(r)).toList();
    final displayResults = [...likelyLights, ...otherDevices];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan RGBIC Lights'),
        actions: [
          IconButton(
            onPressed: _isScanning ? null : _startScan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _startScan,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_savedGroups.isNotEmpty) ...[
              Text('Saved Groups', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._savedGroups.map((g) => Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.group),
                      title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${g.deviceIds.length} lights'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await GroupService.instance.deleteGroup(g.name);
                              await _loadGroups();
                            },
                          ),
                          FilledButton.tonal(
                            onPressed: _isConnecting ? null : () => _connectToGroup(g),
                            child: const Text('Connect Group'),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
            ],
            Text('Scanner', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_isScanning ? Icons.radar : Icons.bluetooth_searching),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isScanning ? 'Scanning nearby BLE devices...' : 'Scan finished',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (_isConnecting) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 8),
                    const Text('Tip: keep the LotusLamp app closed while testing this app.'),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (displayResults.isEmpty && !_isScanning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No devices found. Pull down or tap refresh to scan again.'),
                ),
              ),
            ...displayResults.map((result) {
              final likely = _isLikelyLight(result);
              final isConnected = _bleService.connectedDevices.any((d) => d.remoteId == result.device.remoteId);
              return Card(
                child: ListTile(
                  leading: Icon(likely ? Icons.lightbulb : Icons.bluetooth, 
                    color: isConnected ? Colors.green : null),
                  title: Text(_deviceName(result)),
                  subtitle: Text('ID: ${result.device.remoteId.str}\nRSSI: ${result.rssi}'),
                  isThreeLine: true,
                  trailing: FilledButton.tonal(
                    onPressed: _isConnecting ? null : () => isConnected 
                        ? _disconnect(result.device, displayName: _deviceName(result)) 
                        : _connect(result.device, displayName: _deviceName(result)),
                    child: Text(isConnected ? 'Disconnect' : 'Connect'),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_bleService.connectedDevices.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'save_group',
                onPressed: _saveCurrentGroup,
                icon: const Icon(Icons.save),
                label: const Text('Save Group'),
              ),
            ),
          if (_bleService.connectedDevices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'control',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ControlScreen()),
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.settings_remote),
                label: Text('Control ${_bleService.connectedDevices.length} Lights'),
              ),
            ),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _isScanning ? null : _startScan,
            icon: _isScanning
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_isScanning ? 'Scanning' : 'Scan'),
          ),
        ],
      ),
    );
  }
}
