import 'dart:async';
import 'dart:math';
import 'dart:ui';

import '../services/ble_service.dart';

enum RunningEffect { none, thunder, flash, cloud, strobe, breathe }

class EffectRunner {
  EffectRunner(this.bleService);

  final BleService bleService;
  final Random _random = Random();
  
  // Use an ID to prevent overlapping loops when button is pressed rapidly
  int _runId = 0;
  RunningEffect currentEffect = RunningEffect.none;

  bool get isRunning => currentEffect != RunningEffect.none;

  void stop() {
    _runId++;
    currentEffect = RunningEffect.none;
  }

  int _baseDelayMs(double speed) {
    // speed: 1 = slow, 10 = fast
    final clamped = speed.clamp(1.0, 10.0);
    return (750 - (clamped * 60)).round().clamp(80, 700);
  }

  Future<void> startFlash({
    required Color color1,
    required Color color2,
    required bool useSecondColor,
    required double speed,
  }) async {
    stop();
    _runId++;
    final myRunId = _runId;
    currentEffect = RunningEffect.flash;

    await bleService.powerOn();
    final delay = _baseDelayMs(speed);

    while (myRunId == _runId) {
      await bleService.setColor(color1);
      await Future.delayed(Duration(milliseconds: delay));
      if (myRunId != _runId) break;

      await bleService.powerOff();
      await Future.delayed(Duration(milliseconds: (delay * 0.65).round()));
      if (myRunId != _runId) break;

      if (useSecondColor) {
        await bleService.setColor(color2);
        await Future.delayed(Duration(milliseconds: delay));
        if (myRunId != _runId) break;

        await bleService.powerOff();
        await Future.delayed(Duration(milliseconds: (delay * 0.65).round()));
      }
    }
  }

  Future<void> startThunder({
    required Color color1,
    required Color color2,
    required bool useSecondColor,
    required double speed,
  }) async {
    stop();
    _runId++;
    final myRunId = _runId;
    currentEffect = RunningEffect.thunder;

    await bleService.powerOn();
    final base = _baseDelayMs(speed);

    while (myRunId == _runId) {
      final pulseCount = 1 + _random.nextInt(3);
      for (var i = 0; i < pulseCount; i++) {
        if (myRunId != _runId) break;
        final color = useSecondColor && _random.nextBool() ? color2 : color1;
        final onTime = (base * (0.14 + _random.nextDouble() * 0.20)).round();
        final offTime = (base * (0.10 + _random.nextDouble() * 0.25)).round();

        await bleService.setColor(color);
        await Future.delayed(Duration(milliseconds: onTime.clamp(35, 220)));
        if (myRunId != _runId) break;
        
        await bleService.powerOff();
        await Future.delayed(Duration(milliseconds: offTime.clamp(40, 260)));
      }

      if (myRunId != _runId) break;
      final pause = (base * (0.7 + _random.nextDouble() * 1.6)).round();
      await Future.delayed(Duration(milliseconds: pause.clamp(120, 1200)));
    }
  }

  Future<void> startCloud({
    required Color baseColor,
    required Color lightningColor,
    required double speed,
  }) async {
    stop();
    _runId++;
    final myRunId = _runId;
    currentEffect = RunningEffect.cloud;

    await bleService.powerOn();
    final base = _baseDelayMs(speed);

    // Initial state: base color
    await bleService.setColor(baseColor);

    while (myRunId == _runId) {
      final pulseCount = 1 + _random.nextInt(3);
      for (var i = 0; i < pulseCount; i++) {
        if (myRunId != _runId) break;

        // Flash lightning color
        await bleService.setColor(lightningColor);
        final onTime = (base * (0.14 + _random.nextDouble() * 0.20)).round();
        await Future.delayed(Duration(milliseconds: onTime.clamp(35, 220)));

        if (myRunId != _runId) break;

        // Return to base color instead of turning off
        await bleService.setColor(baseColor);
        final offTime = (base * (0.10 + _random.nextDouble() * 0.25)).round();
        await Future.delayed(Duration(milliseconds: offTime.clamp(40, 260)));
      }

      if (myRunId != _runId) break;
      final pause = (base * (0.7 + _random.nextDouble() * 1.6)).round();
      await Future.delayed(Duration(milliseconds: pause.clamp(120, 1200)));
    }
  }

  Future<void> startStrobe({
    required Color color,
    required double speed,
  }) async {
    stop();
    _runId++;
    final myRunId = _runId;
    currentEffect = RunningEffect.strobe;

    await bleService.powerOn();

    // Fast strobe delay: 10 = ~30ms, 1 = ~250ms
    final delay = (250 - (speed * 22)).round().clamp(20, 300);

    while (myRunId == _runId) {
      await bleService.setColor(color);
      await Future.delayed(Duration(milliseconds: delay));
      if (myRunId != _runId) break;

      await bleService.powerOff();
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  Future<void> startBreathe({
    required Color color,
    required double speed,
  }) async {
    stop();
    _runId++;
    final myRunId = _runId;
    currentEffect = RunningEffect.breathe;

    await bleService.powerOn();
    await bleService.setColor(color);

    // speed: 1 = slow, 10 = fast
    final stepDelay = (60 - (speed * 4)).round().clamp(10, 80);

    while (myRunId == _runId) {
      // Fade down
      for (var b = 100; b >= 10; b -= 5) {
        if (myRunId != _runId) break;
        await bleService.setBrightness(b);
        await Future.delayed(Duration(milliseconds: stepDelay));
      }
      
      if (myRunId != _runId) break;

      // Fade up
      for (var b = 10; b <= 100; b += 5) {
        if (myRunId != _runId) break;
        await bleService.setBrightness(b);
        await Future.delayed(Duration(milliseconds: stepDelay));
      }
      
      if (myRunId != _runId) break;
      await Future.delayed(Duration(milliseconds: stepDelay * 4));
    }
  }
}
