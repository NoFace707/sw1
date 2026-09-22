import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/ai/data/device_resource_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sw1.local_ai/resources');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('detecta el runtime nativo empaquetado', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'checkNativeRuntime');
          return true;
        });

    expect(await const DeviceResourceProbe().hasNativeRuntime(), isTrue);
  });

  test(
    'una biblioteca ausente deshabilita la IA local sin propagar error',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'native-runtime-missing');
          });

      expect(await const DeviceResourceProbe().hasNativeRuntime(), isFalse);
    },
  );
}
