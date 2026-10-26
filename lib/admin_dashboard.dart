import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'student_detailed_profile_screen.dart';

/// Marathi only, "English / मराठी" (Semi-English) or English only.
String _t(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'English' => en,
      _ => '$en / $mr',
    };

const _pageSize = 40;

class _Student {
  _Student(this.id, Map<String, dynamic> data)
      : name = (data['name'] as String?)?.trim() ?? '',
        email = (data['email'] as String?) ?? '',
        phone = (data['phone'] as String?) ?? '',
        standard = data['standard'] is num
            ? (data['standard'] as num).toInt().clamp(1, 10)
            : null,
        createdAt = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null;

  final String id;
  final String name;
  final String email;
  final String phone;
  final int? standard;
  final DateTime? createdAt;

  String get title => name.isNotEmpty
      ? name
      : (email.isNotEmpty ? email : (phone.isNotEmpty ? phone : id));
}

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

enum _Access { checking, granted, denied, error }

/// Admin dashboard: students, class (Std 1-10) management and recent activity.
/// The role is re-verified from Firestore (`users/{uid}.role == "admin"`);
/// anyone else is sent back with an access-denied message.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, this.medium = 'Semi-English'});

  final String medium;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late String _medium = widget.medium;
  _Access _access = _Access.checking;
  int _tab = 0;

  String m(String mr, String en) => _t(_medium, mr, en);

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() => _access = _Access.checking);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _deny();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 25));
      final role = snap.data()?['role'];
      final isAdmin = role is String && role.trim().toLowerCase() == 'admin';
      if (!mounted) return;
      if (isAdmin) {
        setState(() => _access = _Access.granted);
      } else {
        _deny();
      }
    } catch (error) {
      debugPrint('Admin check failed: $error');
      if (mounted) setState(() => _access = _Access.error);
    }
  }

  void _deny() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final text = m('प्रवेश नाकारला: तुम्ही प्रशासक नाही.',
        'Access denied: you are not an admin.');
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
    } else {
      setState(() => _access = _Access.denied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_access) {
      case _Access.checking:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Access.denied:
      case _Access.error:
        final denied = _access == _Access.denied;
        return Scaffold(
          appBar: AppBar(title: Text(m('प्रशासक फलक', 'Admin Dashboard'))),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(denied ? Icons.lock_outline : Icons.cloud_off_rounded,
                      size: 56, color: scheme.error),
                  const SizedBox(height: 14),
                  Text(
                    denied
                        ? m('प्रवेश नाकारला', 'Access denied')
                        : m('तपासणी करता आली नाही', 'Could not verify access'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    denied
                        ? m('हे पान फक्त प्रशासकांसाठी आहे.',
                            'This page is for admins only.')
                        : m('इंटरनेट तपासा आणि पुन्हा प्रयत्न करा.',
                            'Check your connection and try again.'),
                    textAlign: TextAlign.center,
                  ),
                  if (!denied) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _verify,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(m('पुन्हा प्रयत्न करा', 'Retry')),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      case _Access.granted:
        break;
    }

    final tabs = <Widget>[
      _StudentsTab(medium: _medium),
      _ClassesTab(medium: _medium),
      _ActivityTab(medium: _medium),
      _LearningContentTab(medium: _medium),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(m('प्रशासक फलक', 'Admin Dashboard')),
        actions: [
          PopupMenuButton<String>(
            tooltip: m('भाषा', 'Language'),
            icon: const Icon(Icons.translate_rounded),
            initialValue: _medium,
            onSelected: (v) => setState(() => _medium = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Marathi', child: Text('मराठी')),
              PopupMenuItem(
                  value: 'Semi-English', child: Text('English / मराठी')),
              PopupMenuItem(value: 'English', child: Text('English')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: m('विद्यार्थी', 'Students'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.class_outlined),
            selectedIcon: const Icon(Icons.class_rounded),
            label: m('वर्ग', 'Classes'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: m('हालचाली', 'Activity'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.library_add_outlined),
            selectedIcon: const Icon(Icons.library_add_rounded),
            label: m('अभ्यासक्रम', 'Curriculum'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Students

enum _LearningEntryType { subject, chapter, scholarshipQuestion }

class _LearningContentTab extends StatefulWidget {
  const _LearningContentTab({required this.medium});

  final String medium;

  @override
  State<_LearningContentTab> createState() => _LearningContentTabState();
}

class _LearningContentTabState extends State<_LearningContentTab> {
  final _formKey = GlobalKey<FormState>();
  final _subjectEnglish = TextEditingController();
  final _subjectMarathi = TextEditingController();
  final _chapterEnglish = TextEditingController();
  final _chapterMarathi = TextEditingController();
  final _questionEnglish = TextEditingController();
  final _questionMarathi = TextEditingController();
  final _explanationEnglish = TextEditingController();
  final _explanationMarathi = TextEditingController();
  final _optionsEnglish = List.generate(4, (_) => TextEditingController());
  final _optionsMarathi = List.generate(4, (_) => TextEditingController());

  _LearningEntryType _type = _LearningEntryType.subject;
  int _standard = 4;
  int _correctIndex = 0;
  bool _saving = false;

  bool get _isQuestion => _type == _LearningEntryType.scholarshipQuestion;

  String m(String mr, String en) => _t(widget.medium, mr, en);

  @override
  void dispose() {
    _subjectEnglish.dispose();
    _subjectMarathi.dispose();
    _chapterEnglish.dispose();
    _chapterMarathi.dispose();
    _questionEnglish.dispose();
    _questionMarathi.dispose();
    _explanationEnglish.dispose();
    _explanationMarathi.dispose();
    for (final controller in [..._optionsEnglish, ..._optionsMarathi]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? m('हे क्षेत्र आवश्यक आहे.', 'This field is required.')
      : null;

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final collection = switch (_type) {
        _LearningEntryType.subject => 'subjects',
        _LearningEntryType.chapter => 'chapters',
        _LearningEntryType.scholarshipQuestion => 'scholarship_questions',
      };
      final document = FirebaseFirestore.instance.collection(collection).doc();
      final data = <String, dynamic>{
        'standard': _standard,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      switch (_type) {
        case _LearningEntryType.subject:
          data.addAll({
            'titleEn': _subjectEnglish.text.trim(),
            'titleMr': _subjectMarathi.text.trim(),
            'name': _subjectEnglish.text.trim(),
            'nameMr': _subjectMarathi.text.trim(),
          });
        case _LearningEntryType.chapter:
          data.addAll({
            'subjectEn': _subjectEnglish.text.trim(),
            'subjectMr': _subjectMarathi.text.trim(),
            'subject': _subjectEnglish.text.trim(),
            'subjectNameMr': _subjectMarathi.text.trim(),
            'titleEn': _chapterEnglish.text.trim(),
            'titleMr': _chapterMarathi.text.trim(),
            'title': _chapterEnglish.text.trim(),
            'titleMarathi': _chapterMarathi.text.trim(),
          });
        case _LearningEntryType.scholarshipQuestion:
          data.addAll({
            'questionEn': _questionEnglish.text.trim(),
            'questionMr': _questionMarathi.text.trim(),
            'optionsEn': _optionsEnglish
                .map((controller) => controller.text.trim())
                .toList(growable: false),
            'optionsMr': _optionsMarathi
                .map((controller) => controller.text.trim())
                .toList(growable: false),
            'correctIndex': _correctIndex,
            'explanationEn': _explanationEnglish.text.trim(),
            'explanationMr': _explanationMarathi.text.trim(),
          });
      }
      await document.set(data);
      if (!mounted) return;
      _formKey.currentState?.reset();
      for (final controller in [
        _subjectEnglish,
        _subjectMarathi,
        _chapterEnglish,
        _chapterMarathi,
        _questionEnglish,
        _questionMarathi,
        _explanationEnglish,
        _explanationMarathi,
        ..._optionsEnglish,
        ..._optionsMarathi,
      ]) {
        controller.clear();
      }
      setState(() => _correctIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(m('अभ्यासक्रम जतन केला.', 'Curriculum item saved.')),
        ),
      );
    } catch (error) {
      debugPrint('Curriculum save failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text(m(
            'जतन करता आले नाही. Firestore परवानग्या तपासा.',
            'Could not save. Check Firestore permissions.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String mr, String en) => InputDecoration(
        labelText: m(mr, en),
        border: const OutlineInputBorder(),
      );

  Widget _textField(
    TextEditingController controller,
    String mr,
    String en, {
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: _decoration(mr, en),
          maxLines: maxLines,
          validator: _required,
          textCapitalization: TextCapitalization.sentences,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final allowedStandards = _isQuestion ? const [4, 5, 7, 8] : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          m('नवीन अभ्यासक्रम जोडा', 'Add curriculum content'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          m(
            'जतन केल्यावर विद्यार्थ्यांना सामग्री थेट दिसेल.',
            'Saved content appears in student portals in real time.',
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<_LearningEntryType>(
          segments: [
            ButtonSegment(
              value: _LearningEntryType.subject,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(m('विषय', 'Subject')),
            ),
            ButtonSegment(
              value: _LearningEntryType.chapter,
              icon: const Icon(Icons.article_outlined),
              label: Text(m('प्रकरण', 'Chapter')),
            ),
            ButtonSegment(
              value: _LearningEntryType.scholarshipQuestion,
              icon: const Icon(Icons.quiz_outlined),
              label: Text(m('शिष्यवृत्ती प्रश्न', 'Scholarship question')),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (selection) => setState(() {
            _type = selection.first;
            if (_isQuestion && !const [4, 5, 7, 8].contains(_standard)) {
              _standard = 4;
            }
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _standard,
          decoration: _decoration('इयत्ता', 'Standard'),
          items: [
            for (final standard
                in allowedStandards ?? List.generate(10, (i) => i + 1))
              DropdownMenuItem(
                value: standard,
                child: Text(m('इयत्ता $standard', 'Standard $standard')),
              ),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) setState(() => _standard = value);
                },
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_type == _LearningEntryType.subject) ...[
                _textField(_subjectEnglish, 'विषयाचे नाव (इंग्रजी)',
                    'Subject name (English)'),
                _textField(_subjectMarathi, 'विषयाचे नाव (मराठी)',
                    'Subject name (Marathi)'),
              ],
              if (_type == _LearningEntryType.chapter) ...[
                _textField(_subjectEnglish, 'विषयाचे नाव (इंग्रजी)',
                    'Subject name (English)'),
                _textField(_subjectMarathi, 'विषयाचे नाव (मराठी)',
                    'Subject name (Marathi)'),
                _textField(_chapterEnglish, 'प्रकरणाचे नाव (इंग्रजी)',
                    'Chapter name (English)'),
                _textField(_chapterMarathi, 'प्रकरणाचे नाव (मराठी)',
                    'Chapter name (Marathi)'),
              ],
              if (_isQuestion) ...[
                _textField(
                    _questionEnglish, 'प्रश्न (इंग्रजी)', 'Question (English)',
                    maxLines: 3),
                _textField(
                    _questionMarathi, 'प्रश्न (मराठी)', 'Question (Marathi)',
                    maxLines: 3),
                for (var index = 0; index < 4; index++) ...[
                  _textField(
                      _optionsEnglish[index],
                      'पर्याय ${index + 1} (इंग्रजी)',
                      'Option ${index + 1} (English)'),
                  _textField(
                      _optionsMarathi[index],
                      'पर्याय ${index + 1} (मराठी)',
                      'Option ${index + 1} (Marathi)'),
                ],
                DropdownButtonFormField<int>(
                  initialValue: _correctIndex,
                  decoration: _decoration('योग्य पर्याय', 'Correct option'),
                  items: [
                    for (var index = 0; index < 4; index++)
                      DropdownMenuItem(
                        value: index,
                        child: Text(
                            m('पर्याय ${index + 1}', 'Option ${index + 1}')),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _correctIndex = value ?? 0),
                ),
                const SizedBox(height: 12),
                _textField(_explanationEnglish, 'स्पष्टीकरण (इंग्रजी)',
                    'Explanation (English)',
                    maxLines: 2),
                _textField(_explanationMarathi, 'स्पष्टीकरण (मराठी)',
                    'Explanation (Marathi)',
                    maxLines: 2),
              ],
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_saving
                    ? m('जतन करत आहे…', 'Saving…')
                    : m('Firestore मध्ये जतन करा', 'Save to Firestore')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.medium});
  final String medium;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _students = <_Student>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  String _query = '';
  int? _filter; // null = all, 0 = unassigned, 1..10 = class

  String m(String mr, String en) => _t(widget.medium, mr, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _students.clear();
      _last = null;
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .limit(_pageSize);
      if (_last != null) query = query.startAfterDocument(_last!);
      final snap = await query.get().timeout(const Duration(seconds: 25));
      _students.addAll(snap.docs.map((d) => _Student(d.id, d.data())));
      if (snap.docs.isNotEmpty) _last = snap.docs.last;
      _hasMore = snap.docs.length == _pageSize;
    } catch (error) {
      debugPrint('Student load failed: $error');
      _error = error is FirebaseException && error.code == 'permission-denied'
          ? m('विद्यार्थी यादी पाहण्याची परवानगी नाही.',
              'No permission to read the student list.')
          : m('यादी लोड झाली नाही. पुन्हा प्रयत्न करा.',
              'Could not load the list. Please retry.');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_Student> get _visible {
    final q = _query.trim().toLowerCase();
    return _students.where((s) {
      if (_filter != null) {
        if (_filter == 0 ? s.standard != null : s.standard != _filter) {
          return false;
        }
      }
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.phone.contains(q);
    }).toList();
  }

  Future<void> _changeClass(_Student s) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(m('इयत्ता निवडा', 'Select class')),
        children: [
          for (var i = 1; i <= 10; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Row(
                children: [
                  Expanded(child: Text(m('इयत्ता $i', 'Std $i'))),
                  if (s.standard == i) const Icon(Icons.check_rounded),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == s.standard || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance.collection('users').doc(s.id).update({
        'standard': picked,
        'classUpdatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final index = _students.indexWhere((e) => e.id == s.id);
      if (index >= 0) {
        setState(() {
          _students[index] = _Student(s.id, {
            'name': s.name,
            'email': s.email,
            'phone': s.phone,
            'standard': picked,
            'createdAt':
                s.createdAt == null ? null : Timestamp.fromDate(s.createdAt!),
          });
        });
      }
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(m('इयत्ता बदलली: $picked', 'Class updated: Std $picked')),
      ));
    } catch (error) {
      debugPrint('Class update failed: $error');
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text(error is TimeoutException
            ? m('कनेक्शन संथ आहे. पुन्हा प्रयत्न करा.',
                'The connection is slow. Please try again.')
            : m('इयत्ता बदलता आली नाही (परवानगी तपासा).',
                'Could not change the class (check permissions).')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SearchBar(
            hintText: m(
                'नाव, ईमेल किंवा मोबाईल शोधा', 'Search name, email or mobile'),
            leading: const Icon(Icons.search_rounded),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip(m('सर्व', 'All'), null),
              _chip(m('वर्ग नाही', 'No class'), 0),
              for (var i = 1; i <= 10; i++) _chip(m('इ. $i', 'Std $i'), i),
            ],
          ),
        ),
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            actions: [
              TextButton(
                onPressed: () => _load(),
                child: Text(m('पुन्हा', 'Retry')),
              ),
            ],
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: visible.isEmpty && !_loading
                ? ListView(children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                          m('विद्यार्थी सापडले नाहीत.', 'No students found.')),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, i) {
                      if (i == visible.length) return _footer();
                      final s = visible[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(s.title.characters.first.toUpperCase()),
                          ),
                          title: Text(s.title),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  StudentDetailedProfileScreen(studentUid: s.id),
                            ),
                          ),
                          subtitle: Text([
                            if (s.email.isNotEmpty) s.email,
                            if (s.phone.isNotEmpty) s.phone,
                          ].join(' · ')),
                          trailing: ActionChip(
                            label: Text(s.standard == null
                                ? m('वर्ग निवडा', 'Set class')
                                : m('इ. ${s.standard}', 'Std ${s.standard}')),
                            onPressed: () => _changeClass(s),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, int? value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: FilterChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Widget _footer() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasMore) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: OutlinedButton(
          onPressed: _load,
          child: Text(m('आणखी लोड करा', 'Load more')),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Classes

class _ClassesTab extends StatefulWidget {
  const _ClassesTab({required this.medium});
  final String medium;

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  // Index 0..9 = Std 1..10; index 10 = total students.
  List<int?> _counts = List<int?>.filled(11, null);
  bool _failed = false;

  String m(String mr, String en) => _t(widget.medium, mr, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int?> _count(Query<Map<String, dynamic>> q) async {
    try {
      final r = await q.count().get().timeout(const Duration(seconds: 25));
      return r.count;
    } catch (error) {
      debugPrint('Count failed: $error');
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _counts = List<int?>.filled(11, null);
    });
    final base = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student');
    final results = await Future.wait([
      for (var i = 1; i <= 10; i++)
        _count(base.where('standard', isEqualTo: i)),
      _count(base),
    ]);
    if (!mounted) return;
    setState(() {
      _counts = results;
      _failed = results.every((e) => e == null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _counts[10];
    final assigned = _counts.take(10).fold<int>(0, (acc, e) => acc + (e ?? 0));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded,
                      size: 36, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m('एकूण विद्यार्थी', 'Total students'),
                            style: TextStyle(color: scheme.onPrimaryContainer)),
                        Text(
                          total?.toString() ?? '…',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                        if (total != null)
                          Text(
                            m('वर्ग न दिलेले: ${(total - assigned).clamp(0, total)}',
                                'Without a class: ${(total - assigned).clamp(0, total)}'),
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                m('आकडेवारी लोड झाली नाही. ओढून पुन्हा प्रयत्न करा.',
                    'Could not load the counts. Pull down to retry.'),
                style: TextStyle(color: scheme.error),
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 1; i <= 10; i++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text('$i')),
                title: Text(m('इयत्ता $i', 'Standard $i')),
                trailing: Text(
                  _counts[i - 1]?.toString() ?? '…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Activity

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.medium});
  final String medium;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  List<_Student>? _recent;
  String? _error;

  String m(String mr, String en) => _t(widget.medium, mr, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get()
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() => _recent = snap.docs
          .map((d) => _Student(d.id, d.data()))
          .toList(growable: false));
    } catch (error) {
      debugPrint('Activity load failed: $error');
      if (!mounted) return;
      setState(() {
        _recent ??= const [];
        _error = m('हालचाली लोड झाल्या नाहीत. ओढून पुन्हा प्रयत्न करा.',
            'Could not load activity. Pull down to retry.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;
    if (recent == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(m('अलीकडील नोंदणी', 'Recent registrations'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (recent.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                  child: Text(m('काही हालचाल नाही.', 'No activity yet.'))),
            ),
          for (final s in recent)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                    child: Icon(Icons.person_add_alt_1_rounded)),
                title: Text(s.title),
                subtitle: Text(
                  m('नवीन नोंदणी · ${_formatDate(s.createdAt)}',
                      'New sign-up · ${_formatDate(s.createdAt)}'),
                ),
                trailing: s.standard == null
                    ? null
                    : Chip(
                        label:
                            Text(m('इ. ${s.standard}', 'Std ${s.standard}'))),
              ),
            ),
        ],
      ),
    );
  }
}
