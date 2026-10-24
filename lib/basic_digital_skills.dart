import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Medium-aware text: Marathi (pure), Semi-English (English / Marathi), English.
String _t(String medium, String mr, String en) => switch (medium) {
      'Marathi' => mr,
      'Semi-English' => '$en / $mr',
      _ => en,
    };

const _basicColor = Color(0xFFE29A30);
const _digitalColor = Color(0xFF3B7DD8);

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

/// A Marathi / English text pair.
class _L {
  const _L(this.mr, this.en);
  final String mr;
  final String en;
  String of(String medium) => _t(medium, mr, en);
}

class _Question {
  const _Question(this.question, this.options, this.correct, this.why);
  final _L question;
  final List<_L> options;
  final int correct;
  final _L why;
}

/// Reusable instant-feedback MCQ quiz.
class _QuizPage extends StatefulWidget {
  const _QuizPage({
    required this.medium,
    required this.title,
    required this.color,
    required this.questions,
  });

  final String medium;
  final String title;
  final Color color;
  final List<_Question> questions;

  @override
  State<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<_QuizPage> {
  int _index = 0;
  int _score = 0;
  int? _picked;

  void _pick(int option) {
    if (_picked != null) return;
    setState(() {
      _picked = option;
      if (option == widget.questions[_index].correct) _score++;
    });
  }

  void _next() => setState(() {
        _index++;
        _picked = null;
      });

  void _restart() => setState(() {
        _index = 0;
        _score = 0;
        _picked = null;
      });

  @override
  Widget build(BuildContext context) {
    final m = widget.medium;
    final total = widget.questions.length;
    if (_index >= total) {
      return _scaffold(widget.title, widget.color, [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.emoji_events_rounded, size: 56, color: widget.color),
                const SizedBox(height: 12),
                Text(
                  _t(m, 'तुमचा गुण: $_score / $total',
                      'Your score: $_score / $total'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _score == total
                      ? _t(m, 'उत्कृष्ट! सर्व उत्तरे बरोबर.',
                          'Excellent! All answers correct.')
                      : _t(m, 'छान प्रयत्न! पुन्हा सराव करा.',
                          'Good effort! Practise again.'),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(_t(m, 'पुन्हा खेळा', 'Try again')),
                ),
              ],
            ),
          ),
        ),
      ]);
    }
    final q = widget.questions[_index];
    return _scaffold(widget.title, widget.color, [
      LinearProgressIndicator(value: (_index + 1) / total),
      const SizedBox(height: 8),
      Text(_t(m, 'प्रश्न ${_index + 1} / $total',
          'Question ${_index + 1} / $total')),
      const SizedBox(height: 12),
      Text(q.question.of(m),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      for (var i = 0; i < q.options.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(14),
              backgroundColor: _picked == null
                  ? null
                  : i == q.correct
                      ? Colors.green.withValues(alpha: .15)
                      : i == _picked
                          ? Colors.red.withValues(alpha: .15)
                          : null,
            ),
            onPressed: () => _pick(i),
            child: Text(q.options[i].of(m)),
          ),
        ),
      if (_picked != null) ...[
        Card(
          color: widget.color.withValues(alpha: .1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '${_picked == q.correct ? _t(m, 'बरोबर! ', 'Correct! ') : _t(m, 'चुकीचे. ', 'Not quite. ')}'
              '${q.why.of(m)}',
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _next,
          child: Text(_index == total - 1
              ? _t(m, 'निकाल पहा', 'See result')
              : _t(m, 'पुढील प्रश्न', 'Next question')),
        ),
      ],
    ]);
  }
}

// ───────────────────────── Module 1 ─────────────────────────

class BasicSkillsPage extends StatelessWidget {
  const BasicSkillsPage({super.key, required this.medium});
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      _t(medium, 'मूलभूत आणि शैक्षणिक कौशल्ये', 'Basic & Academic Skills'),
      _basicColor,
      [
        _Entry(
          icon: Icons.menu_book_rounded,
          color: _basicColor,
          title: _t(medium, 'वाचन साहित्य आणि प्रश्नमंजुषा',
              'Reading & Comprehension Quiz'),
          subtitle: _t(medium, 'धडानुसार वाचन आणि झटपट बहुपर्यायी प्रश्न',
              'Chapter-wise reading and instant MCQs'),
          onTap: () => _open(context, _ReadingListPage(medium: medium)),
        ),
        _Entry(
          icon: Icons.translate_rounded,
          color: const Color(0xFF178C78),
          title: _t(medium, 'शब्दकोश आणि उच्चार', 'Dictionary & Pronunciation'),
          subtitle: _t(medium, 'शब्द शोधा आणि उच्चार ऐका',
              'Look up words and hear them spoken'),
          onTap: () => _open(context, _DictionaryPage(medium: medium)),
        ),
      ],
    );
  }
}

class _Chapter {
  const _Chapter(this.title, this.text, this.questions);
  final _L title;
  final _L text;
  final List<_Question> questions;
}

const _chapters = [
  _Chapter(
    _L('माझी शाळा', 'My School'),
    _L(
      'आमची शाळा गावाच्या मध्यभागी आहे. रोज सकाळी सात वाजता प्रार्थना होते. '
          'शाळेच्या आवारात मोठे वडाचे झाड आहे. मधल्या सुट्टीत आम्ही त्याच्या सावलीत खेळतो. '
          'ग्रंथालयातून रोज एक पुस्तक वाचण्याचा आमचा नियम आहे.',
      'Our school is in the middle of the village. Prayer is held at seven '
          'every morning. There is a big banyan tree in the school yard, and we '
          'play in its shade during recess. We follow a rule of reading one '
          'library book every day.',
    ),
    [
      _Question(
        _L('शाळेत प्रार्थना किती वाजता होते?', 'When is the prayer held?'),
        [
          _L('सकाळी सात वाजता', 'At seven in the morning'),
          _L('सकाळी दहा वाजता', 'At ten in the morning'),
          _L('दुपारी बारा वाजता', 'At noon'),
        ],
        0,
        _L('उतारा: रोज सकाळी सात वाजता प्रार्थना.',
            'The passage says prayer is at seven every morning.'),
      ),
      _Question(
        _L('मधल्या सुट्टीत मुले कुठे खेळतात?',
            'Where do the children play during recess?'),
        [
          _L('ग्रंथालयात', 'In the library'),
          _L('वडाच्या झाडाखाली', 'Under the banyan tree'),
          _L('वर्गात', 'In the classroom'),
        ],
        1,
        _L('ते वडाच्या सावलीत खेळतात.', 'They play in the banyan\'s shade.'),
      ),
      _Question(
        _L('रोज किती पुस्तक वाचण्याचा नियम आहे?',
            'How many books is the daily reading rule?'),
        [
          _L('एक', 'One'),
          _L('दोन', 'Two'),
          _L('पाच', 'Five'),
        ],
        0,
        _L('नियम: रोज एक पुस्तक.', 'The rule is one book every day.'),
      ),
    ],
  ),
  _Chapter(
    _L('पाणी वाचवा', 'Save Water'),
    _L(
      'पाणी हे जीवन आहे. महाराष्ट्रातील अनेक गावांना उन्हाळ्यात पाण्याची टंचाई जाणवते. '
          'नळ वापरून झाल्यावर बंद करावा. पावसाचे पाणी साठवल्यास भूजल पातळी वाढते. '
          'लहान सवयींमधून आपण खूप पाणी वाचवू शकतो.',
      'Water is life. Many villages in Maharashtra face water shortage in '
          'summer. Turn off the tap after use. Storing rainwater raises the '
          'groundwater level. We can save a lot of water through small habits.',
    ),
    [
      _Question(
        _L('पाण्याची टंचाई केव्हा जाणवते?', 'When is water shortage felt?'),
        [
          _L('पावसाळ्यात', 'In the monsoon'),
          _L('उन्हाळ्यात', 'In summer'),
          _L('हिवाळ्यात', 'In winter'),
        ],
        1,
        _L('उन्हाळ्यात अनेक गावांना टंचाई असते.',
            'Many villages face shortage in summer.'),
      ),
      _Question(
        _L('पावसाचे पाणी साठवल्याने काय होते?',
            'What happens when rainwater is stored?'),
        [
          _L('भूजल पातळी वाढते', 'Groundwater level rises'),
          _L('नळ खराब होतो', 'Taps break'),
          _L('काहीच बदल नाही', 'Nothing changes'),
        ],
        0,
        _L('साठवलेले पाणी भूजल वाढवते.',
            'Stored rainwater raises groundwater.'),
      ),
      _Question(
        _L('या उताऱ्याचा मुख्य संदेश कोणता?',
            'What is the main message of the passage?'),
        [
          _L('पाणी जपून वापरा', 'Use water carefully'),
          _L('उन्हाळा कठीण असतो', 'Summer is hard'),
          _L('नळ विकत घ्या', 'Buy taps'),
        ],
        0,
        _L('संपूर्ण उतारा पाणी बचतीबद्दल आहे.',
            'The whole passage is about saving water.'),
      ),
    ],
  ),
  _Chapter(
    _L('छत्रपती शिवाजी महाराज', 'Chhatrapati Shivaji Maharaj'),
    _L(
      'छत्रपती शिवाजी महाराजांचा जन्म १९ फेब्रुवारी १६३० रोजी शिवनेरी किल्ल्यावर झाला. '
          'त्यांनी स्वराज्याची स्थापना केली. १६७४ मध्ये रायगडावर त्यांचा राज्याभिषेक झाला. '
          'ते उत्तम प्रशासक आणि दूरदृष्टीचे नेते होते.',
      'Chhatrapati Shivaji Maharaj was born on 19 February 1630 at Shivneri '
          'Fort. He founded the Swarajya. He was crowned at Raigad in 1674. He '
          'was an excellent administrator and a far-sighted leader.',
    ),
    [
      _Question(
        _L('शिवाजी महाराजांचा जन्म कोणत्या किल्ल्यावर झाला?',
            'At which fort was Shivaji Maharaj born?'),
        [
          _L('रायगड', 'Raigad'),
          _L('शिवनेरी', 'Shivneri'),
          _L('सिंहगड', 'Sinhagad'),
        ],
        1,
        _L('जन्म शिवनेरी किल्ल्यावर.', 'He was born at Shivneri.'),
      ),
      _Question(
        _L('राज्याभिषेक कोणत्या वर्षी झाला?',
            'In which year was the coronation?'),
        [
          _L('१६३०', '1630'),
          _L('१६७४', '1674'),
          _L('१७०७', '1707'),
        ],
        1,
        _L('राज्याभिषेक १६७४ मध्ये रायगडावर.',
            'The coronation was in 1674 at Raigad.'),
      ),
    ],
  ),
];

class _ReadingListPage extends StatelessWidget {
  const _ReadingListPage({required this.medium});
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      _t(medium, 'वाचन साहित्य', 'Reading Material'),
      _basicColor,
      [
        for (var i = 0; i < _chapters.length; i++)
          _Entry(
            icon: Icons.article_rounded,
            color: _basicColor,
            title: _t(medium, 'धडा ${i + 1}: ${_chapters[i].title.mr}',
                'Chapter ${i + 1}: ${_chapters[i].title.en}'),
            subtitle: _t(medium, '${_chapters[i].questions.length} प्रश्न',
                '${_chapters[i].questions.length} questions'),
            onTap: () => _open(
                context, _ReadingPage(medium: medium, chapter: _chapters[i])),
          ),
      ],
    );
  }
}

class _ReadingPage extends StatefulWidget {
  const _ReadingPage({required this.medium, required this.chapter});
  final String medium;
  final _Chapter chapter;

  @override
  State<_ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<_ReadingPage> {
  double _fontSize = 16;

  @override
  Widget build(BuildContext context) {
    final m = widget.medium;
    final c = widget.chapter;
    return _scaffold(c.title.of(m), _basicColor, [
      Row(
        children: [
          Text(_t(m, 'अक्षरांचा आकार', 'Text size')),
          Expanded(
            child: Slider(
              value: _fontSize,
              min: 14,
              max: 26,
              divisions: 6,
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
        ],
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: m == 'Semi-English'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.text.en,
                        style: TextStyle(fontSize: _fontSize, height: 1.6)),
                    const Divider(height: 24),
                    Text(c.text.mr,
                        style: TextStyle(fontSize: _fontSize, height: 1.6)),
                  ],
                )
              : Text(m == 'Marathi' ? c.text.mr : c.text.en,
                  style: TextStyle(fontSize: _fontSize, height: 1.6)),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        icon: const Icon(Icons.quiz_rounded),
        label:
            Text(_t(m, 'आकलन प्रश्नमंजुषा सोडवा', 'Take comprehension quiz')),
        onPressed: () => _open(
          context,
          _QuizPage(
            medium: m,
            title: c.title.of(m),
            color: _basicColor,
            questions: c.questions,
          ),
        ),
      ),
    ]);
  }
}

class _Word {
  const _Word(this.en, this.mr, this.meaningEn, this.example);
  final String en;
  final String mr;
  final String meaningEn;
  final String example;
}

const _words = [
  _Word('Library', 'ग्रंथालय', 'A place where books are kept for reading.',
      'I borrow a book from the library.'),
  _Word('Water', 'पाणी', 'A clear liquid we drink.', 'Drink clean water.'),
  _Word('Teacher', 'शिक्षक', 'A person who teaches students.',
      'Our teacher explains the lesson.'),
  _Word('Village', 'गाव', 'A small settlement in the countryside.',
      'My village has a river.'),
  _Word('Farmer', 'शेतकरी', 'A person who grows crops.',
      'The farmer sows seeds in June.'),
  _Word('Friend', 'मित्र', 'A person you like and trust.',
      'She is my best friend.'),
  _Word('Courage', 'धैर्य', 'The ability to face fear.',
      'He showed courage in danger.'),
  _Word('Education', 'शिक्षण', 'The process of learning in school.',
      'Education opens many doors.'),
  _Word('Honest', 'प्रामाणिक', 'Telling the truth; not cheating.',
      'An honest student never copies.'),
  _Word('Environment', 'पर्यावरण', 'The natural world around us.',
      'Protect the environment.'),
  _Word('Festival', 'सण', 'A special day of celebration.',
      'Diwali is a festival of lights.'),
  _Word('Mountain', 'डोंगर', 'A very high natural hill.',
      'We climbed the mountain.'),
  _Word(
      'Kind', 'दयाळू', 'Caring and helpful to others.', 'Be kind to animals.'),
  _Word('Practice', 'सराव', 'Repeated exercise to improve a skill.',
      'Daily practice makes you perfect.'),
  _Word('Safe', 'सुरक्षित', 'Not in danger.', 'Keep your password safe.'),
];

class _DictionaryPage extends StatefulWidget {
  const _DictionaryPage({required this.medium});
  final String medium;

  @override
  State<_DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<_DictionaryPage> {
  final _controller = TextEditingController();
  FlutterTts? _tts;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _tts?.stop();
    super.dispose();
  }

  Future<void> _speak(String text, String language) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final tts = _tts ??= FlutterTts();
      await tts.setLanguage(language);
      await tts.setSpeechRate(0.4);
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(_t(widget.medium, 'या उपकरणावर ऑडिओ उपलब्ध नाही.',
            'Audio is not available on this device.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medium;
    final q = _query.trim().toLowerCase();
    final results = _words
        .where((w) =>
            q.isEmpty || w.en.toLowerCase().contains(q) || w.mr.contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_t(m, 'शब्दकोश', 'Dictionary'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF178C78).withValues(alpha: .12),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBar(
                controller: _controller,
                hintText: _t(m, 'इंग्रजी किंवा मराठी शब्द शोधा',
                    'Search an English or Marathi word'),
                leading: const Icon(Icons.search_rounded),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(_t(
                          m, 'शब्द सापडला नाही.', 'No matching word found.')))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final w = results[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('${w.en}  •  ${w.mr}',
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                    IconButton.filledTonal(
                                      tooltip: _t(m, 'इंग्रजी उच्चार ऐका',
                                          'Hear English'),
                                      icon: const Icon(Icons.volume_up_rounded),
                                      onPressed: () => _speak(w.en, 'en-IN'),
                                    ),
                                    IconButton.filledTonal(
                                      tooltip: _t(m, 'मराठी उच्चार ऐका',
                                          'Hear Marathi'),
                                      icon: const Icon(Icons.record_voice_over),
                                      onPressed: () => _speak(w.mr, 'mr-IN'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(w.meaningEn),
                                const SizedBox(height: 4),
                                Text('“${w.example}”',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Module 2 ─────────────────────────

class DigitalSkillsPage extends StatelessWidget {
  const DigitalSkillsPage({super.key, required this.medium});
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _scaffold(
      _t(medium, 'डिजिटल आणि तंत्रज्ञान कौशल्ये', 'Digital & Tech Skills'),
      _digitalColor,
      [
        _Entry(
          icon: Icons.extension_rounded,
          color: const Color(0xFF5865C8),
          title: _t(medium, 'ब्लॉक कोडिंग भुलभुलैया', 'Block Coding Maze'),
          subtitle: _t(medium, 'ब्लॉक जोडून रोबोटला वाट दाखवा',
              'Snap blocks to guide the robot'),
          onTap: () => _open(context, _MazePage(medium: medium)),
        ),
        _Entry(
          icon: Icons.shield_rounded,
          color: const Color(0xFFD9534F),
          title: _t(medium, 'सायबर सुरक्षा प्रश्नमंजुषा', 'Cyber Safety Quiz'),
          subtitle: _t(
              medium, 'ऑनलाइन सुरक्षित राहण्याचे प्रश्न', 'Stay safe online'),
          onTap: () => _open(
            context,
            _QuizPage(
              medium: medium,
              title: _t(medium, 'सायबर सुरक्षा', 'Cyber Safety'),
              color: const Color(0xFFD9534F),
              questions: _cyberQuestions,
            ),
          ),
        ),
        _Entry(
          icon: Icons.password_rounded,
          color: const Color(0xFF178C78),
          title: _t(medium, 'पासवर्ड ताकद तपासक', 'Password Strength Checker'),
          subtitle: _t(medium, 'तुमचा पासवर्ड साठवला जात नाही',
              'Your password is never stored'),
          onTap: () => _open(context, _PasswordPage(medium: medium)),
        ),
      ],
    );
  }
}

const _cyberQuestions = [
  _Question(
    _L('अनोळखी व्यक्तीने तुमचा ओटीपी मागितला. तुम्ही काय कराल?',
        'A stranger asks for your OTP. What do you do?'),
    [
      _L('ओटीपी देईन', 'Share the OTP'),
      _L('कधीही देणार नाही आणि मोठ्यांना सांगेन',
          'Never share it and tell an elder'),
      _L('अर्धा ओटीपी सांगेन', 'Share half of it'),
    ],
    1,
    _L('ओटीपी हा गुप्त असतो; तो कोणालाही देऊ नका.',
        'An OTP is secret; never give it to anyone.'),
  ),
  _Question(
    _L('मजबूत पासवर्ड कोणता?', 'Which is the strongest password?'),
    [
      _L('12345678', '12345678'),
      _L('माझेनाव', 'myname'),
      _L('T!ger#Run9&Hill', 'T!ger#Run9&Hill'),
    ],
    2,
    _L('लांब आणि अक्षरे, अंक, चिन्हे यांचे मिश्रण सुरक्षित.',
        'Long and mixed with letters, numbers and symbols is safest.'),
  ),
  _Question(
    _L('“तुम्ही बक्षीस जिंकले! येथे क्लिक करा” असा संदेश आला. हे काय आहे?',
        'You get "You won a prize! Click here". What is it?'),
    [
      _L('खरे बक्षीस', 'A real prize'),
      _L('फिशिंग (फसवणूक)', 'Phishing (a scam)'),
      _L('शाळेची सूचना', 'A school notice'),
    ],
    1,
    _L('अशा दुव्यांवर क्लिक करू नका.', 'Do not click such links.'),
  ),
  _Question(
    _L('ऑनलाइन कोणती माहिती उघड करू नये?', 'What should you not share online?'),
    [
      _L('घरचा पत्ता आणि पासवर्ड', 'Home address and passwords'),
      _L('आवडता रंग', 'Favourite colour'),
      _L('आवडता खेळ', 'Favourite game'),
    ],
    0,
    _L('वैयक्तिक माहिती खासगी ठेवा.', 'Keep personal details private.'),
  ),
  _Question(
    _L('ऑनलाइन कोणी त्रास दिल्यास काय करावे?',
        'What if someone bullies you online?'),
    [
      _L('गप्प राहून सहन करणे', 'Suffer silently'),
      _L('स्क्रीनशॉट घेऊन ब्लॉक करा आणि मोठ्यांना सांगा',
          'Screenshot, block and tell a trusted adult'),
      _L('बदला घेणे', 'Take revenge'),
    ],
    1,
    _L('पुरावा ठेवा, ब्लॉक करा, मदत घ्या. मदतीसाठी चाइल्डलाइन १०९८.',
        'Keep proof, block, get help. Childline: 1098.'),
  ),
];

class _MazeLevel {
  const _MazeLevel(this.rows);
  // S = start (facing east), G = goal, # = wall, . = open
  final List<String> rows;
}

const _mazeLevels = [
  _MazeLevel(['S....', '####.', '....G']),
  _MazeLevel(['S...#', '###.#', 'G...#']),
  _MazeLevel(['S.###', '#.###', '#...#', '###.#', '###.G']),
];

enum _Block { forward, left, right }

class _MazePage extends StatefulWidget {
  const _MazePage({required this.medium});
  final String medium;

  @override
  State<_MazePage> createState() => _MazePageState();
}

class _MazePageState extends State<_MazePage> {
  static const _maxBlocks = 20;
  static const _dr = [0, 1, 0, -1];
  static const _dc = [1, 0, -1, 0];

  int _level = 0;
  final List<_Block> _program = [];
  bool _running = false;
  bool _disposed = false;
  int _row = 0;
  int _col = 0;
  int _dir = 0;
  int? _activeBlock;
  String? _result;
  bool _won = false;

  List<String> get _grid => _mazeLevels[_level].rows;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _reset() {
    for (var r = 0; r < _grid.length; r++) {
      final c = _grid[r].indexOf('S');
      if (c >= 0) {
        _row = r;
        _col = c;
      }
    }
    _dir = 0;
    _activeBlock = null;
    _result = null;
    _won = false;
  }

  void _add(_Block b) {
    if (_running || _program.length >= _maxBlocks) return;
    setState(() {
      _program.add(b);
      _reset();
    });
  }

  Future<void> _run() async {
    if (_running || _program.isEmpty) return;
    setState(() {
      _reset();
      _running = true;
    });
    final m = widget.medium;
    for (var i = 0; i < _program.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (_disposed) return;
      setState(() => _activeBlock = i);
      switch (_program[i]) {
        case _Block.left:
          setState(() => _dir = (_dir + 3) % 4);
        case _Block.right:
          setState(() => _dir = (_dir + 1) % 4);
        case _Block.forward:
          final nr = _row + _dr[_dir];
          final nc = _col + _dc[_dir];
          final inside =
              nr >= 0 && nr < _grid.length && nc >= 0 && nc < _grid[nr].length;
          if (!inside || _grid[nr][nc] == '#') {
            setState(() {
              _running = false;
              _result = _t(m, 'रोबोट भिंतीवर आदळला! कार्यक्रम तपासा.',
                  'The robot hit a wall! Check your program.');
            });
            return;
          }
          setState(() {
            _row = nr;
            _col = nc;
          });
      }
    }
    final reached = _grid[_row][_col] == 'G';
    if (_disposed) return;
    setState(() {
      _running = false;
      _won = reached;
      _result = reached
          ? _t(m, 'शाबास! रोबोट ध्येयापर्यंत पोहोचला.',
              'Well done! The robot reached the goal.')
          : _t(m, 'रोबोट ध्येयापर्यंत पोहोचला नाही. पुन्हा प्रयत्न करा.',
              'The robot did not reach the goal. Try again.');
    });
  }

  String _blockLabel(_Block b) {
    final m = widget.medium;
    return switch (b) {
      _Block.forward => _t(m, 'पुढे चाला', 'Move forward'),
      _Block.left => _t(m, 'डावीकडे वळा', 'Turn left'),
      _Block.right => _t(m, 'उजवीकडे वळा', 'Turn right'),
    };
  }

  IconData _blockIcon(_Block b) => switch (b) {
        _Block.forward => Icons.arrow_upward_rounded,
        _Block.left => Icons.turn_left_rounded,
        _Block.right => Icons.turn_right_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final m = widget.medium;
    final scheme = Theme.of(context).colorScheme;
    return _scaffold(
      _t(m, 'ब्लॉक कोडिंग भुलभुलैया', 'Block Coding Maze'),
      const Color(0xFF5865C8),
      [
        Text(_t(m, 'स्तर ${_level + 1} / ${_mazeLevels.length}',
            'Level ${_level + 1} / ${_mazeLevels.length}')),
        const SizedBox(height: 4),
        Text(
          _t(
              m,
              'ब्लॉक जोडून रोबोटला ⭐ पर्यंत न्या. रोबोट सुरुवातीला उजवीकडे पाहतो.',
              'Snap blocks to take the robot to the ⭐. It starts facing right.'),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (var r = 0; r < _grid.length; r++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var c = 0; c < _grid[r].length; c++)
                Container(
                  width: 52,
                  height: 52,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _grid[r][c] == '#'
                        ? scheme.outline
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: (r == _row && c == _col)
                      ? Transform.rotate(
                          angle: _dir * 1.5708,
                          child: const Icon(Icons.smart_toy_rounded,
                              size: 32, color: Color(0xFF5865C8)),
                        )
                      : _grid[r][c] == 'G'
                          ? const Icon(Icons.star_rounded,
                              size: 30, color: Color(0xFFE29A30))
                          : null,
                ),
            ],
          ),
        _heading(_t(m, 'ब्लॉक', 'Blocks')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in _Block.values)
              ActionChip(
                avatar: Icon(_blockIcon(b), size: 18),
                label: Text(_blockLabel(b)),
                onPressed: _running ? null : () => _add(b),
              ),
          ],
        ),
        _heading(_t(m, 'तुमचा कार्यक्रम (${_program.length}/$_maxBlocks)',
            'Your program (${_program.length}/$_maxBlocks)')),
        if (_program.isEmpty)
          Text(_t(m, 'वरील ब्लॉक निवडा.', 'Pick blocks above.'))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _program.length; i++)
                Chip(
                  avatar: Icon(_blockIcon(_program[i]), size: 16),
                  label: Text('${i + 1}'),
                  backgroundColor:
                      _activeBlock == i ? scheme.primaryContainer : null,
                ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _running || _program.isEmpty ? null : _run,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_t(m, 'चालवा', 'Run')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: _t(m, 'शेवटचा ब्लॉक काढा', 'Undo last block'),
              onPressed: _running || _program.isEmpty
                  ? null
                  : () => setState(() {
                        _program.removeLast();
                        _reset();
                      }),
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton.filledTonal(
              tooltip: _t(m, 'पुसून टाका', 'Clear'),
              onPressed: _running
                  ? null
                  : () => setState(() {
                        _program.clear();
                        _reset();
                      }),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              color:
                  (_won ? Colors.green : Colors.orange).withValues(alpha: .15),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_result!),
              ),
            ),
          ),
        if (_won && _level < _mazeLevels.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FilledButton(
              onPressed: () => setState(() {
                _level++;
                _program.clear();
                _reset();
              }),
              child: Text(_t(m, 'पुढील स्तर', 'Next level')),
            ),
          ),
      ],
    );
  }
}

class _PasswordPage extends StatefulWidget {
  const _PasswordPage({required this.medium});
  final String medium;

  @override
  State<_PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<_PasswordPage> {
  static const _common = {
    'password',
    'password1',
    '12345678',
    '123456789',
    'qwerty123',
    'abcd1234',
    'iloveyou',
    'admin123',
    'india123',
  };

  final _controller = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Returns (score 0-5, list of missing tips).
  (int, List<_L>) _evaluate(String p) {
    final tips = <_L>[];
    var score = 0;
    if (p.length >= 8) {
      score++;
    } else {
      tips.add(const _L('किमान ८ अक्षरे वापरा.', 'Use at least 8 characters.'));
    }
    if (p.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) {
      score++;
    } else {
      tips.add(const _L('लहान आणि मोठी इंग्रजी अक्षरे मिसळा.',
          'Mix lowercase and uppercase letters.'));
    }
    if (RegExp(r'\d').hasMatch(p)) {
      score++;
    } else {
      tips.add(const _L('अंक जोडा.', 'Add numbers.'));
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) {
      score++;
    } else {
      tips.add(
          const _L('चिन्हे जोडा (! @ # ...).', 'Add symbols (! @ # ...).'));
    }
    if (_common.contains(p.toLowerCase()) || RegExp(r'^(.)\1+$').hasMatch(p)) {
      score = 0;
      tips.insert(
          0,
          const _L('हा पासवर्ड खूप सामान्य आहे. वेगळा निवडा.',
              'This password is very common. Choose another.'));
    }
    return (score, tips);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.medium;
    final p = _controller.text;
    final (score, tips) = _evaluate(p);
    final labels = [
      _t(m, 'खूप कमकुवत', 'Very weak'),
      _t(m, 'कमकुवत', 'Weak'),
      _t(m, 'ठीक', 'Fair'),
      _t(m, 'चांगला', 'Good'),
      _t(m, 'मजबूत', 'Strong'),
      _t(m, 'खूप मजबूत', 'Very strong'),
    ];
    final colors = [
      Colors.red,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.green,
    ];
    return _scaffold(
      _t(m, 'पासवर्ड ताकद तपासक', 'Password Strength Checker'),
      const Color(0xFF178C78),
      [
        TextField(
          controller: _controller,
          obscureText: _hidden,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _t(m, 'पासवर्ड टाका', 'Enter a password'),
            suffixIcon: IconButton(
              icon: Icon(_hidden
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(
          _t(m, 'हा पासवर्ड फक्त या स्क्रीनवर तपासला जातो; साठवला जात नाही.',
              'Checked only on this screen; never saved or sent.'),
          style: const TextStyle(fontSize: 12),
        ),
        if (p.isNotEmpty) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: score / 5,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            color: colors[score],
          ),
          const SizedBox(height: 8),
          Text(labels[score],
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors[score])),
          if (tips.isNotEmpty) _heading(_t(m, 'सुधारणा सूचना', 'Tips')),
          for (final tip in tips)
            ListTile(
              dense: true,
              leading: const Icon(Icons.lightbulb_outline_rounded),
              title: Text(tip.of(m)),
            ),
        ],
      ],
    );
  }
}
