import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

enum StudyState { idle, active, paused, ending }

/// Tracks one study session and mirrors its state to
/// `study_sessions/{id}`. A Cloud Function (see `functions/index.js`) turns
/// state changes into FCM pushes for the linked parents.
class StudySessionController extends ChangeNotifier
    with WidgetsBindingObserver {
  StudySessionController({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _pauseDebounce = Duration(seconds: 3);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StudyState _state = StudyState.idle;
  DocumentReference<Map<String, dynamic>>? _doc;
  DateTime? _activeSince;
  Duration _accumulated = Duration.zero;
  Timer? _pauseTimer;
  bool _locked = false;
  String? _syncError;

  StudyState get state => _state;
  bool get isRunning => _state == StudyState.active || _state == StudyState.paused;
  bool get locked => _locked;
  String? get syncError => _syncError;

  Duration get elapsed => _activeSince == null
      ? _accumulated
      : _accumulated + DateTime.now().difference(_activeSince!);

  /// Returns false when nobody is signed in or a session is already running.
  Future<bool> start({required bool locked}) async {
    final user = _auth.currentUser;
    if (user == null || isRunning) return false;
    _locked = locked;
    _doc = _firestore.collection('study_sessions').doc();
    _accumulated = Duration.zero;
    _activeSince = DateTime.now();
    _state = StudyState.active;
    WidgetsBinding.instance.addObserver(this);
    _write({
      'studentUid': user.uid,
      'studentName': user.displayName ?? user.email?.split('@').first ?? '',
      'state': 'started',
      'locked': locked,
      'startedAt': FieldValue.serverTimestamp(),
      'activeSeconds': 0,
    });
    notifyListeners();
    return true;
  }

  Future<void> end() async {
    if (!isRunning) return;
    _pauseTimer?.cancel();
    _state = StudyState.ending;
    _freezeClock();
    WidgetsBinding.instance.removeObserver(this);
    _write({
      'state': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'activeSeconds': _accumulated.inSeconds,
    });
    _doc = null;
    _state = StudyState.idle;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isRunning) return;
    switch (state) {
      case AppLifecycleState.resumed: // onResume
        _pauseTimer?.cancel();
        if (_state == StudyState.paused) {
          _state = StudyState.active;
          _activeSince = DateTime.now();
          _write({'state': 'active'});
          notifyListeners();
        }
      case AppLifecycleState.hidden: // onPause
        // Debounced so that quick overlays (permission dialogs, share sheets)
        // do not spam the parent.
        _pauseTimer ??= Timer(_pauseDebounce, _markPaused);
      case AppLifecycleState.paused: // onStop
        _pauseTimer?.cancel();
        _pauseTimer = null;
        _markPaused();
      case AppLifecycleState.detached:
        unawaited(end());
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _markPaused() {
    _pauseTimer = null;
    if (_state != StudyState.active) return;
    _freezeClock();
    _state = StudyState.paused;
    _write({'state': 'paused', 'activeSeconds': _accumulated.inSeconds});
    notifyListeners();
  }

  void _freezeClock() {
    final since = _activeSince;
    if (since != null) {
      _accumulated += DateTime.now().difference(since);
      _activeSince = null;
    }
  }

  /// Fire-and-forget: Firestore queues writes offline, and awaiting them
  /// would hang the UI until the server acknowledges.
  void _write(Map<String, dynamic> data) {
    final doc = _doc;
    if (doc == null) return;
    doc.set({...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true)).then((_) {
      if (_syncError != null) {
        _syncError = null;
        notifyListeners();
      }
    }).catchError((Object error) {
      debugPrint('Study session sync failed: $error');
      _syncError = error.toString();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
