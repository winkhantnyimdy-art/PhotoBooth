import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CameraController constructor in test', () {
    final controller = CameraController(
      CameraDescription(
        name: 'x',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 0,
      ),
      ResolutionPreset.high,
    );
    print('CTOR_OK value.isInitialized=${controller.value.isInitialized}');
    expect(true, isTrue);
  });
}
