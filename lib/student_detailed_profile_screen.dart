import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'student_profile_screen.dart';

/// Complete student information in two tabs: personal details and academic
/// progress. Students see their own record; teachers/admins pass [studentUid]
/// (Firestore rules allow staff to read any `users/{uid}`, its `quiz_scores`
/// and `study_sessions`).
class StudentDetailedProfileScreen extends StatefulWidget {
  const StudentDetailedProfileScreen({
    super.key,
    this.studentUid,
    this.onSignOut,
    this.onProfileChanged,
  });

  /// Defaults to the signed-in user.
  final String? studentUid;

  /// Needed for the "Edit profile" button, which also hosts log out.
  final VoidCallback? onSignOut;
  final ValueChanged<String>? onProfileChanged;

  @override
  State<StudentDetailedProfileScreen> createState() =>
      _StudentDetailedProfileScreenState();
}

class _ScoreEntry {
  _ScoreEntry(Map<String, dynamic> data)
      : score = data['score'] is num ? (data['score'] as num).toInt() : 0,
        outOf = data['outOf'] is num && (data['outOf'] as num) > 0
            ? (data['outOf'] as num).toInt()
            : 10,
        activity = (data['activity'] as String?)?.trim() ?? '',
        date = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null;

  final int score;
  final int outOf;
  final String activity;
  final DateTime? date;

  double get percent => score / outOf;
}

class _Progress {
  const _Progress({
    required this.scores,
    required this.studyDays,
    required this.studyMinutes,
  });

  final List<_ScoreEntry> scores;
  final int studyDays; // distinct days with a study session, last 30 days
  final int studyMinutes;

  double? get averagePercent => scores.isEmpty
      ? null
      : scores.map((s) => s.percent).reduce((a, b) => a + b) / scores.length;
}

class _StudentDetailedProfileScreenState
    extends State<StudentDetailedProfileScreen> {
  static const _windowDays = 30;

  late final String? _uid =
      widget.studentUid ?? FirebaseAuth.instance.currentUser?.uid;
  late final bool _isSelf = _uid != null &&
      _uid == FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic>? _data;
  _Progress? _progress;
  bool _loading = true;
  bool _progressFailed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'You are signed out.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _progressFailed = false;
    });
    final db = FirebaseFirestore.instance;
    try {
      final snap = await db
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 20));
      _data = snap.data() ?? <String, dynamic>{};
      if (!snap.exists && !_isSelf) _error = 'Student not found.';
    } on FirebaseException catch (e) {
      _error = e.code == 'permission-denied'
          ? 'You do not have permission to view this profile.'
          : 'Could not load the profile. Check your connection.';
    } catch (_) {
      _error = 'Could not load the profile. Check your connection.';
    }
    if (_error == null) {
      // Progress is secondary: a failure here must not hide personal info.
      try {
        _progress = await _loadProgress(db, uid);
      } catch (error) {
        debugPrint('Progress unavailable: $error');
        _progressFailed = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<_Progress> _loadProgress(FirebaseFirestore db, String uid) async {
    final since = DateTime.now().subtract(const Duration(days: _windowDays));
    final results = await Future.wait([
      db
          .collection('users')
          .doc(uid)
          .collection('quiz_scores')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get(),
      db
          .collection('study_sessions')
          .where('studentUid', isEqualTo: uid)
          .limit(200)
          .get(),
    ]).timeout(const Duration(seconds: 20));

    final scores =
        results[0].docs.map((d) => _ScoreEntry(d.data())).toList();

    final days = <String>{};
    var seconds = 0;
    for (final doc in results[1].docs) {
      final data = doc.data();
      final started = data['startedAt'];
      if (started is! Timestamp) continue;
      final date = started.toDate();
      if (date.isBefore(since)) continue;
      days.add('${date.year}-${date.month}-${date.day}');
      final active = data['activeSeconds'];
      if (active is num) seconds += active.toInt();
    }
    return _Progress(
      scores: scores,
      studyDays: days.length,
      studyMinutes: seconds ~/ 60,
    );
  }

  /// Uses the AI summary when a teacher/Cloud Function has written one;
  /// otherwise derives weak activities from recent quiz scores.
  List<String> _weakAreas() {
    final listed = _data?['weakTopics'];
    if (listed is List && listed.isNotEmpty) {
      return listed.whereType<String>().toList();
    }
    final byActivity = <String, List<double>>{};
    for (final s in _progress?.scores ?? const <_ScoreEntry>[]) {
      if (s.activity.isEmpty) continue;
      byActivity.putIfAbsent(s.activity, () => []).add(s.percent);
    }
    return [
      for (final e in byActivity.entries)
        if (e.value.reduce((a, b) => a + b) / e.value.length < 0.6) e.key,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isSelf
              ? 'My profile / माझी माहिती'
              : 'Student details / विद्यार्थी माहिती'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.person_outline), text: 'Personal'),
            Tab(icon: Icon(Icons.insights_rounded), text: 'Progress'),
          ]),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : TabBarView(children: [_personalTab(), _progressTab()]),
      ),
    );
  }

  Widget _page(List<Widget> children) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      );

  Widget _personalTab() {
    final data = _data ?? const <String, dynamic>{};
    final user = FirebaseAuth.instance.currentUser;
    String text(String key, [String? fallback]) {
      final v = (data[key] as String?)?.trim() ?? '';
      return v.isNotEmpty ? v : (fallback ?? '');
    }

    final name = text('name', _isSelf ? user?.displayName : null);
    final std = data['standard'];
    final joined = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;
    final premium = data['isPremium'] == true;
    final scheme = Theme.of(context).colorScheme;

    return _page([
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Name not set' : name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(text('role', 'student')),
                        ),
                        if (premium)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: scheme.primaryContainer,
                            label: const Text('Premium'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            _infoTile(Icons.email_outlined, 'Email',
                text('email', _isSelf ? user?.email : null)),
            _infoTile(Icons.phone_outlined, 'Mobile',
                text('phone', _isSelf ? user?.phoneNumber : null)),
            _infoTile(Icons.school_outlined, 'Class',
                std is num ? 'Std ${std.toInt()}' : ''),
            _infoTile(Icons.translate, 'Medium', text('medium')),
            _infoTile(Icons.event_outlined, 'Joined', _date(joined)),
          ],
        ),
      ),
      if (_isSelf && widget.onSignOut != null) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _openEditor,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile / log out'),
        ),
      ],
    ]);
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudentProfileScreen(
        onSignOut: widget.onSignOut!,
        onSaved: widget.onProfileChanged,
      ),
    ));
    if (mounted) _load();
  }

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontSize: 12)),
        subtitle: Text(
          value.isEmpty ? 'Not provided' : value,
          style: const TextStyle(fontSize: 15),
        ),
      );

  Widget _progressTab() {
    if (_progressFailed || _progress == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Progress is unavailable right now.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final progress = _progress!;
    final avg = progress.averagePercent;
    final attendance = progress.studyDays / _windowDays;
    final weak = _weakAreas();
    final aiSummary = ((_data?['aiWeaknessSummary'] as String?) ?? '').trim();

    return _page([
      Row(
        children: [
          Expanded(
            child: _statCard(
              'Attendance',
              '${(attendance * 100).round()}%',
              '${progress.studyDays} study days in $_windowDays days',
              attendance,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              'Avg. quiz score',
              avg == null ? '—' : '${(avg * 100).round()}%',
              '${progress.scores.length} recent quizzes',
              avg,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Attendance counts days with a study session. '
          'Study time: ${progress.studyMinutes} min.',
          style: const TextStyle(fontSize: 12),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, size: 20),
                const SizedBox(width: 8),
                Text('AI weakness summary',
                    style: Theme.of(context).textTheme.titleSmall),
              ]),
              const SizedBox(height: 8),
              if (aiSummary.isNotEmpty) Text(aiSummary),
              if (weak.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: [for (final w in weak) Chip(label: Text(w))],
                ),
              if (aiSummary.isEmpty && weak.isEmpty)
                Text(progress.scores.isEmpty
                    ? 'No quiz data yet.'
                    : 'No weak areas found. Keep it up!'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent quiz scores',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (progress.scores.isEmpty) const Text('No quizzes taken yet.'),
              for (final s in progress.scores.take(8))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.activity.isEmpty ? 'Quiz' : s.activity),
                  subtitle: Text(_date(s.date)),
                  trailing: Text(
                    '${s.score}/${s.outOf}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _statCard(String title, String value, String caption, double? ratio) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: ratio?.clamp(0.0, 1.0)),
              const SizedBox(height: 6),
              Text(caption, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );

  String _date(DateTime? d) {
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
