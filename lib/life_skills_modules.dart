import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

String _lifeText(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'Semi-English' => '$en / $mr',
      _ => en,
    };

const _lifeGreen = Color(0xFF178C78);
const _lifeBlue = Color(0xFF3B7DD8);
const _lifeAmber = Color(0xFFE29A30);
const _lifePurple = Color(0xFF8A5CC8);

const _hygieneHabits = <String, (String, String)>{
  'brush': ('दात घासले', 'Brushed teeth'),
  'wash': ('हात स्वच्छ धुतले', 'Washed hands'),
  'bath': ('अंघोळ केली', 'Had a bath'),
  'clothes': ('स्वच्छ कपडे घातले', 'Wore clean clothes'),
  'water': ('पुरेसे पाणी प्यायलो', 'Drank enough water'),
  'sleep': ('वेळेवर झोपायची तयारी', 'Got ready for bed on time'),
};

class _CoinEntry {
  const _CoinEntry({
    required this.amount,
    required this.note,
    required this.createdAt,
  });

  final int amount;
  final String note;
  final DateTime createdAt;

  Map<String, Object> toMap() => {
        'amount': amount,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory _CoinEntry.fromMap(Map<String, dynamic> map) => _CoinEntry(
        amount: map['amount'] is num ? (map['amount'] as num).toInt() : 0,
        note: map['note'] is String ? map['note'] as String : '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] is num ? (map['createdAt'] as num).toInt() : 0,
        ),
      );
}

class _MoodEntry {
  const _MoodEntry({
    required this.id,
    required this.emoji,
    required this.label,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String emoji;
  final String label;
  final String note;
  final DateTime createdAt;

  Map<String, Object> toMap() => {
        'id': id,
        'emoji': emoji,
        'label': label,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory _MoodEntry.fromMap(Map<String, dynamic> map) => _MoodEntry(
        id: map['id'] is String ? map['id'] as String : '',
        emoji: map['emoji'] is String ? map['emoji'] as String : '🙂',
        label: map['label'] is String ? map['label'] as String : '',
        note: map['note'] is String ? map['note'] as String : '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] is num ? (map['createdAt'] as num).toInt() : 0,
        ),
      );
}

/// Four interactive life-skills modules for the student portal.
///
/// Updates are applied locally first. Signed-in users are additionally synced
/// to `users/{uid}/life_skills/state`; Firestore's local cache queues writes
/// while offline.
class LifeSkillsModulesPage extends StatefulWidget {
  const LifeSkillsModulesPage({super.key, required this.medium});

  final String medium;

  @override
  State<LifeSkillsModulesPage> createState() => _LifeSkillsModulesPageState();
}

class _LifeSkillsModulesPageState extends State<LifeSkillsModulesPage> {
  static final Map<String, Map<String, dynamic>> _localSnapshots = {};

  Timer? _pomodoro;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  DocumentReference<Map<String, dynamic>>? _stateDocument;
  Future<void> _writeQueue = Future<void>.value();

  late final String _localKey;
  int _coins = 0;
  int _savingsGoal = 25;
  List<_CoinEntry> _coinHistory = [];
  String _habitDate = '';
  Map<String, bool> _habits = {};
  bool _habitRewarded = false;
  List<_MoodEntry> _moods = [];
  String _syncStatus = 'local';

  int _focusMinutes = 25;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  int? _selectedMood;
  final TextEditingController _moodNote = TextEditingController();
  final TextEditingController _coinAmount = TextEditingController(text: '1');
  final TextEditingController _coinNote = TextEditingController();
  final TextEditingController _savingsGoalController =
      TextEditingController(text: '25');
  bool _isEarning = true;

  String get _medium => widget.medium;
  String _t(String mr, String en) => _lifeText(_medium, mr, en);

  static const _moodOptions = <(String, String, String)>[
    ('😄', 'आनंदी', 'Happy'),
    ('🙂', 'शांत', 'Calm'),
    ('😢', 'दुःखी', 'Sad'),
    ('😠', 'रागीट', 'Angry'),
    ('😰', 'चिंताग्रस्त', 'Worried'),
  ];

  @override
  void initState() {
    super.initState();
    _habitDate = _todayKey();
    _localKey = _currentUid ?? 'local-student';
    _restoreLocal();
    _connectToFirestore();
  }

  String? get _currentUid {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (error) {
      debugPrint('Life-skills authentication unavailable: $error');
      return null;
    }
  }

  String _todayKey([DateTime? date]) {
    final value = date ?? DateTime.now();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  void _restoreLocal() {
    final data = _localSnapshots[_localKey];
    if (data != null) _applySnapshot(data);
    _resetHabitsForToday();
  }

  void _connectToFirestore() {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      _stateDocument = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('life_skills')
          .doc('state');
      _subscription = _stateDocument!.snapshots().listen(
        (snapshot) {
          if (!mounted) return;
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              _applySnapshot(data);
              _resetHabitsForToday();
              _saveLocalSnapshot();
            }
          } else {
            _persist();
          }
          setState(() {
            _syncStatus = snapshot.metadata.hasPendingWrites
                ? 'syncing'
                : snapshot.metadata.isFromCache
                    ? 'offline'
                    : 'synced';
          });
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('Life-skills sync failed: $error');
          if (mounted) setState(() => _syncStatus = 'offline');
        },
      );
    } catch (error) {
      debugPrint('Life-skills cloud storage unavailable: $error');
      _stateDocument = null;
      if (mounted) setState(() => _syncStatus = 'offline');
    }
  }

  void _applySnapshot(Map<String, dynamic> data) {
    final rawHistory = data['coinHistory'];
    final rawMoods = data['moods'];
    final rawHabits = data['habits'];
    _coins = data['coins'] is num ? (data['coins'] as num).toInt() : 0;
    _savingsGoal = data['savingsGoal'] is num
        ? (data['savingsGoal'] as num).toInt().clamp(1, 10000)
        : 25;
    _savingsGoalController.text = '$_savingsGoal';
    _coinHistory = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map(
                (entry) => _CoinEntry.fromMap(Map<String, dynamic>.from(entry)))
            .take(50)
            .toList()
        : [];
    _moods = rawMoods is List
        ? rawMoods
            .whereType<Map>()
            .map(
                (entry) => _MoodEntry.fromMap(Map<String, dynamic>.from(entry)))
            .take(50)
            .toList()
        : [];
    _habitDate =
        data['habitDate'] is String ? data['habitDate'] as String : _todayKey();
    _habits = rawHabits is Map
        ? rawHabits.map((key, value) => MapEntry(key.toString(), value == true))
        : {};
    _habitRewarded = data['habitRewarded'] == true;
  }

  Map<String, dynamic> _snapshot() => {
        'coins': _coins,
        'savingsGoal': _savingsGoal,
        'coinHistory': _coinHistory.map((entry) => entry.toMap()).toList(),
        'habitDate': _habitDate,
        'habits': _habits,
        'habitRewarded': _habitRewarded,
        'moods': _moods.map((entry) => entry.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  void _saveLocalSnapshot() {
    final data = _snapshot()..remove('updatedAt');
    _localSnapshots[_localKey] = data;
  }

  void _persist() {
    _saveLocalSnapshot();
    final document = _stateDocument;
    if (document == null) {
      if (mounted) setState(() => _syncStatus = 'local');
      return;
    }
    final data = _snapshot();
    if (mounted) setState(() => _syncStatus = 'syncing');
    _writeQueue = _writeQueue.then((_) async {
      await document.set(data, SetOptions(merge: true));
      if (mounted) setState(() => _syncStatus = 'synced');
    }).catchError((Object error, StackTrace stack) {
      debugPrint('Life-skills save queued for retry: $error');
      if (mounted) setState(() => _syncStatus = 'offline');
    });
  }

  void _resetHabitsForToday() {
    final today = _todayKey();
    if (_habitDate == today) return;
    _habitDate = today;
    _habits = {};
    _habitRewarded = false;
  }

  void _addCoins(int amount, String note) {
    _coins += amount;
    _coinHistory.insert(
      0,
      _CoinEntry(
        amount: amount,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    if (_coinHistory.length > 50) _coinHistory.removeLast();
    _persist();
  }

  void _toggleHabit(String key, bool checked) {
    _resetHabitsForToday();
    _habits[key] = checked;
    final allDone =
        _hygieneHabits.keys.every((habit) => _habits[habit] == true);
    final reward = allDone && !_habitRewarded;
    if (reward) _habitRewarded = true;
    setState(() {});
    _persist();
    if (reward) {
      _addCoins(
        1,
        _t('आजच्या स्वच्छतेच्या सवयी पूर्ण', 'Completed all habits today'),
      );
      _message(_t('छान! स्वच्छतेसाठी १ नाणे मिळाले.',
          'Great! You earned 1 coin for your hygiene routine.'));
    }
  }

  void _startPomodoro() {
    if (_isRunning) {
      _pomodoro?.cancel();
      setState(() => _isRunning = false);
      return;
    }
    setState(() => _isRunning = true);
    _pomodoro = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isRunning = false;
        });
        if (_isBreak) {
          setState(() {
            _isBreak = false;
            _secondsRemaining = _focusMinutes * 60;
          });
          _message(_t('विश्रांती पूर्ण. पुन्हा अभ्यासासाठी तयार!',
              'Break complete. Ready for another focus session!'));
          return;
        }
        _addCoins(
          1,
          _t('पोमोडोरो अभ्यास सत्र', 'Pomodoro focus session'),
        );
        _message(_t(
            'अभ्यास सत्र पूर्ण! १ नाणे मिळाले. आता ५ मिनिटे विश्रांती घ्या.',
            'Focus session complete! You earned 1 coin. Take a 5-minute break.'));
        setState(() {
          _isBreak = true;
          _secondsRemaining = 5 * 60;
        });
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  void _chooseTimer({required bool isBreak, required int minutes}) {
    _pomodoro?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = isBreak;
      if (!isBreak) _focusMinutes = minutes;
      _secondsRemaining = minutes * 60;
    });
  }

  void _logMood() {
    final index = _selectedMood;
    if (index == null) return;
    final mood = _moodOptions[index];
    setState(() {
      _moods.insert(
        0,
        _MoodEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          emoji: mood.$1,
          label: _t(mood.$2, mood.$3),
          note: _moodNote.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (_moods.length > 50) _moods.removeLast();
      _moodNote.clear();
      _selectedMood = null;
    });
    _persist();
  }

  void _saveCoins() {
    final amount = int.tryParse(_coinAmount.text.trim());
    if (amount == null || amount < 1 || amount > 1000) {
      _message(_t('१ ते १००० मधील नाण्यांची संख्या टाका.',
          'Enter a coin amount from 1 to 1000.'));
      return;
    }
    if (!_isEarning && amount > _coins) {
      _message(_t('इतकी नाणी खर्चासाठी उपलब्ध नाहीत.',
          'You do not have enough coins to spend that amount.'));
      return;
    }
    final note = _coinNote.text.trim().isEmpty
        ? _t(_isEarning ? 'बचत' : 'खर्च', _isEarning ? 'Saved' : 'Spent')
        : _coinNote.text.trim();
    setState(() {
      _coins += _isEarning ? amount : -amount;
      _coinHistory.insert(
        0,
        _CoinEntry(
          amount: _isEarning ? amount : -amount,
          note: note,
          createdAt: DateTime.now(),
        ),
      );
      if (_coinHistory.length > 50) _coinHistory.removeLast();
      _coinAmount.text = '1';
      _coinNote.clear();
    });
    _persist();
  }

  void _setSavingsGoal(int? value) {
    if (value == null || value < 1 || value > 10000) {
      _message(_t('ध्येय १ ते १०,००० नाण्यांदरम्यान ठेवा.',
          'Set a goal between 1 and 10,000 coins.'));
      return;
    }
    setState(() => _savingsGoal = value);
    _persist();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _pomodoro?.cancel();
    _subscription?.cancel();
    _moodNote.dispose();
    _coinAmount.dispose();
    _coinNote.dispose();
    _savingsGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedHabits =
        _hygieneHabits.keys.where((key) => _habits[key] == true).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('जीवन कौशल्ये', 'Life Skills'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            _t('दररोजच्या जीवनासाठी चार छोटे, उपयुक्त सराव.',
                'Four practical activities for everyday life.'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _syncIndicator(theme),
          const SizedBox(height: 12),
          _timerModule(theme),
          const SizedBox(height: 12),
          _financialModule(theme),
          const SizedBox(height: 12),
          _hygieneModule(theme, completedHabits),
          const SizedBox(height: 12),
          _moodModule(theme),
        ],
      ),
    );
  }

  Widget _syncIndicator(ThemeData theme) {
    final (label, icon, color) = switch (_syncStatus) {
      'synced' => (
          _t('क्लाउडमध्ये जतन झाले', 'Saved to cloud'),
          Icons.cloud_done_outlined,
          _lifeGreen
        ),
      'syncing' => (
          _t('जतन करत आहे…', 'Saving…'),
          Icons.cloud_upload_outlined,
          _lifeBlue
        ),
      'offline' => (
          _t('ऑफलाइन · बदल या उपकरणावर जतन', 'Offline · saved on device'),
          Icons.cloud_off_outlined,
          _lifeAmber
        ),
      _ => (_t('स्थानिक जतन', 'Saved locally'), Icons.save_outlined, _lifeBlue),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
        side: BorderSide(color: color.withValues(alpha: .25)),
        backgroundColor: color.withValues(alpha: .08),
      ),
    );
  }

  Widget _moduleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _timerModule(ThemeData theme) {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final color = _isBreak ? _lifeGreen : _lifeBlue;
    return _moduleCard(
      title: _t('वेळेचे नियोजन', 'Time Management'),
      subtitle: _t('पोमोडोरो अभ्यास आणि विश्रांती टायमर',
          'Pomodoro focus and break timer'),
      icon: Icons.timer_rounded,
      color: _lifeBlue,
      children: [
        Center(
          child: Text(
            _isBreak
                ? _t('विश्रांती', 'Break')
                : _t('एकाग्र अभ्यास', 'Focus session'),
            style: theme.textTheme.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '$minutes:$seconds',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final duration in [15, 25, 45])
              ChoiceChip(
                label: Text(_t('$duration मिनिटे', '$duration min')),
                selected: !_isBreak && _focusMinutes == duration,
                onSelected: _isRunning
                    ? null
                    : (_) => _chooseTimer(isBreak: false, minutes: duration),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _startPomodoro,
              icon: Icon(
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(
                  _isRunning ? _t('थांबवा', 'Pause') : _t('सुरू करा', 'Start')),
            ),
            OutlinedButton.icon(
              onPressed: () => _chooseTimer(
                isBreak: false,
                minutes: _focusMinutes,
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(_t('पुन्हा सुरू', 'Reset')),
            ),
            OutlinedButton(
              onPressed: _isRunning
                  ? null
                  : () => _chooseTimer(isBreak: true, minutes: 5),
              child: Text(_t('५ मिनिटे विश्रांती', '5-min break')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t('एक अभ्यास सत्र पूर्ण केल्यावर १ नाणे मिळते.',
              'Complete a focus session to earn 1 coin.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _financialModule(ThemeData theme) {
    final progress = (_coins / _savingsGoal).clamp(0.0, 1.0).toDouble();
    return _moduleCard(
      title: _t('आर्थिक साक्षरता', 'Financial Literacy'),
      subtitle: _t('डिजिटल पिगी बँक आणि नाण्यांचे नियोजन',
          'Digital piggy bank and coin planning'),
      icon: Icons.savings_rounded,
      color: _lifeAmber,
      children: [
        Card(
          color: _lifeAmber.withValues(alpha: .08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('माझी नाण्यांची बचत', 'My coin savings'),
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '$_coins ${_t('नाणी', 'coins')}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                      color: _lifeAmber, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 6),
                Text(_t(
                    'ध्येय: $_savingsGoal नाणी', 'Goal: $_savingsGoal coins')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('life-skills-savings-goal'),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('बचतीचे ध्येय', 'Savings goal'),
                  suffixText: _t('नाणी', 'coins'),
                  border: const OutlineInputBorder(),
                ),
                controller: _savingsGoalController,
                onSubmitted: (value) => _setSavingsGoal(int.tryParse(value)),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () =>
                  _setSavingsGoal(int.tryParse(_savingsGoalController.text)),
              child: Text(_t('जतन', 'Save')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('नाणी जमा', 'Add coins')),
            ),
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.remove_rounded),
              label: Text(_t('नाणी खर्च', 'Spend coins')),
            ),
          ],
          selected: {_isEarning},
          onSelectionChanged: (selection) =>
              setState(() => _isEarning = selection.first),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                controller: _coinAmount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('नाणी', 'Coins'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _coinNote,
                decoration: InputDecoration(
                  labelText: _t('तपशील', 'Note'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saveCoins,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(_t('नोंद जतन करा', 'Save transaction')),
        ),
        if (_coinHistory.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_t('अलीकडील नोंदी', 'Recent transactions'),
              style: theme.textTheme.titleSmall),
          for (final entry in _coinHistory.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                entry.amount >= 0
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: entry.amount >= 0 ? _lifeGreen : theme.colorScheme.error,
              ),
              title: Text(entry.note),
              trailing: Text(
                '${entry.amount >= 0 ? '+' : ''}${entry.amount} ${_t('नाणी', 'coins')}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          _t('बचतीचे ध्येय ठरवा. गरज आणि इच्छा यांमध्ये फरक ओळखा.',
              'Set a savings goal and think about needs versus wants.'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _hygieneModule(ThemeData theme, int completedHabits) {
    return _moduleCard(
      title: _t('स्वतःची काळजी आणि स्वच्छता', 'Self-Care & Hygiene'),
      subtitle: _t('$completedHabits / ${_hygieneHabits.length} सवयी आज पूर्ण',
          '$completedHabits of ${_hygieneHabits.length} habits done today'),
      icon: Icons.health_and_safety_rounded,
      color: _lifeGreen,
      children: [
        LinearProgressIndicator(value: completedHabits / _hygieneHabits.length),
        const SizedBox(height: 8),
        for (final habit in _hygieneHabits.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _habits[habit.key] ?? false,
            title: Text(_t(habit.value.$1, habit.value.$2)),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (checked) => _toggleHabit(habit.key, checked ?? false),
          ),
        Text(
          _t('सर्व सवयी पूर्ण केल्यावर दिवसातून एकदा १ नाणे मिळते.',
              'Complete the routine to earn 1 coin once per day.'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _moodModule(ThemeData theme) {
    final options = _moodOptions;
    return _moduleCard(
      title: _t('भावनिक बुद्धिमत्ता', 'Emotional Intelligence'),
      subtitle: _t('मूड ट्रॅकर · आज तुम्हाला कसे वाटते?',
          'Mood tracker · How are you feeling?'),
      icon: Icons.mood_rounded,
      color: _lifePurple,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (var index = 0; index < options.length; index++)
              ChoiceChip(
                avatar: Text(options[index].$1),
                label: Text(_t(options[index].$2, options[index].$3)),
                selected: _selectedMood == index,
                onSelected: (_) => setState(() => _selectedMood = index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _moodNote,
          maxLength: 160,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: _t('टीप (ऐच्छिक)', 'Note (optional)'),
            border: const OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: _selectedMood == null ? null : _logMood,
          icon: const Icon(Icons.check_rounded),
          label: Text(_t('मूड नोंदवा', 'Log mood')),
        ),
        if (_moods.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_t('माझ्या अलीकडील नोंदी', 'Recent mood entries'),
              style: theme.textTheme.titleSmall),
          for (final mood in _moods.take(7))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(mood.emoji, style: theme.textTheme.headlineSmall),
              title: Text(mood.label),
              subtitle: Text([
                _formatDate(mood.createdAt),
                if (mood.note.isNotEmpty) mood.note,
              ].join(' · ')),
            ),
          if (_moods.first.label == _t('दुःखी', 'Sad') ||
              _moods.first.label == _t('रागीट', 'Angry') ||
              _moods.first.label == _t('चिंताग्रस्त', 'Worried'))
            Card(
              color: _lifeAmber.withValues(alpha: .1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_t(
                  'तुमच्या भावना समजण्यासारख्या आहेत. विश्वासू मोठ्या व्यक्तीशी किंवा शिक्षकांशी बोला.',
                  'Your feelings are valid. Talk with a trusted adult or teacher.',
                )),
              ),
            ),
        ],
      ],
    );
  }

  String _formatDate(DateTime value) {
    final date = _todayKey(value);
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }
}
