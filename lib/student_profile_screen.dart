import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'unified_login.dart' show normaliseMobile;

const _profileMediums = ['Marathi', 'Semi-English', 'English'];

/// View and edit the signed-in student's `users/{uid}` document.
/// Role and class are protected by Firestore rules, so they are read-only.
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({
    super.key,
    required this.onSignOut,
    this.onSaved,
  });

  /// Signs out and returns to the login screen (see `_RoleGate._signOut`).
  final VoidCallback onSignOut;

  /// Called with the saved medium so the caller can refresh its state.
  final ValueChanged<String>? onSaved;

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _medium = 'Semi-English';
  int? _standard;
  String _email = '';
  bool _exists = false;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(_user!.uid);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) {
      setState(() {
        _loading = false;
        _loadError = 'You are signed out.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 20));
      final data = snap.data();
      _exists = snap.exists;
      _nameController.text =
          ((data?['name'] as String?) ?? user.displayName ?? '').trim();
      _phoneController.text =
          ((data?['phone'] as String?) ?? user.phoneNumber ?? '').trim();
      _email = ((data?['email'] as String?) ?? user.email ?? '').trim();
      final std = data?['standard'];
      _standard = std is num ? std.toInt() : null;
      final medium = data?['medium'];
      if (medium is String && _profileMediums.contains(medium)) {
        _medium = medium;
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      debugPrint('Profile load failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load your profile. Check your connection.';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phone = rawPhone.isEmpty ? null : normaliseMobile(rawPhone);
    try {
      final data = <String, Object?>{
        'name': name,
        'phone': phone,
        'medium': _medium,
      };
      if (_exists) {
        await _doc.update(data).timeout(const Duration(seconds: 15));
      } else {
        // Missing profile: create a plain student document (rules require it).
        await _doc.set({
          ...data,
          'role': 'student',
          'email': _user?.email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
        _exists = true;
      }
      try {
        await _user?.updateDisplayName(name);
      } catch (_) {}
      widget.onSaved?.call(_medium);
      if (!mounted) return;
      if (phone != null) _phoneController.text = phone;
      setState(() => _saving = false);
      _snack('Profile updated.');
    } on FirebaseException catch (error) {
      _fail(error.code == 'permission-denied'
          ? 'You do not have permission to change this.'
          : 'Could not save. Please try again.');
    } on TimeoutException {
      _fail('The connection is slow. Please try again.');
    } catch (_) {
      _fail('Could not save. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(message);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will return to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile / माझी माहिती')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _form(),
    );
  }

  Widget _form() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name / पूर्ण नाव',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _email.isEmpty ? '—' : _email,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email / ईमेल',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile / मोबाईल',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    return normaliseMobile(value) == null
                        ? 'Enter a valid 10-digit mobile number'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue:
                      _standard == null ? 'Not assigned yet' : '$_standard',
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Class / इयत्ता',
                    helperText: 'Assigned by your teacher',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _medium,
                  decoration: const InputDecoration(
                    labelText: 'Medium / माध्यम',
                    prefixIcon: Icon(Icons.translate),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in _profileMediums)
                      DropdownMenuItem(value: m, child: Text(m)),
                  ],
                  onChanged: (v) => setState(() => _medium = v ?? _medium),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
