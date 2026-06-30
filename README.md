# RGBIC Light Control

A simple Flutter BLE app for RGBIC / LED strip testing.

It includes only the controls you requested:

- BLE scan and connect
- Color 1 picker
- Optional Color 2 picker
- Thunder effect
- Flash effect
- Speed slider
- Brightness slider
- Stop / off button
- Protocol switch for testing two common ELK/Lotus-style command formats

## Important

This is not a clone of LotusLamp X. It is a clean custom controller app. It tries common ELK-BLEDOM / Lotus-style BLE commands, but your exact RGBIC device may use a different command protocol.

If it connects but the light does not change, test both protocol options in the control screen.

## How to run

1. Extract this folder.
2. Open terminal inside the folder.
3. Run:

```bash
flutter create . --platforms=android --project-name=rgbic_light_control
flutter pub get
```

4. Open `android/app/src/main/AndroidManifest.xml`.
5. Paste the permissions from:

```text
android_snippets/AndroidManifest_permissions.xml
```

Paste them directly under the opening `<manifest>` tag and before `<application>`.

6. In `android/app/build.gradle`, confirm Android min SDK is at least 21:

```gradle
minSdkVersion 21
```

7. Connect your Android phone using USB debugging.
8. Run:

```bash
flutter run
```

## Testing steps

1. Close LotusLamp X completely.
2. Turn on the RGBIC light.
3. Open this app.
4. Allow Nearby Devices / Bluetooth permission.
5. Tap Scan.
6. Select the device that looks like `ELK`, `MELK`, `LEDBLE`, `RGB`, or similar.
7. Tap Send Color 1.
8. Test Thunder and Flash.
9. If connected but no light change, switch the protocol dropdown and test again.

## Where to edit real commands

Open:

```text
lib/services/led_protocol.dart
```

Change these functions if your device uses different bytes:

- `powerOn()`
- `powerOff()`
- `setColor(Color color)`
- `setBrightness(int percent)`

## Current common commands included

Legacy format:

```text
Power on:  7E 00 04 F0 00 01 FF 00 EF
Power off: 7E 00 04 00 00 00 FF 00 EF
Color:     7E 00 05 03 RR GG BB 00 EF
```

Modern format:

```text
Power on:  7E 04 04 F0 00 01 FF 00 EF
Power off: 7E 04 04 00 00 00 FF 00 EF
Color:     7E 07 05 03 RR GG BB 10 EF
```
