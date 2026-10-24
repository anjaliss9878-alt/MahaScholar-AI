import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

GenerativeModel _tutorModel({
  required int standard,
  required String medium,
}) {
  final languageInstruction = switch (medium) {
    'Marathi' => 'Reply in Marathi.',
    'English' => 'Reply in English.',
    _ =>
      'Reply in the same language as the student. Use simple English and Marathi as helpful.',
  };
  return FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    systemInstruction: Content.system(
      'You are MahaScholar AI, a kind and age-appropriate Maharashtra State '
      'Board tutor for class $standard. $languageInstruction Explain concepts '
      'step by step, ask guiding questions when useful, and never shame the '
      'student. Keep answers focused and safe for children.',
    ),
    generationConfig: GenerationConfig(
      maxOutputTokens: 1200,
      temperature: 0.35,
    ),
  );
}

Future<String> solveHomeworkWithGemini({
  required int standard,
  required String medium,
  required String prompt,
  required Uint8List imageBytes,
  required String mimeType,
}) async {
  if (imageBytes.length > 8 * 1024 * 1024) {
    throw ArgumentError('Please choose an image smaller than 8 MB.');
  }
  final model = _tutorModel(standard: standard, medium: medium);
  final response = await model.generateContent([
    Content.multi([
      TextPart(
        'Help solve this class $standard homework question. '
        'Explain the method step by step, show the working, and finish with '
        'a short final answer. The student added this context: '
        '${prompt.trim().isEmpty ? 'Please read the question in the image.' : prompt.trim()}',
      ),
      InlineDataPart(mimeType, imageBytes),
    ]),
  ]);
  final answer = response.text?.trim();
  if (answer == null || answer.isEmpty) {
    throw StateError('Gemini did not return an answer. Please try again.');
  }
  return answer;
}

class AiTutorChat extends StatefulWidget {
  const AiTutorChat({
    super.key,
    required this.standard,
    required this.medium,
    required this.firebaseReady,
  });

  final int standard;
  final String medium;
  final bool firebaseReady;

  @override
  State<AiTutorChat> createState() => _AiTutorChatState();
}

class _TutorMessage {
  const _TutorMessage({required this.text, required this.fromStudent});

  final String text;
  final bool fromStudent;
}

class _AiTutorChatState extends State<AiTutorChat> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final List<_TutorMessage> _messages = [];
  ChatSession? _chat;
  bool _sending = false;

  String _text(String marathi, String english) => switch (widget.medium) {
        'Marathi' => marathi,
        'Semi-English' => '$english / $marathi',
        _ => english,
      };

  Future<void> _send() async {
    final question = _input.text.trim();
    if (question.isEmpty || _sending) return;
    if (!widget.firebaseReady) {
      _showMessage(_text(
        'एआय मदतीसाठी Firebase जोडणी आवश्यक आहे.',
        'Firebase must be configured to use the AI tutor.',
      ));
      return;
    }

    setState(() {
      _sending = true;
      _messages.add(_TutorMessage(text: question, fromStudent: true));
      _input.clear();
    });
    try {
      if (_chat == null || _messages.where((m) => m.fromStudent).length > 10) {
        _chat = _tutorModel(
          standard: widget.standard,
          medium: widget.medium,
        ).startChat();
      }
      final response = await _chat!.sendMessage(Content.text(question));
      final answer = response.text?.trim();
      if (answer == null || answer.isEmpty) {
        throw StateError('Gemini did not return an answer. Please try again.');
      }
      if (!mounted) return;
      setState(() => _messages.add(
            _TutorMessage(text: answer, fromStudent: false),
          ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      debugPrint('Gemini tutor request failed: $error');
      if (mounted) {
        _showMessage(_text(
          'उत्तर मिळाले नाही. Firebase AI Logic सेटिंग्ज आणि इंटरनेट तपासून पुन्हा प्रयत्न करा.',
          'Could not get an answer. Check Firebase AI Logic setup and your connection, then try again.',
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_rounded, color: scheme.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _text('एआय मित्राशी बोला', 'Chat with your AI Buddy'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                'अभ्यासाचा प्रश्न विचारा आणि पायरी-पायरीने समजून घ्या.',
                'Ask a school question and get a step-by-step explanation.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_messages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Align(
                      alignment: message.fromStudent
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: message.fromStudent
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SelectableText(message.text),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: _text('तुमचा प्रश्न लिहा…', 'Type your question…'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _text('पाठवा', 'Send'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text(
                'एआयचे उत्तर शिक्षक किंवा पाठ्यपुस्तकासोबत तपासा.',
                'Check important answers with a teacher or textbook.',
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
