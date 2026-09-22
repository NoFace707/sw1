import 'package:flutter/services.dart';

import 'local_model_manager.dart';

class DeviceResourceProbe {
  const DeviceResourceProbe();

  static const _channel = MethodChannel('sw1.local_ai/resources');

  Future<bool> hasNativeRuntime() async {
    try {
      return await _channel.invokeMethod<bool>('checkNativeRuntime') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<DeviceResourceProfile> read() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('read');
    if (data == null) throw StateError('No se pudieron medir los recursos.');
    return DeviceResourceProfile(
      architecture: '${data['architecture'] ?? 'unsupported'}',
      ramBytes: (data['ramBytes'] as num?)?.toInt() ?? 0,
      freeStorageBytes: (data['freeStorageBytes'] as num?)?.toInt() ?? 0,
    );
  }
}
