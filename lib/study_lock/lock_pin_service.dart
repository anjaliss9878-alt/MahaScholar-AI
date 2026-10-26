import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PinVerification {
  const PinVerification.ok()
      : ok = true,
        lockedFor = null,
        attemptsLeft = 0;
  const PinVerification.wrong(this.attemptsLeft)
      : ok = false,
        lockedFor = null;
  const PinVerification.lockedOut(this.lockedFor)
      : ok = false,
        attemptsLeft = 0;

  final bool ok;
  final int attemptsLeft;
  final Duration? lockedFor;
}

class PinException implements Exception {
  const PinException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Stores a salted, iterated hash of the parent PIN in app-private native
/// storage (not readable by other apps).
/// The PIN is never kept in plain text and verification works offline.
class LockPinService {
  LockPinService() : _storage = _PinStorage();

  static const int minLength = 4;
  static const int maxLength = 6;
  static const int _maxAttempts = 5;
  static const int _iterations = 20000;

  static const _kHash = 'study_lock_pin_hash';
  static const _kSalt = 'study_lock_pin_salt';
  static const _kFails = 'study_lock_pin_fails';
  static const _kLockedUntil = 'study_lock_pin_locked_until';

  final _PinStorage _storage;

  Future<bool> hasPin() async {
    try {
      return (await _storage.read(key: _kHash)) != null;
    } catch (error) {
      debugPrint('PIN read failed: $error');
      return false;
    }
  }

  static bool isValidFormat(String pin) =>
      pin.length >= minLength &&
      pin.length <= maxLength &&
      RegExp(r'^\d+$').hasMatch(pin);

  /// Sets or changes the PIN. Changing requires [currentPin].
  Future<void> setPin(String newPin, {String? currentPin}) async {
    if (!isValidFormat(newPin)) {
      throw const PinException('PIN ४ ते ६ अंकी असावा / PIN must be 4–6 digits');
    }
    if (await hasPin()) {
      final check = await verify(currentPin ?? '');
      if (!check.ok) {
        throw const PinException('सध्याचा PIN चुकीचा आहे / Current PIN is wrong');
      }
    }
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    try {
      await _storage.write(key: _kSalt, value: salt);
      await _storage.write(key: _kHash, value: _hash(newPin, salt));
      await _resetFails();
    } catch (error) {
      debugPrint('PIN write failed: $error');
      throw const PinException('PIN जतन करता आला नाही / Could not save PIN');
    }
  }

  Future<PinVerification> verify(String pin) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final until = int.tryParse(await _storage.read(key: _kLockedUntil) ?? '');
      if (until != null && until > now) {
        return PinVerification.lockedOut(Duration(milliseconds: until - now));
      }
      final salt = await _storage.read(key: _kSalt);
      final stored = await _storage.read(key: _kHash);
      if (salt == null || stored == null) {
        return const PinVerification.wrong(0);
      }
      if (_constantTimeEquals(_hash(pin, salt), stored)) {
        await _resetFails();
        return const PinVerification.ok();
      }
      final fails =
          (int.tryParse(await _storage.read(key: _kFails) ?? '') ?? 0) + 1;
      await _storage.write(key: _kFails, value: '$fails');
      if (fails % _maxAttempts == 0) {
        // Back-off grows with every lockout round: 30s, 60s, 90s...
        final wait = Duration(seconds: 30 * (fails ~/ _maxAttempts));
        await _storage.write(
          key: _kLockedUntil,
          value: '${now + wait.inMilliseconds}',
        );
        return PinVerification.lockedOut(wait);
      }
      return PinVerification.wrong(_maxAttempts - (fails % _maxAttempts));
    } catch (error) {
      debugPrint('PIN verify failed: $error');
      return const PinVerification.wrong(0);
    }
  }

  Future<void> _resetFails() async {
    await _storage.delete(key: _kFails);
    await _storage.delete(key: _kLockedUntil);
  }

  String _hash(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin')).bytes;
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64Url.encode(digest);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class _PinStorage {
  static const _channel = MethodChannel('com.example.shala_saathi/lock_task');

  Future<String?> read({required String key}) =>
      _channel.invokeMethod<String>('prefGet', {'key': key});

  Future<void> write({required String key, required String value}) =>
      _channel.invokeMethod<void>('prefSet', {'key': key, 'value': value});

  Future<void> delete({required String key}) =>
      _channel.invokeMethod<void>('prefDelete', {'key': key});
}
