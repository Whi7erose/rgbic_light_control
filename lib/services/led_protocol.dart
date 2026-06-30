import 'dart:ui';

enum LedProtocolVariant {
  elkLegacy,
  elkModern,
}

extension LedProtocolVariantName on LedProtocolVariant {
  String get label {
    switch (this) {
      case LedProtocolVariant.elkLegacy:
        return 'ELK legacy: 7E 00 ... EF';
      case LedProtocolVariant.elkModern:
        return 'ELK modern: 7E 07 ... EF';
    }
  }
}

class LedProtocol {
  LedProtocol({this.variant = LedProtocolVariant.elkLegacy});

  LedProtocolVariant variant;

  List<int> powerOn() {
    switch (variant) {
      case LedProtocolVariant.elkLegacy:
        return [0x7e, 0x00, 0x04, 0xf0, 0x00, 0x01, 0xff, 0x00, 0xef];
      case LedProtocolVariant.elkModern:
        return [0x7e, 0x04, 0x04, 0xf0, 0x00, 0x01, 0xff, 0x00, 0xef];
    }
  }

  List<int> powerOff() {
    switch (variant) {
      case LedProtocolVariant.elkLegacy:
        return [0x7e, 0x00, 0x04, 0x00, 0x00, 0x00, 0xff, 0x00, 0xef];
      case LedProtocolVariant.elkModern:
        return [0x7e, 0x04, 0x04, 0x00, 0x00, 0x00, 0xff, 0x00, 0xef];
    }
  }

  List<int> setColor(Color color) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;
    switch (variant) {
      case LedProtocolVariant.elkLegacy:
        return [0x7e, 0x00, 0x05, 0x03, r, g, b, 0x00, 0xef];
      case LedProtocolVariant.elkModern:
        return [0x7e, 0x07, 0x05, 0x03, r, g, b, 0x10, 0xef];
    }
  }

  List<int> setBrightness(int percent) {
    final safePercent = percent.clamp(1, 100);
    final value = ((safePercent / 100) * 0xff).round().clamp(1, 0xff);
    switch (variant) {
      case LedProtocolVariant.elkLegacy:
        return [0x7e, 0x00, 0x01, value, 0x00, 0x00, 0x00, 0x00, 0xef];
      case LedProtocolVariant.elkModern:
        return [0x7e, 0x04, 0x01, value, 0x00, 0x00, 0x00, 0x00, 0xef];
    }
  }

  String toHex(List<int> bytes) => bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
