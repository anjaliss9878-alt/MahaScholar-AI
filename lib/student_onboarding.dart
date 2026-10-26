import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _onboardingMediums = ['Marathi', 'Semi-English', 'English'];

/// True when the signed-in student has no usable `users/{uid}` profile yet.
/// Network or permission problems return false so they never block the app.
Future<bool> studentNeedsOnboarding() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 15));
    final name = (snap.data()?['name'] as String?)?.trim() ?? '';
    return !snap.exists || name.isEmpty;
  } catch (error) {
    debugPrint('Onboarding check skipped: $error');
    return false;
  }
}

/// Lets a student create or complete their `users/{uid}` profile.
/// Calls [onDone] after saving (or skipping) so the caller can continue to
/// the student dashboard.
class StudentOnboardingScreen extends StatefulWidget {
  const StudentOnboardingScreen({
    super.key,
    required this.onDone,
    required this.onSignOut,
  });

  final VoidCallback onDone;
  final VoidCallback onSignOut;

  @override
  State<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends State<StudentOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _standard = 5;
  String _medium = 'Semi-English';
  bool _exists = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(_user!.uid);

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    _nameController.text = _user?.displayName ?? '';
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 15));
      final data = snap.data();
      _exists = snap.exists;
      final name = (data?['name'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) _nameController.text = name;
      final std = data?['standard'];
      if (std is num && std >= 1 && std <= 10) _standard = std.toInt();
      final medium = data?['medium'];
      if (medium is String && _onboardingMediums.contains(medium)) {
        _medium = medium;
      }
    } catch (error) {
      debugPrint('Profile prefill failed: $error');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _nameController.text.trim();
    try {
      if (_exists) {
        // Rules forbid students from changing role/standard on an existing
        // profile, so only the editable fields are updated.
        await _doc.update({'name': name, 'medium': _medium}).timeout(
            const Duration(seconds: 15));
      } else {
        await _doc.set({
          'role': 'student',
          'name': name,
          'email': _user?.email,
          'phone': _user?.phoneNumber,
          'standard': _standard,
          'medium': _medium,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
      }
      try {
        await _user?.updateDisplayName(name);
      } catch (_) {}
      if (mounted) widget.onDone();
    } on FirebaseException catch (error) {
      _fail(error.code == 'permission-denied'
          ? 'You do not have permission to save this profile.'
          : 'Could not save your details. Please try again.');
    } catch (_) {
      _fail('Could not save your details. Check your connection.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile / तुमची माहिती'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: widget.onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _exists
                              ? 'Update your details'
                              : 'Complete your profile',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name / पूर्ण नाव',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v ?? '').trim().length < 2
                              ? 'Enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: _standard,
                          decoration: InputDecoration(
                            labelText: 'Class / इयत्ता',
                            border: const OutlineInputBorder(),
                            helperText: _exists
                                ? 'Your teacher assigns your class.'
                                : null,
                          ),
                          items: [
                            for (var i = 1; i <= 10; i++)
                              DropdownMenuItem(value: i, child: Text('$i')),
                          ],
                          onChanged: _exists
                              ? null
                              : (v) => setState(() => _standard = v ?? 5),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _medium,
                          decoration: const InputDecoration(
                            labelText: 'Medium / माध्यम',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final m in _onboardingMediums)
                              DropdownMenuItem(value: m, child: Text(m)),
                          ],
                          onChanged: (v) =>
                              setState(() => _medium = v ?? _medium),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save & continue'),
                        ),
                        TextButton(
                          onPressed: _saving ? null : widget.onDone,
                          child: const Text('Skip for now'),
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
