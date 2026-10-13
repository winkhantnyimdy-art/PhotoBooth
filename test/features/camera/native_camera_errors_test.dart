import 'package:flutter_test/flutter_test.dart';

import 'package:photo_booth/core/media/browser_capabilities_stub.dart';

/// Native (Android/iOS) camera error mapping.
///
/// The stub used to return null for every code, so a denied camera permission
/// surfaced the generic "Camera unavailable / try again" copy with no hint
/// about where to grant it. These tests pin the actionable Android messages.
void main() {
  group('BrowserCapabilities.describeCameraError (native)', () {
    test('a denied camera permission points at system Settings', () {
      final reason =
          BrowserCapabilities.describeCameraError('CameraAccessDenied');

      expect(reason, isNotNull);
      expect(reason!.title, contains('permission'));
      expect(reason.detail, contains('Settings'));
    });

    test('a missing camera keeps the no-camera copy', () {
      final reason =
          BrowserCapabilities.describeCameraError('cameraNotFound');

      expect(reason, isNotNull);
      expect(reason!.title, contains('No cameras'));
    });

    test('unknown codes fall back to the generic message', () {
      expect(BrowserCapabilities.describeCameraError(null), isNull);
      expect(BrowserCapabilities.describeCameraError(''), isNull);
      expect(
        BrowserCapabilities.describeCameraError('someFutureCode'),
        isNull,
      );
    });

    test('secure context and camera support are always true on native', () {
      expect(BrowserCapabilities.isSecureContext, isTrue);
      expect(BrowserCapabilities.hasCameraSupport, isTrue);
    });
  });
}
