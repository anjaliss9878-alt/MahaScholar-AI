import 'dart:async';
import 'dart:io';
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

/// Student-safe message for any AI failure. Raw errors (which can contain
/// project ids or API details) are only logged, never shown.
String describeTutorError(Object error, String medium) {
  String m(String mr, String en) => switch (medium) {
        'Marathi' => mr,
        'English' => en,
        _ => '$en / $mr',
      };
  if (error is TimeoutException) {
    return m('उत्तराला वेळ लागत आहे. पुन्हा प्रयत्न करा.',
        'The answer is taking too long. Please try again.');
  }
  if (error is SocketException || error is HandshakeException) {
    return m('इंटरनेट उपलब्ध नाही. कनेक्शन तपासा.',
        'No internet. Check your connection.');
  }
  if (error is QuotaExceeded) {
    return m('आज खूप प्रश्न विचारले गेले. थोड्या वेळाने पुन्हा प्रयत्न करा.',
        'The AI is busy right now. Please try again in a little while.');
  }
  if (error is UnsupportedUserLocation) {
    return m('एआय मदत तुमच्या ठिकाणी उपलब्ध नाही.',
        'AI help is not available in your location.');
  }
  if (error is InvalidApiKey ||
      error is ServiceApiNotEnabled ||
      error is FirebaseAISdkException) {
    return m('एआय मदत सध्या उपलब्ध नाही. शिक्षकांना कळवा.',
        'AI help is not available right now. Please tell your teacher.');
  }
  if (error is ServerException) {
    final text = error.message.toLowerCase();
    if (text.contains('429') || text.contains('quota')) {
      return m('एआय व्यस्त आहे. थोड्या वेळाने प्रयत्न करा.',
          'The AI is busy right now. Please try again in a little while.');
    }
    return m('सर्व्हरमध्ये अडचण आली. पुन्हा प्रयत्न करा.',
        'The AI server had a problem. Please try again.');
  }
  if (error is StateError) {
    return m('उत्तर मिळाले नाही. प्रश्न वेगळ्या शब्दांत विचारा.',
        'No answer came back. Try asking in different words.');
  }
  return m('काहीतरी चुकले. पुन्हा प्रयत्न करा.',
      'Something went wrong. Please try again.');
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
      // Stream the reply so the answer appears as it is generated.
      final buffer = StringBuffer();
      var reply = -1;
      await for (final chunk in _chat!
          .sendMessageStream(Content.text(question))
          .timeout(const Duration(seconds: 45))) {
        final part = chunk.text;
        if (part == null || part.isEmpty || !mounted) continue;
        buffer.write(part);
        setState(() {
          final message =
              _TutorMessage(text: buffer.toString(), fromStudent: false);
          if (reply == -1) {
            _messages.add(message);
            reply = _messages.length - 1;
          } else {
            _messages[reply] = message;
          }
        });
        _scrollToEnd();
      }
      if (buffer.toString().trim().isEmpty) {
        throw StateError('Empty answer');
      }
    } catch (error) {
      debugPrint('Gemini tutor request failed: $error');
      // A failed turn can leave the chat history inconsistent; start fresh.
      _chat = null;
      if (mounted) _showMessage(describeTutorError(error, widget.medium));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
