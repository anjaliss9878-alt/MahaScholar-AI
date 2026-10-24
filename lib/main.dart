import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'basic_digital_skills.dart';
import 'admin_dashboard.dart';
import 'student_portal.dart';
import 'career_test.dart';
import 'unified_login.dart';
import 'life_skills_modules.dart';
import 'ai_tutor.dart';
import 'progress_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

String? _firebaseStartupError;
bool _firebaseReady = false;

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _installGlobalErrorHandling();
    await _bootstrap();
    runApp(const MahaScholarAiApp());
  }, (error, stack) {
    debugPrint('Unhandled zone error: $error\n$stack');
  });
}

void _installGlobalErrorHandling() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error\n$stack');
    return true;
  };
  // Replace the red error screen with a friendly Material 3 fallback.
  ErrorWidget.builder = (details) => _ErrorFallback(details: details);
}

Future<void> _bootstrap() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    _firebaseReady = true;
  } catch (error) {
    // Unsupported platform (e.g. Linux) or a bad configuration: the login
    // screen shows the reason instead of the app crashing at startup.
    _firebaseStartupError = 'Firebase प्रारंभ करता आले नाही: $error';
    return;
  }
  try {
    // Local persistence keeps content readable when the network drops.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024,
    );
  } catch (error) {
    debugPrint('Firestore settings skipped: $error');
  }
}

/// Shown in place of any widget that throws during build.
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 44, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                'काहीतरी चुकले / Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'कृपया मागे जाऊन पुन्हा प्रयत्न करा.\nPlease go back and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: scheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _examShortcutsEnglish(String target) {
  if (target == 'Scholarship') {
    return const [
      'Spot the rule between consecutive terms before calculating.',
      'Estimate first, then eliminate impossible options.',
      'Cancel common factors before multiplying fractions.',
    ];
  }
  return const [
    'Look for rotation, reflection, sequence and grouping patterns.',
    'Underline the given values and requested units before choosing an operation.',
    'Read the complete sentence and use context to eliminate options.',
  ];
}

class MahaScholarAiApp extends StatelessWidget {
  const MahaScholarAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'महास्कॉलर एआय',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3659C9),
          surface: const Color(0xFFF7F8FC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9ECF4)),
          ),
        ),
      ),
      home: const _RoleGate(),
    );
  }
}

class _LearningResource {
  const _LearningResource({
    required this.title,
    required this.fileName,
    required this.standard,
    required this.medium,
    required this.subject,
    this.target = 'Classroom',
    this.id = '',
    this.downloadUrl,
    this.storagePath,
    this.uploadBytes,
  });

  final String id;
  final String title;
  final String fileName;
  final int standard;
  final String medium;
  final String subject;
  final String target;
  final String? downloadUrl;
  final String? storagePath;
  final Uint8List? uploadBytes;

  factory _LearningResource.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return _LearningResource(
      id: document.id,
      title: data['title'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      standard: (data['standard'] as num?)?.toInt() ?? 1,
      medium: data['medium'] as String? ?? 'Marathi',
      subject: data['subject'] as String? ?? '',
      target: data['target'] as String? ?? 'Classroom',
      downloadUrl: data['downloadUrl'] as String?,
      storagePath: data['storagePath'] as String?,
    );
  }
}

class _TeacherVideo {
  const _TeacherVideo({
    required this.title,
    required this.subject,
    required this.chapter,
    required this.url,
    required this.standard,
    required this.medium,
    this.id = '',
    this.target = 'Classroom',
  });

  final String id;
  final String title;
  final String subject;
  final String chapter;
  final String url;
  final int standard;
  final String medium;
  final String target;

  factory _TeacherVideo.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return _TeacherVideo(
      id: document.id,
      title: data['title'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      chapter: data['chapter'] as String? ?? '',
      url: data['url'] as String? ?? '',
      standard: (data['standard'] as num?)?.toInt() ?? 1,
      medium: data['medium'] as String? ?? 'Marathi',
      target: data['target'] as String? ?? 'Classroom',
    );
  }
}

class _TeacherQuiz {
  const _TeacherQuiz({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.standard,
    required this.medium,
    this.target = 'Classroom',
    this.assessmentType = 'Daily practice',
    this.id = '',
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final int standard;
  final String medium;
  final String target;
  final String assessmentType;

  factory _TeacherQuiz.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return _TeacherQuiz(
      id: document.id,
      question: data['question'] as String? ?? '',
      options: List<String>.from(data['options'] as List? ?? const []),
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
      standard: (data['standard'] as num?)?.toInt() ?? 1,
      medium: data['medium'] as String? ?? 'Marathi',
      target: data['target'] as String? ?? 'Classroom',
      assessmentType: data['assessmentType'] as String? ?? 'Daily practice',
    );
  }
}

const int _contentPageSize = 30;

/// Paginated Firestore feed: the first page is live (real-time), further pages
/// are fetched on demand with `startAfterDocument`. The exposed stream is a
/// broadcast stream, never errors (falls back to the last cached list) and can
/// safely be listened to by many widgets.
class _PagedFeed<T> {
  _PagedFeed({
    required this.query,
    required this.fromDocument,
    this.pageSize = _contentPageSize,
  }) {
    _controller = StreamController<List<T>>.broadcast(
      onListen: _start,
      onCancel: () {
        if (!_controller.hasListener) _stop();
      },
    );
  }

  final Query<Map<String, dynamic>> Function({required bool ordered}) query;
  final T Function(QueryDocumentSnapshot<Map<String, dynamic>>) fromDocument;
  final int pageSize;

  late final StreamController<List<T>> _controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _firstPage = const [];
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _extraPages = [];
  List<T> items = const [];
  bool hasMore = true;
  bool loadingMore = false;
  bool _ordered = true;
  bool _disposed = false;
  Object? lastError;

  Stream<List<T>> get stream => _controller.stream;

  void _start() {
    if (_subscription != null) return;
    _subscription = query(ordered: _ordered).limit(pageSize).snapshots().listen(
      (snapshot) {
        lastError = null;
        _firstPage = snapshot.docs;
        if (_extraPages.isEmpty) hasMore = snapshot.docs.length >= pageSize;
        _emit();
      },
      onError: (Object error) {
        // A missing composite index must not break the app: retry unordered.
        if (_ordered &&
            error is FirebaseException &&
            error.code == 'failed-precondition') {
          _ordered = false;
          _stop();
          _start();
          return;
        }
        lastError = error;
        _emitSafe(items);
      },
      cancelOnError: false,
    );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _emit() {
    final seen = <String>{};
    final docs = [..._firstPage, ..._extraPages]
        .where((doc) => seen.add(doc.id))
        .toList();
    if (!_ordered) {
      docs.sort((a, b) =>
          _LearningContentStore._compareCreatedAt(a.data(), b.data()));
    }
    items = docs.map(fromDocument).toList();
    _emitSafe(items);
  }

  void _emitSafe(List<T> value) {
    if (!_disposed && !_controller.isClosed) _controller.add(value);
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore || _disposed) return;
    final last = _extraPages.isNotEmpty
        ? _extraPages.last
        : (_firstPage.isNotEmpty ? _firstPage.last : null);
    if (last == null) return;
    loadingMore = true;
    _emitSafe(items);
    try {
      final page = await query(ordered: _ordered)
          .startAfterDocument(last)
          .limit(pageSize)
          .get();
      _extraPages.addAll(page.docs);
      hasMore = page.docs.length >= pageSize;
      lastError = null;
    } catch (error) {
      lastError = error;
    } finally {
      loadingMore = false;
      _emit();
    }
  }

  void dispose() {
    _disposed = true;
    _stop();
    _controller.close();
  }
}

class _LearningContentStore {
  List<_LearningResource> resources = [];
  List<_TeacherVideo> videos = [];
  List<_TeacherQuiz> quizzes = [];
  int quizCompletions = 0;
  int studyCompletions = 0;

  FirebaseFirestore get _firestore {
    if (!_firebaseReady) {
      throw StateError(
        _firebaseStartupError ??
            'Firebase सेट केलेले नाही. firebase_options.dart तयार करा किंवा '
                'FIREBASE_* dart-define मूल्ये द्या.',
      );
    }
    return FirebaseFirestore.instance;
  }

  _PagedFeed<T> _feed<T>(
    Map<String, _PagedFeed<dynamic>> cache,
    String collection,
    int standard,
    String medium,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>>) fromDocument,
  ) {
    return cache.putIfAbsent('$standard:$medium', () {
      return _PagedFeed<T>(
        fromDocument: fromDocument,
        query: ({required bool ordered}) {
          final base = _firestore
              .collection(collection)
              .where('standard', isEqualTo: standard)
              .where('medium', isEqualTo: medium);
          return ordered ? base.orderBy('createdAt', descending: true) : base;
        },
      );
    }) as _PagedFeed<T>;
  }

  _PagedFeed<_LearningResource>? _resourceFeed;
  _PagedFeed<_TeacherVideo>? _videoFeed;
  _PagedFeed<_TeacherQuiz>? _quizFeed;

  // Safe fallbacks: when Firebase is missing or offline, widgets receive the
  // last cached list (or an empty list) instead of an error or a dead stream.
  Stream<List<T>> _safeStream<T>(_PagedFeed<T>? feed, List<T> cached) {
    if (feed == null) return Stream<List<T>>.value(cached).asBroadcastStream();
    return feed.stream;
  }

  Stream<List<_LearningResource>> watchResources(int standard, String medium) {
    if (!_firebaseReady) return _safeStream(null, resources);
    _resourceFeed = _feed(_resourceFeeds, 'resources', standard, medium,
        _LearningResource.fromDocument);
    return _safeStream(_resourceFeed, resources);
  }

  Stream<List<_TeacherVideo>> watchVideos(int standard, String medium) {
    if (!_firebaseReady) return _safeStream(null, videos);
    _videoFeed = _feed(
        _videoFeeds, 'videos', standard, medium, _TeacherVideo.fromDocument);
    return _safeStream(_videoFeed, videos);
  }

  Stream<List<_TeacherQuiz>> watchQuizzes(int standard, String medium) {
    if (!_firebaseReady) return _safeStream(null, quizzes);
    _quizFeed = _feed(
        _quizFeeds, 'quizzes', standard, medium, _TeacherQuiz.fromDocument);
    return _safeStream(_quizFeed, quizzes);
  }

  bool get hasMoreContent =>
      (_resourceFeed?.hasMore ?? false) ||
      (_videoFeed?.hasMore ?? false) ||
      (_quizFeed?.hasMore ?? false);

  bool get loadingMoreContent =>
      (_resourceFeed?.loadingMore ?? false) ||
      (_videoFeed?.loadingMore ?? false) ||
      (_quizFeed?.loadingMore ?? false);

  Object? get contentError =>
      _resourceFeed?.lastError ?? _videoFeed?.lastError ?? _quizFeed?.lastError;

  /// Loads the next batch for resources, videos and quizzes.
  Future<void> loadMoreContent() => Future.wait([
        if (_resourceFeed != null) _resourceFeed!.loadMore(),
        if (_videoFeed != null) _videoFeed!.loadMore(),
        if (_quizFeed != null) _quizFeed!.loadMore(),
      ]);

  final Map<String, _PagedFeed<dynamic>> _resourceFeeds = {};
  final Map<String, _PagedFeed<dynamic>> _videoFeeds = {};
  final Map<String, _PagedFeed<dynamic>> _quizFeeds = {};

  static int _compareCreatedAt(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aTime = a['createdAt'];
    final bTime = b['createdAt'];
    if (aTime is Timestamp && bTime is Timestamp) {
      return bTime.compareTo(aTime);
    }
    return 0;
  }

  Future<void> saveResource(_LearningResource resource) async {
    final bytes = resource.uploadBytes;
    final document = _firestore
        .collection('resources')
        .doc(resource.id.isEmpty ? null : resource.id);
    String downloadUrl;
    String? storagePath;
    Reference? uploadedFile;
    var uploadCompleted = false;
    try {
      if (bytes != null) {
        if (bytes.length < 5 ||
            String.fromCharCodes(bytes.take(5)) != '%PDF-') {
          throw FormatException('निवडलेली फाइल वैध पीडीएफ नाही.');
        }
        storagePath =
            'learning_resources/${resource.standard}/${resource.medium}/${document.id}/${resource.fileName}';
        uploadedFile = FirebaseStorage.instance.ref(storagePath);
        await uploadedFile.putData(
          bytes,
          SettableMetadata(contentType: 'application/pdf'),
        );
        uploadCompleted = true;
        downloadUrl = await uploadedFile.getDownloadURL();
      } else {
        final uri = Uri.tryParse(resource.downloadUrl ?? '');
        if (uri == null ||
            !uri.hasAuthority ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          throw FormatException(
            'पीडीएफ फाइल किंवा वैध पाठ्यपुस्तक दुवा निवडा.',
          );
        }
        downloadUrl = uri.toString();
      }
      final metadata = <String, dynamic>{
        'title': resource.title,
        'fileName': resource.fileName,
        'standard': resource.standard,
        'medium': resource.medium,
        'subject': resource.subject,
        'target': resource.target,
        'category': resource.target,
        'downloadUrl': downloadUrl,
        'storagePath': storagePath,
        'resourceType': bytes == null ? 'textbookLink' : 'pdf',
        'createdAt': FieldValue.serverTimestamp(),
      };
      final batch = _firestore.batch()
        ..set(document, metadata)
        ..set(
          _firestore.collection('learning_resources').doc(document.id),
          metadata,
        );
      await batch.commit();
    } catch (error) {
      if (uploadCompleted && uploadedFile != null) {
        try {
          await uploadedFile.delete();
        } catch (cleanupError) {
          throw StateError(
            'साहित्य जतन झाले नाही ($error); अपलोड केलेली फाइल '
            'काढता आली नाही ($cleanupError).',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> deleteResource(_LearningResource resource) async {
    final batch = _firestore.batch()
      ..delete(_firestore.collection('resources').doc(resource.id))
      ..delete(
        _firestore.collection('learning_resources').doc(resource.id),
      );
    await batch.commit();
    if (resource.storagePath case final path?) {
      await FirebaseStorage.instance.ref(path).delete();
    }
  }

  Future<void> saveVideo(_TeacherVideo video) async {
    final collection = _firestore.collection('videos');
    final document = collection.doc(video.id.isEmpty ? null : video.id);
    await document.set({
      'title': video.title,
      'subject': video.subject,
      'chapter': video.chapter,
      'url': video.url,
      'standard': video.standard,
      'medium': video.medium,
      'target': video.target,
      'category': video.target,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteVideo(_TeacherVideo video) =>
      _firestore.collection('videos').doc(video.id).delete();

  Future<void> saveQuiz(_TeacherQuiz quiz) async {
    final collection = _firestore.collection('quizzes');
    final document = collection.doc(quiz.id.isEmpty ? null : quiz.id);
    await document.set({
      'question': quiz.question,
      'options': quiz.options,
      'correctIndex': quiz.correctIndex,
      'standard': quiz.standard,
      'medium': quiz.medium,
      'target': quiz.target,
      'category': quiz.target,
      'assessmentType': quiz.assessmentType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteQuiz(_TeacherQuiz quiz) =>
      _firestore.collection('quizzes').doc(quiz.id).delete();

  _TeacherQuiz? quizFor(int standard, String medium) {
    for (final quiz in quizzes.reversed) {
      if (quiz.standard == standard &&
          quiz.medium == medium &&
          quiz.target == 'Classroom') {
        return quiz;
      }
    }
    return null;
  }

  List<_TeacherQuiz> quizzesForTarget(
    int standard,
    String target, {
    String? medium,
  }) =>
      quizzes
          .where((quiz) =>
              quiz.standard == standard &&
              quiz.target == target &&
              (medium == null || quiz.medium == medium))
          .toList()
          .reversed
          .toList();

  _TeacherVideo? videoFor({
    required int standard,
    required String medium,
    required String subject,
    required String chapter,
    String target = 'Classroom',
  }) {
    for (final video in videos.reversed) {
      if (video.standard == standard &&
          video.medium == medium &&
          video.target == target &&
          video.subject.toLowerCase() == subject.toLowerCase() &&
          video.chapter.toLowerCase() == chapter.toLowerCase()) {
        return video;
      }
    }
    return null;
  }
}

class _LiveContentBoundary extends StatelessWidget {
  const _LiveContentBoundary({
    super.key,
    required this.content,
    required this.standard,
    required this.medium,
    required this.child,
  });

  final _LearningContentStore content;
  final int standard;
  final String medium;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_LearningResource>>(
      stream: content.watchResources(standard, medium),
      initialData: content.resources,
      builder: (context, resourcesSnapshot) {
        if (resourcesSnapshot.hasData) {
          content.resources = resourcesSnapshot.data!;
        }
        return StreamBuilder<List<_TeacherVideo>>(
          stream: content.watchVideos(standard, medium),
          initialData: content.videos,
          builder: (context, videosSnapshot) {
            if (videosSnapshot.hasData) content.videos = videosSnapshot.data!;
            return StreamBuilder<List<_TeacherQuiz>>(
              stream: content.watchQuizzes(standard, medium),
              initialData: content.quizzes,
              builder: (context, quizzesSnapshot) {
                if (quizzesSnapshot.hasData) {
                  content.quizzes = quizzesSnapshot.data!;
                }
                final error = resourcesSnapshot.error ??
                    videosSnapshot.error ??
                    quizzesSnapshot.error ??
                    content.contentError;
                return Column(
                  children: [
                    if (!_firebaseReady || error != null)
                      _FirebaseStatusBanner(
                        message: error == null ? null : '$error',
                        offline: _firebaseReady,
                        medium: medium,
                      ),
                    Expanded(child: child),
                    if (_firebaseReady && content.hasMoreContent)
                      _LoadMoreBar(content: content, medium: medium),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LoadMoreBar extends StatefulWidget {
  const _LoadMoreBar({required this.content, required this.medium});

  final _LearningContentStore content;
  final String medium;

  @override
  State<_LoadMoreBar> createState() => _LoadMoreBarState();
}

class _LoadMoreBarState extends State<_LoadMoreBar> {
  Future<void> _load() async {
    setState(() {});
    await widget.content.loadMoreContent();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.content.loadingMoreContent;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: loading
            ? const SizedBox(
                height: 36,
                width: 36,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.expand_more_rounded),
                label: Text(
                  _mediumLabel(
                    widget.medium,
                    marathi: 'आणखी साहित्य लोड करा',
                    semiEnglish: 'आणखी Content लोड करा',
                    english: 'Load more content',
                  ),
                ),
              ),
      ),
    );
  }
}

class _FirebaseStatusBanner extends StatelessWidget {
  const _FirebaseStatusBanner({
    this.message,
    this.offline = false,
    this.medium = 'Semi-English',
  });

  final String? message;
  final bool offline;
  final String medium;

  @override
  Widget build(BuildContext context) {
    final detail = message ?? _firebaseStartupError;
    final offlineText = _mediumLabel(
      medium,
      marathi: 'नेटवर्क उपलब्ध नाही. जतन केलेली माहिती दाखवली जात आहे.',
      semiEnglish: 'Network नाही. Saved माहिती दाखवली जात आहे.',
      english: 'You are offline. Showing saved content.',
    );
    return Material(
      color: const Color(0xFFFFF3D9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 18, color: Color(0xFF8A5A00)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                offline
                    ? offlineText
                    : detail == null
                        ? 'स्थानिक चाचणी: Firebase जोडलेले नाही. Firebase शिवाय वाचन-मात्र वापर उपलब्ध आहे.'
                        : 'Firebase त्रुटी: $detail',
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _foreignLanguageTargets = ['Spanish', 'French', 'German'];

List<String> _targetsForStandard(int standard) => [
      'Classroom',
      'Scholarship',
      'Navodaya',
      if (standard == 5 || standard == 8) 'Sainik School',
      ..._foreignLanguageTargets,
    ];

String _targetLabel(String target) => switch (target) {
      'Classroom' => 'वर्ग-अध्ययन',
      'Scholarship' => 'शिष्यवृत्ती परीक्षा',
      'Navodaya' => 'जवाहर नवोदय विद्यालय प्रवेश परीक्षा',
      'Sainik School' => 'सैनिक शाळा प्रवेश परीक्षा',
      'Spanish' => 'स्पॅनिश भाषा',
      'French' => 'फ्रेंच भाषा',
      'German' => 'जर्मन भाषा',
      _ => target,
    };

String _localizedTarget(String target, String medium) {
  final marathi = _targetLabel(target);
  final english = switch (target) {
    'Classroom' => 'Classroom',
    'Scholarship' => 'Scholarship Exam',
    'Navodaya' => 'Jawahar Navodaya Vidyalaya',
    'Sainik School' => 'Sainik School Entrance Exam',
    'Spanish' => 'Spanish',
    'French' => 'French',
    'German' => 'German',
    _ => target,
  };
  return _mediumLabel(
    medium,
    marathi: marathi,
    semiEnglish: '$english / $marathi',
    english: english,
  );
}

String _marathiNumber(int number) {
  const digits = '०१२३४५६७८९';
  return number
      .toString()
      .split('')
      .map((digit) => digits[int.parse(digit)])
      .join();
}

String _mediumMarathi(String medium) => switch (medium) {
      'Marathi' => 'मराठी माध्यम',
      'Semi-English' => 'अर्ध-इंग्रजी माध्यम',
      'English' => 'इंग्रजी माध्यम',
      _ => medium,
    };

String _mediumEnglish(String medium) => switch (medium) {
      'Marathi' => 'Marathi',
      'Semi-English' => 'Semi-English',
      'English' => 'English',
      _ => medium,
    };

String _mediumLabel(
  String medium, {
  required String marathi,
  String? semiEnglish,
  required String english,
}) =>
    switch (medium) {
      'Marathi' => marathi,
      'Semi-English' => semiEnglish ?? english,
      _ => english,
    };

String _assessmentLabel(String type) => switch (type) {
      'Daily practice' => 'दैनंदिन सराव',
      'Practice test' => 'सराव चाचणी',
      'Mock test' => 'नमुना परीक्षा',
      'Previous-year simulation' => 'मागील वर्षांच्या धर्तीवरील सराव',
      _ => type,
    };

class _RoleGate extends StatefulWidget {
  const _RoleGate();

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  final _content = _LearningContentStore();
  // 'checking' (restoring a saved session) | 'login' | 'student' | 'admin'
  String _role = 'login';
  String? _loginMessage;

  @override
  void initState() {
    super.initState();
    if (_firebaseReady && AuthService.currentUser != null) {
      _role = 'checking';
      _restoreSession();
    }
  }

  /// Re-verifies the role of a previously signed-in user on app start.
  Future<void> _restoreSession() async {
    final user = AuthService.currentUser;
    try {
      final role = await AuthService.resolveRole(user!);
      if (!mounted) return;
      setState(() => _role = role == AppRole.admin ? 'admin' : 'student');
    } catch (error) {
      // Only an authentication failure ends the session; a network problem
      // must not log a returning user out.
      if (error is FirebaseAuthException) {
        try {
          await AuthService.signOut();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _role = 'login';
        _loginMessage = describeAuthError(error, 'Semi-English');
      });
    }
  }

  Future<void> _signOut() async {
    // Drop any pushed pages so none is left on top of the login screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (_firebaseReady) {
      try {
        await AuthService.signOut();
      } catch (error) {
        debugPrint('Sign-out failed: $error');
      }
    }
    if (!mounted) return;
    setState(() {
      _role = 'login';
      _loginMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_role) {
      case 'checking':
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case 'student':
        return LearningHome(content: _content, onSignOut: _signOut);
      case 'admin':
        return _AdminDashboard(content: _content, onSignOut: _signOut);
    }
    return UnifiedLoginScreen(
      firebaseReady: _firebaseReady,
      startupError: _firebaseStartupError,
      initialMessage: _loginMessage,
      onRole: (role) => setState(
        () => _role = role == AppRole.admin ? 'admin' : 'student',
      ),
      onLocalDemo: () => setState(() => _role = 'student'),
    );
  }
}

class LearningHome extends StatefulWidget {
  // ignore: library_private_types_in_public_api
  const LearningHome({
    super.key,
    // ignore: library_private_types_in_public_api
    required this.content,
    required this.onSignOut,
  });

  // ignore: library_private_types_in_public_api
  final _LearningContentStore content;
  final VoidCallback onSignOut;

  @override
  // ignore: library_private_types_in_public_api
  State<LearningHome> createState() => _LearningHomeState();
}

class _LearningHomeState extends State<LearningHome> {
  int _standard = 5;
  String _medium = 'Semi-English';
  int _tabIndex = 0;
  StudentProfile? _profile;
  bool _profileLoading = false;
  bool _profileError = false;
  final _subjectsKey = GlobalKey();

  bool get _isKidsZone => _standard <= 4;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Loads `users/{uid}` (server, then offline cache) and applies the
  /// admin-assigned class and saved medium. Failures keep the defaults.
  Future<void> _loadProfile() async {
    if (!_firebaseReady || AuthService.currentUser == null) return;
    setState(() {
      _profileLoading = true;
      _profileError = false;
    });
    try {
      final profile = await StudentProfileService.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profileLoading = false;
        if (profile?.standard != null) _standard = profile!.standard!;
        if (profile?.medium != null) _medium = profile!.medium!;
      });
    } catch (error) {
      debugPrint('Student profile unavailable: $error');
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
        _profileError = true;
      });
    }
  }

  void _changeMedium(String medium) {
    setState(() => _medium = medium);
    if (_firebaseReady && AuthService.currentUser != null) {
      unawaited(StudentProfileService.saveMedium(medium));
    }
  }

  List<({String label, IconData icon})> get _tabs => [
        (
          label: _mediumLabel(
            _medium,
            marathi: 'अभ्यास',
            semiEnglish: 'Study / अभ्यास',
            english: 'Study',
          ),
          icon: Icons.menu_book_rounded,
        ),
        (
          label: _mediumLabel(
            _medium,
            marathi: 'एआय मदत',
            semiEnglish: 'AI Help / एआय मदत',
            english: 'AI Help',
          ),
          icon: Icons.auto_awesome_rounded,
        ),
        (
          label: _mediumLabel(
            _medium,
            marathi: 'कौशल्ये',
            semiEnglish: 'Skills / कौशल्ये',
            english: 'Skills',
          ),
          icon: Icons.lightbulb_rounded,
        ),
        (
          label: _mediumLabel(
            _medium,
            marathi: 'करिअर',
            semiEnglish: 'Career / करिअर',
            english: 'Career',
          ),
          icon: Icons.explore_rounded,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isKidsZone = _standard <= 4;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: isKidsZone ? const Color(0xFFE98528) : const Color(0xFF3659C9),
      brightness: Brightness.light,
      surface: isKidsZone ? const Color(0xFFFFFBF5) : const Color(0xFFF7F8FC),
    );

    return AnimatedTheme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isKidsZone
                  ? const Color(0xFFF2E4D2)
                  : const Color(0xFFE9ECF4),
            ),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: PopScope(
        // Back on a secondary tab returns to the Study home; only the home
        // tab lets the system handle back (leave the app).
        canPop: _tabIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) setState(() => _tabIndex = 0);
        },
        child: Scaffold(
          body: _LiveContentBoundary(
            key: ValueKey('student-$_standard-$_medium'),
            content: widget.content,
            standard: _standard,
            medium: _medium,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: IndexedStack(
                      index: _tabIndex,
                      children: [
                        _StudyPage(
                          standard: _standard,
                          medium: _medium,
                          isKidsZone: _isKidsZone,
                          content: widget.content,
                          profile: _profile,
                          profileLoading: _profileLoading,
                          profileError: _profileError,
                          subjectsKey: _subjectsKey,
                          onStandardChanged: (value) =>
                              setState(() => _standard = value),
                          onMediumChanged: _changeMedium,
                          onRetryProfile: _loadProfile,
                        ),
                        _AiRoomPage(standard: _standard, medium: _medium),
                        _SkillsPage(
                          isKidsZone: _isKidsZone,
                          medium: _medium,
                        ),
                        _CareerPage(standard: _standard, medium: _medium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (index) => setState(() => _tabIndex = index),
            destinations: [
              for (var index = 0; index < _tabs.length; index++)
                NavigationDestination(
                  icon: Icon(_tabs[index].icon),
                  selectedIcon: Icon(_tabs[index].icon),
                  label: _tabs[index].label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final zoneColor =
        _isKidsZone ? const Color(0xFFB85C27) : const Color(0xFF3659C9);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.school_rounded,
              color: zoneColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MahaScholar AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  _mediumLabel(
                    _medium,
                    marathi:
                        'इयत्ता ${_marathiNumber(_standard)} · मराठी माध्यम',
                    semiEnglish:
                        'Std ${_marathiNumber(_standard)} · Semi-English',
                    english: 'Standard $_standard · English medium',
                  ),
                  style: TextStyle(
                    color: _isKidsZone
                        ? const Color(0xFFE27B28)
                        : const Color(0xFF68718A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showClassSwitcherModal,
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: Text(_mediumLabel(
              _medium,
              marathi: 'बदला',
              semiEnglish: 'Switch / बदला',
              english: 'Switch',
            )),
            style: OutlinedButton.styleFrom(
              foregroundColor: zoneColor,
              side: const BorderSide(color: Color(0xFFDCE2F0)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _mediumLabel(
              _medium,
              marathi: 'बाहेर पडा',
              semiEnglish: 'Sign out / बाहेर पडा',
              english: 'Sign out',
            ),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  void _showClassSwitcherModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final sheetScheme = ColorScheme.fromSeed(
              seedColor: _standard <= 4
                  ? const Color(0xFFE98528)
                  : const Color(0xFF3659C9),
              surface: _standard <= 4
                  ? const Color(0xFFFFFBF5)
                  : const Color(0xFFF7F8FC),
            );
            return Theme(
              data: ThemeData(useMaterial3: true, colorScheme: sheetScheme),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _mediumLabel(
                            _medium,
                            marathi: 'तुमची अध्ययन माहिती',
                            semiEnglish: 'Learning profile / अध्ययन माहिती',
                            english: 'Learning profile',
                          ),
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _mediumLabel(
                            _medium,
                            marathi:
                                'तुमचा वर्ग आणि माध्यम निवडून अध्ययन विभाग वैयक्तिक करा.',
                            semiEnglish:
                                'Choose your standard and medium / इयत्ता व माध्यम निवडा.',
                            english:
                                'Choose a standard and medium to personalise your study space.',
                          ),
                          style:
                              TextStyle(color: Color(0xFF737B91), height: 1.4),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _mediumLabel(
                            _medium,
                            marathi: 'इयत्ता निवडा',
                            semiEnglish: 'Standard / इयत्ता',
                            english: 'Standard',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF737B91),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            for (var standard = 1; standard <= 10; standard++)
                              ChoiceChip(
                                label: Text(_mediumLabel(
                                  _medium,
                                  marathi: _marathiNumber(standard),
                                  semiEnglish: '$standard',
                                  english: '$standard',
                                )),
                                selected: _standard == standard,
                                onSelected: (_) {
                                  setState(() => _standard = standard);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _mediumLabel(
                            _medium,
                            marathi: 'अध्ययनाचे माध्यम',
                            semiEnglish: 'Medium / माध्यम',
                            english: 'Medium',
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF737B91),
                          ),
                        ),
                        const SizedBox(height: 11),
                        Wrap(
                          spacing: 9,
                          children: [
                            for (final medium in [
                              'Marathi',
                              'Semi-English',
                              'English',
                            ])
                              ChoiceChip(
                                label: Text(_mediumLabel(
                                  _medium,
                                  marathi: _mediumMarathi(medium),
                                  semiEnglish:
                                      '${_mediumEnglish(medium)} / ${_mediumMarathi(medium)}',
                                  english: _mediumEnglish(medium),
                                )),
                                selected: _medium == medium,
                                onSelected: (_) {
                                  setState(() => _medium = medium);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text(_mediumLabel(
                              _medium,
                              marathi: 'पूर्ण',
                              semiEnglish: 'Done / पूर्ण',
                              english: 'Done',
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({
    required this.content,
    required this.onSignOut,
  });

  final _LearningContentStore content;
  final VoidCallback onSignOut;

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  int _standard = 5;
  String _medium = 'Semi-English';
  String _target = 'Classroom';

  List<_LearningResource> get _resources => widget.content.resources
      .where((item) =>
          item.standard == _standard &&
          item.medium == _medium &&
          item.target == _target)
      .toList()
      .reversed
      .toList();

  List<_TeacherVideo> get _videos => widget.content.videos
      .where((item) =>
          item.standard == _standard &&
          item.medium == _medium &&
          item.target == _target)
      .toList()
      .reversed
      .toList();

  List<_TeacherQuiz> get _quizzes => widget.content.quizzes
      .where((item) =>
          item.standard == _standard &&
          item.medium == _medium &&
          item.target == _target)
      .toList()
      .reversed
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'शिक्षक प्रशासक फलक',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'महास्कॉलर · प्रशासक',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                color: Color(0xFF68718A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'विद्यार्थी आणि वर्ग / Students & classes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminDashboard()),
            ),
            icon: const Icon(Icons.groups_rounded),
          ),
          IconButton(
            tooltip: 'बाहेर पडा',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _LiveContentBoundary(
        key: ValueKey('admin-$_standard-$_medium'),
        content: widget.content,
        standard: _standard,
        medium: _medium,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageIntro(
                  eyebrow: 'अभ्यासक्रम आणि वर्ग',
                  title: 'वर्ग व्यवस्थापन',
                  subtitle:
                      'इयत्ता आणि माध्यमानुसार विद्यार्थ्यांसाठी अध्ययन साहित्य प्रकाशित करा.',
                  icon: Icons.cast_for_education_rounded,
                  color: Color(0xFF3659C9),
                ),
                const SizedBox(height: 18),
                _buildTargetSelector(),
                const SizedBox(height: 16),
                _buildAnalytics(),
                const SizedBox(height: 22),
                _buildSectionHeader(
                  title: 'पाठ्यपुस्तके आणि प्रकरणांच्या टिपा',
                  subtitle: 'निवडलेले लक्ष्य · ${_targetLabel(_target)}',
                  action: 'साहित्य जोडा',
                  icon: Icons.upload_file_rounded,
                  onPressed: _addResource,
                ),
                const SizedBox(height: 9),
                if (_resources.isEmpty)
                  const _AdminEmptyState(
                    text: 'या वर्गासाठी अद्याप पीडीएफ साहित्य जोडलेले नाही.',
                  )
                else
                  for (var index = 0; index < _resources.length; index++)
                    _buildResourceTile(_resources[index]),
                const SizedBox(height: 21),
                _buildSectionHeader(
                  title: 'विषयानुसार ध्वनिचित्र धडे',
                  subtitle: 'प्रकरणासाठी ध्वनिचित्र दुवा जोडा किंवा बदला.',
                  action: 'धडा जोडा',
                  icon: Icons.video_call_rounded,
                  onPressed: () => _editVideo(),
                ),
                const SizedBox(height: 9),
                if (_videos.isEmpty)
                  const _AdminEmptyState(
                    text: 'या वर्गासाठी शिक्षकांचे धडे अद्याप जोडलेले नाहीत.',
                  )
                else
                  for (final video in _videos) _buildVideoTile(video),
                const SizedBox(height: 21),
                _buildSectionHeader(
                  title: 'सराव प्रश्न आणि नमुना परीक्षा',
                  subtitle:
                      'निवडलेल्या परीक्षेसाठी किंवा भाषेसाठी प्रश्न तयार करा.',
                  action: 'प्रश्न जोडा',
                  icon: Icons.quiz_rounded,
                  onPressed: () => _editQuiz(),
                ),
                const SizedBox(height: 9),
                if (_quizzes.isEmpty)
                  const _AdminEmptyState(
                    text:
                        'या लक्ष्याकरिता शिक्षकांनी अद्याप प्रश्न तयार केलेले नाहीत.',
                  )
                else
                  for (final quiz in _quizzes) _buildQuizTile(quiz),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'साहित्याचे लक्ष्य',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: .8,
                fontWeight: FontWeight.w800,
                color: Color(0xFF737B91),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _standard,
                    decoration: InputDecoration(
                      labelText: 'इयत्ता',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    items: [
                      for (var value = 1; value <= 10; value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_marathiNumber(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _standard = value;
                          if (!_targetsForStandard(value).contains(_target)) {
                            _target = 'Classroom';
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _medium,
                    decoration: InputDecoration(
                      labelText: 'माध्यम',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Marathi',
                        child: Text('मराठी'),
                      ),
                      DropdownMenuItem(
                        value: 'Semi-English',
                        child: Text('अर्ध-इंग्रजी'),
                      ),
                      DropdownMenuItem(
                        value: 'English',
                        child: Text('इंग्रजी'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _medium = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(_standard),
              initialValue: _target,
              decoration: InputDecoration(
                labelText: 'परीक्षा / भाषेचे लक्ष्य',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              items: [
                for (final target in _targetsForStandard(_standard))
                  DropdownMenuItem(
                    value: target,
                    child: Text(_localizedTarget(target, _medium)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _target = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'विद्यार्थी सहभागाचा आढावा',
          subtitle: 'प्रात्यक्षिक फलक · या सत्रातील माहिती',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _AnalyticsTile(
              label: 'सक्रिय विद्यार्थी',
              value: '128',
              icon: Icons.groups_rounded,
              color: const Color(0xFF3659C9),
              footnote: 'प्रात्यक्षिक सहभाग',
            ),
            _AnalyticsTile(
              label: 'पूर्ण प्रश्नमंजुषा',
              value: '${widget.content.quizCompletions}',
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF168B73),
              footnote: 'या अ‍ॅप सत्रात',
            ),
            _AnalyticsTile(
              label: 'पूर्ण अध्ययन घटक',
              value: '${widget.content.studyCompletions}',
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF9A64BD),
              footnote: 'या सत्रात पूर्ण',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String action,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _SectionHeading(title: title, subtitle: subtitle),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(action),
        ),
      ],
    );
  }

  Widget _buildResourceTile(_LearningResource resource) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(
          Icons.picture_as_pdf_rounded,
          color: Color(0xFFC34444),
        ),
        title: Text(resource.title),
        subtitle: Text('${resource.subject} · ${resource.fileName}'),
        trailing: IconButton(
          tooltip: 'साहित्य काढून टाका',
          onPressed: () => _deleteResource(resource),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ),
    );
  }

  Widget _buildVideoTile(_TeacherVideo video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(
          Icons.ondemand_video_rounded,
          color: Color(0xFF425DC3),
        ),
        title: Text(video.title),
        subtitle: Text(
          '${video.subject} · ${video.chapter}\n${video.url}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _editVideo(existing: video);
            } else {
              _deleteVideo(video);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('बदला')),
            PopupMenuItem(value: 'delete', child: Text('काढून टाका')),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizTile(_TeacherQuiz quiz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.quiz_rounded, color: Color(0xFF168B73)),
        title: Text(quiz.question),
        subtitle: Text(
          '${_targetLabel(quiz.target)} · ${_assessmentLabel(quiz.assessmentType)} · ${_marathiNumber(quiz.options.length)} पर्याय',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _editQuiz(existing: quiz);
            } else {
              _deleteQuiz(quiz);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('बदला')),
            PopupMenuItem(value: 'delete', child: Text('काढून टाका')),
          ],
        ),
      ),
    );
  }

  Future<void> _addResource() async {
    final result = await _showResourceEditor(
      context,
      standard: _standard,
      medium: _medium,
      target: _target,
    );
    if (result == null || !mounted) return;
    try {
      await widget.content.saveResource(result);
      if (mounted) _showSavedMessage('अध्ययन साहित्य प्रकाशित झाले.');
    } catch (error) {
      if (mounted) _showSavedMessage('साहित्य जतन करता आले नाही: $error');
    }
  }

  Future<void> _editVideo({_TeacherVideo? existing}) async {
    final result = await _showVideoEditor(
      context,
      standard: _standard,
      medium: _medium,
      target: _target,
      existing: existing,
    );
    if (result == null || !mounted) return;
    try {
      await widget.content.saveVideo(
        _TeacherVideo(
          id: existing?.id ?? '',
          title: result.title,
          subject: result.subject,
          chapter: result.chapter,
          url: result.url,
          standard: result.standard,
          medium: result.medium,
          target: result.target,
        ),
      );
      if (mounted) _showSavedMessage('ध्वनिचित्र दुवा जतन झाला.');
    } catch (error) {
      if (mounted) _showSavedMessage('दुवा जतन करता आला नाही: $error');
    }
  }

  Future<void> _editQuiz({_TeacherQuiz? existing}) async {
    final result = await _showQuizEditor(
      context,
      standard: _standard,
      medium: _medium,
      target: _target,
      existing: existing,
    );
    if (result == null || !mounted) return;
    try {
      await widget.content.saveQuiz(
        _TeacherQuiz(
          id: existing?.id ?? '',
          question: result.question,
          options: result.options,
          correctIndex: result.correctIndex,
          standard: result.standard,
          medium: result.medium,
          target: result.target,
          assessmentType: result.assessmentType,
        ),
      );
      if (mounted) _showSavedMessage('प्रश्नमंजुषा जतन झाली.');
    } catch (error) {
      if (mounted) _showSavedMessage('प्रश्नमंजुषा जतन झाली नाही: $error');
    }
  }

  Future<void> _deleteResource(_LearningResource resource) async {
    try {
      await widget.content.deleteResource(resource);
    } catch (error) {
      if (mounted) _showSavedMessage('साहित्य काढता आले नाही: $error');
    }
  }

  Future<void> _deleteVideo(_TeacherVideo video) async {
    try {
      await widget.content.deleteVideo(video);
    } catch (error) {
      if (mounted) _showSavedMessage('दुवा काढता आला नाही: $error');
    }
  }

  Future<void> _deleteQuiz(_TeacherQuiz quiz) async {
    try {
      await widget.content.deleteQuiz(quiz);
    } catch (error) {
      if (mounted) _showSavedMessage('प्रश्नमंजुषा काढता आली नाही: $error');
    }
  }

  void _showSavedMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF68718A), fontSize: 12),
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 50) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                footnote,
                style: const TextStyle(fontSize: 9, color: Color(0xFF737B91)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<_LearningResource?> _showResourceEditor(
  BuildContext context, {
  required int standard,
  required String medium,
  required String target,
}) async {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final subject = TextEditingController();
  final fileName = TextEditingController();
  final textbookUrl = TextEditingController();
  Uint8List? uploadBytes;
  String? pickerError;
  final result = await showDialog<_LearningResource>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        scrollable: true,
        title: const Text('पीडीएफ / पाठ्यपुस्तक दुवा जोडा'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'लक्ष्य: इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)} · ${_targetLabel(target)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: title,
                decoration:
                    const InputDecoration(labelText: 'साहित्याचे शीर्षक'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'शीर्षक लिहा'
                    : null,
              ),
              TextFormField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'विषय'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'विषय लिहा' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final file = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf'],
                    );
                    if (file == null) return;
                    final bytes = await file.readAsBytes();
                    setDialogState(() {
                      uploadBytes = bytes;
                      textbookUrl.clear();
                      fileName.text = file.name;
                      pickerError = null;
                    });
                  } catch (error) {
                    setDialogState(
                        () => pickerError = 'फाइल निवडता आली नाही: $error');
                  }
                },
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(
                  fileName.text.isEmpty ? 'पीडीएफ फाइल निवडा' : fileName.text,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextFormField(
                controller: textbookUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'किंवा पाठ्यपुस्तकाचा दुवा',
                  hintText: 'https://...',
                ),
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    setDialogState(() {
                      uploadBytes = null;
                      fileName.clear();
                      pickerError = null;
                    });
                  }
                },
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final uri = Uri.tryParse(text);
                  if (uri == null ||
                      !uri.hasAuthority ||
                      (uri.scheme != 'https' && uri.scheme != 'http')) {
                    return 'योग्य http(s) पाठ्यपुस्तक दुवा लिहा';
                  }
                  return null;
                },
              ),
              if (pickerError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    pickerError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करा'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              if (uploadBytes == null && textbookUrl.text.trim().isEmpty) {
                setDialogState(() =>
                    pickerError = 'पीडीएफ फाइल किंवा पाठ्यपुस्तक दुवा द्या.');
                return;
              }
              final hasPdf = uploadBytes != null;
              Navigator.pop(
                dialogContext,
                _LearningResource(
                  title: title.text.trim(),
                  fileName: hasPdf ? fileName.text.trim() : 'पाठ्यपुस्तक दुवा',
                  standard: standard,
                  medium: medium,
                  subject: subject.text.trim(),
                  target: target,
                  uploadBytes: uploadBytes,
                  downloadUrl: hasPdf ? null : textbookUrl.text.trim(),
                ),
              );
            },
            icon: const Icon(Icons.upload_rounded),
            label: const Text('फाइल अपलोड करा'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  subject.dispose();
  fileName.dispose();
  textbookUrl.dispose();
  return result;
}

Future<_TeacherVideo?> _showVideoEditor(
  BuildContext context, {
  required int standard,
  required String medium,
  required String target,
  _TeacherVideo? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: existing?.title ?? '');
  final subject = TextEditingController(text: existing?.subject ?? '');
  final chapter = TextEditingController(text: existing?.chapter ?? '');
  final url = TextEditingController(text: existing?.url ?? '');
  final result = await showDialog<_TeacherVideo>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(
          existing == null ? 'ध्वनिचित्र धडा जोडा' : 'ध्वनिचित्र धडा बदला'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'लक्ष्य: इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)}'),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'धड्याचे शीर्षक'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'शीर्षक लिहा' : null,
            ),
            TextFormField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'विषय'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'विषय लिहा' : null,
            ),
            TextFormField(
              controller: chapter,
              decoration: const InputDecoration(labelText: 'प्रकरण / विषय'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'प्रकरण किंवा विषय लिहा'
                  : null,
            ),
            TextFormField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'ध्वनिचित्र दुवा',
                hintText: 'https://...',
              ),
              validator: (value) {
                final uri = Uri.tryParse(value?.trim() ?? '');
                if (uri == null ||
                    !uri.hasAuthority ||
                    (uri.scheme != 'https' && uri.scheme != 'http')) {
                  return 'योग्य http(s) दुवा लिहा';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('रद्द करा'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.pop(
              dialogContext,
              _TeacherVideo(
                id: existing?.id ?? '',
                title: title.text.trim(),
                subject: subject.text.trim(),
                chapter: chapter.text.trim(),
                url: url.text.trim(),
                standard: standard,
                medium: medium,
                target: target,
              ),
            );
          },
          child: const Text('धडा जतन करा'),
        ),
      ],
    ),
  );
  title.dispose();
  subject.dispose();
  chapter.dispose();
  url.dispose();
  return result;
}

Future<_TeacherQuiz?> _showQuizEditor(
  BuildContext context, {
  required int standard,
  required String medium,
  required String target,
  _TeacherQuiz? existing,
}) async {
  final formKey = GlobalKey<FormState>();
  final question = TextEditingController(text: existing?.question ?? '');
  final options = List.generate(
    4,
    (index) => TextEditingController(
      text: existing != null && index < existing.options.length
          ? existing.options[index]
          : '',
    ),
  );
  var correctIndex = existing?.correctIndex ?? 0;
  var assessmentType = existing?.assessmentType ?? 'Daily practice';
  final result = await showDialog<_TeacherQuiz>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        scrollable: true,
        title: Text(existing == null ? 'सराव प्रश्न तयार करा' : 'प्रश्न बदला'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'लक्ष्य: इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)} · ${_targetLabel(target)}',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: assessmentType,
                decoration: const InputDecoration(
                  labelText: 'सरावाचा प्रकार',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Daily practice',
                    child: Text('दैनंदिन सराव'),
                  ),
                  DropdownMenuItem(
                    value: 'Practice test',
                    child: Text('सराव चाचणी'),
                  ),
                  DropdownMenuItem(
                    value: 'Mock test',
                    child: Text('नमुना परीक्षा'),
                  ),
                  DropdownMenuItem(
                    value: 'Previous-year simulation',
                    child: Text('मागील वर्षांच्या धर्तीवरील परीक्षा'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => assessmentType = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: question,
                decoration: const InputDecoration(labelText: 'प्रश्न'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'प्रश्न लिहा'
                    : null,
              ),
              for (var index = 0; index < options.length; index++)
                TextFormField(
                  controller: options[index],
                  decoration: InputDecoration(
                    labelText: 'पर्याय ${_marathiNumber(index + 1)}',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'चारही पर्याय लिहा'
                      : null,
                ),
              const SizedBox(height: 7),
              const Text(
                'योग्य उत्तर निवडा:',
                style: TextStyle(fontSize: 11, color: Color(0xFF68718A)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (var index = 0; index < options.length; index++)
                    ChoiceChip(
                      label: Text('पर्याय ${_marathiNumber(index + 1)}'),
                      selected: correctIndex == index,
                      onSelected: (_) =>
                          setDialogState(() => correctIndex = index),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करा'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(
                dialogContext,
                _TeacherQuiz(
                  id: existing?.id ?? '',
                  question: question.text.trim(),
                  options: options
                      .map((option) => option.text.trim())
                      .toList(growable: false),
                  correctIndex: correctIndex,
                  standard: standard,
                  medium: medium,
                  target: target,
                  assessmentType: assessmentType,
                ),
              );
            },
            child: const Text('प्रश्न जतन करा'),
          ),
        ],
      ),
    ),
  );
  question.dispose();
  for (final option in options) {
    option.dispose();
  }
  return result;
}

class _SubjectInfo {
  const _SubjectInfo({
    required this.name,
    required this.key,
    required this.icon,
    required this.color,
  });

  final String name;
  final String key;
  final IconData icon;
  final int color;
}

List<_SubjectInfo> _subjectsForMedium({
  required int standard,
  required String medium,
}) {
  String subjectName({
    required String english,
    required String marathi,
    String? semiEnglish,
  }) =>
      _mediumLabel(
        medium,
        marathi: marathi,
        semiEnglish: semiEnglish ?? '$english / $marathi',
        english: english,
      );

  if (standard <= 4) {
    return [
      _SubjectInfo(
        name: subjectName(
          english: 'Mathematics',
          marathi: 'गणित',
          semiEnglish: 'Maths / गणित',
        ),
        key: 'maths',
        icon: Icons.calculate_rounded,
        color: 0xFF5467D8,
      ),
      _SubjectInfo(
        name: subjectName(
          english: 'Marathi Language',
          marathi: 'मराठी',
          semiEnglish: 'Marathi / मराठी',
        ),
        key: 'marathi',
        icon: Icons.auto_stories_rounded,
        color: 0xFF9A64BD,
      ),
      _SubjectInfo(
        name: subjectName(
          english: 'English Language',
          marathi: 'इंग्रजी',
          semiEnglish: 'English / इंग्रजी',
        ),
        key: 'english',
        icon: Icons.translate_rounded,
        color: 0xFF168B73,
      ),
      _SubjectInfo(
        name: subjectName(
          english: 'Environmental Studies',
          marathi: 'परिसर अभ्यास',
          semiEnglish: 'EVS / परिसर अभ्यास',
        ),
        key: 'evs',
        icon: Icons.nature_people_rounded,
        color: 0xFFE28A38,
      ),
    ];
  }

  return [
    _SubjectInfo(
      name: subjectName(
        english: 'Mathematics',
        marathi: 'गणित',
        semiEnglish: 'Maths / गणित',
      ),
      key: 'maths',
      icon: Icons.calculate_rounded,
      color: 0xFF5467D8,
    ),
    _SubjectInfo(
      name: subjectName(
        english: 'General Science',
        marathi: 'विज्ञान व तंत्रज्ञान',
        semiEnglish: 'Science / विज्ञान',
      ),
      key: 'science',
      icon: Icons.science_rounded,
      color: 0xFF23A887,
    ),
    _SubjectInfo(
      name: subjectName(
        english: 'History & Civics',
        marathi: 'इतिहास व नागरिकशास्त्र',
        semiEnglish: 'History & Civics / इतिहास',
      ),
      key: 'history',
      icon: Icons.account_balance_rounded,
      color: 0xFF9A64BD,
    ),
    _SubjectInfo(
      name: subjectName(
        english: 'Geography',
        marathi: 'भूगोल',
        semiEnglish: 'Geography / भूगोल',
      ),
      key: 'geography',
      icon: Icons.public_rounded,
      color: 0xFFDA8A33,
    ),
    _SubjectInfo(
      name: subjectName(
        english: 'Marathi Language',
        marathi: 'मराठी',
        semiEnglish: 'Marathi / मराठी',
      ),
      key: 'marathi',
      icon: Icons.auto_stories_rounded,
      color: 0xFFB85C75,
    ),
    _SubjectInfo(
      name: subjectName(
        english: 'English Language',
        marathi: 'इंग्रजी',
        semiEnglish: 'English / इंग्रजी',
      ),
      key: 'english',
      icon: Icons.translate_rounded,
      color: 0xFF168B73,
    ),
    _SubjectInfo(
      name: subjectName(
        english: 'Hindi Language',
        marathi: 'हिंदी',
        semiEnglish: 'Hindi / हिंदी',
      ),
      key: 'hindi',
      icon: Icons.language_rounded,
      color: 0xFFE28A38,
    ),
  ];
}

List<String> _chapterTitlesFor({
  required String subjectKey,
  required int standard,
  required String medium,
}) {
  if (medium != 'Semi-English') {
    return _chapterTitlesForSingle(
      subjectKey: subjectKey,
      standard: standard,
      medium: medium,
    );
  }
  final englishTitles = _chapterTitlesForSingle(
    subjectKey: subjectKey,
    standard: standard,
    medium: 'English',
  );
  final marathiTitles = _chapterTitlesForSingle(
    subjectKey: subjectKey,
    standard: standard,
    medium: 'Marathi',
  );
  return [
    for (var index = 0; index < englishTitles.length; index++)
      '${englishTitles[index]} / ${marathiTitles[index]}',
  ];
}

List<String> _chapterTitlesForSingle({
  required String subjectKey,
  required int standard,
  required String medium,
}) {
  final marathi = medium == 'Marathi' ||
      (medium == 'Semi-English' &&
          (subjectKey == 'history' || subjectKey == 'geography'));
  switch (subjectKey) {
    case 'maths':
      if (marathi) {
        return standard <= 7
            ? [
                'संख्या आणि संख्या पद्धती',
                'बेरीज व वजाबाकी',
                'गुणाकार व भागाकार',
                'अपूर्णांक',
                'भूमिती आणि मापन'
              ]
            : [
                'वास्तव संख्या',
                'बहुपदी आणि बीजगणित',
                'रेषीय समीकरणे',
                'भूमिती',
                'सांख्यिकी व संभाव्यता'
              ];
      }
      return standard <= 7
          ? [
              'Numbers and Number Patterns',
              'Addition and Subtraction',
              'Multiplication and Division',
              'Fractions',
              'Shapes and Measurement'
            ]
          : [
              'Real Numbers',
              'Polynomials and Algebra',
              'Linear Equations',
              'Geometry',
              'Statistics and Probability'
            ];
    case 'science':
      if (marathi) {
        return standard <= 7
            ? [
                'सजीवांचे जग',
                'वनस्पती आणि प्राणी',
                'पदार्थ आणि त्यांचे गुणधर्म',
                'बल आणि ऊर्जा',
                'पर्यावरणाची काळजी'
              ]
            : [
                'सजीव आणि जीवनप्रक्रिया',
                'पदार्थ: रचना व गुणधर्म',
                'बल, गती आणि ऊर्जा',
                'प्रकाश व विद्युत',
                'पर्यावरण आणि तंत्रज्ञान'
              ];
      }
      return standard <= 7
          ? [
              'The Living World',
              'Plants and Animals',
              'Materials Around Us',
              'Force and Energy',
              'Caring for Our Environment'
            ]
          : [
              'Life Processes',
              'Matter: Structure and Properties',
              'Force, Motion and Energy',
              'Light and Electricity',
              'Environment and Technology'
            ];
    case 'history':
      if (marathi) {
        return [
          'इतिहासाची साधने',
          'प्राचीन भारत',
          'मध्ययुगीन भारत',
          'आधुनिक भारत',
          'भारतीय संविधान आणि नागरिक'
        ];
      }
      return [
        'Sources of History',
        'Ancient India',
        'Medieval India',
        'Modern India',
        'The Constitution and Citizenship'
      ];
    case 'geography':
      if (marathi) {
        return [
          'पृथ्वी आणि नकाशे',
          'हवामान आणि पर्जन्य',
          'नैसर्गिक संसाधने',
          'लोकसंख्या आणि वस्ती',
          'भारताचा भूगोल'
        ];
      }
      return [
        'Earth and Maps',
        'Weather and Rainfall',
        'Natural Resources',
        'Population and Settlements',
        'Geography of India'
      ];
    case 'marathi':
      return [
        'गद्य वाचन',
        'कविता आणि भावार्थ',
        'शब्दसंपत्ती',
        'व्याकरण',
        'लेखन कौशल्य'
      ];
    case 'hindi':
      return ['गद्य पाठ', 'कविता', 'शब्द भंडार', 'व्याकरण', 'लेखन कौशल'];
    case 'english':
      return [
        'Prose and Reading',
        'Poetry and Meaning',
        'Vocabulary',
        'Grammar in Use',
        'Writing Skills'
      ];
    case 'evs':
      if (medium == 'Marathi') {
        return [
          'माझे कुटुंब आणि शाळा',
          'आपला परिसर',
          'वनस्पती आणि प्राणी',
          'पाणी आणि हवा',
          'स्वच्छता आणि आरोग्य'
        ];
      }
      return [
        'My Family and School',
        'Our Neighbourhood',
        'Plants and Animals',
        'Water and Air',
        'Health and Cleanliness'
      ];
    default:
      return [
        'Explore the topic',
        'Key ideas',
        'Practice together',
        'Try an activity',
        'Quick revision'
      ];
  }
}

class _StudyPage extends StatelessWidget {
  const _StudyPage({
    required this.standard,
    required this.medium,
    required this.isKidsZone,
    required this.content,
    required this.profile,
    required this.profileLoading,
    required this.profileError,
    required this.subjectsKey,
    required this.onStandardChanged,
    required this.onMediumChanged,
    required this.onRetryProfile,
  });

  final int standard;
  final String medium;
  final bool isKidsZone;
  final _LearningContentStore content;
  final StudentProfile? profile;
  final bool profileLoading;
  final bool profileError;
  final GlobalKey subjectsKey;
  final ValueChanged<int> onStandardChanged;
  final ValueChanged<String> onMediumChanged;
  final VoidCallback onRetryProfile;

  @override
  Widget build(BuildContext context) {
    final notes = content.resources
        .where((r) =>
            r.standard == standard &&
            r.medium == medium &&
            r.target == 'Classroom')
        .toList()
        .reversed
        .map((r) => PortalItem(
              title: r.title,
              subtitle: '${r.subject} · ${r.fileName}',
              onOpen: () => _showResourcePreview(context, r),
            ))
        .toList();
    final videos = content.videos
        .where((v) =>
            v.standard == standard &&
            v.medium == medium &&
            v.target == 'Classroom')
        .toList()
        .reversed
        .map((v) => PortalItem(
              title: v.title,
              subtitle:
                  [v.subject, v.chapter].where((e) => e.isNotEmpty).join(' · '),
              onOpen: () async {
                final uri = Uri.tryParse(v.url);
                if (uri == null || !await launchUrl(uri)) {
                  debugPrint('Could not open video ${v.url}');
                }
              },
            ))
        .toList();
    final quizCount =
        content.quizzesForTarget(standard, 'Classroom', medium: medium).length;

    return _PageScroll(
      children: [
        StudentDashboard(
          standard: standard,
          medium: medium,
          profile: profile,
          loading: profileLoading,
          profileError: profileError,
          notes: notes,
          videos: videos,
          quizCount: quizCount,
          onStandardChanged: onStandardChanged,
          onMediumChanged: onMediumChanged,
          onRetry: onRetryProfile,
          onSubjects: () {
            final target = subjectsKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 350),
              );
            }
          },
          onQuiz: () => _showDailyQuiz(
            context,
            standard,
            medium: medium,
            content: content,
          ),
        ),
        const SizedBox(height: 17),
        _WelcomeBanner(
          isKidsZone: isKidsZone,
          standard: standard,
          medium: medium,
        ),
        if (isKidsZone) ...[
          const SizedBox(height: 13),
          const _KidsProgressStrip(),
        ],
        const SizedBox(height: 17),
        _DailyQuizBanner(
          isKidsZone: isKidsZone,
          medium: medium,
          onTap: () => _showDailyQuiz(
            context,
            standard,
            medium: medium,
            content: content,
          ),
        ),
        const SizedBox(height: 23),
        _SectionHeading(
          title: _mediumLabel(
            medium,
            marathi: isKidsZone
                ? 'बालविभाग · तुमचे विषय'
                : 'अभ्यास विभाग · तुमचे विषय',
            semiEnglish: isKidsZone
                ? 'Kids Zone / बालविभाग · Subjects / विषय'
                : 'Scholar Zone / अभ्यास विभाग · Subjects / विषय',
            english:
                isKidsZone ? 'Kids Zone · Subjects' : 'Scholar Zone · Subjects',
          ),
          subtitle: _mediumLabel(
            medium,
            marathi: isKidsZone
                ? 'इयत्ता ${_marathiNumber(standard)} · बालभारती अध्ययनक्रम'
                : 'महाराष्ट्र राज्य मंडळ · इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)}',
            semiEnglish:
                'Maharashtra State Board / महाराष्ट्र राज्य मंडळ · Std $standard · Semi-English',
            english:
                'Maharashtra State Board · Standard $standard · English medium',
          ),
          trailing: _mediumLabel(
            medium,
            marathi: isKidsZone ? 'पहा' : 'अभ्यासक्रम',
            semiEnglish: isKidsZone ? 'Explore / पहा' : 'Syllabus / अभ्यासक्रम',
            english: isKidsZone ? 'Explore' : 'Syllabus',
          ),
        ),
        const SizedBox(height: 13),
        KeyedSubtree(
          key: subjectsKey,
          child: _SubjectGrid(
            isKidsZone: isKidsZone,
            standard: standard,
            medium: medium,
            content: content,
          ),
        ),
        LiveCurriculumSection(
          standard: standard,
          medium: medium,
        ),
        const SizedBox(height: 23),
        _TeacherResourcesSection(
          content: content,
          standard: standard,
          medium: medium,
        ),
        const SizedBox(height: 14),
        _ForeignLanguageLabCard(
          standard: standard,
          medium: medium,
          content: content,
        ),
        const SizedBox(height: 20),
        if (isKidsZone) ...[
          _SectionHeading(
            title: _mediumLabel(
              medium,
              marathi: 'बालविभाग · खेळा आणि शिका',
              semiEnglish:
                  'Kids Zone / बालविभाग · Play & Learn / खेळा आणि शिका',
              english: 'Kids Zone · Play & Learn',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'गोष्टी, अक्षरध्वनी धडे आणि मजेदार कोडी.',
              semiEnglish:
                  'Stories, phonics & puzzles / गोष्टी, ध्वनी आणि कोडी',
              english: 'Stories, phonics lessons and fun puzzles.',
            ),
          ),
          const SizedBox(height: 13),
          _FeatureCard(
            icon: Icons.auto_stories_rounded,
            iconColor: const Color(0xFF9A64BD),
            eyebrow: _mediumLabel(
              medium,
              marathi: 'बालभारती · वाचा आणि ऐका',
              semiEnglish: 'Balbharati / बालभारती · Read & Listen',
              english: 'Balbharati · Read & Listen',
            ),
            title: _mediumLabel(
              medium,
              marathi: 'बालभारतीच्या गोष्टी',
              semiEnglish: 'Balbharati Stories / बालभारतीच्या गोष्टी',
              english: 'Balbharati Stories',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'छोटी गोष्ट वाचा, लक्षपूर्वक ऐका आणि नवे शब्द शिका.',
              semiEnglish:
                  'Read a story, listen and learn new words / गोष्ट वाचा आणि नवे शब्द शिका.',
              english:
                  'Read a short story, listen carefully and discover new words.',
            ),
            action: _mediumLabel(
              medium,
              marathi: 'गोष्ट वाचा',
              semiEnglish: 'Read a story / गोष्ट वाचा',
              english: 'Read a story',
            ),
            onTap: () => _showKidsActivity(
              context,
              standard: standard,
              medium: medium,
              content: content,
              title: _mediumLabel(
                medium,
                marathi: 'बालभारतीची गोष्ट',
                semiEnglish: 'Balbharati Story / बालभारतीची गोष्ट',
                english: 'A Balbharati Story',
              ),
              english:
                  'Read a short story with a family member. Notice who the characters are and what they learn.',
              marathi:
                  'कुटुंबातील व्यक्तीसोबत छोटी गोष्ट वाचा. पात्रे कोण आहेत आणि त्यांना काय शिकायला मिळते ते पाहा.',
            ),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.record_voice_over_rounded,
            iconColor: const Color(0xFF198B78),
            eyebrow: _mediumLabel(
              medium,
              marathi: 'इंग्रजी अक्षरध्वनी · ध्वनिचित्र',
              semiEnglish: 'English Phonics / इंग्रजी अक्षरध्वनी',
              english: 'English Phonics · Video',
            ),
            title: _mediumLabel(
              medium,
              marathi: 'अक्षरांचे ध्वनी ओळखा',
              semiEnglish: 'Sound it out / अक्षरध्वनी ओळखा',
              english: 'Sound it out!',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'अक्षरांचे ध्वनी जोडून नवे शब्द वाचण्याचा सराव करा.',
              semiEnglish:
                  'Practise letter sounds and blend them into words / अक्षरध्वनी जोडून शब्द वाचा.',
              english:
                  'Practise letter sounds and blend them to read a new word.',
            ),
            action: _mediumLabel(
              medium,
              marathi: 'धडा पहा',
              semiEnglish: 'Watch lesson / धडा पहा',
              english: 'Watch phonics lesson',
            ),
            onTap: () => _showVideoLesson(
              context,
              content: content,
              medium: medium,
              standard: standard,
              subject: 'इंग्रजी अक्षरध्वनी',
              chapter: 'अक्षरध्वनी आणि शब्दजोड',
              onCompleted: () => content.studyCompletions++,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.extension_rounded,
            iconColor: const Color(0xFF5467D8),
            eyebrow: _mediumLabel(
              medium,
              marathi: 'गणिती कोडे',
              semiEnglish: 'Math Puzzle / गणिती कोडे',
              english: 'Math Puzzle',
            ),
            title: _mediumLabel(
              medium,
              marathi: 'संख्यांचे छोटे आव्हान',
              semiEnglish: 'Number Challenge / संख्यांचे आव्हान',
              english: 'A Little Number Challenge',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'झटपट प्रश्न सोडवा आणि प्रगतीचा आनंद साजरा करा.',
              semiEnglish:
                  'Solve a quick question and celebrate your progress / झटपट प्रश्न सोडवा.',
              english: 'Solve a quick question and celebrate your progress.',
            ),
            action: _mediumLabel(
              medium,
              marathi: 'कोडे सोडवा',
              semiEnglish: 'Try a puzzle / कोडे सोडवा',
              english: 'Try a puzzle',
            ),
            onTap: () => _showDailyQuiz(
              context,
              standard,
              medium: medium,
              content: content,
            ),
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.nature_people_rounded,
            iconColor: const Color(0xFFE28A38),
            eyebrow: _mediumLabel(
              medium,
              marathi: 'परिसर अभ्यास',
              semiEnglish: 'EVS / परिसर अभ्यास',
              english: 'Environmental Studies',
            ),
            title: _mediumLabel(
              medium,
              marathi: 'सभोवतालचे जग जाणून घ्या',
              semiEnglish: 'Explore Your World / परिसर जाणून घ्या',
              english: 'Explore the World Around You',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'निसर्ग, माणसे आणि परिसरातील ठिकाणे न्याहाळा.',
              semiEnglish:
                  'Notice nature, people and places / निसर्ग व परिसर न्याहाळा.',
              english: 'Notice nature, people and places in your community.',
            ),
            action: _mediumLabel(
              medium,
              marathi: 'शोधा',
              semiEnglish: 'Explore / शोधा',
              english: 'Explore',
            ),
            onTap: () => _showKidsActivity(
              context,
              standard: standard,
              medium: medium,
              content: content,
              title: _mediumLabel(
                medium,
                marathi: 'तुमचा परिसर जाणून घ्या',
                semiEnglish: 'Explore Your Surroundings / परिसर जाणून घ्या',
                english: 'Explore Your Surroundings',
              ),
              english:
                  'Find one plant near you. What colour are its leaves, and what does it need to grow?',
              marathi:
                  'तुमच्या जवळची एक वनस्पती पाहा. तिच्या पानांचा रंग कोणता आहे आणि तिला वाढण्यासाठी कशाची गरज आहे?',
            ),
          ),
        ] else ...[
          _ExamPrepCard(standard: standard, medium: medium),
        ],
        if (standard == 4 ||
            standard == 5 ||
            standard == 7 ||
            standard == 8) ...[
          const SizedBox(height: 13),
          _CompetitiveExamHub(
            standard: standard,
            medium: medium,
            content: content,
          ),
        ],
        const SizedBox(height: 22),
        _PremiumUpgradeCard(
          medium: medium,
          onTap: () => _showPremiumCheckout(
            context,
            standard: standard,
            medium: medium,
          ),
        ),
      ],
    );
  }
}

class _ForeignLanguageLabCard extends StatelessWidget {
  const _ForeignLanguageLabCard({
    required this.standard,
    required this.medium,
    required this.content,
  });

  final int standard;
  final String medium;
  final _LearningContentStore content;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF0F7FF),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFDDEBFF),
          child: Icon(Icons.public_rounded, color: Color(0xFF3659C9)),
        ),
        title: Text(
          _mediumLabel(
            medium,
            marathi: 'परदेशी भाषा प्रयोगशाळा',
            semiEnglish: 'Foreign Language Lab / परदेशी भाषा प्रयोगशाळा',
            english: 'Foreign Language Lab',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          _mediumLabel(
            medium,
            marathi: 'स्पॅनिश · फ्रेंच · जर्मन | शब्द, उच्चार आणि संभाषण',
            semiEnglish:
                'Spanish, French & German / स्पॅनिश, फ्रेंच, जर्मन · Words & Speaking',
            english: 'Spanish, French & German · Vocabulary & Conversation',
          ),
          style: TextStyle(fontSize: 11, height: 1.35),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () => _showForeignLanguageLab(
          context,
          standard: standard,
          medium: medium,
          content: content,
        ),
      ),
    );
  }
}

class _CompetitiveExamHub extends StatelessWidget {
  const _CompetitiveExamHub({
    required this.standard,
    required this.medium,
    required this.content,
  });

  final int standard;
  final String medium;
  final _LearningContentStore content;

  @override
  Widget build(BuildContext context) {
    final targets = switch (standard) {
      4 || 7 => const ['Scholarship'],
      5 || 8 => const ['Navodaya', 'Sainik School'],
      _ => const <String>[],
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFFC47B17)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _mediumLabel(
                      medium,
                      marathi: 'स्पर्धा परीक्षा केंद्र',
                      semiEnglish:
                          'Competitive Exam Hub / स्पर्धा परीक्षा केंद्र',
                      english: 'Competitive Exam Hub',
                    ),
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _mediumLabel(
                medium,
                marathi:
                    'इयत्ता ${_marathiNumber(standard)} · सराव चाचण्या, नमुना प्रश्नपत्रिका, मागील वर्षांच्या धर्तीवरील परीक्षा आणि सोप्या युक्त्या.',
                semiEnglish:
                    'Std $standard · Practice tests, mock papers & shortcut tricks / सराव चाचण्या व सोप्या युक्त्या',
                english:
                    'Standard $standard · Practice tests, mock papers and shortcut tricks.',
              ),
              style: const TextStyle(
                color: Color(0xFF68718A),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 11),
            for (final target in targets)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showExamModule(
                      context,
                      standard: standard,
                      medium: medium,
                      target: target,
                      content: content,
                    ),
                    icon: Icon(
                      target == 'Scholarship'
                          ? Icons.workspace_premium_rounded
                          : Icons.school_rounded,
                    ),
                    label: Text(_examTitle(standard, target, medium)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _examTitle(int standard, String target, String medium) {
  final marathi = switch (target) {
    'Scholarship' => standard == 4
        ? 'पूर्वोन्नती शिष्यवृत्ती परीक्षा'
        : 'मध्योन्नती शिष्यवृत्ती परीक्षा',
    'Navodaya' => 'जवाहर नवोदय विद्यालय निवड परीक्षा',
    'Sainik School' => 'सैनिक शाळा प्रवेश परीक्षा',
    _ => target,
  };
  final english = switch (target) {
    'Scholarship' => standard == 4
        ? 'Purvonnati Scholarship Examination'
        : 'Madhyonnati Scholarship Examination',
    'Navodaya' => 'Jawahar Navodaya Vidyalaya Selection Test',
    'Sainik School' => 'Sainik School Entrance Examination',
    _ => target,
  };
  return _mediumLabel(
    medium,
    marathi: marathi,
    semiEnglish: '$english / $marathi',
    english: english,
  );
}

class _PracticeQuestion {
  const _PracticeQuestion({
    required this.subject,
    required this.question,
    required this.options,
    required this.answerIndex,
  });

  final String subject;
  final String question;
  final List<String> options;
  final int answerIndex;
}

List<_PracticeQuestion> _examQuestions(String target, String medium) {
  if (medium != 'Marathi') {
    final questions = _examQuestionsEnglish(target);
    if (medium == 'English') return questions;
    final marathi = _examQuestionsMarathi(target);
    return [
      for (var i = 0; i < questions.length; i++)
        _PracticeQuestion(
          subject: '${questions[i].subject} / ${marathi[i].subject}',
          question: '${questions[i].question} / ${marathi[i].question}',
          options: [
            for (var j = 0; j < questions[i].options.length; j++)
              '${questions[i].options[j]} / ${marathi[i].options[j]}',
          ],
          answerIndex: questions[i].answerIndex,
        ),
    ];
  }
  return _examQuestionsMarathi(target);
}

List<_PracticeQuestion> _examQuestionsEnglish(String target) {
  if (target == 'Scholarship') {
    return const [
      _PracticeQuestion(
        subject: 'Mental Ability',
        question: 'Complete the sequence: 2, 4, 8, 16, __',
        options: ['18', '24', '32', '30'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'Reasoning',
        question: 'Which shape is different from the others?',
        options: ['Triangle', 'Square', 'Circle', 'Rectangle'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'Arithmetic',
        question: 'What is 3/4 of 20?',
        options: ['12', '15', '16', '18'],
        answerIndex: 1,
      ),
    ];
  }
  if (target == 'Navodaya') {
    return const [
      _PracticeQuestion(
        subject: 'Mental Ability',
        question: 'Find the next number: 5, 10, 20, 40, __',
        options: ['45', '60', '80', '100'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'Arithmetic',
        question: 'A box has 24 pencils. How many pencils are in 3 boxes?',
        options: ['62', '68', '72', '84'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'Language',
        question: 'Choose the word closest in meaning to “brave”.',
        options: ['Courageous', 'Careless', 'Quiet', 'Tired'],
        answerIndex: 0,
      ),
    ];
  }
  return const [
    _PracticeQuestion(
      subject: 'Mental Ability',
      question: 'If A=1, B=2, C=3, what is the value of CAB?',
      options: ['312', '321', '123', '213'],
      answerIndex: 0,
    ),
    _PracticeQuestion(
      subject: 'Arithmetic',
      question: 'A train travels 60 km in 2 hours. What is its speed?',
      options: ['20 km/h', '30 km/h', '40 km/h', '120 km/h'],
      answerIndex: 1,
    ),
    _PracticeQuestion(
      subject: 'Language',
      question: 'Choose the correctly spelled word.',
      options: ['School', 'Skool', 'Scool', 'Shcool'],
      answerIndex: 0,
    ),
  ];
}

List<_PracticeQuestion> _examQuestionsMarathi(String target) {
  if (target == 'Scholarship') {
    return const [
      _PracticeQuestion(
        subject: 'मानसिक क्षमता',
        question: 'मालिकेतील पुढील संख्या ओळखा: २, ४, ८, १६, __',
        options: ['१८', '२४', '३२', '३०'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'तर्कशक्ती',
        question: 'इतरांपेक्षा वेगळा आकार कोणता?',
        options: ['त्रिकोण', 'चौरस', 'वर्तुळ', 'आयत'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'गणित',
        question: '२० चा ३/४ भाग किती?',
        options: ['१२', '१५', '१६', '१८'],
        answerIndex: 1,
      ),
    ];
  }
  if (target == 'Navodaya') {
    return const [
      _PracticeQuestion(
        subject: 'Mental Ability',
        question: 'पुढील संख्या ओळखा: ५, १०, २०, ४०, __',
        options: ['४५', '६०', '८०', '१००'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'Arithmetic',
        question:
            'एका पेटीत २४ पेन्सिली आहेत. अशा ३ पेट्यांत किती पेन्सिली असतील?',
        options: ['६२', '६८', '७२', '८४'],
        answerIndex: 2,
      ),
      _PracticeQuestion(
        subject: 'Language',
        question: '“धाडसी” या शब्दाचा समानार्थी शब्द निवडा.',
        options: ['शूर', 'निष्काळजी', 'शांत', 'थकलेला'],
        answerIndex: 0,
      ),
    ];
  }
  return const [
    _PracticeQuestion(
      subject: 'मानसिक क्षमता',
      question: 'अ=१, ब=२, क=३ असल्यास “कअब” या क्रमाचे मूल्य काय?',
      options: ['३१२', '३२१', '१२३', '२१३'],
      answerIndex: 0,
    ),
    _PracticeQuestion(
      subject: 'अंकगणित',
      question: 'आगगाडी २ तासांत ६० किमी जाते. तिचा वेग किती?',
      options: ['२० किमी/तास', '३० किमी/तास', '४० किमी/तास', '१२० किमी/तास'],
      answerIndex: 1,
    ),
    _PracticeQuestion(
      subject: 'भाषा',
      question: '“शाळा” या शब्दाचे योग्य लेखन निवडा.',
      options: ['शाळा', 'शाला', 'शळा', 'शाळ'],
      answerIndex: 0,
    ),
  ];
}

List<String> _examShortcuts(String target) {
  if (target == 'Scholarship') {
    return const [
      'मालिकेतील सलग पदांमधील नियम ओळखून मग उत्तर काढा.',
      'आधी अंदाज करा; अशक्य पर्याय बाद करून योग्य उत्तर निवडा.',
      'अपूर्णांकांचा गुणाकार करण्यापूर्वी समान अवयव रद्द करा.',
    ];
  }
  return const [
    'आकार फिरवणे, प्रतिबिंब, संख्या-मालिका आणि गट तयार करण्याचे नियम शोधा.',
    'क्रिया निवडण्यापूर्वी दिलेली माहिती आणि विचारलेले एकक अधोरेखित करा.',
    'संपूर्ण वाक्य वाचा; संदर्भावरून अयोग्य पर्याय बाद करा.',
  ];
}

void _showExamModule(
  BuildContext context, {
  required int standard,
  required String medium,
  required String target,
  required _LearningContentStore content,
}) {
  final teacherQuizzes =
      content.quizzesForTarget(standard, target, medium: medium);
  final teacherNotes = content.resources
      .where((resource) =>
          resource.standard == standard &&
          resource.medium == medium &&
          resource.target == target)
      .toList()
      .reversed
      .toList();
  final targetQuestions = _examQuestions(target, medium);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _examTitle(standard, target, medium),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            _mediumLabel(
              medium,
              marathi:
                  'इयत्ता ${_marathiNumber(standard)} · ${target == 'Scholarship' ? 'मानसिक क्षमता आणि शैक्षणिक क्षमता' : 'मानसिक क्षमता · अंकगणित · भाषा'}',
              semiEnglish:
                  'Std $standard · ${target == 'Scholarship' ? 'Mental Ability & Scholastic Aptitude / मानसिक क्षमता व शैक्षणिक क्षमता' : 'Mental Ability / मानसिक क्षमता · Arithmetic / अंकगणित · Language / भाषा'}',
              english:
                  'Standard $standard · ${target == 'Scholarship' ? 'Mental Ability & Scholastic Aptitude' : 'Mental Ability · Arithmetic · Language'}',
            ),
            style: const TextStyle(color: Color(0xFF68718A), fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final area
              in targetQuestions.map((item) => item.subject).toSet())
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Chip(
                avatar:
                    const Icon(Icons.check_circle_outline_rounded, size: 17),
                label: Text(area),
              ),
            ),
          const SizedBox(height: 8),
          _examAction(
            context,
            icon: Icons.quiz_rounded,
            title: _mediumLabel(
              medium,
              marathi: 'सराव चाचणी',
              semiEnglish: 'Practice Test / सराव चाचणी',
              english: 'Practice Test',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'इयत्तेनुसार तीन नमुना प्रश्न.',
              semiEnglish: 'Three sample questions / तीन नमुना प्रश्न',
              english: 'Three standard-specific sample questions.',
            ),
            onTap: () => _runPracticeQuiz(
              context,
              title: _mediumLabel(
                medium,
                marathi: 'सराव चाचणी',
                semiEnglish: 'Practice Test / सराव चाचणी',
                english: 'Practice Test',
              ),
              questions: targetQuestions,
              content: content,
              standard: standard,
            ),
          ),
          _examAction(
            context,
            icon: Icons.timer_outlined,
            title: _mediumLabel(
              medium,
              marathi: 'नमुना परीक्षा',
              semiEnglish: 'Mock Test / नमुना परीक्षा',
              english: 'Mock Test',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi: 'इयत्तेनुसार प्रश्नपत्रिका सोडवण्याचा सराव.',
              semiEnglish: 'Mock paper practice / नमुना प्रश्नपत्रिका सराव',
              english: 'Standard-specific mock paper practice.',
            ),
            onTap: () => _runPracticeQuiz(
              context,
              title: _mediumLabel(
                medium,
                marathi: 'नमुना परीक्षा',
                semiEnglish: 'Mock Test / नमुना परीक्षा',
                english: 'Mock Test',
              ),
              questions: targetQuestions.reversed.toList(),
              content: content,
              standard: standard,
            ),
          ),
          _examAction(
            context,
            icon: Icons.history_edu_rounded,
            title: _mediumLabel(
              medium,
              marathi: 'मागील वर्षांच्या धर्तीवरील प्रश्नपत्रिका',
              semiEnglish:
                  'Previous-year style paper / मागील वर्षांच्या धर्तीवरील पेपर',
              english: 'Previous-year style paper simulation',
            ),
            subtitle: _mediumLabel(
              medium,
              marathi:
                  'हा सरावासाठी नमुना आहे; अधिकृत जुनी प्रश्नपत्रिका नाही.',
              semiEnglish:
                  'Practice sample only; not an official past paper / हा सराव नमुना आहे.',
              english: 'Practice sample only; not an official archived paper.',
            ),
            onTap: () => _runPracticeQuiz(
              context,
              title: _mediumLabel(
                medium,
                marathi: 'मागील वर्षांच्या धर्तीवरील सराव',
                semiEnglish:
                    'Previous-year style practice / मागील वर्षांचा सराव',
                english: 'Previous-year style practice',
              ),
              questions: targetQuestions,
              content: content,
              standard: standard,
            ),
          ),
          ExpansionTile(
            leading: const Icon(Icons.bolt_rounded, color: Color(0xFFC47B17)),
            title: Text(_mediumLabel(
              medium,
              marathi: 'झटपट युक्त्या',
              semiEnglish: 'Shortcut Tricks / झटपट युक्त्या',
              english: 'Shortcut Tricks',
            )),
            children: [
              for (var index = 0;
                  index < _examShortcuts(target).length;
                  index++)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.lightbulb_outline_rounded),
                  title: Text(
                    _mediumLabel(
                      medium,
                      marathi: _examShortcuts(target)[index],
                      semiEnglish:
                          '${_examShortcutsEnglish(target)[index]} / ${_examShortcuts(target)[index]}',
                      english: _examShortcutsEnglish(target)[index],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
          if (teacherQuizzes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionHeading(
              title: 'शिक्षकांनी दिलेले सराव प्रश्न',
              subtitle: 'या परीक्षेसाठी शिक्षकांनी सामायिक केलेले प्रश्न.',
            ),
            for (final quiz in teacherQuizzes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.assignment_outlined),
                title: Text(quiz.question),
                subtitle: Text(_assessmentLabel(quiz.assessmentType)),
                onTap: () => _runPracticeQuiz(
                  context,
                  title: _assessmentLabel(quiz.assessmentType),
                  questions: [
                    _PracticeQuestion(
                      subject: target,
                      question: quiz.question,
                      options: quiz.options,
                      answerIndex: quiz.correctIndex,
                    ),
                  ],
                  content: content,
                  standard: standard,
                ),
              ),
          ],
          if (teacherNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const _SectionHeading(
              title: 'शिक्षकांच्या अभ्यास टिपा',
              subtitle: 'परीक्षेसाठी पीडीएफ आणि उजळणी साहित्य.',
            ),
            for (final note in teacherNotes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text(note.title),
                subtitle: Text('${note.subject} · ${note.fileName}'),
                onTap: () => _showResourcePreview(context, note),
              ),
          ],
        ],
      ),
    ),
  );
}

Widget _examAction(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) =>
    Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.play_arrow_rounded),
        onTap: onTap,
      ),
    );

void _runPracticeQuiz(
  BuildContext context, {
  required String title,
  required List<_PracticeQuestion> questions,
  required _LearningContentStore content,
  required int standard,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var questionIndex = 0;
      var score = 0;
      int? selectedIndex;
      var completed = false;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final question = questions[questionIndex];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                if (completed)
                  Text('Completed · Score $score / ${questions.length}')
                else ...[
                  Text(
                    'Question ${questionIndex + 1} of ${questions.length} · ${question.subject}',
                    style:
                        const TextStyle(color: Color(0xFF68718A), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(question.question,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  RadioGroup<int>(
                    groupValue: selectedIndex,
                    onChanged: (value) =>
                        setSheetState(() => selectedIndex = value),
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < question.options.length;
                            index++)
                          RadioListTile<int>(
                            value: index,
                            contentPadding: EdgeInsets.zero,
                            title: Text(question.options[index]),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: completed
                        ? () => Navigator.pop(sheetContext)
                        : () {
                            if (selectedIndex == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Choose an answer first.'),
                                ),
                              );
                              return;
                            }
                            setSheetState(() {
                              if (selectedIndex == question.answerIndex) {
                                score++;
                              }
                              if (questionIndex + 1 == questions.length) {
                                completed = true;
                                content.quizCompletions++;
                              } else {
                                questionIndex++;
                                selectedIndex = null;
                              }
                            });
                          },
                    child: Text(completed
                        ? 'Close · बंद करा'
                        : questionIndex + 1 == questions.length
                            ? 'Finish test · चाचणी पूर्ण करा'
                            : 'Next · पुढे'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showForeignLanguageLab(
  BuildContext context, {
  required int standard,
  required String medium,
  required _LearningContentStore content,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var language = 'Spanish';
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final words = _localizedLanguageWords(language, medium);
          final phrases = _localizedLanguagePhrases(language, medium);
          final notes = content.resources
              .where((resource) =>
                  resource.standard == standard &&
                  resource.medium == medium &&
                  resource.target == language)
              .toList()
              .reversed
              .toList();
          final quizzes = content.quizzesForTarget(
            standard,
            language,
            medium: medium,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mediumLabel(
                    medium,
                    marathi: 'परदेशी भाषा अध्ययन प्रयोगशाळा',
                    semiEnglish:
                        'Foreign Language Lab / परदेशी भाषा प्रयोगशाळा',
                    english: 'Foreign Language Lab',
                  ),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  _mediumLabel(
                    medium,
                    marathi:
                        'इयत्ता ${_marathiNumber(standard)} साठी प्राथमिक धडे · ध्वनी बटणे उच्चाराचे प्रात्यक्षिक आहेत.',
                    semiEnglish:
                        'Intro modules for Standard $standard · Pronunciation buttons are simulations / उच्चाराचे प्रात्यक्षिक',
                    english:
                        'Introductory modules for Standard $standard · Audio buttons simulate pronunciation.',
                  ),
                  style:
                      const TextStyle(color: Color(0xFF68718A), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final item in _foreignLanguageTargets)
                      ChoiceChip(
                        label: Text(_mediumLabel(
                          medium,
                          marathi: _languageMarathiName(item),
                          semiEnglish: '$item / ${_languageMarathiName(item)}',
                          english: item,
                        )),
                        selected: language == item,
                        onSelected: (_) => setSheetState(() => language = item),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_languageGreeting(language, medium),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                _SectionHeading(
                  title: _mediumLabel(
                    medium,
                    marathi: 'मूलभूत शब्दसंग्रह',
                    semiEnglish: 'Vocabulary / शब्दसंग्रह',
                    english: 'Basic Vocabulary',
                  ),
                  subtitle: _mediumLabel(
                    medium,
                    marathi: 'उच्चाराचे प्रात्यक्षिक ऐका आणि पुन्हा म्हणा.',
                    semiEnglish:
                        'Listen to the pronunciation simulation and repeat / ऐका आणि पुन्हा म्हणा.',
                    english:
                        'Listen to the pronunciation simulation and repeat.',
                  ),
                ),
                for (var wordIndex = 0; wordIndex < words.length; wordIndex++)
                  Card(
                    margin: const EdgeInsets.only(top: 6),
                    child: ListTile(
                      title: Text(words[wordIndex].$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      subtitle: Text(
                        '${words[wordIndex].$2} · ${_mediumLabel(medium, marathi: 'उच्चार', semiEnglish: 'Pronunciation / उच्चार', english: 'Pronunciation')}: ${words[wordIndex].$3}',
                      ),
                      trailing: IconButton(
                        tooltip: _mediumLabel(
                          medium,
                          marathi: 'उच्चार ऐका',
                          semiEnglish: 'Play pronunciation / उच्चार ऐका',
                          english: 'Play pronunciation',
                        ),
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(_mediumLabel(
                            medium,
                            marathi:
                                'उच्चाराचे प्रात्यक्षिक: ${words[wordIndex].$1} (${words[wordIndex].$3})',
                            semiEnglish:
                                'Pronunciation: ${words[wordIndex].$1} (${words[wordIndex].$3})',
                            english:
                                'Pronunciation simulation: ${words[wordIndex].$1} (${words[wordIndex].$3})',
                          )),
                        )),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _SectionHeading(
                  title: _mediumLabel(
                    medium,
                    marathi: 'दैनंदिन संभाषण',
                    semiEnglish: 'Conversation / संभाषण',
                    english: 'Everyday Conversation',
                  ),
                  subtitle: _mediumLabel(
                    medium,
                    marathi: 'अभिवादन आणि उपयोगी वाक्ये.',
                    semiEnglish:
                        'Greetings and useful phrases / अभिवादन व वाक्ये',
                    english: 'Greetings and useful phrases.',
                  ),
                ),
                for (var phraseIndex = 0;
                    phraseIndex < phrases.length;
                    phraseIndex++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text(phrases[phraseIndex].$1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(phrases[phraseIndex].$2),
                    trailing: IconButton(
                      tooltip: _mediumLabel(
                        medium,
                        marathi: 'वाक्याचा उच्चार ऐका',
                        semiEnglish: 'Play phrase / वाक्य ऐका',
                        english: 'Play phrase pronunciation',
                      ),
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_mediumLabel(
                          medium,
                          marathi:
                              'उच्चाराचे प्रात्यक्षिक: ${phrases[phraseIndex].$1} (${phrases[phraseIndex].$3})',
                          semiEnglish:
                              'Pronunciation: ${phrases[phraseIndex].$1} (${phrases[phraseIndex].$3})',
                          english:
                              'Pronunciation simulation: ${phrases[phraseIndex].$1} (${phrases[phraseIndex].$3})',
                        )),
                      )),
                    ),
                  ),
                if (quizzes.isNotEmpty) ...[
                  _SectionHeading(
                    title: _mediumLabel(
                      medium,
                      marathi: 'शिक्षकांनी तयार केलेला भाषा सराव',
                      semiEnglish:
                          'Teacher Language Practice / शिक्षकांचा भाषा सराव',
                      english: 'Teacher Language Practice',
                    ),
                    subtitle: _mediumLabel(
                      medium,
                      marathi: 'तुमच्या इयत्तेसाठी तयार केलेले प्रश्न.',
                      semiEnglish:
                          'Questions set for your standard / तुमच्या इयत्तेचे प्रश्न',
                      english: 'Custom questions for your standard.',
                    ),
                  ),
                  for (final quiz in quizzes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(quiz.question),
                      subtitle: Text(_assessmentLabel(quiz.assessmentType)),
                      onTap: () => _runPracticeQuiz(
                        context,
                        title: '${_languageMarathiName(language)} सराव',
                        questions: [
                          _PracticeQuestion(
                            subject: language,
                            question: quiz.question,
                            options: quiz.options,
                            answerIndex: quiz.correctIndex,
                          ),
                        ],
                        content: content,
                        standard: standard,
                      ),
                    ),
                ],
                if (notes.isNotEmpty) ...[
                  _SectionHeading(
                    title: _mediumLabel(
                      medium,
                      marathi: 'शिक्षकांच्या टिपा',
                      semiEnglish: 'Teacher Notes / शिक्षकांच्या टिपा',
                      english: 'Teacher Notes',
                    ),
                    subtitle: _mediumLabel(
                      medium,
                      marathi: 'विद्यार्थ्यांसाठी सामायिक केलेले भाषा साहित्य.',
                      semiEnglish:
                          'Language resources for students / भाषा साहित्य',
                      english: 'Language resources shared with students.',
                    ),
                  ),
                  for (final note in notes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_rounded),
                      title: Text(note.title),
                      subtitle: Text('${note.subject} · ${note.fileName}'),
                      onTap: () => _showResourcePreview(context, note),
                    ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

String _languageMarathiName(String language) => switch (language) {
      'Spanish' => 'स्पॅनिश',
      'French' => 'फ्रेंच',
      'German' => 'जर्मन',
      _ => language,
    };

String _languageGreeting(String language, String medium) {
  final greeting = switch (language) {
    'Spanish' => '¡Hola!',
    'French' => 'Bonjour!',
    _ => 'Hallo!',
  };
  final marathiName = _languageMarathiName(language);
  return _mediumLabel(
    medium,
    marathi: '$greeting · नमस्कार! $marathiName शिकूया.',
    semiEnglish: '$greeting · Hello / नमस्कार! Let’s learn $language.',
    english: '$greeting · Hello! Let’s learn $language.',
  );
}

const _languageWords = {
  'Spanish': [
    ('Hola', 'नमस्कार', 'ओ-ला'),
    ('Gracias', 'धन्यवाद', 'ग्रा-सियास'),
    ('Agua', 'पाणी', 'आ-ग्वा'),
    ('Amigo / Amiga', 'मित्र / मैत्रीण', 'अ-मी-गो / अ-मी-गा'),
  ],
  'French': [
    ('Bonjour', 'नमस्कार', 'बों-झूर'),
    ('Merci', 'धन्यवाद', 'मेर्सी'),
    ('Eau', 'पाणी', 'ओ'),
    ('Ami / Amie', 'मित्र / मैत्रीण', 'अ-मी'),
  ],
  'German': [
    ('Hallo', 'नमस्कार', 'हा-लो'),
    ('Danke', 'धन्यवाद', 'डान-क'),
    ('Wasser', 'पाणी', 'वासर'),
    ('Freund / Freundin', 'मित्र / मैत्रीण', 'फ्रॉइंट / फ्रॉइंडिन'),
  ],
};

const _languagePhrases = {
  'Spanish': [
    ('¿Cómo estás?', 'तुम्ही कसे आहात?', 'कोमो एस्तास'),
    ('Me llamo ...', 'माझे नाव ... आहे.', 'मे यामो'),
    ('Por favor', 'कृपया', 'पोर फावोर'),
  ],
  'French': [
    ('Comment ça va?', 'तुम्ही कसे आहात?', 'कोमाँ सा वा'),
    ("Je m'appelle ...", 'माझे नाव ... आहे.', 'झ मापेल'),
    ("S'il vous plaît", 'कृपया', 'सिल वू प्ले'),
  ],
  'German': [
    ('Wie geht es dir?', 'तुम्ही कसे आहात?', 'वी गेट एस डीर'),
    ('Ich heiße ...', 'माझे नाव ... आहे.', 'इख हायसे'),
    ('Bitte', 'कृपया', 'बिट्टे'),
  ],
};

String _languageGlossEnglish(String language, int index) {
  const glosses = {
    'Spanish': ['Hello', 'Thank you', 'Water', 'Friend'],
    'French': ['Hello / Good day', 'Thank you', 'Water', 'Friend'],
    'German': ['Hello', 'Thank you', 'Water', 'Friend'],
  };
  return glosses[language]![index];
}

List<(String, String, String)> _localizedLanguageWords(
  String language,
  String medium,
) {
  final words = _languageWords[language]!;
  return [
    for (var index = 0; index < words.length; index++)
      (
        words[index].$1,
        _mediumLabel(
          medium,
          marathi: words[index].$2,
          semiEnglish:
              '${_languageGlossEnglish(language, index)} / ${words[index].$2}',
          english: _languageGlossEnglish(language, index),
        ),
        words[index].$3,
      ),
  ];
}

List<(String, String, String)> _localizedLanguagePhrases(
  String language,
  String medium,
) {
  final phrases = _languagePhrases[language]!;
  const englishPhrases = {
    'Spanish': ['How are you?', 'My name is ...', 'Please'],
    'French': ['How are you?', 'My name is ...', 'Please'],
    'German': ['How are you?', 'My name is ...', 'Please'],
  };
  return [
    for (var index = 0; index < phrases.length; index++)
      (
        phrases[index].$1,
        _mediumLabel(
          medium,
          marathi: phrases[index].$2,
          semiEnglish:
              '${englishPhrases[language]![index]} / ${phrases[index].$2}',
          english: englishPhrases[language]![index],
        ),
        phrases[index].$3,
      ),
  ];
}

class _TeacherResourcesSection extends StatelessWidget {
  const _TeacherResourcesSection({
    required this.content,
    required this.standard,
    required this.medium,
  });

  final _LearningContentStore content;
  final int standard;
  final String medium;

  @override
  Widget build(BuildContext context) {
    final resources = content.resources
        .where(
          (resource) =>
              resource.standard == standard &&
              resource.medium == medium &&
              resource.target == 'Classroom',
        )
        .toList()
        .reversed
        .toList();
    if (resources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: _mediumLabel(
            medium,
            marathi: 'शिक्षकांनी जोडलेले साहित्य',
            semiEnglish: 'Teacher Resources / शिक्षकांचे साहित्य',
            english: 'Teacher Resources',
          ),
          subtitle: _mediumLabel(
            medium,
            marathi: 'तुमच्या इयत्तेसाठी पीडीएफ पुस्तके आणि प्रकरणांच्या टिपा.',
            semiEnglish: 'PDF books & chapter notes / पीडीएफ पुस्तके व टिपा',
            english: 'PDF books and chapter notes for your standard.',
          ),
        ),
        const SizedBox(height: 10),
        for (final resource in resources)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF0FF),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFF425DC3),
                  ),
                ),
                title: Text(
                  resource.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${resource.subject} · ${resource.fileName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'पीडीएफ नमुना उघडा',
                  onPressed: () => _showResourcePreview(context, resource),
                  icon: const Icon(Icons.download_for_offline_outlined),
                ),
                onTap: () => _showResourcePreview(context, resource),
              ),
            ),
          ),
      ],
    );
  }
}

void _showResourcePreview(BuildContext context, _LearningResource resource) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.picture_as_pdf_rounded,
        color: Color(0xFF425DC3),
      ),
      title: Text(resource.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${resource.subject} · Standard ${resource.standard}'),
          Text('${resource.medium} medium · ${resource.fileName}'),
          const SizedBox(height: 12),
          Text(
            resource.downloadUrl == null
                ? 'पीडीएफ दुवा उपलब्ध नाही.'
                : 'अपलोड केलेली पीडीएफ फाइल उघडण्यासाठी खालील बटण निवडा.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('बंद करा'),
        ),
        FilledButton.icon(
          onPressed: resource.downloadUrl == null
              ? null
              : () async {
                  try {
                    final opened = await launchUrl(
                      Uri.parse(resource.downloadUrl!),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened) {
                      throw StateError('पीडीएफ उघडणारा अनुप्रयोग उपलब्ध नाही.');
                    }
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                            content: Text('पीडीएफ उघडता आली नाही: $error')),
                      );
                    }
                  }
                },
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('साहित्य उघडा'),
        ),
      ],
    ),
  );
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.isKidsZone,
    required this.standard,
    required this.medium,
  });

  final bool isKidsZone;
  final int standard;
  final String medium;

  @override
  Widget build(BuildContext context) {
    final accent = isKidsZone ? const Color(0xFF9C4E14) : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isKidsZone
              ? const [Color(0xFFFFD178), Color(0xFFFFA867)]
              : const [Color(0xFF304DB6), Color(0xFF6379E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKidsZone ? 'शोधायला तयार आहात?' : 'तुमचे ध्येय साध्य करा.',
                  style: TextStyle(
                    color: accent,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isKidsZone
                      ? 'आज शिका, खेळा आणि तारे मिळवा!'
                      : 'दररोजचा थोडासा सराव मोठी प्रगती घडवतो.',
                  style: TextStyle(
                    color: accent.withValues(alpha: .85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'इयत्ता ${_marathiNumber(standard)}  ·  ${_mediumMarathi(medium)}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isKidsZone ? Icons.rocket_launch_rounded : Icons.track_changes,
            size: 62,
            color: accent.withValues(alpha: .9),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF737B91)),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Color(0xFF425DC3),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _DailyQuizBanner extends StatelessWidget {
  const _DailyQuizBanner({
    required this.isKidsZone,
    required this.medium,
    required this.onTap,
  });

  final bool isKidsZone;
  final String medium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isKidsZone ? const Color(0xFFB85C27) : const Color(0xFF3659C9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isKidsZone
                  ? const [Color(0xFFFFF0D6), Color(0xFFFFE1C1)]
                  : const [Color(0xFFEAF0FF), Color(0xFFE5E9FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: color.withValues(alpha: .16)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.quiz_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mediumLabel(
                        medium,
                        marathi: 'दैनिक सराव चाचणी',
                        semiEnglish: 'Daily Practice Test / दैनिक सराव चाचणी',
                        english: 'Daily Practice Test',
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _mediumLabel(
                        medium,
                        marathi: isKidsZone
                            ? 'तुमच्यासाठी एक मजेदार झटपट प्रश्न!'
                            : 'बहुपर्यायी प्रश्नमंजुषा · समज तपासा',
                        semiEnglish: isKidsZone
                            ? 'A fun quick question / मजेदार झटपट प्रश्न'
                            : 'MCQ Quiz / बहुपर्यायी प्रश्न · Test your understanding',
                        english: isKidsZone
                            ? 'A quick, fun question for you!'
                            : 'MCQ Quiz · Test your understanding',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF68718A),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectGrid extends StatelessWidget {
  const _SubjectGrid({
    required this.isKidsZone,
    required this.standard,
    required this.medium,
    required this.content,
  });

  final bool isKidsZone;
  final int standard;
  final String medium;
  final _LearningContentStore content;

  @override
  Widget build(BuildContext context) {
    final subjects = _subjectsForMedium(standard: standard, medium: medium);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subjects.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final color = Color(subject.color);
        return InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => _showSubjectChapters(
            context,
            standard: standard,
            subject: subject.name,
            subjectKey: subject.key,
            medium: medium,
            isKidsZone: isKidsZone,
            content: content,
          ),
          child: Card(
            elevation: 2,
            shadowColor: color.withValues(alpha: .16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 35,
                    width: 35,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(subject.icon, color: color, size: 20),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KidsProgressStrip extends StatelessWidget {
  const _KidsProgressStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProgressBadge(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFE78937),
            value: 'सलग ३ दिवसांचा अभ्यास',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ProgressBadge(
            icon: Icons.star_rounded,
            color: const Color(0xFFD39A22),
            value: '१२ तारे मिळवले',
          ),
        ),
      ],
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9ECF4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 47,
              width: 47,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF737B91),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onTap,
                    child: Text(
                      action,
                      style: const TextStyle(
                        color: Color(0xFF425DC3),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamPrepCard extends StatelessWidget {
  const _ExamPrepCard({required this.standard, required this.medium});

  final int standard;
  final String medium;

  @override
  Widget build(BuildContext context) {
    final isBoardYear = standard == 10;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE2FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFF465DC2), size: 30),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mediumLabel(
                    medium,
                    marathi: isBoardYear
                        ? 'दहावीच्या परीक्षेची तयारी'
                        : 'मूलभूत संकल्पना पक्क्या करा',
                    semiEnglish: isBoardYear
                        ? 'SSC Preparation / दहावीची तयारी'
                        : 'Build Strong Basics / संकल्पना पक्क्या करा',
                    english: isBoardYear
                        ? 'SSC Exam Preparation'
                        : 'Build Strong Foundations',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isBoardYear
                      ? _mediumLabel(
                          medium,
                          marathi:
                              'उजळणी आराखडे, नमुना प्रश्नपत्रिका आणि परीक्षेचा सराव.',
                          semiEnglish:
                              'Revision plans and mock papers / उजळणी व नमुना पेपर',
                          english:
                              'Revision plans, mock papers and exam practice.',
                        )
                      : _mediumLabel(
                          medium,
                          marathi:
                              'राज्य मंडळाचा अभ्यासक्रम प्रकरणानुसार पूर्ण करा.',
                          semiEnglish:
                              'Follow the State Board syllabus / राज्य मंडळाचा अभ्यासक्रम',
                          english:
                              'Follow the State Board syllabus chapter by chapter.',
                        ),
                  style: const TextStyle(
                    color: Color(0xFF636D8A),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumUpgradeCard extends StatelessWidget {
  const _PremiumUpgradeCard({required this.onTap, required this.medium});

  final VoidCallback onTap;
  final String medium;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB77916).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFB77916),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _mediumLabel(
                      medium,
                      marathi: 'अधिक अध्ययन सुविधा · शुल्क',
                      semiEnglish: 'Premium Learning / विशेष अध्ययन सुविधा',
                      english: 'Premium Learning · Course Fees',
                    ),
                    style: TextStyle(
                      color: Color(0xFF94600C),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .55,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              _mediumLabel(
                medium,
                marathi: 'शिकण्याचे नवे मार्ग उघडा',
                semiEnglish: 'Unlock More Ways to Learn / शिकण्याचे नवे मार्ग',
                english: 'Unlock More Ways to Learn',
              ),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _mediumLabel(
                medium,
                marathi:
                    'दहावीचा प्रश्नसंच, मार्गदर्शन आणि जाहिरातमुक्त ध्वनिचित्र धडे.',
                semiEnglish:
                    'Question banks, mentorship & video lessons / प्रश्नसंच व मार्गदर्शन',
                english:
                    'Board question banks, mentorship and ad-free video lessons.',
              ),
              style: TextStyle(
                color: Color(0xFF737B91),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.lock_rounded, size: 16),
              label: Text(_mediumLabel(
                medium,
                marathi: 'सुरक्षित शुल्क भरणा पहा',
                semiEnglish: 'Secure Checkout / सुरक्षित शुल्क भरणा',
                english: 'View Secure Checkout',
              )),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94600C),
                side: const BorderSide(color: Color(0x55B77916)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiRoomPage extends StatelessWidget {
  const _AiRoomPage({required this.standard, required this.medium});

  final int standard;
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      children: [
        _PageIntro(
          eyebrow: _mediumLabel(
            medium,
            marathi: 'तुमचा एआय अध्ययन-सहाय्यक',
            semiEnglish: 'AI Study Companion / एआय अध्ययन-सहाय्यक',
            english: 'Your AI Study Companion',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'एआय अध्ययन कक्षात स्वागत',
            semiEnglish: 'Welcome to the AI Room / एआय कक्षात स्वागत',
            english: 'Welcome to the AI Room',
          ),
          subtitle: _mediumLabel(
            medium,
            marathi:
                'प्रश्न विचारा, संकल्पना समजून घ्या आणि स्वतःच्या गतीने सराव करा.',
            semiEnglish:
                'Ask questions and practise at your pace / प्रश्न विचारा व सराव करा.',
            english:
                'Ask questions, understand concepts and practise at your own pace.',
          ),
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFF6556C8),
        ),
        const SizedBox(height: 22),
        AiTutorChat(
          standard: standard,
          medium: medium,
          firebaseReady: _firebaseReady,
        ),
        const SizedBox(height: 13),
        _HomeworkSolverCard(standard: standard, medium: medium),
        const SizedBox(height: 13),
        _ToolCard(
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF138D76),
          tag: _mediumLabel(
            medium,
            marathi: 'हस्तलिखित उत्तरपत्रिका तपासणी',
            semiEnglish: 'Handwritten Paper Check / उत्तरपत्रिका तपासणी',
            english: 'Handwritten Paper Check',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'सरावाची उत्तरपत्रिका तपासा',
            semiEnglish: 'Check Practice Paper / सरावपत्रिका तपासा',
            english: 'Check Your Practice Paper',
          ),
          description: _mediumLabel(
            medium,
            marathi:
                'नमुना गुण, अभिप्राय आणि उजळणीच्या सूचनांसाठी हस्तलिखित उत्तरपत्रिका निवडा.',
            semiEnglish:
                'Upload a handwritten sheet for sample marks and feedback / गुण व अभिप्रायासाठी उत्तरपत्रिका निवडा.',
            english:
                'Choose a handwritten answer sheet for sample marks, feedback and revision tips.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'उत्तरपत्रिका निवडा',
            semiEnglish: 'Choose Paper / उत्तरपत्रिका निवडा',
            english: 'Choose a Paper',
          ),
          onTap: () => _showInfo(
            context,
            _mediumLabel(medium,
                marathi: 'उत्तरपत्रिका तपासणी',
                semiEnglish: 'Paper Checker / उत्तरपत्रिका तपासणी',
                english: 'Paper Checker'),
            _mediumLabel(medium,
                marathi:
                    'या प्रात्यक्षिकात उत्तरांचा अभिप्राय आणि उजळणीच्या सूचना दिसतात.',
                semiEnglish:
                    'Sample answer feedback and revision tips / उत्तरांचा अभिप्राय व उजळणी सूचना.',
                english: 'Preview answer feedback and revision suggestions.'),
          ),
        ),
        const SizedBox(height: 13),
        _TipCard(
          icon: Icons.shield_outlined,
          text: _mediumLabel(
            medium,
            marathi:
                'एआयच्या सूचना अभ्यासासाठी मदत करतात. महत्त्वाची उत्तरे पाठ्यपुस्तक किंवा शिक्षकांकडून तपासा.',
            semiEnglish:
                'AI is a study aid. Check important answers with your textbook or teacher / उत्तरे तपासा.',
            english:
                'AI suggestions are a study aid. Check important answers with your textbook or teacher.',
          ),
        ),
      ],
    );
  }
}

class _HomeworkSolverCard extends StatefulWidget {
  const _HomeworkSolverCard({required this.standard, required this.medium});

  final int standard;
  final String medium;

  @override
  State<_HomeworkSolverCard> createState() => _HomeworkSolverCardState();
}

class _HomeworkSolverCardState extends State<_HomeworkSolverCard> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _homeworkPrompt = TextEditingController();
  Uint8List? _homeworkImage;
  String? _solution;
  bool _isPickingImage = false;
  bool _isGeneratingSolution = false;

  @override
  void dispose() {
    _homeworkPrompt.dispose();
    super.dispose();
  }

  Future<void> _selectImage(ImageSource source) async {
    if (_isPickingImage || _isGeneratingSolution) return;
    setState(() => _isPickingImage = true);

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }
      if (!mounted) return;

      final imageBytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _homeworkImage = imageBytes;
        _isPickingImage = false;
        _isGeneratingSolution = true;
        _solution = null;
      });

      await _generateSolution(imageBytes, image.mimeType ?? 'image/jpeg');
    } on PlatformException {
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      _showPickerError(_mediumLabel(
        widget.medium,
        marathi:
            'छायाचित्र उघडता आले नाही. परवानग्या तपासून पुन्हा प्रयत्न करा.',
        semiEnglish:
            'Could not open image. Check permissions / छायाचित्र उघडले नाही.',
        english:
            'Could not open the image source. Check permissions and try again.',
      ));
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      _showPickerError(_mediumLabel(
        widget.medium,
        marathi:
            'छायाचित्र निवडण्याची सुविधा उपलब्ध नाही. अवलंबने मिळवून अ‍ॅप पुन्हा सुरू करा.',
        semiEnglish:
            'Image picker unavailable. Run flutter pub get and restart / छायाचित्र सुविधा उपलब्ध नाही.',
        english:
            'Image picker is unavailable. Run flutter pub get and restart the app.',
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPickingImage = false;
        _isGeneratingSolution = false;
      });
      debugPrint('Homework image selection failed: $error');
      _showPickerError(
        _mediumLabel(
          widget.medium,
          marathi: 'छायाचित्र निवडता आले नाही. पुन्हा प्रयत्न करा.',
          semiEnglish:
              'Could not select image. Please try again / छायाचित्र निवडा.',
          english: 'Could not select the image. Please try again.',
        ),
      );
    }
  }

  Future<void> _generateSolution(Uint8List imageBytes, String mimeType) async {
    try {
      final solution = await solveHomeworkWithGemini(
        standard: widget.standard,
        medium: widget.medium,
        prompt: _homeworkPrompt.text,
        imageBytes: imageBytes,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() {
        _isGeneratingSolution = false;
        _solution = solution;
      });
    } catch (error) {
      debugPrint('Gemini homework solution failed: $error');
      if (!mounted) return;
      setState(() => _isGeneratingSolution = false);
      _showPickerError(
        _mediumLabel(
          widget.medium,
          marathi:
              'उत्तर तयार झाले नाही. Firebase AI Logic जोडणी तपासून पुन्हा प्रयत्न करा.',
          semiEnglish:
              'Could not generate an answer. Check Firebase AI Logic / उत्तर मिळाले नाही.',
          english:
              'Could not generate an answer. Check Firebase AI Logic setup and try again.',
        ),
      );
    }
  }

  void _showPickerError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 41,
                  width: 41,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C65D2).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: Color(0xFF4C65D2),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _mediumLabel(
                      widget.medium,
                      marathi: 'छायाचित्र घ्या आणि उत्तर शोधा',
                      semiEnglish:
                          'Snap & Solve / छायाचित्र घ्या आणि उत्तर शोधा',
                      english: 'Snap & Solve',
                    ),
                    style: TextStyle(
                      color: Color(0xFF4C65D2),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: .65,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              _mediumLabel(
                widget.medium,
                marathi: 'गृहपाठासाठी मदत मिळवा',
                semiEnglish: 'Homework Help / गृहपाठासाठी मदत',
                english: 'Get Help with Homework',
              ),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _mediumLabel(
                widget.medium,
                marathi:
                    'गृहपाठाचे छायाचित्र निवडा. पायरी-पायरीने उत्तराचे प्रात्यक्षिक पाहा.',
                semiEnglish:
                    'Choose a homework photo for a step-by-step sample solution / उत्तराचे प्रात्यक्षिक पहा.',
                english:
                    'Choose a homework photo to see a sample step-by-step solution.',
              ),
              style: const TextStyle(
                color: Color(0xFF737B91),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: _homeworkPrompt,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _mediumLabel(
                  widget.medium,
                  marathi: 'विषय किंवा अतिरिक्त सूचना (ऐच्छिक)',
                  semiEnglish: 'Subject or context / विषय किंवा सूचना',
                  english: 'Subject or extra context (optional)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_homeworkImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _homeworkImage!,
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                  semanticLabel: 'निवडलेले गृहपाठाचे छायाचित्र',
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 9,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isPickingImage || _isGeneratingSolution
                      ? null
                      : () => _selectImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 17),
                  label: Text(_mediumLabel(
                    widget.medium,
                    marathi: 'छायाचित्र काढा',
                    semiEnglish: 'Take Photo / छायाचित्र काढा',
                    english: 'Take a Photo',
                  )),
                ),
                OutlinedButton.icon(
                  onPressed: _isPickingImage || _isGeneratingSolution
                      ? null
                      : () => _selectImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 17),
                  label: Text(_mediumLabel(
                    widget.medium,
                    marathi: 'छायाचित्र निवडा',
                    semiEnglish: 'Choose Image / छायाचित्र निवडा',
                    english: 'Choose Image',
                  )),
                ),
              ],
            ),
            if (_isPickingImage) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 7),
              Text(
                _mediumLabel(
                  widget.medium,
                  marathi: 'छायाचित्र निवडण्याचे साधन उघडत आहे…',
                  semiEnglish: 'Opening image picker / छायाचित्र उघडत आहे…',
                  english: 'Opening image picker…',
                ),
                style: TextStyle(fontSize: 12, color: Color(0xFF737B91)),
              ),
            ],
            if (_isGeneratingSolution) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 7),
              Text(
                _mediumLabel(
                  widget.medium,
                  marathi: 'एआय उत्तर समजावून सांगत आहे…',
                  semiEnglish: 'AI is working / एआय उत्तर तयार करत आहे…',
                  english: 'AI is preparing a step-by-step explanation…',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_solution != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  _solution!,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillsPage extends StatelessWidget {
  const _SkillsPage({required this.isKidsZone, required this.medium});

  final bool isKidsZone;
  final String medium;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      children: [
        _PageIntro(
          eyebrow: _mediumLabel(
            medium,
            marathi: 'पाठ्यपुस्तकापलीकडील कौशल्ये',
            semiEnglish: 'Beyond Textbooks / पाठ्यपुस्तकापलीकडील कौशल्ये',
            english: 'Beyond Textbooks',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'कौशल्य विकास प्रयोगशाळा',
            semiEnglish: 'Skills Lab / कौशल्य विकास प्रयोगशाळा',
            english: 'Skills Lab',
          ),
          subtitle: _mediumLabel(
            medium,
            marathi: isKidsZone
                ? 'जिज्ञासू विद्यार्थ्यांसाठी खेळातून सराव.'
                : 'शाळा, काम आणि जीवनासाठी उपयुक्त कौशल्ये विकसित करा.',
            semiEnglish: isKidsZone
                ? 'Learn through play / खेळातून सराव करा.'
                : 'Build useful life skills / जीवनोपयोगी कौशल्ये विकसित करा.',
            english: isKidsZone
                ? 'Practise through playful activities.'
                : 'Build useful skills for school, work and life.',
          ),
          icon: Icons.lightbulb_rounded,
          color: const Color(0xFFE29A30),
        ),
        const SizedBox(height: 22),
        _ToolCard(
          icon: Icons.record_voice_over_rounded,
          color: const Color(0xFF178C78),
          tag: _mediumLabel(
            medium,
            marathi: 'एआय इंग्रजी संभाषण सराव',
            semiEnglish: 'AI English Conversation / इंग्रजी संभाषण',
            english: 'AI English Conversation',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'आत्मविश्वासाने बोला',
            semiEnglish: 'Speak with Confidence / आत्मविश्वासाने बोला',
            english: 'Speak with Confidence',
          ),
          description: _mediumLabel(
            medium,
            marathi:
                'सोपे प्रश्न आणि अभिप्राय यांच्या मदतीने दैनंदिन संभाषणाचा सराव करा.',
            semiEnglish:
                'Practise everyday conversations / दैनंदिन संभाषणाचा सराव करा.',
            english:
                'Practise everyday conversations with simple prompts and feedback.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'बोलण्याचा सराव सुरू करा',
            semiEnglish: 'Start Speaking Practice / बोलण्याचा सराव सुरू करा',
            english: 'Start Speaking Practice',
          ),
          onTap: () => _showVoicePractice(context),
        ),
        const SizedBox(height: 13),
        _ToolCard(
          icon: Icons.code_rounded,
          color: const Color(0xFF5865C8),
          tag: _mediumLabel(
            medium,
            marathi: isKidsZone
                ? 'स्क्रॅच संकेतलेखन'
                : 'पायथन आणि स्क्रॅच संकेतलेखन',
            semiEnglish: isKidsZone
                ? 'Scratch Coding / स्क्रॅच संकेतलेखन'
                : 'Python & Scratch Coding / पायथन व स्क्रॅच संकेतलेखन',
            english: isKidsZone ? 'Scratch Coding' : 'Python & Scratch Coding',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'तुमचा पहिला संगणक कार्यक्रम तयार करा',
            semiEnglish: 'Build Your First Program / पहिला कार्यक्रम तयार करा',
            english: 'Build Your First Program',
          ),
          description: _mediumLabel(
            medium,
            marathi: isKidsZone
                ? 'स्क्रॅचमधील ठोकळे, आकृतिबंध आणि सोप्या तर्काने गोष्ट तयार करा.'
                : 'स्क्रॅच प्रकल्प पहा आणि पायथनची सुरुवात करा.',
            semiEnglish: isKidsZone
                ? 'Create with Scratch blocks / स्क्रॅच ठोकळ्यांनी तयार करा.'
                : 'Explore Scratch and start Python / पायथनची सुरुवात करा.',
            english: isKidsZone
                ? 'Create a story with Scratch blocks and simple logic.'
                : 'Explore Scratch projects and get started with Python.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'संकेतलेखनाचे आव्हान सोडवा',
            semiEnglish: 'Try Coding Challenge / संकेतलेखन आव्हान',
            english: 'Try Coding Challenge',
          ),
          onTap: () => _showCodingChallenge(context, isKidsZone: isKidsZone),
        ),
        const SizedBox(height: 13),
        _ToolCard(
          icon: Icons.bolt_rounded,
          color: const Color(0xFFD77A33),
          tag: _mediumLabel(
            medium,
            marathi: 'वैदिक गणित आणि आर्थिक साक्षरता',
            semiEnglish: 'Vedic Maths & Money Skills / वैदिक गणित',
            english: 'Vedic Maths & Money Skills',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'झटपट गणित, योग्य निवड',
            semiEnglish: 'Quick Maths, Smart Choices / झटपट गणित',
            english: 'Quick Maths, Smart Choices',
          ),
          description: _mediumLabel(
            medium,
            marathi:
                'मानसिक गणिताची युक्ती शिका आणि खिशातील पैसे व यूपीआय सुरक्षिततेची माहिती घ्या.',
            semiEnglish:
                'Learn mental maths and money safety / गणित व आर्थिक सुरक्षितता शिका.',
            english:
                'Learn mental-maths tricks and the basics of money and UPI safety.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'आर्थिक कौशल्ये शिका',
            semiEnglish: 'Learn Money Skills / आर्थिक कौशल्ये',
            english: 'Learn Money Skills',
          ),
          onTap: () => _showMoneySkills(context),
        ),
        const SizedBox(height: 13),
        _ToolCard(
          icon: Icons.menu_book_rounded,
          color: const Color(0xFFE29A30),
          tag: _mediumLabel(
            medium,
            marathi: 'मॉड्यूल १',
            semiEnglish: 'Module 1 / मॉड्यूल १',
            english: 'Module 1',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'मूलभूत आणि शैक्षणिक कौशल्ये',
            semiEnglish:
                'Basic & Academic Skills / मूलभूत आणि शैक्षणिक कौशल्ये',
            english: 'Basic & Academic Skills',
          ),
          description: _mediumLabel(
            medium,
            marathi: 'धडानुसार वाचन, झटपट प्रश्नमंजुषा, शब्दकोश आणि उच्चार.',
            semiEnglish:
                'Reading, quizzes, dictionary & pronunciation / वाचन, प्रश्नमंजुषा, शब्दकोश.',
            english:
                'Chapter reading, instant quizzes, dictionary & pronunciation.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'मॉड्यूल उघडा',
            semiEnglish: 'Open Module / मॉड्यूल उघडा',
            english: 'Open Module',
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => BasicSkillsPage(medium: medium))),
        ),
        const SizedBox(height: 13),
        _ToolCard(
          icon: Icons.devices_rounded,
          color: const Color(0xFF3B7DD8),
          tag: _mediumLabel(
            medium,
            marathi: 'मॉड्यूल २',
            semiEnglish: 'Module 2 / मॉड्यूल २',
            english: 'Module 2',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'डिजिटल आणि तंत्रज्ञान कौशल्ये',
            semiEnglish:
                'Digital & Tech Skills / डिजिटल आणि तंत्रज्ञान कौशल्ये',
            english: 'Digital & Tech Skills',
          ),
          description: _mediumLabel(
            medium,
            marathi: 'ब्लॉक कोडिंग भुलभुलैया, सायबर सुरक्षा आणि पासवर्ड तपासक.',
            semiEnglish:
                'Block coding, cyber safety, password checker / ब्लॉक कोडिंग, सायबर सुरक्षा.',
            english: 'Block coding maze, cyber safety & password checker.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'मॉड्यूल उघडा',
            semiEnglish: 'Open Module / मॉड्यूल उघडा',
            english: 'Open Module',
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DigitalSkillsPage(medium: medium))),
        ),
        const SizedBox(height: 13),
        _ToolCard(
          icon: Icons.self_improvement_rounded,
          color: const Color(0xFF178C78),
          tag: _mediumLabel(
            medium,
            marathi: 'मॉड्यूल ३',
            semiEnglish: 'Module 3 / मॉड्यूल ३',
            english: 'Module 3',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'जीवन कौशल्ये',
            semiEnglish: 'Life Skills / जीवन कौशल्ये',
            english: 'Life Skills',
          ),
          description: _mediumLabel(
            medium,
            marathi:
                'पोमोडोरो टायमर, नाण्यांची बचत, स्वच्छतेच्या सवयी आणि मूड ट्रॅकर.',
            semiEnglish:
                'Pomodoro, coin savings, hygiene & mood tracker / टायमर, बचत व स्वच्छता.',
            english:
                'Pomodoro timer, coin savings, hygiene habits & mood tracker.',
          ),
          action: _mediumLabel(
            medium,
            marathi: 'मॉड्यूल उघडा',
            semiEnglish: 'Open Module / मॉड्यूल उघडा',
            english: 'Open Module',
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => LifeSkillsModulesPage(medium: medium))),
        ),
      ],
    );
  }
}

class _CareerPathway {
  const _CareerPathway({
    required this.title,
    required this.marathiTitle,
    required this.eligibility,
    required this.marathiEligibility,
    required this.duration,
    required this.marathiDuration,
    required this.fields,
    required this.marathiFields,
    required this.icon,
    required this.color,
  });

  final String title;
  final String marathiTitle;
  final String eligibility;
  final String marathiEligibility;
  final String duration;
  final String marathiDuration;
  final String fields;
  final String marathiFields;
  final IconData icon;
  final Color color;
}

const _maharashtraCareerDirectory = [
  _CareerPathway(
    title: 'Science stream',
    marathiTitle: 'विज्ञान शाखा',
    eligibility:
        '10th pass; meet the current junior-college admission and subject requirements.',
    marathiEligibility:
        '१० वी उत्तीर्ण; कनिष्ठ महाविद्यालयाचे प्रवेश व विषय निकष तपासा.',
    duration: '2 years (11th–12th)',
    marathiDuration: '२ वर्षे (११ वी–१२ वी)',
    fields: 'Engineering, medicine, pure sciences, pharmacy, computing.',
    marathiFields: 'अभियांत्रिकी, वैद्यकीय, शुद्ध विज्ञान, औषधनिर्माण, संगणक.',
    icon: Icons.biotech_rounded,
    color: Color(0xFF4276C7),
  ),
  _CareerPathway(
    title: 'Commerce stream',
    marathiTitle: 'वाणिज्य शाखा',
    eligibility:
        '10th pass; confirm the college’s admission rules and available subjects.',
    marathiEligibility:
        '१० वी उत्तीर्ण; महाविद्यालयाचे प्रवेश व विषय निकष तपासा.',
    duration: '2 years (11th–12th)',
    marathiDuration: '२ वर्षे (११ वी–१२ वी)',
    fields: 'Accounting, finance, banking, business, economics.',
    marathiFields: 'लेखांकन, वित्त, बँकिंग, व्यवसाय, अर्थशास्त्र.',
    icon: Icons.query_stats_rounded,
    color: Color(0xFF168B73),
  ),
  _CareerPathway(
    title: 'Arts / Humanities',
    marathiTitle: 'कला / मानवविद्या शाखा',
    eligibility: '10th pass; subject combinations vary by junior college.',
    marathiEligibility:
        '१० वी उत्तीर्ण; विषयांचे पर्याय महाविद्यालयानुसार बदलतात.',
    duration: '2 years (11th–12th)',
    marathiDuration: '२ वर्षे (११ वी–१२ वी)',
    fields: 'Law, design, media, psychology, social sciences, public service.',
    marathiFields: 'कायदा, डिझाइन, माध्यमे, मानसशास्त्र, समाजशास्त्र, लोकसेवा.',
    icon: Icons.palette_rounded,
    color: Color(0xFF9A64BD),
  ),
  _CareerPathway(
    title: 'Polytechnic diploma',
    marathiTitle: 'पॉलिटेक्निक पदविका',
    eligibility:
        'Usually 10th pass for first-year diploma admission; check the current Maharashtra DTE notice and branch criteria.',
    marathiEligibility:
        'साधारणपणे पहिल्या वर्षाच्या पदविकेसाठी १० वी उत्तीर्ण; महाराष्ट्र DTE ची चालू सूचना व शाखेचे निकष तपासा.',
    duration: 'Usually 3 years after 10th',
    marathiDuration: '१० वी नंतर साधारण ३ वर्षे',
    fields:
        'Civil, mechanical, electrical, computer, electronics, emerging technologies.',
    marathiFields:
        'स्थापत्य, यांत्रिकी, विद्युत, संगणक, इलेक्ट्रॉनिक्स, नवीन तंत्रज्ञान.',
    icon: Icons.handyman_rounded,
    color: Color(0xFFDA8A33),
  ),
  _CareerPathway(
    title: 'ITI / Crafts training',
    marathiTitle: 'ITI / व्यवसाय प्रशिक्षण',
    eligibility:
        '10th pass is required for many trades; entry requirements vary by trade and institute.',
    marathiEligibility:
        'अनेक व्यवसायांसाठी १० वी उत्तीर्ण आवश्यक; पात्रता व्यवसाय व संस्थेनुसार बदलते.',
    duration: 'Commonly 1–2 years, depending on trade',
    marathiDuration: 'व्यवसायानुसार साधारण १–२ वर्षे',
    fields:
        'Electrician, fitter, machinist, refrigeration, welding, computer operator.',
    marathiFields:
        'इलेक्ट्रिशियन, फिटर, मशीनिस्ट, रेफ्रिजरेशन, वेल्डिंग, संगणक ऑपरेटर.',
    icon: Icons.construction_rounded,
    color: Color(0xFF477F9D),
  ),
  _CareerPathway(
    title: 'NDA (Defence services)',
    marathiTitle: 'NDA (संरक्षण सेवा)',
    eligibility:
        'The UPSC NDA exam requires 12th-level eligibility; Air Force and Naval wings require 12th with Physics, Chemistry and Mathematics. Check current UPSC age and other criteria.',
    marathiEligibility:
        'UPSC NDA परीक्षेसाठी १२ वीची पात्रता आवश्यक; वायुसेना व नौदलासाठी भौतिकशास्त्र, रसायनशास्त्र व गणित आवश्यक. UPSC चे सध्याचे वयोमर्यादा व इतर निकष तपासा.',
    duration: 'After 12th: selection process and academy training',
    marathiDuration: '१२ वी नंतर: निवड प्रक्रिया व अकादमी प्रशिक्षण',
    fields: 'Army, Navy, Air Force officer careers.',
    marathiFields: 'लष्कर, नौदल, वायुसेना अधिकारी पदे.',
    icon: Icons.shield_rounded,
    color: Color(0xFF477F68),
  ),
  _CareerPathway(
    title: 'Agriculture',
    marathiTitle: 'कृषी शिक्षण',
    eligibility:
        'Routes vary: vocational/agriculture diplomas may accept 10th; degree programmes generally require 12th with specified subjects and admission criteria.',
    marathiEligibility:
        'मार्गानुसार पात्रता बदलते: काही कृषी पदविका १० वी नंतर; पदवी अभ्यासक्रमांसाठी साधारणपणे ठरावीक विषयांसह १२ वी आवश्यक.',
    duration: 'Diploma commonly 2 years; bachelor’s degree commonly 4 years',
    marathiDuration: 'पदविका साधारण २ वर्षे; पदवी साधारण ४ वर्षे',
    fields:
        'Agronomy, horticulture, animal science, agricultural engineering, food technology.',
    marathiFields:
        'कृषीशास्त्र, उद्यानविद्या, पशुविज्ञान, कृषी अभियांत्रिकी, अन्न तंत्रज्ञान.',
    icon: Icons.eco_rounded,
    color: Color(0xFF6D9437),
  ),
];

class _CareerPage extends StatelessWidget {
  const _CareerPage({required this.standard, required this.medium});

  final int standard;
  final String medium;

  @override
  Widget build(BuildContext context) {
    final canTakeAptitudeTest = standard >= 8;
    return _PageScroll(
      children: [
        _PageIntro(
          eyebrow: _mediumLabel(
            medium,
            marathi: 'भविष्यातील संधी जाणून घ्या',
            semiEnglish: 'Explore Future Options / भविष्यातील संधी',
            english: 'Explore Future Options',
          ),
          title: _mediumLabel(
            medium,
            marathi: 'तुमच्या भविष्याची सुरुवात इथून',
            semiEnglish: 'Start Planning Your Future / भविष्याची सुरुवात',
            english: 'Start Planning Your Future',
          ),
          subtitle: _mediumLabel(
            medium,
            marathi: standard >= 10
                ? 'दहावीनंतरचे पर्याय समजून घ्या आणि तुमच्यासाठी योग्य मार्ग शोधा.'
                : 'तुमच्या आवडी जाणून घ्या आणि पुढील शिक्षणाचे पर्याय समजून घ्या.',
            semiEnglish: standard >= 10
                ? 'Explore options after 10th / दहावीनंतरचे पर्याय जाणून घ्या.'
                : 'Explore your interests / तुमच्या आवडी जाणून घ्या.',
            english: standard >= 10
                ? 'Explore your options after 10th standard.'
                : 'Explore your interests and further-study options.',
          ),
          icon: Icons.explore_rounded,
          color: const Color(0xFF3C75A1),
        ),
        const SizedBox(height: 18),
        if (canTakeAptitudeTest) ...[
          _ToolCard(
            icon: Icons.assignment_turned_in_rounded,
            color: const Color(0xFF3C75A1),
            tag: _mediumLabel(
              medium,
              marathi: 'नवीन · करिअर चाचणी',
              semiEnglish: 'New · Career Test / करिअर चाचणी',
              english: 'New · Career Test',
            ),
            title: _mediumLabel(
              medium,
              marathi: 'तुमच्यासाठी योग्य शाखा कोणती?',
              semiEnglish: 'Which Stream Suits You? / योग्य शाखा कोणती?',
              english: 'Which Stream Suits You?',
            ),
            description: _mediumLabel(
              medium,
              marathi:
                  '१३ प्रश्नांतून क्षमता आणि आवड तपासा; विज्ञान, वाणिज्य, कला किंवा पदविका यांपैकी सुचवलेला मार्ग पहा.',
              semiEnglish:
                  '13 questions on aptitude & interest / क्षमता व आवड; get a Science, Commerce, Arts or Diploma suggestion.',
              english:
                  'Answer 13 questions on aptitude and interest and get a Science, Commerce, Arts or Diploma suggestion.',
            ),
            action: _mediumLabel(
              medium,
              marathi: 'करिअर चाचणी सुरू करा',
              semiEnglish: 'Start Career Test / करिअर चाचणी सुरू करा',
              english: 'Start Career Test',
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CareerTestPage(medium: medium))),
          ),
          const SizedBox(height: 13),
          _ToolCard(
            icon: Icons.psychology_rounded,
            color: const Color(0xFF7357BE),
            tag: _mediumLabel(
              medium,
              marathi: 'एआय कल आणि आवड चाचणी',
              semiEnglish: 'AI Aptitude Test / कल चाचणी',
              english: 'AI Aptitude Test',
            ),
            title: _mediumLabel(
              medium,
              marathi: 'तुमच्या आवडीची क्षेत्रे शोधा',
              semiEnglish: 'Explore Your Interests / आवडीची क्षेत्रे शोधा',
              english: 'Explore Your Interests',
            ),
            description: _mediumLabel(
              medium,
              marathi:
                  'क्षमता आणि आवडींची छोटी प्रश्नमंजुषा सोडवा; नंतर कुटुंब व शिक्षकांशी पुढील पर्यायांबद्दल चर्चा करा.',
              semiEnglish:
                  'Answer a short quiz / छोटी प्रश्नमंजुषा सोडवा; then discuss options with family and teachers.',
              english:
                  'Take a short quiz about your strengths and interests, then discuss options with family and teachers.',
            ),
            action: _mediumLabel(
              medium,
              marathi: 'कल चाचणी सुरू करा',
              semiEnglish: 'Start Aptitude Test / कल चाचणी सुरू करा',
              english: 'Start Aptitude Test',
            ),
            onTap: () => _showAptitudeTest(context),
          ),
          const SizedBox(height: 21),
        ],
        _SectionHeading(
          title: _mediumLabel(
            medium,
            marathi: 'महाराष्ट्र करिअर मार्गदर्शिका',
            semiEnglish: 'Maharashtra Career Guide / करिअर मार्गदर्शिका',
            english: 'Maharashtra Career Guide',
          ),
          subtitle: _mediumLabel(
            medium,
            marathi: 'पात्रता, कालावधी आणि कार्यक्षेत्रे',
            semiEnglish: 'Eligibility, Duration & Fields / पात्रता व क्षेत्रे',
            english: 'Eligibility, duration and fields',
          ),
        ),
        const SizedBox(height: 12),
        for (final pathway in _maharashtraCareerDirectory) ...[
          _PathwayCard(
            title: _mediumLabel(
              medium,
              marathi: pathway.marathiTitle,
              semiEnglish: '${pathway.title} / ${pathway.marathiTitle}',
              english: pathway.title,
            ),
            detail: _mediumLabel(
              medium,
              marathi: pathway.marathiEligibility,
              semiEnglish:
                  '${pathway.eligibility} / ${pathway.marathiEligibility}',
              english: pathway.eligibility,
            ),
            icon: pathway.icon,
            color: pathway.color,
            onTap: () => _showCareerDetails(context, pathway, medium),
          ),
          const SizedBox(height: 10),
        ],
        _TipCard(
          icon: Icons.info_outline_rounded,
          text: _mediumLabel(
            medium,
            marathi:
                'पात्रता, वयोमर्यादा, प्रवेश आणि अभ्यासक्रमाचा कालावधी बदलू शकतो. अर्ज करण्यापूर्वी अधिकृत सूचना तपासा आणि समुपदेशकांचा सल्ला घ्या.',
            semiEnglish:
                'Check current official notices before applying / अर्जापूर्वी अधिकृत सूचना तपासा.',
            english:
                'Eligibility, age limits, admissions and duration can change. Verify current official notices and speak with a counsellor before applying.',
          ),
        ),
      ],
    );
  }
}

void _showVoicePractice(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var promptIndex = 0;
      var isPractising = false;
      const prompts = [
        ('Introduce yourself.', 'स्वतःची ओळख करून द्या.'),
        ('What is your favourite subject?', 'तुमचा आवडता विषय कोणता?'),
        (
          'Describe a place you love.',
          'तुम्हाला आवडणाऱ्या ठिकाणाचे वर्णन करा.'
        ),
      ];
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final prompt = prompts[promptIndex];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'एआय इंग्रजी संभाषण सराव',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Voice practice simulator · बोलण्याचा सराव',
                  style: TextStyle(color: Color(0xFF737B91), fontSize: 12),
                ),
                const SizedBox(height: 18),
                _PracticePromptCard(
                  prompt: prompt.$1,
                  translation: prompt.$2,
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF178C78),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      setSheetState(() => isPractising = !isPractising);
                    },
                    icon: Icon(isPractising
                        ? Icons.stop_circle_outlined
                        : Icons.mic_rounded),
                    label: Text(isPractising
                        ? 'सराव पूर्ण करा'
                        : 'बोलण्याचा सराव सुरू करा'),
                  ),
                ),
                if (isPractising) ...[
                  const SizedBox(height: 12),
                  const _TipCard(
                    icon: Icons.volume_up_rounded,
                    text:
                        'Practice mode is ready. Say your answer aloud, then use Next prompt for another turn. This demo does not record audio.',
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setSheetState(
                        () => promptIndex = (promptIndex + 1) % prompts.length,
                      ),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('पुढील प्रश्न'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class _PracticePromptCard extends StatelessWidget {
  const _PracticePromptCard({
    required this.prompt,
    required this.translation,
    required this.icon,
    required this.color,
  });

  final String prompt;
  final String translation;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prompt,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(translation,
                    style: const TextStyle(
                        color: Color(0xFF68718A), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showCodingChallenge(BuildContext context, {required bool isKidsZone}) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var usePython = !isKidsZone;
      var checkedAnswer = false;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Coding mini challenge',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Learn by trying · करून शिकूया',
                  style: TextStyle(color: Color(0xFF737B91), fontSize: 12),
                ),
                const SizedBox(height: 15),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.extension_rounded),
                      label: Text('Scratch'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.code_rounded),
                      label: Text('Python'),
                    ),
                  ],
                  selected: {usePython},
                  onSelectionChanged: (selection) => setSheetState(() {
                    usePython = selection.first;
                    checkedAnswer = false;
                  }),
                ),
                const SizedBox(height: 15),
                _PracticePromptCard(
                  prompt: usePython
                      ? 'Challenge: display your name three times.'
                      : 'Challenge: make a character say “Hello!” three times.',
                  translation: usePython
                      ? 'आव्हान: तुमचे नाव तीन वेळा दाखवा.'
                      : 'आव्हान: पात्राकडून “Hello!” तीन वेळा बोलून घ्या.',
                  icon: Icons.lightbulb_outline_rounded,
                  color: const Color(0xFF5865C8),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20253A),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    usePython
                        ? 'for _ in range(3):\n    print("Namaste!")'
                        : 'when green flag clicked\nrepeat (3)\n  say [Hello!] for (2) seconds',
                    style: const TextStyle(
                      color: Color(0xFFE4E8FF),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setSheetState(
                    () => checkedAnswer = !checkedAnswer,
                  ),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: Text(checkedAnswer
                      ? 'Try another challenge'
                      : 'Check my challenge'),
                ),
                if (checkedAnswer) ...[
                  const SizedBox(height: 8),
                  const _TipCard(
                    icon: Icons.celebration_rounded,
                    text:
                        'Great job! Repeating an instruction is called a loop. छान! सूचना पुन्हा वापरण्याला loop म्हणतात.',
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

void _showMoneySkills(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var selectedTopic = 0;
      var answerShown = false;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final isVedicMaths = selectedTopic == 0;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vedic Maths & Money Skills',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Number tricks, pocket money & safe UPI habits',
                  style: TextStyle(color: Color(0xFF737B91), fontSize: 12),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.bolt_rounded),
                      label: Text('Vedic Maths'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.savings_rounded),
                      label: Text('Money smart'),
                    ),
                  ],
                  selected: {selectedTopic},
                  onSelectionChanged: (selection) => setSheetState(() {
                    selectedTopic = selection.first;
                    answerShown = false;
                  }),
                ),
                const SizedBox(height: 14),
                if (isVedicMaths) ...[
                  _PracticePromptCard(
                    prompt: 'Try: 25 × 16 = ?',
                    translation: 'विचार करा: २५ × १६ = किती?',
                    icon: Icons.calculate_rounded,
                    color: const Color(0xFFD77A33),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Hint: 25 × 4 = 100, and 16 = 4 × 4.',
                    style: TextStyle(
                        color: Color(0xFF68718A), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setSheetState(
                      () => answerShown = !answerShown,
                    ),
                    child: Text(answerShown ? 'Hide answer' : 'Show answer'),
                  ),
                  if (answerShown)
                    const _TipCard(
                      icon: Icons.check_circle_outline_rounded,
                      text: '25 × 16 = 25 × 4 × 4 = 100 × 4 = 400. उत्तर: ४००.',
                    ),
                ] else ...[
                  const _PracticePromptCard(
                    prompt: 'Pocket-money plan: save before you spend.',
                    translation: 'खिशातील पैशांचे नियोजन: खर्चापूर्वी बचत करा.',
                    icon: Icons.savings_rounded,
                    color: Color(0xFF168B73),
                  ),
                  const SizedBox(height: 11),
                  const _TipCard(
                    icon: Icons.account_balance_wallet_outlined,
                    text:
                        'Example: from ₹100, save ₹20, plan ₹60 for a goal and keep ₹20 for a small treat. Discuss spending plans with a trusted adult.',
                  ),
                  const SizedBox(height: 9),
                  const _TipCard(
                    icon: Icons.verified_user_outlined,
                    text:
                        'UPI safety: never share your UPI PIN or OTP. A PIN is used to send money, not to receive it. Ask a parent or guardian before making any payment.',
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

void _showCareerDetails(
  BuildContext context,
  _CareerPathway pathway,
  String medium,
) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: pathway.color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(pathway.icon, color: pathway.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mediumLabel(
                        medium,
                        marathi: pathway.marathiTitle,
                        semiEnglish:
                            '${pathway.title} / ${pathway.marathiTitle}',
                        english: pathway.title,
                      ),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          _DirectoryDetail(
            label: _mediumLabel(
              medium,
              marathi: 'पात्रता',
              semiEnglish: 'Eligibility / पात्रता',
              english: 'Eligibility',
            ),
            detail: _mediumLabel(
              medium,
              marathi: pathway.marathiEligibility,
              semiEnglish:
                  '${pathway.eligibility} / ${pathway.marathiEligibility}',
              english: pathway.eligibility,
            ),
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: 14),
          _DirectoryDetail(
            label: _mediumLabel(
              medium,
              marathi: 'कालावधी',
              semiEnglish: 'Duration / कालावधी',
              english: 'Duration',
            ),
            detail: _mediumLabel(
              medium,
              marathi: pathway.marathiDuration,
              semiEnglish: '${pathway.duration} / ${pathway.marathiDuration}',
              english: pathway.duration,
            ),
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 14),
          _DirectoryDetail(
            label: _mediumLabel(
              medium,
              marathi: 'क्षेत्रे',
              semiEnglish: 'Fields to Explore / क्षेत्रे',
              english: 'Fields to Explore',
            ),
            detail: _mediumLabel(
              medium,
              marathi: pathway.marathiFields,
              semiEnglish: '${pathway.fields} / ${pathway.marathiFields}',
              english: pathway.fields,
            ),
            icon: Icons.explore_outlined,
          ),
          const SizedBox(height: 16),
          _TipCard(
            icon: Icons.info_outline_rounded,
            text: _mediumLabel(
              medium,
              marathi:
                  'ही सर्वसाधारण माहिती आहे; प्रवेशाची हमी नाही. पात्रता व तारखांसाठी अधिकृत संस्थेची सूचना तपासा.',
              semiEnglish:
                  'Verify current official notices / सध्याच्या अधिकृत सूचना तपासा.',
              english:
                  'This is a general guide, not an admission guarantee. Verify current eligibility and dates with the official authority or institute.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _DirectoryDetail extends StatelessWidget {
  const _DirectoryDetail({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF425DC3)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(fontSize: 12, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}

void _showAptitudeTest(BuildContext context) {
  const questions = [
    (
      prompt: 'Which activity sounds most interesting?',
      marathi: 'कोणता उपक्रम तुम्हाला सर्वात आवडेल?',
      options: [
        'Build or repair something',
        'Solve a number puzzle',
        'Help or teach someone'
      ],
      categories: [
        'Technology & making',
        'Science & analysis',
        'People & service'
      ],
    ),
    (
      prompt: 'Which school task do you enjoy most?',
      marathi: 'शाळेतील कोणते काम तुम्हाला आवडते?',
      options: [
        'A hands-on project',
        'A tricky question',
        'A group presentation'
      ],
      categories: [
        'Technology & making',
        'Science & analysis',
        'People & service'
      ],
    ),
    (
      prompt: 'What would you like to explore next?',
      marathi: 'पुढे तुम्हाला काय जाणून घ्यायला आवडेल?',
      options: [
        'How machines work',
        'Why patterns happen',
        'How communities grow'
      ],
      categories: [
        'Technology & making',
        'Science & analysis',
        'People & service'
      ],
    ),
  ];

  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var questionIndex = 0;
      final answers = <int>[];
      var selectedOption = -1;
      var showResult = false;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final question = questions[questionIndex];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Aptitude & Interest Explorer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A reflection tool, not an exam or a career decision.',
                  style: TextStyle(color: Color(0xFF737B91), fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (!showResult) ...[
                  Text(
                    'Question ${questionIndex + 1} of ${questions.length}',
                    style: const TextStyle(
                      color: Color(0xFF425DC3),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(question.prompt,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(question.marathi,
                      style: const TextStyle(
                          color: Color(0xFF68718A), fontSize: 13)),
                  const SizedBox(height: 12),
                  RadioGroup<int>(
                    groupValue: selectedOption,
                    onChanged: (value) => setSheetState(
                      () => selectedOption = value ?? -1,
                    ),
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < question.options.length;
                            index++)
                          Card(
                            child: RadioListTile<int>(
                              value: index,
                              title: Text(question.options[index]),
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selectedOption < 0
                          ? null
                          : () => setSheetState(() {
                                answers.add(selectedOption);
                                if (questionIndex < questions.length - 1) {
                                  questionIndex++;
                                  selectedOption = -1;
                                } else {
                                  showResult = true;
                                }
                              }),
                      child: Text(questionIndex == questions.length - 1
                          ? 'See my interest themes'
                          : 'Next'),
                    ),
                  ),
                ] else ...[
                  _AptitudeResult(questions: questions, answers: answers),
                  const SizedBox(height: 14),
                  const _TipCard(
                    icon: Icons.forum_outlined,
                    text:
                        'Use these themes to start a conversation with your family, teachers or a career counsellor. They do not measure ability or decide your future.',
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

class _AptitudeResult extends StatelessWidget {
  const _AptitudeResult({required this.questions, required this.answers});

  final List<
      ({
        String prompt,
        String marathi,
        List<String> options,
        List<String> categories
      })> questions;
  final List<int> answers;

  @override
  Widget build(BuildContext context) {
    final scores = <String, int>{};
    for (var index = 0; index < answers.length; index++) {
      final category = questions[index].categories[answers[index]];
      scores[category] = (scores[category] ?? 0) + 1;
    }
    final rankedCategories = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.emoji_objects_rounded,
            size: 38, color: Color(0xFF7357BE)),
        const SizedBox(height: 8),
        const Text(
          'Your interest themes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final category in rankedCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _StudyIndicator(
              icon: Icons.stars_rounded,
              label: '$category · ${scores[category]}',
              color: const Color(0xFF7357BE),
            ),
          ),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                      color: Color(0xFF68718A), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 40, color: color),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.color,
    required this.tag,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tag;
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 41,
                  width: 41,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: .65,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF737B91),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(action),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: .35)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathwayCard extends StatelessWidget {
  const _PathwayCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFF737B91),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8991A5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF707A91)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF626B80),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

void _showSubjectChapters(
  BuildContext context, {
  required int standard,
  required String subject,
  required String subjectKey,
  required String medium,
  required bool isKidsZone,
  required _LearningContentStore content,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * .78;
      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)} · ${isKidsZone ? 'शोधा आणि शिका' : 'महाराष्ट्र राज्य मंडळ'}',
                style: const TextStyle(
                  color: Color(0xFF737B91),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _chapterTitlesFor(
                    subjectKey: subjectKey,
                    standard: standard,
                    medium: medium,
                  ).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final chapter = index + 1;
                    final chapterTitle = _chapterTitlesFor(
                      subjectKey: subjectKey,
                      standard: standard,
                      medium: medium,
                    )[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$chapter. $chapterTitle',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isKidsZone
                                  ? 'इयत्ता ${_marathiNumber(standard)} · $subject उपक्रम'
                                  : '$subject · बालभारती अध्ययनक्रम',
                              style: const TextStyle(
                                color: Color(0xFF737B91),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 7,
                              children: isKidsZone
                                  ? const [
                                      _StudyIndicator(
                                        icon: Icons.headphones_rounded,
                                        label: 'ऐका आणि शिका',
                                        color: Color(0xFF9A64BD),
                                      ),
                                      _StudyIndicator(
                                        icon: Icons.extension_rounded,
                                        label: 'मजेदार उपक्रम',
                                        color: Color(0xFF168B73),
                                      ),
                                    ]
                                  : [
                                      _StudyIndicator(
                                        icon: Icons.menu_book_rounded,
                                        label: medium == 'Semi-English' &&
                                                (subjectKey == 'maths' ||
                                                    subjectKey == 'science')
                                            ? 'इंग्रजी धडा · बालभारती टिपा'
                                            : 'बालभारती स्वाध्याय',
                                        color: Color(0xFF425DC3),
                                      ),
                                      _StudyIndicator(
                                        icon: Icons.star_rounded,
                                        label: 'महत्त्वाच्या टिपा',
                                        color: Color(0xFFB77916),
                                      ),
                                    ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showChapterNotes(
                                    context,
                                    standard: standard,
                                    medium: medium,
                                    subject: subject,
                                    chapter: chapterTitle,
                                    content: content,
                                  ),
                                  icon: const Icon(Icons.menu_book_rounded,
                                      size: 18),
                                  label:
                                      const Text('पीडीएफ टिपा / पाठ्यपुस्तक'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _showVideoLesson(
                                    context,
                                    content: content,
                                    medium: medium,
                                    standard: standard,
                                    subject: subject,
                                    chapter: chapterTitle,
                                    videoUrl: content
                                        .videoFor(
                                          standard: standard,
                                          medium: medium,
                                          subject: subject,
                                          chapter: chapterTitle,
                                        )
                                        ?.url,
                                    onCompleted: () =>
                                        content.studyCompletions++,
                                  ),
                                  icon: const Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('ध्वनिचित्र धडा'),
                                ),
                              ],
                            ),
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
    },
  );
}

void _showChapterNotes(
  BuildContext context, {
  required int standard,
  required String medium,
  required String subject,
  required String chapter,
  required _LearningContentStore content,
}) {
  final resources = content.resources
      .where((resource) =>
          resource.standard == standard &&
          resource.medium == medium &&
          resource.target == 'Classroom' &&
          (subject.split(' / ').any((name) =>
                  resource.subject.toLowerCase() == name.toLowerCase()) ||
              resource.subject.toLowerCase() == 'all'))
      .toList()
      .reversed
      .toList();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$subject · $chapter',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            _mediumLabel(
              medium,
              marathi:
                  'इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)} · पाठ्यपुस्तक व पीडीएफ टिपा',
              semiEnglish:
                  'Std $standard · Semi-English · PDF Notes & Textbook',
              english:
                  'Standard $standard · English medium · Chapter Notes & Textbook',
            ),
            style: const TextStyle(color: Color(0xFF68718A), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (resources.isNotEmpty)
            for (final resource in resources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text(resource.title),
                subtitle: Text(resource.fileName),
                onTap: () => _showResourcePreview(context, resource),
              )
          else
            Card(
              color: const Color(0xFFF2F4FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: Color(0xFF425DC3)),
                        SizedBox(width: 8),
                        Text(
                          _mediumLabel(
                            medium,
                            marathi: 'पाठ्यपुस्तक वाचन नमुना',
                            semiEnglish:
                                'Textbook Reading Sample / पाठ्यपुस्तक वाचन',
                            english: 'Textbook Reading Sample',
                          ),
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _mediumLabel(
                        medium,
                        marathi:
                            'प्रकरण: $chapter\n\nहा पाठ्यपुस्तक वाचनाचा नमुना आहे. शिक्षकांनी या इयत्तेसाठी पीडीएफ टिपा जोडल्यास त्या येथे दिसतील.',
                        semiEnglish:
                            'Chapter: $chapter\n\nThis is a sample textbook reader. Teacher-uploaded PDF notes for this standard will appear here. / हा पाठ्यपुस्तक वाचन नमुना आहे.',
                        english:
                            'Chapter: $chapter\n\nThis is a sample textbook reader. Teacher-uploaded PDF notes for this standard will appear here.',
                      ),
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mediumLabel(
                        medium,
                        marathi:
                            'हे प्रात्यक्षिक वाचन-दृश्य आहे; प्रत्यक्ष पीडीएफ जोडलेली नाही.',
                        semiEnglish:
                            'Reader preview only; no actual PDF is attached / हे प्रात्यक्षिक आहे.',
                        english:
                            'Reader preview only; no actual PDF is attached.',
                      ),
                      style: TextStyle(
                        color: Color(0xFF68718A),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(_mediumLabel(
                medium,
                marathi: 'बंद करा',
                semiEnglish: 'Close / बंद करा',
                english: 'Close',
              )),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showVideoLesson(
  BuildContext context, {
  required _LearningContentStore content,
  required String medium,
  required int standard,
  required String subject,
  required String chapter,
  String? videoUrl,
  VoidCallback? onCompleted,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var isPlaying = false;
      var isCompleted = false;
      return StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .84,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        color: Color(0xFF425DC3),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Topic-wise video lesson',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$subject · $chapter',
                    style: const TextStyle(
                      color: Color(0xFF68718A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (videoUrl != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Teacher video: $videoUrl',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF168B73),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF253C81), Color(0xFF5C64C9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: isPlaying ? 1.12 : 1,
                          duration: const Duration(milliseconds: 350),
                          child: Icon(
                            subject.toLowerCase().contains('science') ||
                                    subject.toLowerCase().contains('विज्ञान')
                                ? Icons.science_rounded
                                : Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPlaying
                              ? 'Playing lesson preview'
                              : 'Animated lesson preview',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: isPlaying ? .62 : .28,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(5),
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          onPressed: videoUrl == null
                              ? () => setDialogState(
                                    () => isPlaying = !isPlaying,
                                  )
                              : () async {
                                  try {
                                    final opened = await launchUrl(
                                      Uri.parse(videoUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!opened) {
                                      throw StateError(
                                        'ध्वनिचित्र दुवा उघडता आला नाही.',
                                      );
                                    }
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'ध्वनिचित्र दुवा उघडता आला नाही: $error',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: Icon(
                            videoUrl != null
                                ? Icons.open_in_new_rounded
                                : isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            videoUrl != null
                                ? 'Watch teacher video'
                                : isPlaying
                                    ? 'Pause preview'
                                    : 'Play lesson',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Standard $standard · $medium medium',
                    style: const TextStyle(
                      color: Color(0xFF737B91),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.video_library_rounded,
                      color: Color(0xFF425DC3),
                    ),
                    title: Text('Short concept lecture'),
                    subtitle: Text('Learn the key idea one step at a time.'),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.animation_rounded,
                      color: Color(0xFF168B73),
                    ),
                    title: Text('Animated explanation'),
                    subtitle:
                        Text('See the topic represented with simple visuals.'),
                  ),
                  if (subject.toLowerCase().contains('phonics'))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showPhonicsPractice(context),
                        icon: const Icon(Icons.record_voice_over_rounded),
                        label: const Text('Try a phonics question'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isCompleted
                          ? null
                          : () {
                              setDialogState(() => isCompleted = true);
                              onCompleted?.call();
                              _showParentProgressReport(
                                dialogContext,
                                content: content,
                                standard: standard,
                                medium: medium,
                                activity: 'Study module completed: $chapter',
                              );
                            },
                      icon: Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.task_alt_rounded,
                      ),
                      label: Text(
                        isCompleted
                            ? 'Module completed'
                            : 'Mark lesson complete',
                      ),
                    ),
                  ),
                  Text(
                    'This in-app simulator demonstrates the lesson player; it does not stream external video.',
                    style: TextStyle(
                      color: Color(0xFF737B91),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _StudyIndicator extends StatelessWidget {
  const _StudyIndicator({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

void _showDailyQuiz(
  BuildContext context,
  int standard, {
  required String medium,
  required _LearningContentStore content,
}) {
  final isKidsZone = standard <= 4;
  final teacherQuiz = content.quizFor(standard, medium);
  final question =
      teacherQuiz?.question ?? (isKidsZone ? '३ + ४ किती?' : '१२ × ८ किती?');
  final marathiQuestion = teacherQuiz == null
      ? null
      : 'शिक्षकांनी तयार केलेला प्रश्न · ${_mediumMarathi(medium)}';
  final options = teacherQuiz?.options ??
      (isKidsZone
          ? const ['६', '७', '८', '९']
          : const ['८६', '९६', '१०८', '१२४']);
  final correctIndex = teacherQuiz?.correctIndex ?? 1;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) {
      int? selectedIndex;
      String? feedback;
      bool? isCorrect;
      var quizCompleted = false;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'दैनंदिन सराव चाचणी',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  'इयत्ता ${_marathiNumber(standard)} · दैनंदिन बहुपर्यायी प्रश्न · १० पैकी नमुना गुण',
                  style: const TextStyle(
                    color: Color(0xFF737B91),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (marathiQuestion != null)
                  Text(
                    marathiQuestion,
                    style: const TextStyle(
                      color: Color(0xFF68718A),
                      fontSize: 15,
                    ),
                  ),
                const SizedBox(height: 12),
                RadioGroup<int>(
                  groupValue: selectedIndex,
                  onChanged: quizCompleted
                      ? (_) {}
                      : (value) {
                          setSheetState(() {
                            selectedIndex = value;
                            feedback = null;
                            isCorrect = null;
                          });
                        },
                  child: Column(
                    children: [
                      for (var index = 0; index < options.length; index++)
                        Card(
                          color: selectedIndex == index
                              ? const Color(0xFFEAF0FF)
                              : Colors.white,
                          child: RadioListTile<int>(
                            value: index,
                            enabled: !quizCompleted,
                            title: Text(
                              options[index],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (feedback != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: (isCorrect!
                              ? const Color(0xFF168B73)
                              : const Color(0xFFC34444))
                          .withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      feedback!,
                      style: TextStyle(
                        color: isCorrect!
                            ? const Color(0xFF168B73)
                            : const Color(0xFFC34444),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: quizCompleted
                        ? null
                        : () {
                            if (selectedIndex == null) {
                              setSheetState(() {
                                isCorrect = false;
                                feedback = 'आधी एक उत्तर निवडा.';
                              });
                              return;
                            }

                            final isAnswerCorrect =
                                selectedIndex == correctIndex;
                            final score = isAnswerCorrect ? 10 : 0;
                            content.quizCompletions++;
                            setSheetState(() {
                              quizCompleted = true;
                              if (isAnswerCorrect) {
                                isCorrect = true;
                                feedback = isKidsZone
                                    ? 'बरोबर! ३ + ४ = ७. छान!'
                                    : 'बरोबर! १२ × ८ = ९६.';
                              } else {
                                isCorrect = false;
                                feedback = isKidsZone
                                    ? 'चूक झाली. ३ नंतर आणखी ४ मोजून पाहा!'
                                    : 'चूक झाली. १२ × ८ = ९६. पुन्हा प्रयत्न करा!';
                              }
                            });
                            _showParentProgressReport(
                              context,
                              content: content,
                              standard: standard,
                              medium: medium,
                              activity: 'दैनंदिन प्रश्नमंजुषा पूर्ण',
                              score: score,
                            );
                          },
                    child: Text(
                      quizCompleted ? 'चाचणी पूर्ण' : 'उत्तर सादर करा',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showKidsActivity(
  BuildContext context, {
  required int standard,
  required String medium,
  required _LearningContentStore content,
  required String title,
  required String english,
  required String marathi,
}) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _PracticePromptCard(
            prompt: english,
            translation: marathi,
            icon: Icons.auto_stories_rounded,
            color: const Color(0xFF9A64BD),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                content.studyCompletions++;
                Navigator.pop(sheetContext);
                _showParentProgressReport(
                  context,
                  content: content,
                  standard: standard,
                  medium: medium,
                  activity: 'Study module completed: $title',
                );
              },
              child: const Text('Done · झाले'),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showPhonicsPractice(BuildContext context) {
  const words = ['Moon', 'Sun', 'Cat'];
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      int? selectedWord;
      String? feedback;
      bool? isCorrect;
      return StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fun English Phonics',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                'Which word starts with the /m/ sound? · /म/ आवाजाने कोणता शब्द सुरू होतो?',
                style: TextStyle(
                    color: Color(0xFF68718A), fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: selectedWord,
                onChanged: (value) => setSheetState(() {
                  selectedWord = value;
                  feedback = null;
                  isCorrect = null;
                }),
                child: Column(
                  children: [
                    for (var index = 0; index < words.length; index++)
                      Card(
                        child: RadioListTile<int>(
                          value: index,
                          title: Text(
                            words[index],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ),
              if (feedback != null) ...[
                const SizedBox(height: 4),
                _TipCard(
                  icon: isCorrect!
                      ? Icons.check_circle_outline_rounded
                      : Icons.lightbulb_outline_rounded,
                  text: feedback!,
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setSheetState(() {
                    if (selectedWord == null) {
                      isCorrect = false;
                      feedback = 'Choose a word first. · आधी एक शब्द निवडा.';
                    } else if (selectedWord == 0) {
                      isCorrect = true;
                      feedback =
                          'Correct! Moon starts with /m/. छान! Moon हा शब्द /म/ आवाजाने सुरू होतो.';
                    } else {
                      isCorrect = false;
                      feedback =
                          'Listen for /m/: Moon. पुन्हा प्रयत्न करा: Moon.';
                    }
                  }),
                  child: const Text('Check answer · उत्तर तपासा'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showParentProgressReport(
  BuildContext context, {
  required _LearningContentStore content,
  required int standard,
  required String medium,
  required String activity,
  int? score,
}) {
  final scoreSave = score == null
      ? Future<String?>.value(null)
      : _recordQuizScore(
          standard: standard,
          medium: medium,
          score: score,
          activity: activity,
        ).then<String?>(
          (_) => null,
          onError: (Object error) {
            debugPrint('Quiz score could not be saved: $error');
            return '$error';
          },
        );
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      String? deliveryStatus;
      var sharing = false;
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          icon: const Icon(
            Icons.mark_email_read_rounded,
            color: Color(0xFF168B73),
          ),
          title: const Text('पालकांसाठी प्रगती अहवाल'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                score == null
                    ? 'विद्यार्थी प्रगती अहवाल: $activity'
                    : 'विद्यार्थी प्रगती अहवाल: प्रश्नमंजुषा पूर्ण · गुण $score/१०',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)}',
                style: const TextStyle(
                  color: Color(0xFF737B91),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'पालकांच्या WhatsApp वर प्रगती अहवाल पाठवा:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: sharing
                    ? null
                    : () async {
                        setDialogState(() {
                          sharing = true;
                          deliveryStatus = null;
                        });
                        final result = await _shareProgressViaWhatsApp(
                          context,
                          content: content,
                          standard: standard,
                          medium: medium,
                          activity: activity,
                          score: score,
                          scoreSave: scoreSave,
                        );
                        if (!context.mounted) return;
                        setDialogState(() {
                          sharing = false;
                          deliveryStatus = result;
                        });
                      },
                icon: sharing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_rounded, size: 17),
                label: Text(sharing ? 'तयार करत आहे…' : 'WhatsApp वर शेअर करा'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: sharing
                      ? null
                      : () async {
                          final result =
                              await _changeParentWhatsAppNumber(context);
                          if (!context.mounted) return;
                          setDialogState(() => deliveryStatus = result);
                        },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('पालकांचा क्रमांक बदला'),
                ),
              ),
              if (deliveryStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  deliveryStatus!,
                  style: const TextStyle(
                    color: Color(0xFF168B73),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'WhatsApp मध्ये संदेश उघडेल. पाठवण्यापूर्वी पालकांचा क्रमांक तपासा आणि Send दाबा.',
                style: TextStyle(
                    color: Color(0xFF737B91), fontSize: 11, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('पूर्ण'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _recordQuizScore({
  required int standard,
  required String medium,
  required int score,
  required String activity,
}) async {
  final user = AuthService.currentUser;
  if (!_firebaseReady || user == null) {
    throw StateError('Sign in with Firebase to save quiz scores.');
  }
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('quiz_scores')
      .add({
    'standard': standard,
    'medium': medium,
    'score': score,
    'outOf': 10,
    'activity': activity,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<String> _shareProgressViaWhatsApp(
  BuildContext context, {
  required _LearningContentStore content,
  required int standard,
  required String medium,
  required String activity,
  required int? score,
  required Future<String?> scoreSave,
}) async {
  final user = AuthService.currentUser;
  if (!_firebaseReady || user == null) {
    return 'WhatsApp अहवालासाठी Firebase मध्ये विद्यार्थी प्रवेश करा.';
  }

  try {
    final userDocument =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final profileSnapshot = await userDocument.get();
    final profile = profileSnapshot.data() ?? <String, dynamic>{};
    var phone = normalizeWhatsAppNumber(
      profile['parentWhatsApp'] is String
          ? profile['parentWhatsApp'] as String
          : '',
    );
    if (phone == null) {
      if (!context.mounted) return 'WhatsApp शेअर रद्द केले.';
      final rawPhone = await _promptForParentWhatsAppNumber(context);
      if (rawPhone == null) return 'WhatsApp शेअर रद्द केले.';
      phone = normalizeWhatsAppNumber(rawPhone);
    }
    if (phone == null) {
      return 'क्रमांक योग्य नाही. देशाच्या कोडसह ८ ते १५ अंक द्या.';
    }
    if (profile['parentWhatsApp'] != phone) {
      await userDocument.set(
        {
          'parentWhatsApp': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    final scoreSaveError = await scoreSave;
    var quizCount = 0;
    int? latestScore = score;
    double? averageScore = score?.toDouble();
    var scoreReadWarning = false;
    try {
      final scoreSnapshot = await userDocument
          .collection('quiz_scores')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      final scores = scoreSnapshot.docs
          .map((document) => document.data()['score'])
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList();
      quizCount = scores.length;
      if (scores.isNotEmpty) {
        latestScore = scores.first.toInt();
        averageScore = scores.reduce((a, b) => a + b) / scores.length;
      }
    } catch (error) {
      debugPrint('Quiz score history unavailable for report: $error');
      scoreReadWarning = true;
    }
    if (scoreSaveError != null && score != null) {
      quizCount = quizCount == 0 ? 1 : quizCount;
      latestScore = score;
      averageScore ??= score.toDouble();
    }

    var coins = 0;
    var habitsCompleted = 0;
    try {
      final lifeSkillsSnapshot =
          await userDocument.collection('life_skills').doc('state').get();
      final skills = lifeSkillsSnapshot.data() ?? <String, dynamic>{};
      coins = skills['coins'] is num ? (skills['coins'] as num).toInt() : 0;
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rawHabits = skills['habits'];
      if (skills['habitDate'] == today && rawHabits is Map) {
        habitsCompleted =
            rawHabits.values.where((value) => value == true).length;
      }
    } catch (error) {
      debugPrint(
          'Life-skills progress unavailable for WhatsApp report: $error');
    }

    final report = composeProgressReport(
      studentName: profile['name'] is String ? profile['name'] as String : '',
      standard: standard,
      medium: medium,
      activity: activity,
      quizCount: quizCount,
      latestScore: latestScore,
      averageScore: averageScore,
      studyCompletions: content.studyCompletions,
      coins: coins,
      habitsCompletedToday: habitsCompleted,
    );
    final warnings = <String>[
      if (scoreReadWarning)
        'टीप: पूर्ण गुण इतिहास मिळाला नाही; सध्याचे गुण अहवालात समाविष्ट आहेत.',
      if (scoreSaveError != null) 'टीप: हा गुण Firestore मध्ये जतन झाला नाही.',
    ];
    final message =
        warnings.isEmpty ? report : '$report\n${warnings.join('\n')}';
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw StateError('WhatsApp link could not be opened on this device.');
    }
    return 'WhatsApp उघडले आहे. संदेश तपासून Send दाबा.';
  } catch (error) {
    debugPrint('WhatsApp progress share failed: $error');
    return 'अहवाल शेअर करता आला नाही: $error';
  }
}

Future<String?> _promptForParentWhatsAppNumber(BuildContext context,
    {String initialNumber = ''}) async {
  final phoneController = TextEditingController(text: initialNumber);
  final number = await showDialog<String>(
    context: context,
    builder: (numberContext) => AlertDialog(
      title: const Text('पालकांचा WhatsApp क्रमांक'),
      content: TextField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'उदा. 9876543210 किंवा +919876543210',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(numberContext),
          child: const Text('रद्द करा'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(numberContext, phoneController.text.trim()),
          child: const Text('जतन करा'),
        ),
      ],
    ),
  );
  phoneController.dispose();
  return number;
}

Future<String> _changeParentWhatsAppNumber(BuildContext context) async {
  final user = AuthService.currentUser;
  if (!_firebaseReady || user == null) {
    return 'क्रमांक जतन करण्यासाठी Firebase विद्यार्थी प्रवेश आवश्यक आहे.';
  }
  try {
    final document =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await document.get();
    final profile = snapshot.data() ?? <String, dynamic>{};
    final initial = profile['parentWhatsApp'] is String
        ? profile['parentWhatsApp'] as String
        : '';
    if (!context.mounted) return 'क्रमांक बदल रद्द केला.';
    final rawPhone = await _promptForParentWhatsAppNumber(
      context,
      initialNumber: initial,
    );
    if (rawPhone == null) return 'क्रमांक बदल रद्द केला.';
    final phone = normalizeWhatsAppNumber(rawPhone);
    if (phone == null) {
      return 'क्रमांक योग्य नाही. देशाच्या कोडसह ८ ते १५ अंक द्या.';
    }
    await document.set(
      {
        'parentWhatsApp': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return 'पालकांचा WhatsApp क्रमांक जतन केला.';
  } catch (error) {
    debugPrint('Parent WhatsApp number could not be saved: $error');
    return 'क्रमांक जतन करता आला नाही: $error';
  }
}

void _showPremiumCheckout(
  BuildContext context, {
  required int standard,
  required String medium,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      var paymentMethod = 'UPI';
      var checkoutComplete = false;
      const paymentMethods = [
        (name: 'UPI', icon: Icons.qr_code_rounded),
        (name: 'Google Pay', icon: Icons.account_balance_wallet_rounded),
        (name: 'PhonePe', icon: Icons.phone_android_rounded),
        (name: 'Credit/Debit Card', icon: Icons.credit_card_rounded),
      ];
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          icon: const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF168B73),
          ),
          title: const Text('विशेष अभ्यासक्रमासाठी शुल्क भरणा'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'महास्कॉलर विशेष सुविधा · इयत्ता ${_marathiNumber(standard)} · ${_mediumMarathi(medium)}',
                style: const TextStyle(
                  color: Color(0xFF68718A),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'दहावीचा प्रश्नसंच, थेट मार्गदर्शन आणि जाहिरातमुक्त ध्वनिचित्र धडे.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 15),
              Text(
                'शुल्क भरण्याची पद्धत निवडा · $paymentMethod निवडले',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in paymentMethods)
                    ChoiceChip(
                      avatar: Icon(method.icon, size: 17),
                      label: Text(method.name),
                      selected: paymentMethod == method.name,
                      onSelected: checkoutComplete
                          ? null
                          : (_) => setDialogState(
                                () => paymentMethod = method.name,
                              ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text(
                  'Secure checkout demo only · ₹0.00 · No charge or payment data is collected. A real gateway requires a verified provider and server-side order validation.',
                  style: TextStyle(
                    color: Color(0xFF626B80),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
              if (checkoutComplete) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF168B73),
                      size: 19,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Demo checkout complete. No payment was processed.',
                        style: TextStyle(
                          color: Color(0xFF168B73),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(checkoutComplete ? 'Done' : 'Cancel'),
            ),
            if (!checkoutComplete)
              FilledButton.icon(
                onPressed: () => setDialogState(
                  () => checkoutComplete = true,
                ),
                icon: const Icon(Icons.lock_rounded, size: 16),
                label: const Text('Simulate secure checkout'),
              ),
          ],
        ),
      );
    },
  );
}

void _showInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
