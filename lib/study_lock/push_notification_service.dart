import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this device's FCM token under `users/{uid}/fcm_tokens/{token}`
/// (the Cloud Function reads it to notify parents) and exposes foreground
/// messages so the UI can show them in-app.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _foreground = StreamController<RemoteMessage>.broadcast();
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  String? _uid;

  Stream<RemoteMessage> get foregroundMessages => _foreground.stream;

  /// Safe to call repeatedly; returns false when permission is denied.
  Future<bool> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;

      _uid = user.uid;
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _saveToken(user.uid, token);

      await _refreshSub?.cancel();
      // ignore: deprecated_member_use
      _refreshSub = messaging.onTokenRefresh.listen((fresh) {
        final uid = _uid;
        if (uid != null) unawaited(_saveToken(uid, fresh));
      }, onError: (Object e) => debugPrint('FCM token refresh error: $e'));

      _messageSub ??= FirebaseMessaging.onMessage.listen(_foreground.add);
      return true;
    } catch (error) {
      debugPrint('FCM init failed: $error');
      return false;
    }
  }

  /// Call on sign-out so the next user on this device does not receive pushes.
  /// Never throws and is bounded by timeouts so sign-out is not blocked
  /// when the device is offline.
  Future<void> detach() async {
    // After an app restart [_uid] is null; fall back to the signed-in user.
    final uid = _uid ?? _currentUid();
    _uid = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (uid == null) return;
    try {
      // ignore: deprecated_member_use
      final tokenFuture = FirebaseMessaging.instance.getToken();
      final token = await tokenFuture.timeout(const Duration(seconds: 5));
      if (token != null) {
        await _tokens(uid)
            .doc(token)
            .delete()
            .timeout(const Duration(seconds: 5));
      }
    } catch (error) {
      debugPrint('FCM detach failed: $error');
    }
  }

  String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase not initialised
    }
  }

  CollectionReference<Map<String, dynamic>> _tokens(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens');

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _tokens(uid).doc(token).set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('FCM token save failed: $error');
    }
  }
}

class ParentLinkException implements Exception {
  const ParentLinkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parent linking goes through callable Cloud Functions so a student cannot
/// forge a link and a parent cannot guess one (codes are server-generated,
/// single-use and expire after 10 minutes).
class ParentLinkService {
  ParentLinkService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Student side: returns a one-time code to show to the parent.
  Future<String> createCode() async {
    final data = await _call('createParentLinkCode', const {});
    final code = data['code'];
    if (code is! String) {
      throw const ParentLinkException('कोड मिळाला नाही / No code received');
    }
    return code;
  }

  /// Parent side: links the signed-in parent to the student owning [code].
  Future<void> redeemCode(String code) async {
    await _call('linkParent', {'code': code.trim()});
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<Object?, Object?>>(payload)
          .timeout(const Duration(seconds: 20));
      return result.data.map((k, v) => MapEntry('$k', v));
    } on FirebaseFunctionsException catch (error) {
      throw ParentLinkException(error.message ?? error.code);
    } on TimeoutException {
      throw const ParentLinkException(
          'सर्व्हर प्रतिसाद देत नाही / Server timed out');
    } catch (error) {
      debugPrint('$name failed: $error');
      throw const ParentLinkException('काहीतरी चुकले / Something went wrong');
    }
  }
}
