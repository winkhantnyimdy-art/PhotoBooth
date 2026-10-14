import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android launcher branding added in Checkpoint 6.
///
/// The Flutter template ships default `ic_launcher.png` files that are easy
/// to regress to (or silently drop) during merges. These tests pin the
/// branded asset set: per-density legacy + adaptive foreground PNGs at the
/// exact dimensions Android expects, the adaptive-icon XML referencing them,
/// and the backdrop color they share with the splash theme.
String _res(String path) => 'android/app/src/main/res/$path';

/// Reads PNG width/height from the IHDR chunk (bytes 16..24), big-endian.
(int, int) _pngSize(Uint8List bytes) {
  expect(bytes.length, greaterThan(24));
  expect(
    String.fromCharCodes(bytes.sublist(1, 4)),
    'PNG',
    reason: 'not a PNG file',
  );
  final ByteData view = ByteData.sublistView(bytes);
  return (view.getUint32(16), view.getUint32(20));
}

void main() {
  group('Android launcher branding', () {
    const Map<String, int> legacy = <String, int>{
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    const Map<String, int> foreground = <String, int>{
      'mipmap-mdpi': 108,
      'mipmap-hdpi': 162,
      'mipmap-xhdpi': 216,
      'mipmap-xxhdpi': 324,
      'mipmap-xxxhdpi': 432,
    };

    test('legacy icons exist at every density with exact sizes', () {
      for (final MapEntry<String, int> entry in legacy.entries) {
        final File file = File(_res('${entry.key}/ic_launcher.png'));
        expect(file.existsSync(), isTrue, reason: entry.key);
        final (int w, int h) = _pngSize(file.readAsBytesSync());
        expect(w, entry.value, reason: '${entry.key} width');
        expect(h, entry.value, reason: '${entry.key} height');
      }
    });

    test('adaptive foregrounds exist at every density with exact sizes', () {
      for (final MapEntry<String, int> entry in foreground.entries) {
        final File file =
            File(_res('${entry.key}/ic_launcher_foreground.png'));
        expect(file.existsSync(), isTrue, reason: entry.key);
        final (int w, int h) = _pngSize(file.readAsBytesSync());
        expect(w, entry.value, reason: '${entry.key} width');
        expect(h, entry.value, reason: '${entry.key} height');
      }
    });

    test('adaptive-icon XML wires the branded layers', () {
      for (final String name in <String>[
        'ic_launcher.xml',
        'ic_launcher_round.xml',
      ]) {
        final String xml = File(
          _res('mipmap-anydpi-v26/$name'),
        ).readAsStringSync();
        expect(xml, contains('<adaptive-icon'), reason: name);
        expect(
          xml,
          contains('@color/ic_launcher_background'),
          reason: '$name background',
        );
        expect(
          xml,
          contains('@mipmap/ic_launcher_foreground'),
          reason: '$name foreground',
        );
      }
    });

    test('icon backdrop color is defined and manifest points at the icon',
        () {
      expect(
        File(_res('values/colors.xml')).readAsStringSync(),
        contains('name="ic_launcher_background"'),
      );
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:icon="@mipmap/ic_launcher"'),
      );
    });
  });
}
