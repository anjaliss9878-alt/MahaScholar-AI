import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_pin_service.dart';

/// Full-screen PIN entry. Pops `true` once the PIN is verified.
class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key, required this.pinService});

  final LockPinService pinService;

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final _controller = TextEditingController();
  Timer? _countdown;
  Duration? _lockedFor;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _countdown?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text;
    if (_busy || _lockedFor != null || !LockPinService.isValidFormat(pin)) {
      return;
    }
    setState(() => _busy = true);
    final result = await widget.pinService.verify(pin);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    _controller.clear();
    setState(() {
      _busy = false;
      if (result.lockedFor != null) {
        _startCountdown(result.lockedFor!);
        _error = null;
      } else {
        _error = 'चुकीचा PIN. उरलेले प्रयत्न: ${result.attemptsLeft}\n'
            'Wrong PIN. Attempts left: ${result.attemptsLeft}';
      }
    });
  }

  void _startCountdown(Duration duration) {
    _countdown?.cancel();
    _lockedFor = duration;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = (_lockedFor ?? Duration.zero) - const Duration(seconds: 1);
      if (!mounted) return;
      setState(() => _lockedFor = left > Duration.zero ? left : null);
      if (_lockedFor == null) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = _lockedFor != null;
    return Scaffold(
      appBar: AppBar(title: const Text('पालक PIN / Parent PIN')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(Icons.lock_person_rounded, size: 56, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'लॉक काढण्यासाठी पालकांचा PIN टाका\n'
                  'Enter the parent PIN to unlock',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  enabled: !locked && !_busy,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: LockPinService.maxLength,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'PIN',
                    errorText: _error,
                    errorMaxLines: 2,
                  ),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'खूप चुकीचे प्रयत्न. ${_lockedFor!.inSeconds} सेकंदांनी पुन्हा प्रयत्न करा.\n'
                      'Too many attempts. Try again in ${_lockedFor!.inSeconds}s.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: (locked || _busy) ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_rounded),
                  label: const Text('अनलॉक करा / Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog to create or change the PIN. Returns true when a PIN was saved.
Future<bool> showSetPinDialog(
  BuildContext context,
  LockPinService service,
) async {
  final hasPin = await service.hasPin();
  if (!context.mounted) return false;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SetPinDialog(service: service, requireCurrent: hasPin),
  );
  return saved ?? false;
}

class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog({required this.service, required this.requireCurrent});

  final LockPinService service;
  final bool requireCurrent;

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pin.text != _confirm.text) {
      setState(() => _error = 'PIN जुळत नाहीत / PINs do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.setPin(
        _pin.text,
        currentPin: widget.requireCurrent ? _current.text : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on PinException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          obscureText: true,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          maxLength: LockPinService.maxLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.password_rounded),
      title: Text(widget.requireCurrent
          ? 'PIN बदला / Change PIN'
          : 'पालक PIN सेट करा / Set parent PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('पालकांनी हा PIN ठरवावा. विद्यार्थ्याला सांगू नका.\n'
                'A parent should choose this PIN. Do not share it.'),
            if (widget.requireCurrent)
              _field(_current, 'सध्याचा PIN / Current PIN'),
            _field(_pin, 'नवीन PIN (४–६ अंक) / New PIN'),
            _field(_confirm, 'PIN पुन्हा / Confirm PIN'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('रद्द करा / Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('जतन करा / Save'),
        ),
      ],
    );
  }
}
