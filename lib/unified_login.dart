import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'study_lock/push_notification_service.dart';

/// Roles resolved after sign-in.
enum AppRole { admin, student }

String _t(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'Semi-English' => '$en / $mr',
      _ => en,
    };

final _emailPattern = RegExp(r'^[\w.+\-]+@([\w\-]+\.)+[A-Za-z]{2,}$');

/// Returns a normalised +91XXXXXXXXXX number, or null when [input] is not a
/// valid 10-digit Indian mobile number (optionally prefixed by +91 / 91 / 0).
String? normaliseMobile(String input) {
  var digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.startsWith('+91')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('91') && digits.length == 12) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? '+91$digits' : null;
}

/// Firebase Auth + Firestore role lookup.
class AuthService {
  AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// Removes this device's FCM token while the user is still authenticated
  /// (Firestore rules need the auth context), then signs out.
  static Future<void> signOut() async {
    await PushNotificationService.instance.detach();
    await _auth.signOut();
  }

  /// Order of trust: custom claim, then `users/{uid}.role` in Firestore.
  /// A first-time user gets a `student` profile; elevated roles can only be
  /// granted server-side (custom claim or an admin-written document), which
  /// Firestore security rules must enforce.
  static Future<AppRole> resolveRole(
    User user, {
    String? name,
    String? standard,
    String? medium,
    bool isNewUser = false,
  }) async {
    try {
      final claim = await _claimRole(user);
      if (_isStaff(claim)) return AppRole.admin;

      final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      DocumentSnapshot<Map<String, dynamic>>? snapshot;
      try {
        snapshot = await doc.get().timeout(const Duration(seconds: 25));
      } on TimeoutException {
        // Slow network: use whatever Firestore has cached locally.
        try {
          snapshot = await doc
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          snapshot = null;
        }
        if (snapshot == null || !snapshot.exists) {
          // Least privilege: a student session until the network recovers.
          debugPrint('Role lookup timed out; continuing as student.');
          return AppRole.student;
        }
      }
      if (!snapshot.exists) {
        // The write is queued by Firestore and synced when online, so it is
        // not awaited: offline, its future would only finish after the server
        // acknowledges it.
        unawaited(createStudentProfile(user,
            name: name,
            standard: standard == null ? null : int.tryParse(standard),
            medium: medium));
        return AppRole.student;
      }
      return _isStaff(snapshot.data()?['role'])
          ? AppRole.admin
          : AppRole.student;
    } catch (error) {
      // The Auth account already exists. Signing a brand-new user out here
      // would trap them in an "already registered" loop, so let them in as a
      // student; the profile is created on their next sign-in.
      if (isNewUser) {
        debugPrint('Profile creation deferred: $error');
        return AppRole.student;
      }
      rethrow;
    }
  }

  /// Creates the default `users/{uid}` student profile. Never throws: the
  /// profile is re-created on the next sign-in if this fails (the rules only
  /// allow `role == 'student'` on create).
  static Future<void> createStudentProfile(
    User user, {
    String? name,
    int? standard,
    String? medium,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': 'student',
        'name': (name ?? user.displayName ?? '').trim(),
        'email': user.email,
        'phone': user.phoneNumber,
        if (standard != null) 'standard': standard,
        if (medium != null) 'medium': medium,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Profile creation failed: $error');
    }
  }

  static bool _isStaff(Object? role) {
    final value = role is String ? role.trim().toLowerCase() : null;
    return value == 'admin' || value == 'teacher';
  }

  /// Reads the role claim from a fresh token; when offline falls back to the
  /// cached token so a returning user is not locked out.
  static Future<Object?> _claimRole(User user) async {
    try {
      final fresh = await user
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 10));
      return fresh.claims?['role'];
    } catch (_) {
      try {
        final cached = await user.getIdTokenResult(false);
        return cached.claims?['role'];
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);
}

/// Maps any sign-in failure to a localized, user-friendly message.
String describeAuthError(Object error, String medium, {String? context}) {
  String m(String mr, String en) => _t(medium, mr, en);
  if (error is TimeoutException) {
    return m('कनेक्शन संथ आहे. कृपया पुन्हा प्रयत्न करा.',
        'The connection is slow. Please try again.');
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => m('ईमेल किंवा मोबाईल क्रमांक अयोग्य आहे.',
          'Invalid email or mobile number.'),
      'user-not-found' || 'wrong-password' || 'invalid-credential' => switch (
            context) {
          'otp' => m('चुकीचा ओटीपी. कृपया पुन्हा तपासा.',
              'Invalid OTP. Please check and try again.'),
          'password' =>
            m('चुकीचा पासवर्ड किंवा ईमेल.', 'Invalid password or email.'),
          _ => m('चुकीचा पासवर्ड किंवा OTP.', 'Invalid password or OTP.'),
        },
      'invalid-verification-id' => m('ओटीपीची मुदत संपली. नवीन ओटीपी मागवा.',
          'The OTP session expired. Request a new one.'),
      'user-disabled' => m('हे खाते बंद केले आहे. शिक्षकांशी संपर्क साधा.',
          'This account is disabled. Contact your teacher.'),
      'too-many-requests' => m(
          'खूप प्रयत्न झाले. थोड्या वेळाने पुन्हा प्रयत्न करा.',
          'Too many attempts. Please try again later.'),
      'network-request-failed' => m('इंटरनेट उपलब्ध नाही. कनेक्शन तपासा.',
          'No internet. Check your connection.'),
      'invalid-verification-code' =>
        m('ओटीपी चुकीचा आहे.', 'The OTP is incorrect.'),
      'session-expired' || 'code-expired' => m(
          'ओटीपीची मुदत संपली. नवीन ओटीपी मागवा.',
          'The OTP has expired. Request a new one.'),
      'invalid-phone-number' =>
        m('मोबाईल क्रमांक अयोग्य आहे.', 'Invalid mobile number.'),
      'quota-exceeded' => m('आज ओटीपी मर्यादा संपली. ईमेलने प्रवेश करा.',
          'OTP limit reached today. Please use email.'),
      'email-already-in-use' => m(
          'या ईमेलने आधीच नोंदणी झाली आहे. कृपया लॉगिन करा.',
          'This email is already registered. Please log in.'),
      'weak-password' => m('पासवर्ड कमकुवत आहे. किमान ६ अक्षरे वापरा.',
          'The password is too weak. Use at least 6 characters.'),
      'operation-not-allowed' => m('ही प्रवेश पद्धत सुरू केलेली नाही.',
          'This sign-in method is not enabled.'),
      // Authentication is not set up for this Firebase project / app.
      'configuration-not-found' ||
      'invalid-api-key' ||
      'app-not-authorized' ||
      'missing-client-identifier' =>
        m(
            'Firebase Authentication सेट केलेले नाही. Firebase Console मध्ये '
                'Authentication सुरू करून Email/Password आणि Phone प्रदाते चालू करा.',
            'Firebase Authentication is not set up. In the Firebase Console, '
                'enable Authentication with the Email/Password and Phone providers.'),
      'captcha-check-failed' || 'web-context-cancelled' => m(
          'सुरक्षा पडताळणी पूर्ण झाली नाही. पुन्हा प्रयत्न करा.',
          'Security verification was not completed. Please try again.'),
      'internal-error' => m(
          'Firebase मध्ये अंतर्गत त्रुटी आली. पुन्हा प्रयत्न करा; '
              'Android साठी SHA-1/SHA-256 कळा जोडल्या आहेत का ते तपासा.',
          'Internal Firebase error. Try again; for Android also check that the '
              'SHA-1/SHA-256 keys are added.'),
      _ => m('प्रवेश करता आला नाही (${error.code}). पुन्हा प्रयत्न करा.',
          'Sign-in failed (${error.code}). Please try again.'),
    };
  }
  if (error is FirebaseException) {
    return error.code == 'permission-denied'
        ? m('तुमच्या खात्याची भूमिका तपासता आली नाही (परवानगी नाही).',
            'Could not verify your role (permission denied).')
        : m('सर्व्हरशी संपर्क होऊ शकला नाही. पुन्हा प्रयत्न करा.',
            'Could not reach the server. Please try again.');
  }
  return m('काहीतरी चुकले. पुन्हा प्रयत्न करा.',
      'Something went wrong. Please try again.');
}

enum _Step { identifier, password, otp }

/// Single unified login: one field for mobile number or email.
/// Email -> password step. Mobile -> OTP step.
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({
    super.key,
    required this.firebaseReady,
    required this.onRole,
    required this.onLocalDemo,
    this.startupError,
    this.initialMessage,
  });

  final bool firebaseReady;
  final String? startupError;
  final String? initialMessage;
  final void Function(AppRole role) onRole;
  final VoidCallback onLocalDemo;

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _idController = TextEditingController();
  final _secretController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _signUp = false;
  String _standard = '10';
  String _medium = 'Semi-English';
  _Step _step = _Step.identifier;
  bool _busy = false;
  bool _finishing = false;
  bool _hidePassword = true;
  String? _error;
  String? _info;

  String? _email;
  String? _mobile;
  String? _verificationId;
  ConfirmationResult? _webConfirmation;
  int? _resendToken;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _error = widget.initialMessage;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idController.dispose();
    _secretController.dispose();
    _nameController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  void _setMode(bool signUp) {
    if (_busy || signUp == _signUp) return;
    _timer?.cancel();
    setState(() {
      _signUp = signUp;
      _step = _Step.identifier;
      _secretController.clear();
      _confirmController.clear();
      _error = null;
      _info = null;
      _resendSeconds = 0;
    });
  }

  String m(String mr, String en) => _t(_medium, mr, en);

  void _fail(Object error) {
    debugPrint('Login error: $error');
    if (!mounted) return;
    final message = describeAuthError(
      error,
      _medium,
      context: switch (_step) {
        _Step.otp => 'otp',
        _Step.password => 'password',
        _Step.identifier => null,
      },
    );
    setState(() {
      _busy = false;
      _error = message;
    });
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  String? _validateIdentifier(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      return m('मोबाईल क्रमांक किंवा ईमेल टाका.',
          'Enter your mobile number or email.');
    }
    if (v.contains('@')) {
      return _emailPattern.hasMatch(v)
          ? null
          : m('अयोग्य ईमेल.', 'Invalid email address.');
    }
    return normaliseMobile(v) == null
        ? m('१० अंकी वैध मोबाईल क्रमांक टाका.',
            'Enter a valid 10-digit mobile number.')
        : null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    if (!widget.firebaseReady) {
      setState(() =>
          _error = m('Firebase जोडलेले नाही.', 'Firebase is not set up.'));
      return;
    }
    switch (_step) {
      case _Step.identifier:
        if (!_formKey.currentState!.validate()) return;
        await _continueWithIdentifier();
      case _Step.password:
        final password = _secretController.text;
        if (password.isEmpty) {
          _showError(m('पासवर्ड टाका.', 'Enter your password.'));
          return;
        }
        if (_signUp) {
          if (password.length < 6) {
            _showError(m('पासवर्ड किमान ६ अक्षरांचा असावा.',
                'Password must be at least 6 characters.'));
            return;
          }
          if (password != _confirmController.text) {
            _showError(m('दोन्ही पासवर्ड जुळत नाहीत.',
                'The two passwords do not match.'));
            return;
          }
        }
        await _signInWithEmail();
      case _Step.otp:
        if (_secretController.text.trim().length != 6) {
          setState(
              () => _error = m('६ अंकी ओटीपी टाका.', 'Enter the 6-digit OTP.'));
          return;
        }
        await _confirmOtp();
    }
  }

  Future<void> _continueWithIdentifier() async {
    final value = _idController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    if (value.contains('@')) {
      setState(() {
        _email = value.toLowerCase();
        _mobile = null;
        _step = _Step.password;
        _secretController.clear();
        _busy = false;
      });
      return;
    }
    _mobile = normaliseMobile(value);
    _email = null;
    await _sendOtp();
  }

  Future<void> _sendOtp() async {
    final phone = _mobile;
    if (phone == null) {
      _fail(FirebaseAuthException(code: 'invalid-phone-number'));
      return;
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      setState(() {
        _busy = false;
        _error = m('या डिव्हाइसवर ओटीपी लॉगिन उपलब्ध नाही. ईमेल वापरा.',
            'OTP login is not available on this device. Please use email.');
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        _webConfirmation = await auth.signInWithPhoneNumber(phone);
        _onCodeSent();
        return;
      }
      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          // Instant verification / SMS auto-retrieval on Android.
          try {
            final result = await auth.signInWithCredential(credential);
            await _finish(result.user,
                isNewUser: result.additionalUserInfo?.isNewUser ?? false);
          } catch (error) {
            _fail(error);
          }
        },
        verificationFailed: _fail,
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          _onCodeSent();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (error) {
      _fail(error);
    }
    // Watchdog: if Firebase never calls back, never leave the button frozen.
    Future<void>.delayed(const Duration(seconds: 75), () {
      if (mounted && _busy && _step == _Step.identifier && !_finishing) {
        _fail(TimeoutException('otp'));
      }
    });
  }

  void _onCodeSent() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.otp;
      _secretController.clear();
      _info = m('ओटीपी $_mobile वर पाठवला आहे.', 'OTP sent to $_mobile.');
    });
    _startResendTimer();
  }

  Future<void> _confirmOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = _secretController.text.trim();
      final UserCredential result;
      if (kIsWeb) {
        final confirmation = _webConfirmation;
        if (confirmation == null) throw StateError('no confirmation');
        result = await confirmation.confirm(code);
      } else {
        final id = _verificationId;
        if (id == null) throw StateError('no verification id');
        result = await FirebaseAuth.instance.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: id, smsCode: code),
        );
      }
      await _finish(result.user,
          isNewUser: result.additionalUserInfo?.isNewUser ?? false);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final UserCredential result;
      if (_signUp) {
        result = await auth.createUserWithEmailAndPassword(
          email: _email!,
          password: _secretController.text,
        );
        try {
          await result.user?.updateDisplayName(_name);
        } catch (_) {
          // The name is also saved in the Firestore profile.
        }
        final created = result.user;
        if (created != null) {
          await AuthService.createStudentProfile(
            created,
            name: _name,
            standard: int.tryParse(_standard),
            medium: _medium,
          );
        }
      } else {
        result = await auth.signInWithEmailAndPassword(
          email: _email!,
          password: _secretController.text,
        );
      }
      await _finish(result.user,
          isNewUser:
              _signUp || (result.additionalUserInfo?.isNewUser ?? false));
    } on FirebaseAuthException catch (error) {
      if (_signUp && error.code == 'email-already-in-use') {
        _switchToLoginForExistingAccount();
      } else {
        _fail(error);
      }
    } catch (error) {
      _fail(error);
    }
  }

  /// Keeps the typed email and password so the user can log in with one tap.
  void _switchToLoginForExistingAccount() {
    if (!mounted) return;
    final message = m('या ईमेलने आधीच नोंदणी झाली आहे. कृपया लॉगिन करा.',
        'This email is already registered. Please log in.');
    setState(() {
      _busy = false;
      _signUp = false;
      _step = _Step.password;
      _confirmController.clear();
      _error = null;
      _info = message;
    });
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: m('लॉगिन', 'Log in'),
          onPressed: () {
            if (mounted && !_signUp && _step == _Step.password) _submit();
          },
        ),
      ));
  }

  /// Verifies the role; on failure signs out so no half-authenticated state
  /// can reach a protected screen. Guarded so that SMS auto-verification and a
  /// manual OTP entry cannot route twice.
  Future<void> _finish(User? user, {bool isNewUser = false}) async {
    if (_finishing) return;
    _finishing = true;
    try {
      if (user == null) throw StateError('no user');
      final role = await AuthService.resolveRole(
        user,
        name: _signUp ? _name : null,
        standard: _signUp ? _standard : null,
        medium: _signUp ? _medium : null,
        isNewUser: isNewUser || _signUp,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onRole(role);
    } catch (error) {
      try {
        await AuthService.signOut();
      } catch (_) {}
      _fail(error);
    } finally {
      _finishing = false;
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email;
    if (email == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = m(
            '$email नोंदणीकृत असल्यास पासवर्ड रीसेट दुवा पाठवला आहे. '
                'इनबॉक्स व स्पॅम तपासा.',
            'If $email is registered, a reset link was sent. '
                'Check your inbox and spam folder.');
      });
    } catch (error) {
      _fail(error);
    }
  }

  void _backToIdentifier() {
    _timer?.cancel();
    setState(() {
      _step = _Step.identifier;
      _secretController.clear();
      _confirmController.clear();
      _error = null;
      _info = null;
      _resendSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = switch (_step) {
      _Step.identifier =>
        _signUp ? m('नवीन नोंदणी', 'Create account') : m('लॉगिन करा', 'Log in'),
      _Step.password => _signUp
          ? m('पासवर्ड तयार करा', 'Create a password')
          : m('पासवर्ड टाका', 'Enter password'),
      _Step.otp => m('ओटीपी पडताळणी', 'Verify OTP'),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                          visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: 'Marathi', label: Text('मराठी')),
                        ButtonSegment(
                            value: 'Semi-English', label: Text('Semi')),
                        ButtonSegment(value: 'English', label: Text('English')),
                      ],
                      selected: {_medium},
                      onSelectionChanged: (s) =>
                          setState(() => _medium = s.first),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.school_rounded,
                        color: scheme.primary, size: 38),
                  ),
                  const SizedBox(height: 18),
                  const Text('महास्कॉलर एआय',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    m('महाराष्ट्र राज्य मंडळाच्या विद्यार्थी आणि शिक्षकांसाठी एकच व्यासपीठ.',
                        'One platform for Maharashtra State Board students and teachers.'),
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_step == _Step.identifier) ...[
                              SegmentedButton<bool>(
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: false,
                                    icon: const Icon(Icons.login_rounded),
                                    label: Text(m('लॉगिन', 'Log in')),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: const Icon(Icons.person_add_alt_1),
                                    label: Text(m('नवीन नोंदणी', 'Sign Up')),
                                  ),
                                ],
                                selected: {_signUp},
                                onSelectionChanged: (s) => _setMode(s.first),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 14),
                            if (_step == _Step.identifier && _signUp) ...[
                              TextFormField(
                                controller: _nameController,
                                enabled: !_busy,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v ?? '').trim().length < 2
                                    ? m('तुमचे नाव टाका.', 'Enter your name.')
                                    : null,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: m(
                                      'विद्यार्थ्याचे पूर्ण नाव', 'Full name'),
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _standard,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: m('इयत्ता', 'Standard'),
                                  prefixIcon: const Icon(Icons.class_outlined),
                                ),
                                items: [
                                  for (var i = 1; i <= 12; i++)
                                    DropdownMenuItem(
                                      value: '$i',
                                      child:
                                          Text(m('इयत्ता $i', 'Standard $i')),
                                    ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(
                                        () => _standard = v ?? _standard),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_step == _Step.identifier)
                              TextFormField(
                                controller: _idController,
                                enabled: !_busy,
                                autofocus: true,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.go,
                                validator: _validateIdentifier,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: m('मोबाईल क्रमांक / ईमेल',
                                      'Mobile number / Email'),
                                  prefixIcon:
                                      const Icon(Icons.person_outline_rounded),
                                ),
                              )
                            else ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(_step == _Step.otp
                                    ? Icons.phone_android_rounded
                                    : Icons.email_outlined),
                                title: Text(_mobile ?? _email ?? ''),
                                trailing: TextButton(
                                  onPressed: _busy ? null : _backToIdentifier,
                                  child: Text(m('बदला', 'Change')),
                                ),
                              ),
                              TextField(
                                controller: _secretController,
                                enabled: !_busy,
                                autofocus: true,
                                obscureText:
                                    _step == _Step.password && _hidePassword,
                                keyboardType: _step == _Step.otp
                                    ? TextInputType.number
                                    : TextInputType.visiblePassword,
                                inputFormatters: _step == _Step.otp
                                    ? [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6),
                                      ]
                                    : null,
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  labelText: _step == _Step.otp
                                      ? m('६ अंकी ओटीपी', '6-digit OTP')
                                      : m('पासवर्ड', 'Password'),
                                  prefixIcon: Icon(_step == _Step.otp
                                      ? Icons.sms_outlined
                                      : Icons.lock_outline_rounded),
                                  suffixIcon: _step == _Step.password
                                      ? IconButton(
                                          tooltip: _hidePassword
                                              ? m('दाखवा', 'Show')
                                              : m('लपवा', 'Hide'),
                                          icon: Icon(_hidePassword
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded),
                                          onPressed: () => setState(() =>
                                              _hidePassword = !_hidePassword),
                                        )
                                      : null,
                                ),
                              ),
                              if (_step == _Step.password && _signUp) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _confirmController,
                                  enabled: !_busy,
                                  obscureText: _hidePassword,
                                  onSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: m('पासवर्डची पुन्हा खात्री करा',
                                        'Confirm password'),
                                    helperText: m('किमान ६ अक्षरे',
                                        'At least 6 characters'),
                                    prefixIcon:
                                        const Icon(Icons.lock_reset_rounded),
                                  ),
                                ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: _step == _Step.password && _signUp
                                    ? const SizedBox(height: 8)
                                    : _step == _Step.password
                                        ? TextButton(
                                            onPressed:
                                                _busy ? null : _forgotPassword,
                                            child: Text(m('पासवर्ड विसरलात?',
                                                'Forgot password?')),
                                          )
                                        : TextButton(
                                            onPressed:
                                                _busy || _resendSeconds > 0
                                                    ? null
                                                    : _sendOtp,
                                            child: Text(_resendSeconds > 0
                                                ? m('पुन्हा पाठवा ($_resendSeconds से.)',
                                                    'Resend in ${_resendSeconds}s')
                                                : m('ओटीपी पुन्हा पाठवा',
                                                    'Resend OTP')),
                                          ),
                              ),
                            ],
                            if (_error != null)
                              _Message(_error!, isError: true),
                            if (_info != null) _Message(_info!),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50)),
                              child: _busy
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    )
                                  : Text(
                                      _step == _Step.otp
                                          ? (_signUp
                                              ? m('पडताळा आणि नोंदणी करा',
                                                  'Verify & Sign Up')
                                              : m('पडताळा आणि लॉगिन',
                                                  'Verify & Log in'))
                                          : _signUp
                                              ? (_step == _Step.password
                                                  ? m('खाते तयार करा',
                                                      'Create account')
                                                  : m('नोंदणी करा', 'Sign Up'))
                                              : m('लॉगिन', 'Login'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!widget.firebaseReady) ...[
                    Card(
                      color: const Color(0xFFFFF3D9),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.startupError ??
                              'स्थानिक चाचणी: Firebase जोडलेले नाही. Firebase शिवाय वाचन-मात्र वापर उपलब्ध आहे.',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: widget.onLocalDemo,
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('विद्यार्थी प्रवेश'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    m('महाराष्ट्र राज्य मंडळ · इयत्ता १–१०',
                        'Maharashtra State Board · Std 1–10'),
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.isError = false});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: color)),
          ),
        ],
      ),
    );
  }
}
