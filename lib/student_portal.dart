import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _mediums = ['Marathi', 'Semi-English', 'English'];

/// Marathi only, "English / मराठी" (Semi-English) or English only.
String _t(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'English' => en,
      _ => '$en / $mr',
    };

String _num(String medium, int n) {
  if (medium == 'English') return '$n';
  const digits = '०१२३४५६७८९';
  final marathi = '$n'.split('').map((c) => digits[int.parse(c)]).join();
  return medium == 'Marathi' ? marathi : '$n';
}

/// The student's profile from `users/{uid}`.
class StudentProfile {
  const StudentProfile({
    this.name = '',
    this.standard,
    this.medium,
    this.subjects = const [],
    this.fromCache = false,
  });

  factory StudentProfile.fromData(
    Map<String, dynamic>? data, {
    bool fromCache = false,
  }) {
    final std = data?['standard'];
    final medium = data?['medium'];
    final subjects = data?['subjects'];
    return StudentProfile(
      name: (data?['name'] as String?)?.trim() ?? '',
      standard: std is num && std >= 1 && std <= 10 ? std.toInt() : null,
      medium: medium is String && _mediums.contains(medium) ? medium : null,
      subjects: subjects is List
          ? subjects.whereType<String>().map((e) => e.trim()).toList()
          : const [],
      fromCache: fromCache,
    );
  }

  final String name;
  final int? standard; // class assigned by the admin (1-10)
  final String? medium;
  final List<String> subjects;
  final bool fromCache;
}

class StudentProfileService {
  StudentProfileService._();

  static DocumentReference<Map<String, dynamic>>? get _doc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  /// Server first; if the network is slow or down, the offline cache.
  /// Throws only when neither is available.
  static Future<StudentProfile?> load() async {
    final doc = _doc;
    if (doc == null) return null;
    try {
      final snap = await doc.get().timeout(const Duration(seconds: 20));
      return StudentProfile.fromData(
        snap.data(),
        fromCache: snap.metadata.isFromCache,
      );
    } catch (error) {
      debugPrint('Profile fetch failed, trying cache: $error');
      final cached = await doc
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 5));
      if (!cached.exists) rethrow;
      return StudentProfile.fromData(cached.data(), fromCache: true);
    }
  }

  /// Best effort; security rules may forbid it, which is not an error.
  static Future<void> saveMedium(String medium) async {
    try {
      await _doc?.set({'medium': medium}, SetOptions(merge: true)).timeout(
          const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Medium not saved: $error');
    }
  }
}

/// Live Firestore curriculum additions for the selected student standard.
/// The admin dashboard writes matching documents to these three collections.
class LiveCurriculumSection extends StatefulWidget {
  const LiveCurriculumSection({
    super.key,
    required this.standard,
    required this.medium,
  });

  final int standard;
  final String medium;

  @override
  State<LiveCurriculumSection> createState() => _LiveCurriculumSectionState();
}

class _LiveCurriculumSectionState extends State<LiveCurriculumSection> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _subjects;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _chapters;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _questions;

  String m(String mr, String en) => _t(widget.medium, mr, en);

  @override
  void initState() {
    super.initState();
    _setStreams();
  }

  @override
  void didUpdateWidget(covariant LiveCurriculumSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.standard != widget.standard) _setStreams();
  }

  void _setStreams() {
    final firestore = FirebaseFirestore.instance;
    _subjects = firestore
        .collection('subjects')
        .where('standard', isEqualTo: widget.standard)
        .snapshots();
    _chapters = firestore
        .collection('chapters')
        .where('standard', isEqualTo: widget.standard)
        .snapshots();
    _questions = firestore
        .collection('scholarship_questions')
        .where('standard', isEqualTo: widget.standard)
        .snapshots();
  }

  String _localized(
      Map<String, dynamic> data, List<String> keys, String fallback) {
    final localizedKeys = keys
        .where((key) =>
            key.toLowerCase().contains('mr') ||
            key.toLowerCase().contains('marathi'))
        .toList();
    final englishKeys = keys.toSet().difference(localizedKeys.toSet()).toList();
    final orderedKeys = widget.medium == 'Marathi'
        ? [...localizedKeys, ...englishKeys]
        : [...englishKeys, ...localizedKeys];
    for (final key in orderedKeys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  Widget _sectionTitle(
          BuildContext context, String mr, String en, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m(mr, en),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      );

  Widget _streamError(Object error) {
    debugPrint('Live curriculum stream failed: $error');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        m('सामग्री लोड झाली नाही. कनेक्शन किंवा परवानग्या तपासा.',
            'Content could not load. Check connection or Firestore permissions.'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
            context, 'नवीन विषय', 'New subjects', Icons.library_books_outlined),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _subjects,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _streamError(snapshot.error!);
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Text(m('अद्याप नवीन विषय जोडलेले नाहीत.',
                  'No new subjects have been added yet.'));
            }
            return Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final doc in docs)
                  Chip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 18),
                    label: Text(_localized(
                      doc.data(),
                      ['titleEn', 'name', 'titleMr', 'nameMr'],
                      m('विषय', 'Subject'),
                    )),
                  ),
              ],
            );
          },
        ),
        _sectionTitle(
            context, 'नवीन प्रकरणे', 'New chapters', Icons.article_outlined),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _chapters,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _streamError(snapshot.error!);
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Text(m('अद्याप नवीन प्रकरणे जोडलेली नाहीत.',
                  'No new chapters have been added yet.'));
            }
            return Column(
              children: [
                for (final doc in docs)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(_localized(
                        doc.data(),
                        ['titleEn', 'title', 'titleMr', 'titleMarathi'],
                        m('प्रकरण', 'Chapter'),
                      )),
                      subtitle: Text(_localized(
                        doc.data(),
                        ['subjectEn', 'subject', 'subjectMr', 'subjectNameMr'],
                        '',
                      )),
                    ),
                  ),
              ],
            );
          },
        ),
        if (const [4, 5, 7, 8].contains(widget.standard)) ...[
          _sectionTitle(context, 'शिष्यवृत्ती प्रश्न', 'Scholarship questions',
              Icons.workspace_premium_outlined),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _questions,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _streamError(snapshot.error!);
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Text(m('अद्याप प्रश्न जोडलेले नाहीत.',
                    'No scholarship questions have been added yet.'));
              }
              return Column(
                children: [
                  for (final doc in docs)
                    _LiveScholarshipQuestionCard(
                      data: doc.data(),
                      medium: widget.medium,
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _LiveScholarshipQuestionCard extends StatefulWidget {
  const _LiveScholarshipQuestionCard({
    required this.data,
    required this.medium,
  });

  final Map<String, dynamic> data;
  final String medium;

  @override
  State<_LiveScholarshipQuestionCard> createState() =>
      _LiveScholarshipQuestionCardState();
}

class _LiveScholarshipQuestionCardState
    extends State<_LiveScholarshipQuestionCard> {
  int? _selected;
  bool _checked = false;

  String m(String mr, String en) => _t(widget.medium, mr, en);

  String _localized(List<String> keys, String fallback) {
    final localizedKeys = keys
        .where((key) =>
            key.toLowerCase().contains('mr') ||
            key.toLowerCase().contains('marathi'))
        .toList();
    final englishKeys = keys.toSet().difference(localizedKeys.toSet()).toList();
    final orderedKeys = widget.medium == 'Marathi'
        ? [...localizedKeys, ...englishKeys]
        : [...englishKeys, ...localizedKeys];
    for (final key in orderedKeys) {
      final value = widget.data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final optionsKey = widget.medium == 'Marathi' ? 'optionsMr' : 'optionsEn';
    final rawOptions = widget.data[optionsKey] ?? widget.data['optionsEn'];
    final options = rawOptions is List
        ? rawOptions.whereType<String>().toList(growable: false)
        : const <String>[];
    final correct = widget.data['correctIndex'];
    final correctIndex = correct is num ? correct.toInt() : -1;
    final valid = options.length == 4 && correctIndex >= 0 && correctIndex < 4;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _localized(['questionEn', 'questionMr'],
                  m('प्रश्न उपलब्ध नाही', 'Question unavailable')),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (!valid)
              Text(
                m('प्रश्नाचे पर्याय अपूर्ण आहेत.',
                    'This question has incomplete options.'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else ...[
              RadioGroup<int>(
                groupValue: _selected,
                onChanged: _checked
                    ? (_) {}
                    : (value) => setState(() => _selected = value),
                child: Column(
                  children: [
                    for (var index = 0; index < options.length; index++)
                      RadioListTile<int>(
                        value: index,
                        title: Text(options[index]),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: _selected == null || _checked
                    ? null
                    : () => setState(() => _checked = true),
                child: Text(m('उत्तर तपासा', 'Check answer')),
              ),
              if (_checked) ...[
                const SizedBox(height: 8),
                Text(
                  _selected == correctIndex
                      ? m('बरोबर उत्तर!', 'Correct answer!')
                      : m('पुन्हा प्रयत्न करा.', 'Try again next time.'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _selected == correctIndex
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                if (_localized(['explanationEn', 'explanationMr'], '')
                    .isNotEmpty)
                  Text(_localized(['explanationEn', 'explanationMr'], '')),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A note or video shown in the quick-access sheets.
class PortalItem {
  const PortalItem({required this.title, required this.subtitle, this.onOpen});

  final String title;
  final String subtitle;
  final VoidCallback? onOpen;
}

/// Dashboard at the top of the Study tab: profile, class (Std 1-10) and
/// medium selectors, and quick-access cards.
class StudentDashboard extends StatelessWidget {
  const StudentDashboard({
    super.key,
    required this.standard,
    required this.medium,
    required this.profile,
    required this.loading,
    required this.profileError,
    required this.notes,
    required this.videos,
    required this.quizCount,
    required this.onStandardChanged,
    required this.onMediumChanged,
    required this.onRetry,
    required this.onSubjects,
    required this.onQuiz,
  });

  final int standard;
  final String medium;
  final StudentProfile? profile;
  final bool loading;
  final bool profileError;
  final List<PortalItem> notes;
  final List<PortalItem> videos;
  final int quizCount;
  final ValueChanged<int> onStandardChanged;
  final ValueChanged<String> onMediumChanged;
  final VoidCallback onRetry;
  final VoidCallback onSubjects;
  final VoidCallback onQuiz;

  String m(String mr, String en) => _t(medium, mr, en);

  void _openList(BuildContext context, String title, List<PortalItem> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    m('या इयत्तेसाठी अजून काही जोडलेले नाही.',
                        'Nothing has been added for this class yet.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  trailing: item.onOpen == null
                      ? null
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: item.onOpen == null
                      ? null
                      : () {
                          Navigator.pop(sheet);
                          item.onOpen!();
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = profile?.name ?? '';
    final assigned = profile?.standard;
    final subjects = profile?.subjects ?? const <String>[];

    final cards =
        <({IconData icon, String label, String value, VoidCallback tap})>[
      (
        icon: Icons.menu_book_rounded,
        label: m('विषय', 'Subjects'),
        value: m('पाठ्यपुस्तक', 'Textbook'),
        tap: onSubjects,
      ),
      (
        icon: Icons.sticky_note_2_rounded,
        label: m('नोट्स', 'Notes'),
        value: _num(medium, notes.length),
        tap: () =>
            _openList(context, m('नोट्स आणि पीडीएफ', 'Notes & PDFs'), notes),
      ),
      (
        icon: Icons.play_circle_rounded,
        label: m('व्हिडिओ पाठ', 'Video lectures'),
        value: _num(medium, videos.length),
        tap: () =>
            _openList(context, m('व्हिडिओ पाठ', 'Video lectures'), videos),
      ),
      (
        icon: Icons.quiz_rounded,
        label: m('सराव चाचण्या', 'Practice quizzes'),
        value: _num(medium, quizCount),
        tap: onQuiz,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: Text(name.isEmpty ? '🎓' : name.characters.first),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty
                                ? m('नमस्कार, विद्यार्थी!', 'Hello, student!')
                                : m('नमस्कार, $name!', 'Hello, $name!'),
                            style: text.titleMedium
                                ?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                          Text(
                            m('इयत्ता ${_num(medium, standard)}',
                                'Standard $standard'),
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    if (profile?.fromCache ?? false)
                      Tooltip(
                        message: m('ऑफलाइन माहिती', 'Offline data'),
                        child: Icon(Icons.cloud_off_rounded,
                            color: scheme.onPrimaryContainer),
                      ),
                  ],
                ),
                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(m('तुमचे विषय', 'Your assigned subjects'),
                      style: text.labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in subjects)
                        ActionChip(label: Text(s), onPressed: onSubjects),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (profileError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              color: scheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.wifi_off_rounded,
                    color: scheme.onErrorContainer),
                title: Text(
                  m('प्रोफाइल लोड झाली नाही. सामान्य अभ्यासक्रम दाखवला आहे.',
                      'Could not load your profile. Showing the default syllabus.'),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                trailing: TextButton(
                  onPressed: onRetry,
                  child: Text(m('पुन्हा', 'Retry')),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(m('इयत्ता निवडा (१–१०)', 'Choose class (Std 1–10)'),
            style: text.titleSmall),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final n = i + 1;
              return ChoiceChip(
                avatar: assigned == n
                    ? const Icon(Icons.star_rounded, size: 16)
                    : null,
                label: Text(m('इ. ${_num('Marathi', n)}', 'Std $n')),
                selected: standard == n,
                onSelected: (_) => onStandardChanged(n),
              );
            },
          ),
        ),
        if (assigned != null && assigned != standard)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              onPressed: () => onStandardChanged(assigned),
              icon: const Icon(Icons.star_rounded, size: 16),
              label: Text(m('माझी इयत्ता: ${_num('Marathi', assigned)}',
                  'My class: Std $assigned')),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in _mediums)
              ChoiceChip(
                label: Text(switch (option) {
                  'Marathi' => m('मराठी', 'Marathi'),
                  'English' => m('इंग्रजी', 'English'),
                  _ => m('सेमी-इंग्रजी', 'Semi-English'),
                }),
                selected: medium == option,
                onSelected: (_) => onMediumChanged(option),
              ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 640 ? 4 : 2;
          final width = (box.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in cards)
                SizedBox(
                  width: width,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: c.tap,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(c.icon, color: scheme.primary, size: 28),
                            const SizedBox(height: 10),
                            Text(c.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text(c.value,
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}
