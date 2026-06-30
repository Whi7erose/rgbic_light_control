import 'package:flutter/material.dart';

import '../effects/effect_runner.dart';
import '../services/ble_service.dart';
import '../services/led_protocol.dart';
import '../widgets/color_picker_button.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final BleService _bleService = BleService.instance;
  late final EffectRunner _effectRunner;

  Color _color1 = Colors.white;
  Color _color2 = Colors.deepPurpleAccent;
  bool _useSecondColor = true;
  double _speed = 5;
  int _brightness = 100;
  String _status = 'Connected';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _effectRunner = EffectRunner(_bleService);
  }

  @override
  void dispose() {
    _effectRunner.stop();
    super.dispose();
  }

  Future<void> _safeAction(Future<void> Function() action, String successMessage) async {
    setState(() {
      _busy = true;
      _status = 'Sending command...';
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _status = successMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendStaticColor(Color color) async {
    await _safeAction(() async {
      _effectRunner.stop();
      await _bleService.powerOn();
      await _bleService.setBrightness(_brightness);
      await _bleService.setColor(color);
    }, 'Static color sent');
  }

  Future<void> _startFlash() async {
    setState(() => _status = 'Flash running');
    await _effectRunner.startFlash(
      color1: _color1,
      color2: _color2,
      useSecondColor: _useSecondColor,
      speed: _speed,
    );
  }

  Future<void> _startThunder() async {
    setState(() => _status = 'Thunder running');
    await _effectRunner.startThunder(
      color1: _color1,
      color2: _color2,
      useSecondColor: _useSecondColor,
      speed: _speed,
    );
  }

  Future<void> _startCloud() async {
    setState(() => _status = 'Cloud running');
    await _effectRunner.startCloud(
      baseColor: _color1,
      lightningColor: _useSecondColor ? _color2 : Colors.white,
      speed: _speed,
    );
  }

  Future<void> _startStrobe() async {
    setState(() => _status = 'Strobe running');
    await _effectRunner.startStrobe(
      color: _color1,
      speed: _speed,
    );
  }

  Future<void> _startBreathe() async {
    setState(() => _status = 'Breathe running');
    await _effectRunner.startBreathe(
      color: _color1,
      speed: _speed,
    );
  }

  Future<void> _stopEffect() async {
    await _safeAction(() async {
      _effectRunner.stop();
      await _bleService.powerOff();
    }, 'Stopped');
  }

  String _hex(List<int> bytes) => _bleService.protocol.toHex(bytes);

  @override
  Widget build(BuildContext context) {
    final protocol = _bleService.protocol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RGBIC Control'),
        actions: [
          IconButton(
            onPressed: () async {
              _effectRunner.stop();
              await _bleService.disconnect();
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bleService.connectedDevices.isNotEmpty 
                        ? '${_bleService.connectedDevices.length} Device(s): ${_bleService.connectedDeviceName}'
                        : 'RGBIC Device',
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text('Write characteristic: ${_bleService.writeCharacteristicId ?? 'not found'}'),
                  const SizedBox(height: 6),
                  Text('Status: $_status'),
                  if (_busy) const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ColorPickerButton(
            title: 'Color 1',
            color: _color1,
            onChanged: (value) => setState(() => _color1 = value),
          ),
          SwitchListTile(
            title: const Text('Use second color'),
            subtitle: const Text('Thunder and Flash can alternate between two colors.'),
            value: _useSecondColor,
            onChanged: (value) => setState(() => _useSecondColor = value),
          ),
          if (_useSecondColor)
            ColorPickerButton(
              title: 'Color 2',
              color: _color2,
              onChanged: (value) => setState(() => _color2 = value),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Speed: ${_speed.toStringAsFixed(1)}', style: Theme.of(context).textTheme.titleMedium),
                  Slider(
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _speed.toStringAsFixed(1),
                    value: _speed,
                    onChanged: (value) => setState(() => _speed = value),
                  ),
                  Text('Brightness: $_brightness%', style: Theme.of(context).textTheme.titleMedium),
                  Slider(
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '$_brightness%',
                    value: _brightness.toDouble(),
                    onChanged: (value) => setState(() => _brightness = value.round()),
                    onChangeEnd: (value) => _safeAction(
                      () => _bleService.setBrightness(value.round()),
                      'Brightness updated',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _sendStaticColor(_color1),
                    icon: const Icon(Icons.palette),
                    label: const Text('Send Color 1'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _startThunder(),
                    icon: const Icon(Icons.thunderstorm),
                    label: const Text('Start Thunder Effect'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _startCloud(),
                    icon: const Icon(Icons.cloud),
                    label: const Text('Start Cloud Effect'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _startFlash(),
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Start Flash Effect'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _startStrobe(),
                    icon: const Icon(Icons.flare),
                    label: const Text('Start Fast Strobe Effect'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _startBreathe(),
                    icon: const Icon(Icons.air),
                    label: const Text('Start Breathe Effect'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _stopEffect,
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Stop / Off'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Protocol testing', style: Theme.of(context).textTheme.titleMedium),
                  DropdownButton<LedProtocolVariant>(
                    isExpanded: true,
                    value: protocol.variant,
                    items: LedProtocolVariant.values
                        .map((variant) => DropdownMenuItem(
                              value: variant,
                              child: Text(variant.label),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => protocol.variant = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Color command: ${_hex(protocol.setColor(_color1))}'),
                  Text('Off command: ${_hex(protocol.powerOff())}'),
                  const SizedBox(height: 8),
                  const Text(
                    'If the device connects but light does not change, switch protocol and test again.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
