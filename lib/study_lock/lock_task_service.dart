import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to Android's `startLockTask()` / `stopLockTask()`.
///
/// Without device-owner provisioning Android shows a one-time "screen pinning"
/// confirmation; with a device-owner / `setLockTaskPackages` it is a true kiosk.
class LockTaskService {
  const LockTaskService();

  static const MethodChannel _channel =
      MethodChannel('com.example.shala_saathi/lock_task');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> start() => _invoke('startLockTask');

  Future<bool> stop() => _invoke('stopLockTask');

  Future<bool> isLocked() => _invoke('isLocked');

  Future<bool> _invoke(String method) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (error) {
      debugPrint('LockTask $method failed: ${error.code} ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
