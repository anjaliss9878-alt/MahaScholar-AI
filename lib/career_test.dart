import 'package:flutter/material.dart';

// Medium-aware text: Marathi (pure), Semi-English (English / Marathi), English.
String _t(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'Semi-English' => '$en / $mr',
      _ => en,
    };

enum _Stream { science, commerce, arts, diploma }

class _L {
  const _L(this.mr, this.en);
  final String mr;
  final String en;
  String of(String medium) => _t(medium, mr, en);
}

/// Scored aptitude question; a correct answer adds points to [streams].
class _AptitudeQ {
  const _AptitudeQ(this.question, this.options, this.correct, this.streams);
  final _L question;
  final List<_L> options;
  final int correct;
  final List<_Stream> streams;
}

/// Interest question; option i supports stream i (science, commerce, arts, diploma).
class _InterestQ {
  const _InterestQ(this.question, this.options);
  final _L question;
  final List<_L> options;
}

const _aptitudeQuestions = [
  _AptitudeQ(
    _L('२०० चे १५% किती?', 'What is 15% of 200?'),
    [_L('२०', '20'), _L('३०', '30'), _L('४०', '40'), _L('१५', '15')],
    1,
    [_Stream.science, _Stream.commerce],
  ),
  _AptitudeQ(
    _L('१२ पेनांची किंमत ₹६० आहे. तर ५ पेनांची किंमत किती?',
        '12 pens cost ₹60. What do 5 pens cost?'),
    [_L('₹२०', '₹20'), _L('₹२५', '₹25'), _L('₹३०', '₹30'), _L('₹३५', '₹35')],
    1,
    [_Stream.commerce, _Stream.science],
  ),
  _AptitudeQ(
    _L('मालिका पूर्ण करा: २, ६, १८, ५४, ?',
        'Complete the series: 2, 6, 18, 54, ?'),
    [_L('१०८', '108'), _L('१६२', '162'), _L('१२६', '126'), _L('१८०', '180')],
    1,
    [_Stream.science, _Stream.diploma],
  ),
  _AptitudeQ(
    _L('“प्रामाणिक” या शब्दाचा जवळचा अर्थ कोणता?',
        'Which word is closest in meaning to "honest"?'),
    [
      _L('खरे बोलणारा', 'Truthful'),
      _L('आळशी', 'Lazy'),
      _L('रागीट', 'Angry'),
      _L('घाबरट', 'Timid'),
    ],
    0,
    [_Stream.arts, _Stream.commerce],
  ),
  _AptitudeQ(
    _L('नट घट्ट करण्यासाठी कोणते साधन वापरतात?',
        'Which tool is used to tighten a nut?'),
    [
      _L('पाना (स्पॅनर)', 'Spanner'),
      _L('हातोडा', 'Hammer'),
      _L('करवत', 'Saw'),
      _L('चिमटा', 'Tweezers'),
    ],
    0,
    [_Stream.diploma, _Stream.science],
  ),
  _AptitudeQ(
    _L('एक चाक घड्याळाच्या काट्यांच्या दिशेने फिरते. त्याला जोडलेले दुसरे चाक कसे फिरेल?',
        'A gear turns clockwise. How does the gear meshed with it turn?'),
    [
      _L('घड्याळाच्या काट्यांच्या दिशेने', 'Clockwise'),
      _L('विरुद्ध दिशेने', 'Anticlockwise'),
      _L('फिरणार नाही', 'It will not turn'),
      _L('आळीपाळीने', 'It alternates'),
    ],
    1,
    [_Stream.diploma],
  ),
  _AptitudeQ(
    _L('भारतीय संविधानाच्या मसुदा समितीचे अध्यक्ष कोण होते?',
        'Who chaired the Drafting Committee of the Indian Constitution?'),
    [
      _L('महात्मा गांधी', 'Mahatma Gandhi'),
      _L('डॉ. बाबासाहेब आंबेडकर', 'Dr. B. R. Ambedkar'),
      _L('पंडित नेहरू', 'Pt. Jawaharlal Nehru'),
      _L('सरदार पटेल', 'Sardar Patel'),
    ],
    1,
    [_Stream.arts],
  ),
];

const _interestQuestions = [
  _InterestQ(
    _L('सुट्टीत तुम्हाला काय करायला आवडेल?',
        'What would you enjoy in a holiday?'),
    [
      _L('विज्ञान प्रयोग करणे', 'Doing a science experiment'),
      _L('दुकान चालवण्याचा खेळ खेळणे', 'Playing shopkeeper and handling money'),
      _L('गोष्ट किंवा कविता लिहिणे', 'Writing a story or poem'),
      _L('एखादे यंत्र दुरुस्त करणे', 'Repairing a machine'),
    ],
  ),
  _InterestQ(
    _L('कोणता विषय तुम्हाला सर्वाधिक आवडतो?',
        'Which subject do you like most?'),
    [
      _L('विज्ञान / गणित', 'Science / Maths'),
      _L('अर्थशास्त्र / हिशेब', 'Economics / Accounts'),
      _L('इतिहास / भाषा', 'History / Languages'),
      _L('तंत्रज्ञान / कार्यानुभव', 'Technology / Work experience'),
    ],
  ),
  _InterestQ(
    _L('भविष्यात तुम्हाला कोण व्हायला आवडेल?',
        'Whom would you like to become?'),
    [
      _L('डॉक्टर / शास्त्रज्ञ', 'Doctor / Scientist'),
      _L('सनदी लेखापाल / उद्योजक', 'Chartered accountant / Entrepreneur'),
      _L('शिक्षक / अधिकारी / पत्रकार', 'Teacher / Officer / Journalist'),
      _L('तंत्रज्ञ / अभियंता', 'Technician / Engineer'),
    ],
  ),
  _InterestQ(
    _L('समस्या आली तर तुम्ही काय करता?', 'When you face a problem, you...'),
    [
      _L('कारण शोधून तर्क लावता', 'Find the cause and reason it out'),
      _L('खर्च-फायदा तपासता', 'Weigh the cost and benefit'),
      _L('लोकांशी बोलून मार्ग काढता', 'Talk to people to find a way'),
      _L('प्रत्यक्ष हाताने करून पाहता', 'Try fixing it by hand'),
    ],
  ),
  _InterestQ(
    _L('तुम्हाला कोणते काम आवडेल?', 'Which kind of work appeals to you?'),
    [
      _L('प्रयोगशाळा / संशोधन', 'Laboratory / research'),
      _L('बँक / व्यापार', 'Bank / trade'),
      _L('समाजसेवा / कला / प्रशासन', 'Social service / arts / administration'),
      _L('कार्यशाळा / कारखाना', 'Workshop / factory'),
    ],
  ),
  _InterestQ(
    _L('लवकर नोकरी किंवा व्यवसाय सुरू करण्याबद्दल तुमचे मत?',
        'How do you feel about starting work early?'),
    [
      _L('आधी उच्च शिक्षण घेईन', 'I will study longer first'),
      _L('स्वतःचा व्यवसाय हवा', 'I want my own business'),
      _L('स्पर्धा परीक्षा देईन', 'I will prepare for competitive exams'),
      _L('कौशल्य शिकून लवकर कमवेन', 'I want to learn a skill and earn early'),
    ],
  ),
];

const _aptitudePoints = 2;
const _interestPoints = 3;

class _StreamInfo {
  const _StreamInfo({
    required this.stream,
    required this.name,
    required this.icon,
    required this.color,
    required this.path,
    required this.careers,
    required this.exams,
  });

  final _Stream stream;
  final _L name;
  final IconData icon;
  final Color color;
  final _L path;
  final _L careers;
  final _L exams;
}

const _streamInfo = {
  _Stream.science: _StreamInfo(
    stream: _Stream.science,
    name: _L('विज्ञान शाखा', 'Science stream'),
    icon: Icons.biotech_rounded,
    color: Color(0xFF4276C7),
    path: _L(
        '११ वी–१२ वी (भौतिकशास्त्र, रसायनशास्त्र, गणित/जीवशास्त्र) नंतर पदवी.',
        '11th–12th (Physics, Chemistry, Maths/Biology), then a degree.'),
    careers: _L(
        'अभियांत्रिकी, वैद्यकीय, औषधनिर्माण, शुद्ध विज्ञान, संगणक क्षेत्र.',
        'Engineering, medicine, pharmacy, pure sciences, computing.'),
    exams: _L('एमएचटी-सीईटी, नीट, जेईई', 'MHT-CET, NEET, JEE'),
  ),
  _Stream.commerce: _StreamInfo(
    stream: _Stream.commerce,
    name: _L('वाणिज्य शाखा', 'Commerce stream'),
    icon: Icons.account_balance_rounded,
    color: Color(0xFF178C78),
    path: _L(
        '११ वी–१२ वी (हिशेब, अर्थशास्त्र, व्यवसाय अभ्यास) नंतर बी.कॉम/बीबीए.',
        '11th–12th (Accounts, Economics, Business Studies), then B.Com/BBA.'),
    careers: _L('सनदी लेखापाल, बँकिंग, कर सल्लागार, व्यवस्थापन, उद्योजकता.',
        'Chartered accountancy, banking, taxation, management, entrepreneurship.'),
    exams: _L('सीए फाउंडेशन, सीएमए, सीईटी (बीबीए/बीएमएस)',
        'CA Foundation, CMA, CET (BBA/BMS)'),
  ),
  _Stream.arts: _StreamInfo(
    stream: _Stream.arts,
    name: _L('कला शाखा', 'Arts stream'),
    icon: Icons.palette_rounded,
    color: Color(0xFF8A5CC8),
    path: _L('११ वी–१२ वी (इतिहास, राज्यशास्त्र, भाषा, समाजशास्त्र) नंतर बी.ए.',
        '11th–12th (History, Political Science, Languages, Sociology), then B.A.'),
    careers: _L('शिक्षण, कायदा, पत्रकारिता, समाजकार्य, प्रशासकीय सेवा, डिझाइन.',
        'Teaching, law, journalism, social work, civil services, design.'),
    exams: _L('एमपीएससी/यूपीएससी, कायदा सीईटी, शिक्षक पात्रता परीक्षा',
        'MPSC/UPSC, Law CET, teacher eligibility tests'),
  ),
  _Stream.diploma: _StreamInfo(
    stream: _Stream.diploma,
    name: _L('पदविका / आयटीआय (तंत्रशिक्षण)', 'Diploma / ITI (technical)'),
    icon: Icons.build_rounded,
    color: Color(0xFFD77A33),
    path: _L(
        '१० वी नंतर ३ वर्षांची पॉलिटेक्निक पदविका किंवा आयटीआय; पदविकेनंतर थेट द्वितीय वर्ष अभियांत्रिकीला प्रवेश शक्य.',
        '3-year polytechnic diploma or ITI after 10th; diploma holders can seek direct second-year engineering entry.'),
    careers: _L(
        'यांत्रिकी, विद्युत, सिव्हिल, संगणक पदविका, तंत्रज्ञ, लघुउद्योग.',
        'Mechanical, electrical, civil, computer diplomas, technician roles, small business.'),
    exams: _L('डीटीई महाराष्ट्र पॉलिटेक्निक प्रवेश (सीएपी), आयटीआय प्रवेश',
        'DTE Maharashtra polytechnic admission (CAP), ITI admission'),
  ),
};

int _maxScore(_Stream s) {
  var total = _interestQuestions.length * _interestPoints;
  for (final q in _aptitudeQuestions) {
    if (q.streams.contains(s)) total += _aptitudePoints;
  }
  return total;
}

class CareerTestPage extends StatefulWidget {
  const CareerTestPage({super.key, required this.medium});
  final String medium;

  @override
  State<CareerTestPage> createState() => _CareerTestPageState();
}

class _CareerTestPageState extends State<CareerTestPage> {
  static const _total = 7 + 6; // aptitude + interest

  int _step = 0;
  int? _selected;
  final List<int> _answers = [];

  bool get _done => _step >= _total;

  void _confirm() {
    final choice = _selected;
    if (choice == null) return;
    setState(() {
      _answers.add(choice);
      _selected = null;
      _step++;
    });
  }

  void _back() {
    if (_step == 0 || _answers.isEmpty) return;
    setState(() {
      _selected = _answers.removeLast();
      _step--;
    });
  }

  void _restart() => setState(() {
        _step = 0;
        _selected = null;
        _answers.clear();
      });

  @override
  Widget build(BuildContext context) {
    final m = widget.medium;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(m, 'करिअर चाचणी', 'Career Test'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF7357BE).withValues(alpha: .12),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: _done ? _resultWidgets(context) : _questionWidgets(context),
        ),
      ),
    );
  }

  List<Widget> _questionWidgets(BuildContext context) {
    final m = widget.medium;
    final isAptitude = _step < _aptitudeQuestions.length;
    final _L question;
    final List<_L> options;
    if (isAptitude) {
      question = _aptitudeQuestions[_step].question;
      options = _aptitudeQuestions[_step].options;
    } else {
      final q = _interestQuestions[_step - _aptitudeQuestions.length];
      question = q.question;
      options = q.options;
    }
    return [
      LinearProgressIndicator(
        value: _step / _total,
        minHeight: 8,
        borderRadius: BorderRadius.circular(8),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Chip(
            label: Text(isAptitude
                ? _t(m, 'क्षमता', 'Aptitude')
                : _t(m, 'आवड', 'Interest')),
          ),
          const Spacer(),
          Text(_t(m, 'प्रश्न ${_step + 1} / $_total',
              'Question ${_step + 1} / $_total')),
        ],
      ),
      const SizedBox(height: 12),
      Text(question.of(m),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      for (var i = 0; i < options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _OptionTile(
            label: options[i].of(m),
            selected: _selected == i,
            onTap: () => setState(() => _selected = i),
          ),
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(_t(m, 'मागे', 'Back')),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _selected == null ? null : _confirm,
            child: Text(_step == _total - 1
                ? _t(m, 'निकाल पहा', 'See result')
                : _t(m, 'पुढे', 'Next')),
          ),
        ],
      ),
    ];
  }

  List<Widget> _resultWidgets(BuildContext context) {
    final m = widget.medium;
    var aptitudeScore = 0;
    final points = {for (final s in _Stream.values) s: 0};
    for (var i = 0; i < _aptitudeQuestions.length; i++) {
      final q = _aptitudeQuestions[i];
      if (_answers[i] == q.correct) {
        aptitudeScore++;
        for (final s in q.streams) {
          points[s] = points[s]! + _aptitudePoints;
        }
      }
    }
    for (var i = 0; i < _interestQuestions.length; i++) {
      final choice = _answers[_aptitudeQuestions.length + i];
      final s = _Stream.values[choice];
      points[s] = points[s]! + _interestPoints;
    }
    final ranked = [
      for (final s in _Stream.values)
        (stream: s, percent: (points[s]! * 100 / _maxScore(s)).round()),
    ]..sort((a, b) => b.percent.compareTo(a.percent));
    final top = ranked.first;
    final close = ranked[1].percent >= top.percent - 8 ? ranked[1] : null;
    final info = _streamInfo[top.stream]!;
    final scheme = Theme.of(context).colorScheme;

    return [
      Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.quiz_rounded, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                          m,
                          'क्षमता गुण: $aptitudeScore / ${_aptitudeQuestions.length}',
                          'Aptitude score: $aptitudeScore / ${_aptitudeQuestions.length}'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      aptitudeScore >= 6
                          ? _t(m, 'उत्कृष्ट कामगिरी!', 'Excellent performance!')
                          : aptitudeScore >= 4
                              ? _t(m, 'चांगली कामगिरी.', 'Good performance.')
                              : _t(m, 'सराव आणि अन्वेषण सुरू ठेवा.',
                                  'Keep practising and exploring.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(_t(m, 'तुम्हाला सर्वाधिक जुळणारा मार्ग', 'Your best-matching path'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _StreamCard(info: info, medium: m, percent: top.percent, expanded: true),
      if (close != null) ...[
        const SizedBox(height: 12),
        Text(
          _t(
              m,
              'हा मार्गही जवळपास जुळतो: ${_streamInfo[close.stream]!.name.mr}',
              'This path is also a close match: ${_streamInfo[close.stream]!.name.en}'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(_t(m, 'सर्व शाखांची तुलना', 'All streams compared'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      for (final r in ranked)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _StreamCard(
            info: _streamInfo[r.stream]!,
            medium: m,
            percent: r.percent,
            expanded: false,
          ),
        ),
      const SizedBox(height: 4),
      Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _t(
                      m,
                      'ही चाचणी फक्त दिशादर्शक आहे; अंतिम निर्णय नाही. पालक, शिक्षक आणि करिअर समुपदेशकांशी चर्चा करा आणि प्रवेशासाठी अधिकृत सूचना तपासा.',
                      'This test is only a guide, not a final decision. Discuss with parents, teachers and a career counsellor, and verify admission rules from official notices.'),
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _restart,
        icon: const Icon(Icons.replay_rounded),
        label: Text(_t(m, 'चाचणी पुन्हा द्या', 'Retake test')),
      ),
    ];
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.info,
    required this.medium,
    required this.percent,
    required this.expanded,
  });

  final _StreamInfo info;
  final String medium;
  final int percent;
  final bool expanded;

  Widget _detail(IconData icon, String label, String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: info.color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(text,
                      style: const TextStyle(fontSize: 12, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = medium;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: info.color,
                  child: Icon(info.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(info.name.of(m),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Text('$percent%',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: info.color)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              color: info.color,
              borderRadius: BorderRadius.circular(8),
            ),
            if (expanded) ...[
              _detail(Icons.route_rounded,
                  _t(m, 'शिक्षणाचा मार्ग', 'Education path'), info.path.of(m)),
              _detail(Icons.work_outline_rounded,
                  _t(m, 'करिअर क्षेत्रे', 'Career fields'), info.careers.of(m)),
              _detail(
                  Icons.edit_note_rounded,
                  _t(m, 'संबंधित परीक्षा / प्रवेश',
                      'Related exams / admission'),
                  info.exams.of(m)),
            ],
          ],
        ),
      ),
    );
  }
}
