import 'dart:async';

import 'package:flutter/material.dart';

// Medium-aware text: Marathi (pure), Semi-English (English / Marathi), English.
String _t(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'Semi-English' => '$en / $mr',
      _ => en,
    };

const _lifeColor = Color(0xFF178C78);
const _socialColor = Color(0xFF8A5CC8);

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: color.withValues(alpha: .08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(fontSize: 12)),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

Widget _scaffold(String title, Color color, List<Widget> children) {
  return Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: color.withValues(alpha: .12),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: children,
      ),
    ),
  );
}

void _open(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    );

// ───────────────────────── Module 3 ─────────────────────────

class LifeSkillsPage extends StatelessWidget {
  const LifeSkillsPage({super.key, required this.medium});
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      _t(medium, 'जीवन आणि वैयक्तिक कौशल्ये', 'Life & Personal Skills'),
      _lifeColor,
      [
        _Entry(
          icon: Icons.savings_rounded,
          color: _lifeColor,
          title: _t(medium, 'डिजिटल पिगी बँक', 'Digital Piggy Bank'),
          subtitle: _t(medium, 'खाऊचे पैसे आणि बचतीचे ध्येय',
              'Pocket money and savings goal'),
          onTap: () => _open(context, _PiggyBankPage(medium: medium)),
        ),
        _Entry(
          icon: Icons.timer_rounded,
          color: const Color(0xFF3B7DD8),
          title: _t(medium, 'वेळेचे नियोजन', 'Time Management'),
          subtitle: _t(medium, 'एकाग्रता टायमर आणि स्क्रीन-टाइम दिनक्रम',
              'Focus timer and screen-time routine'),
          onTap: () => _open(context, _TimeManagementPage(medium: medium)),
        ),
        _Entry(
          icon: Icons.health_and_safety_rounded,
          color: const Color(0xFFD9534F),
          title: _t(
              medium, 'स्वतःची काळजी आणि प्रथमोपचार', 'Self-Care & First Aid'),
          subtitle: _t(medium, 'स्वच्छतेची यादी आणि उपयुक्त सूचना',
              'Hygiene checklist and tips'),
          onTap: () => _open(context, _SelfCarePage(medium: medium)),
        ),
      ],
    );
  }
}

class _Txn {
  _Txn(this.label, this.amount, this.isIncome);
  final String label;
  final int amount;
  final bool isIncome;
}

class _PiggyBankPage extends StatefulWidget {
  const _PiggyBankPage({required this.medium});
  final String medium;

  @override
  State<_PiggyBankPage> createState() => _PiggyBankPageState();
}

class _PiggyBankPageState extends State<_PiggyBankPage> {
  final List<_Txn> _txns = [];
  final _label = TextEditingController();
  final _amount = TextEditingController();
  final _goalName = TextEditingController(text: 'सायकल');
  final _goalAmount = TextEditingController(text: '2000');
  bool _isIncome = true;

  String get m => widget.medium;

  int get _balance =>
      _txns.fold(0, (sum, t) => t.isIncome ? sum + t.amount : sum - t.amount);

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _goalName.dispose();
    _goalAmount.dispose();
    super.dispose();
  }

  void _add() {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_t(m, 'कृपया योग्य रक्कम टाका.', 'Enter a valid amount.'))));
      return;
    }
    setState(() {
      _txns.insert(
          0,
          _Txn(
              _label.text.trim().isEmpty
                  ? (_isIncome
                      ? _t(m, 'जमा', 'Deposit')
                      : _t(m, 'खर्च', 'Spent'))
                  : _label.text.trim(),
              amount,
              _isIncome));
      _label.clear();
      _amount.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goal = int.tryParse(_goalAmount.text.trim()) ?? 0;
    final progress =
        goal <= 0 ? 0.0 : (_balance / goal).clamp(0.0, 1.0).toDouble();
    return _scaffold(
      _t(m, 'डिजिटल पिगी बँक', 'Digital Piggy Bank'),
      _lifeColor,
      [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _lifeColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t(m, 'सध्याची शिल्लक', 'Current balance')),
              Text('₹ $_balance',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _lifeColor)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 6),
              Text(progress >= 1
                  ? _t(m, 'अभिनंदन! ध्येय पूर्ण झाले 🎉',
                      'Congratulations! Goal reached 🎉')
                  : _t(m, 'ध्येय: ${_goalName.text} — ₹ $goal',
                      'Goal: ${_goalName.text} — ₹ $goal')),
            ],
          ),
        ),
        _heading(_t(m, 'बचतीचे ध्येय', 'Savings goal')),
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _goalName,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: _t(m, 'काय घ्यायचे आहे?', 'Saving for'),
                  border: const OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _goalAmount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: _t(m, 'रक्कम ₹', 'Amount ₹'),
                  border: const OutlineInputBorder()),
            ),
          ),
        ]),
        _heading(_t(m, 'नवीन नोंद', 'New entry')),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
                value: true,
                icon: const Icon(Icons.add_rounded),
                label: Text(_t(m, 'जमा', 'Income'))),
            ButtonSegment(
                value: false,
                icon: const Icon(Icons.remove_rounded),
                label: Text(_t(m, 'खर्च', 'Expense'))),
          ],
          selected: {_isIncome},
          onSelectionChanged: (s) => setState(() => _isIncome = s.first),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _label,
          decoration: InputDecoration(
              labelText: _t(m, 'तपशील (उदा. खाऊ)', 'Note (e.g. snacks)'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: _t(m, 'रक्कम ₹', 'Amount ₹'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.save_rounded),
          label: Text(_t(m, 'नोंद जतन करा', 'Save entry')),
        ),
        _heading(_t(m, 'नोंदी', 'History')),
        if (_txns.isEmpty)
          Text(_t(m, 'अजून कोणतीही नोंद नाही.', 'No entries yet.')),
        for (final t in _txns)
          ListTile(
            dense: true,
            leading: Icon(
                t.isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: t.isIncome ? Colors.green : Colors.red),
            title: Text(t.label),
            trailing: Text('${t.isIncome ? '+' : '-'} ₹ ${t.amount}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: t.isIncome ? Colors.green : Colors.red)),
          ),
      ],
    );
  }
}

class _TimeManagementPage extends StatefulWidget {
  const _TimeManagementPage({required this.medium});
  final String medium;

  @override
  State<_TimeManagementPage> createState() => _TimeManagementPageState();
}

class _TimeManagementPageState extends State<_TimeManagementPage> {
  Timer? _timer;
  int _minutes = 25;
  int _remaining = 25 * 60;
  bool _running = false;

  String get m => widget.medium;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() {
          _remaining = 0;
          _running = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_t(m, 'छान! अभ्यासाची वेळ पूर्ण झाली. थोडा आराम करा.',
                'Well done! Focus session complete. Take a short break.'))));
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _setMinutes(int min) {
    _timer?.cancel();
    setState(() {
      _minutes = min;
      _remaining = min * 60;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (_remaining % 60).toString().padLeft(2, '0');
    final routine = [
      (
        '🌅',
        _t(m, 'सकाळ: आवरून झाल्यावर अभ्यास/वाचन; स्क्रीन नाही.',
            'Morning: get ready, then study/read; no screens.')
      ),
      (
        '🏫',
        _t(m, 'शाळा: मोबाईलचा वापर फक्त शिक्षकांच्या परवानगीने.',
            'School: use phones only with teacher permission.')
      ),
      (
        '🏃',
        _t(m, 'संध्याकाळ: किमान १ तास मैदानी खेळ.',
            'Evening: at least 1 hour of outdoor play.')
      ),
      (
        '📱',
        _t(m, 'मनोरंजनासाठी स्क्रीन-टाइम दिवसाला जास्तीत जास्त १ तास.',
            'Recreational screen time: maximum 1 hour a day.')
      ),
      (
        '😴',
        _t(m, 'झोपण्यापूर्वी १ तास आधी स्क्रीन बंद करा.',
            'Switch off screens 1 hour before bedtime.')
      ),
    ];
    return _scaffold(
      _t(m, 'वेळेचे नियोजन', 'Time Management'),
      const Color(0xFF3B7DD8),
      [
        Center(
          child: Text('$mm:$ss',
              style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B7DD8))),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final min in [15, 25, 45])
              ChoiceChip(
                label: Text(_t(m, '$min मिनिटे', '$min min')),
                selected: _minutes == min,
                onSelected: (_) => _setMinutes(min),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          FilledButton.icon(
            onPressed: _remaining == 0 ? null : _toggle,
            icon:
                Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(_running
                ? _t(m, 'थांबवा', 'Pause')
                : _t(m, 'सुरू करा', 'Start')),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _setMinutes(_minutes),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(_t(m, 'पुन्हा सुरू', 'Reset')),
          ),
        ]),
        _heading(_t(
            m, 'स्क्रीन-टाइम दिनक्रम मार्गदर्शक', 'Screen-time routine guide')),
        for (final r in routine)
          Card(
            elevation: 0,
            color: const Color(0xFFF3F6FC),
            child: ListTile(
              leading: Text(r.$1, style: const TextStyle(fontSize: 24)),
              title: Text(r.$2, style: const TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }
}

class _SelfCarePage extends StatefulWidget {
  const _SelfCarePage({required this.medium});
  final String medium;

  @override
  State<_SelfCarePage> createState() => _SelfCarePageState();
}

class _SelfCarePageState extends State<_SelfCarePage> {
  final Set<int> _done = {};
  String get m => widget.medium;

  @override
  Widget build(BuildContext context) {
    final checklist = [
      _t(m, 'सकाळी आणि रात्री दात घासले', 'Brushed teeth morning and night'),
      _t(m, 'आंघोळ केली आणि स्वच्छ कपडे घातले',
          'Bathed and wore clean clothes'),
      _t(m, 'जेवणापूर्वी आणि शौचानंतर साबणाने हात धुतले',
          'Washed hands with soap before meals and after toilet'),
      _t(m, 'नखे स्वच्छ आणि कापलेली आहेत', 'Nails are clean and trimmed'),
      _t(m, 'दिवसभरात पुरेसे पाणी प्यायले', 'Drank enough water today'),
      _t(m, 'वेळेवर झोपलो/झोपले (८-९ तास)', 'Slept on time (8–9 hours)'),
    ];
    final firstAid = [
      (
        _t(m, 'किरकोळ जखम', 'Minor cut'),
        _t(m, 'स्वच्छ पाण्याने धुवा, दाब देऊन रक्त थांबवा, पट्टी लावा.',
            'Rinse with clean water, press to stop bleeding, apply a bandage.')
      ),
      (
        _t(m, 'भाजणे', 'Minor burn'),
        _t(m, '१० मिनिटे वाहत्या थंड पाण्याखाली धरा. फोड फोडू नका.',
            'Hold under cool running water for 10 minutes. Do not pop blisters.')
      ),
      (
        _t(m, 'नाकातून रक्त', 'Nosebleed'),
        _t(m, 'पुढे वाकून बसा, नाकाचा मऊ भाग १० मिनिटे दाबून धरा.',
            'Sit leaning forward and pinch the soft part of the nose for 10 minutes.')
      ),
      (
        _t(m, 'मोठी दुखापत', 'Serious injury'),
        _t(m, 'लगेच मोठ्यांना सांगा आणि १०८ रुग्णवाहिकेला फोन करा.',
            'Tell an adult immediately and call ambulance 108.')
      ),
    ];
    return _scaffold(
      _t(m, 'स्वतःची काळजी आणि प्रथमोपचार', 'Self-Care & First Aid'),
      const Color(0xFFD9534F),
      [
        Text(
            _t(m, 'आजची स्वच्छता यादी (${_done.length}/${checklist.length})',
                "Today's hygiene checklist (${_done.length}/${checklist.length})"),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
            value: _done.length / checklist.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8)),
        for (var i = 0; i < checklist.length; i++)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _done.contains(i),
            title: Text(checklist[i], style: const TextStyle(fontSize: 13)),
            onChanged: (v) => setState(() {
              if (v == true) {
                _done.add(i);
              } else {
                _done.remove(i);
              }
            }),
          ),
        _heading(_t(m, 'प्रथमोपचार सूचना', 'First-aid tips')),
        for (final f in firstAid)
          Card(
            elevation: 0,
            color: const Color(0xFFFDF0EF),
            child: ListTile(
              leading:
                  const Icon(Icons.healing_rounded, color: Color(0xFFD9534F)),
              title: Text(f.$1,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(f.$2),
            ),
          ),
        const SizedBox(height: 8),
        Text(
            _t(
                m,
                'टीप: ही केवळ प्राथमिक माहिती आहे; गरज असल्यास डॉक्टरांचा सल्ला घ्या.',
                'Note: This is basic guidance only; consult a doctor when needed.'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF68718A))),
      ],
    );
  }
}

// ───────────────────────── Module 4 ─────────────────────────

class SocialSkillsPage extends StatelessWidget {
  const SocialSkillsPage({super.key, required this.medium});
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      _t(medium, 'सामाजिक आणि भावनिक कौशल्ये', 'Social & Emotional Skills'),
      _socialColor,
      [
        _Entry(
          icon: Icons.mood_rounded,
          color: const Color(0xFFE29A30),
          title: _t(medium, 'मूड ट्रॅकर', 'Mood Tracker'),
          subtitle: _t(medium, 'आजच्या भावना नोंदवा', "Log today's feelings"),
          onTap: () => _open(context, _MoodTrackerPage(medium: medium)),
        ),
        _Entry(
          icon: Icons.groups_rounded,
          color: _socialColor,
          title: _t(medium, 'समस्या सोडवणे व सांघिक कार्य',
              'Problem Solving & Teamwork'),
          subtitle: _t(medium, 'प्रसंगांवर आधारित संवादी सराव',
              'Interactive situation scenarios'),
          onTap: () => _open(context, _ScenarioPage(medium: medium)),
        ),
        _Entry(
          icon: Icons.self_improvement_rounded,
          color: _lifeColor,
          title: _t(medium, 'भावनांवर नियंत्रण व शांत होण्याचे व्यायाम',
              'Calm-down & Relaxation Exercises'),
          subtitle: _t(medium, 'श्वासाचा व्यायाम आणि मार्गदर्शन',
              'Breathing and guidance'),
          onTap: () => _open(context, _RelaxationPage(medium: medium)),
        ),
      ],
    );
  }
}

class _MoodTrackerPage extends StatefulWidget {
  const _MoodTrackerPage({required this.medium});
  final String medium;

  @override
  State<_MoodTrackerPage> createState() => _MoodTrackerPageState();
}

class _MoodTrackerPageState extends State<_MoodTrackerPage> {
  final List<(String, String, DateTime, String)> _log = [];
  final _note = TextEditingController();
  int? _selected;

  String get m => widget.medium;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<(String, String)> get _moods => [
        ('😄', _t(m, 'आनंदी', 'Happy')),
        ('🙂', _t(m, 'शांत', 'Calm')),
        ('😢', _t(m, 'दुःखी', 'Sad')),
        ('😠', _t(m, 'रागीट', 'Angry')),
        ('😰', _t(m, 'चिंताग्रस्त', 'Worried')),
      ];

  @override
  Widget build(BuildContext context) {
    final moods = _moods;
    return _scaffold(
      _t(m, 'मूड ट्रॅकर', 'Mood Tracker'),
      const Color(0xFFE29A30),
      [
        Text(_t(m, 'आज तुला कसे वाटते आहे?', 'How are you feeling today?'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < moods.length; i++)
              ChoiceChip(
                label: Text('${moods[i].$1} ${moods[i].$2}'),
                selected: _selected == i,
                onSelected: (_) => setState(() => _selected = i),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: InputDecoration(
              labelText:
                  _t(m, 'कारण / टीप (ऐच्छिक)', 'Reason / note (optional)'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => setState(() {
                    final mood = moods[_selected!];
                    _log.insert(0,
                        (mood.$1, mood.$2, DateTime.now(), _note.text.trim()));
                    _note.clear();
                    _selected = null;
                  }),
          icon: const Icon(Icons.check_rounded),
          label: Text(_t(m, 'नोंद करा', 'Log mood')),
        ),
        _heading(_t(m, 'माझ्या नोंदी', 'My log')),
        if (_log.isEmpty)
          Text(_t(m, 'अजून कोणतीही नोंद नाही.', 'No entries yet.')),
        for (final e in _log)
          ListTile(
            dense: true,
            leading: Text(e.$1, style: const TextStyle(fontSize: 26)),
            title: Text(e.$2),
            subtitle: Text(
                '${e.$3.day.toString().padLeft(2, '0')}/${e.$3.month.toString().padLeft(2, '0')}/${e.$3.year}'
                '${e.$4.isEmpty ? '' : ' · ${e.$4}'}'),
          ),
        if (_log.isNotEmpty &&
            (_log.first.$2 == moods[2].$2 ||
                _log.first.$2 == moods[3].$2 ||
                _log.first.$2 == moods[4].$2))
          Card(
            color: const Color(0xFFFFF6E5),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_t(
                  m,
                  'तुझ्या भावना समजण्यासारख्या आहेत. मोठ्या व्यक्तीशी किंवा शिक्षकांशी बोल आणि शांत होण्याचा व्यायाम करून पहा.',
                  'Your feelings are valid. Talk to a trusted adult or teacher and try a calming exercise.')),
            ),
          ),
      ],
    );
  }
}

class _Scenario {
  const _Scenario(this.situation, this.options, this.best, this.reason);
  final String situation;
  final List<String> options;
  final int best;
  final String reason;
}

class _ScenarioPage extends StatefulWidget {
  const _ScenarioPage({required this.medium});
  final String medium;

  @override
  State<_ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<_ScenarioPage> {
  final Map<int, int> _answers = {};
  String get m => widget.medium;

  @override
  Widget build(BuildContext context) {
    final scenarios = [
      _Scenario(
        _t(m, 'गट प्रकल्पात एक मित्र काहीच काम करत नाही.',
            'In a group project, one friend is not doing any work.'),
        [
          _t(m, 'त्याला सोडून द्या आणि बाकीच्यांनी काम करा.',
              'Ignore him and do the work yourselves.'),
          _t(m, 'शांतपणे बोलून त्याला एक सोपे काम द्या.',
              'Talk calmly and give him a small task.'),
          _t(m, 'सर्वांसमोर त्याला ओरडा.',
              'Shout at him in front of everyone.'),
        ],
        1,
        _t(m, 'शांत संवाद आणि जबाबदारी वाटून दिल्याने संघ मजबूत होतो.',
            'Calm talk and sharing responsibility make a team stronger.'),
      ),
      _Scenario(
        _t(m, 'खेळताना दोन मित्रांचे भांडण झाले.',
            'Two friends are arguing during a game.'),
        [
          _t(m, 'दोघांचे म्हणणे ऐकून नियम पुन्हा ठरवा.',
              'Listen to both and agree on the rules again.'),
          _t(m, 'खेळ बंद करा आणि निघून जा.', 'Stop the game and walk away.'),
          _t(m, 'एकाच्या बाजूने बोला.', 'Take one side.'),
        ],
        0,
        _t(m, 'दोन्ही बाजू ऐकल्यास तोडगा निघतो.',
            'Listening to both sides helps find a fair solution.'),
      ),
      _Scenario(
        _t(m, 'नवीन विद्यार्थी एकटा बसला आहे.',
            'A new student is sitting alone.'),
        [
          _t(m, 'दुर्लक्ष करा.', 'Ignore.'),
          _t(m, 'त्याला हसून आपल्या गटात बोलवा.',
              'Smile and invite him to join your group.'),
          _t(m, 'त्याच्याबद्दल इतरांना सांगा.', 'Gossip about him.'),
        ],
        1,
        _t(m, 'दयाळूपणामुळे नवीन मित्र मिळतात.',
            'Kindness helps build new friendships.'),
      ),
    ];
    return _scaffold(
      _t(m, 'समस्या सोडवणे व सांघिक कार्य', 'Problem Solving & Teamwork'),
      _socialColor,
      [
        for (var i = 0; i < scenarios.length; i++) ...[
          Card(
            elevation: 0,
            color: _socialColor.withValues(alpha: .07),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${scenarios[i].situation}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (var j = 0; j < scenarios[i].options.length; j++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _answers[i] == j
                            ? (j == scenarios[i].best
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded)
                            : Icons.radio_button_unchecked_rounded,
                        color: _answers[i] == j
                            ? (j == scenarios[i].best
                                ? Colors.green
                                : Colors.red)
                            : null,
                      ),
                      title: Text(scenarios[i].options[j]),
                      onTap: () => setState(() => _answers[i] = j),
                    ),
                  if (_answers[i] != null)
                    Text(
                      '${_answers[i] == scenarios[i].best ? _t(m, 'बरोबर! ', 'Correct! ') : _t(m, 'पुन्हा विचार करा. ', 'Think again. ')}${scenarios[i].reason}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RelaxationPage extends StatefulWidget {
  const _RelaxationPage({required this.medium});
  final String medium;

  @override
  State<_RelaxationPage> createState() => _RelaxationPageState();
}

class _RelaxationPageState extends State<_RelaxationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  bool _on = false;

  String get m => widget.medium;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _on = !_on);
    if (_on) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tips = [
      (
        Icons.air_rounded,
        _t(m, '४-४ श्वास', '4-4 breathing'),
        _t(m, '४ सेकंद श्वास घ्या, ४ सेकंद सोडा. ५ वेळा करा.',
            'Breathe in for 4 seconds, out for 4 seconds. Repeat 5 times.')
      ),
      (
        Icons.numbers_rounded,
        _t(m, '१० पर्यंत मोजा', 'Count to 10'),
        _t(m, 'राग आल्यावर हळूहळू १० पर्यंत मोजा आणि मग बोला.',
            'When angry, count slowly to 10 before you speak.')
      ),
      (
        Icons.visibility_rounded,
        _t(m, '५-४-३-२-१ पद्धत', '5-4-3-2-1 grounding'),
        _t(m, '५ गोष्टी पहा, ४ स्पर्श करा, ३ ऐका, २ वास घ्या, १ चव घ्या.',
            'Notice 5 things you see, 4 you touch, 3 you hear, 2 you smell, 1 you taste.')
      ),
      (
        Icons.accessibility_new_rounded,
        _t(m, 'स्नायू सैल करा', 'Relax your muscles'),
        _t(m, 'खांदे उंच करा, ५ सेकंद धरा आणि सोडून द्या.',
            'Raise your shoulders, hold for 5 seconds, then release.')
      ),
    ];
    return _scaffold(
      _t(m, 'शांत होण्याचे व्यायाम', 'Calm-down Exercises'),
      _lifeColor,
      [
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Container(
              width: 90 + 90 * _c.value,
              height: 90 + 90 * _c.value,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lifeColor.withValues(alpha: .15 + .2 * _c.value),
              ),
              child: Text(
                !_on
                    ? '🌿'
                    : (_c.status == AnimationStatus.reverse
                        ? _t(m, 'श्वास सोडा', 'Breathe out')
                        : _t(m, 'श्वास घ्या', 'Breathe in')),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_on ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(_on
                ? _t(m, 'थांबवा', 'Stop')
                : _t(m, 'श्वासाचा व्यायाम सुरू करा', 'Start breathing')),
          ),
        ),
        _heading(_t(m, 'मार्गदर्शन', 'Guidance')),
        for (final t in tips)
          Card(
            elevation: 0,
            color: _lifeColor.withValues(alpha: .07),
            child: ListTile(
              leading: Icon(t.$1, color: _lifeColor),
              title: Text(t.$2,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(t.$3),
            ),
          ),
      ],
    );
  }
}
