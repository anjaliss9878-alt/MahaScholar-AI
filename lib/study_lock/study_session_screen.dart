import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_pin_service.dart';
import 'lock_task_service.dart';
import 'pin_screens.dart';
import 'push_notification_service.dart';
import 'study_session_controller.dart';

/// Card to drop into the student dashboard.
class StudySessionEntryCard extends StatelessWidget {
  const StudySessionEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.secondaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: Icon(Icons.timer_rounded, color: scheme.onSecondaryContainer),
        title: const Text('अभ्यास सत्र / Study session'),
        subtitle: const Text('फोन लॉक करा आणि पालकांना कळवा\n'
            'Lock the phone and notify parents'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StudySessionScreen()),
        ),
      ),
    );
  }
}

class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen({super.key});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  final _session = StudySessionController();
  final _pinService = LockPinService();
  final _lockTask = const LockTaskService();

  Timer? _ticker;
  StreamSubscription<dynamic>? _pushSub;
  bool _lockWanted = true;
  bool _hasPin = false;
  bool _staleLock = false; // locked by a previous run, no session in memory
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _session.isRunning) setState(() {});
    });
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final hasPin = await _pinService.hasPin();
    final locked = await _lockTask.isLocked();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _staleLock = locked && !_session.isRunning;
    });
    // Needed so the parent device (and this one) can receive pushes.
    await PushNotificationService.instance.initialize();
    if (!mounted) return;
    _pushSub = PushNotificationService.instance.foregroundMessages.listen((m) {
      final body = m.notification?.body;
      if (body != null && mounted) _snack(body);
    });
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pushSub?.cancel();
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() async {
    if (_busy) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _snack('आधी लॉगिन करा / Please sign in first');
      return;
    }
    setState(() => _busy = true);
    try {
      var locked = false;
      if (_lockWanted) {
        if (!_lockTask.isSupported) {
          _snack('हे फोन लॉक फक्त Android वर चालते / Lock works on Android only');
        } else {
          if (!_hasPin) {
            final saved = await showSetPinDialog(context, _pinService);
            if (!mounted) return;
            if (!saved) return;
            _hasPin = true;
          }
          locked = await _lockTask.start();
          if (!mounted) return;
          if (!locked) {
            _snack('लॉक सुरू होऊ शकले नाही; सत्र लॉकशिवाय सुरू होईल\n'
                'Could not lock the device; starting without lock');
          }
        }
      }
      await _session.start(locked: locked);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Verifies the PIN (when locked) and only then releases lock-task mode.
  Future<bool> _authorizeUnlock() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PinVerifyScreen(pinService: _pinService),
      ),
    );
    if (ok != true || !mounted) return false;
    final stopped = await _lockTask.stop();
    if (!mounted) return false;
    if (!stopped) _snack('लॉक काढता आले नाही / Could not release the lock');
    return stopped;
  }

  Future<void> _end() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_session.locked && !await _authorizeUnlock()) return;
      await _session.end();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _releaseStaleLock() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await _authorizeUnlock() && mounted) {
        setState(() => _staleLock = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _managePin() async {
    final saved = await showSetPinDialog(context, _pinService);
    if (!mounted || !saved) return;
    setState(() => _hasPin = true);
    _snack('PIN जतन केला / PIN saved');
  }

  Future<void> _onBlockedPop() async {
    if (_session.locked) {
      _snack('बाहेर पडण्यासाठी पालकांचा PIN आवश्यक आहे\n'
          'A parent PIN is required to leave');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('सत्र संपवायचे? / End session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('नाही / No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('हो / Yes'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _end();
    if (mounted) Navigator.of(context).pop();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final running = _session.isRunning;
    return PopScope(
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBlockedPop());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('अभ्यास सत्र / Study session'),
          automaticallyImplyLeading: !(running && _session.locked),
          actions: [
            if (!running)
              IconButton(
                tooltip: 'पालक PIN / Parent PIN',
                icon: const Icon(Icons.password_rounded),
                onPressed: _managePin,
              ),
            if (!running)
              IconButton(
                tooltip: 'पालक जोडा / Link parent',
                icon: const Icon(Icons.family_restroom_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ParentLinkScreen(),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_staleLock) _staleLockCard(context),
              if (running) _runningCard(context) else _setupCard(context),
              if (_session.syncError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'पालकांना सूचना पाठवता आली नाही (ऑफलाइन?) / Parent update pending (offline?)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staleLockCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'फोन अजून लॉक आहे / Device is still locked',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _releaseStaleLock,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('PIN ने अनलॉक करा / Unlock with PIN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setupCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.lock_rounded),
              title: const Text('फोन लॉक करा / Lock device'),
              subtitle: Text(_hasPin
                  ? 'Home, Recent आणि Back बंद; सुटण्यासाठी पालक PIN'
                  : 'पहिल्यांदा पालक PIN सेट करावा लागेल / Parent PIN needed first'),
              value: _lockWanted,
              onChanged:
                  _busy ? null : (v) => setState(() => _lockWanted = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('सत्र सुरू करा / Start session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runningCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paused = _session.state == StudyState.paused;
    return Card.filled(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              _session.locked ? Icons.lock_rounded : Icons.menu_book_rounded,
              size: 40,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              _format(_session.elapsed),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(height: 4),
            Text(paused ? 'थांबले / Paused' : 'अभ्यास सुरू / Studying'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _end,
              icon: Icon(_session.locked
                  ? Icons.lock_open_rounded
                  : Icons.stop_rounded),
              label: Text(_session.locked
                  ? 'PIN टाकून संपवा / End with PIN'
                  : 'सत्र संपवा / End session'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Student shows a code; the parent (on their own device/account) enters it.
class ParentLinkScreen extends StatefulWidget {
  const ParentLinkScreen({super.key});

  @override
  State<ParentLinkScreen> createState() => _ParentLinkScreenState();
}

class _ParentLinkScreenState extends State<ParentLinkScreen> {
  final _service = ParentLinkService();
  final _codeField = TextEditingController();
  String? _code;
  bool _busy = false;

  @override
  void dispose() {
    _codeField.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on ParentLinkException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('पालक जोडा / Link parent')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('१. विद्यार्थी / Student',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('कोड तयार करा आणि पालकांना द्या (१० मिनिटे वैध).\n'
                        'Create a code and give it to your parent (valid 10 min).'),
                    const SizedBox(height: 12),
                    if (_code != null)
                      Center(
                        child: SelectableText(
                          _code!,
                          style: theme.textTheme.displaySmall?.copyWith(
                            letterSpacing: 6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final code = await _service.createCode();
                                if (mounted) setState(() => _code = code);
                              }, 'कोड तयार झाला / Code created'),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('कोड तयार करा / Create code'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('२. पालक / Parent',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('पालकांच्या फोनवर लॉगिन करून कोड टाका.\n'
                        'Sign in on the parent phone and enter the code.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeField,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'कोड / Code',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await _service.redeemCode(_codeField.text);
                                // The parent device must hold an FCM token.
                                await PushNotificationService.instance
                                    .initialize();
                                if (mounted) _codeField.clear();
                              }, 'पालक जोडले गेले / Parent linked'),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('जोडा / Link'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
