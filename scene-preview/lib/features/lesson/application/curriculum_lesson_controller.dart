import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/avatar/scene/automatic_reader.dart';
import '../../auth/auth_api.dart';
import '../domain/course_catalog.dart';
import 'lesson_controller.dart';

class CurriculumBeat {
  const CurriculumBeat({
    required this.step,
    this.check,
    this.audio = const [],
    this.modelStep,
  });
  final Map<String, dynamic> step;
  final Map<String, dynamic>? check;
  final List<String> audio;
  final Map<String, dynamic>? modelStep;
}

/// Content adapter for the existing AdultCoursePanel / LessonNavigation contract.
/// No B1.01-specific presentation or manual recording controls.
class CurriculumLessonController extends LessonController {
  CurriculumLessonController({
    required this.api,
    required this.avatar,
    required String id,
    required this.onSelect,
    AutomaticReader Function(CurriculumLessonController)? readerFactory,
    this.feedbackDelay = const Duration(milliseconds: 1900),
  }) : super(accountId: avatar.accountId, accountNickname: avatar.nickname) {
    courseId = id;
    reader =
        readerFactory?.call(this) ??
        AutomaticReader(
          (path) => (kIsWeb ? Uri.base : Uri.parse('https://49.233.179.83'))
              .resolve(path),
          (state, message) {
            if (_closed) return;
            automaticState = state;
            automaticFeedback = message;
            automaticReading = reader.enabled;
            automaticStarting = state == 'starting';
            notifyListeners();
          },
          (_, _) {},
          onSignal: (value) {
            if (_closed) return;
            micLevel = value;
            notifyListeners();
          },
          onTranscript: (text) {
            if (_closed) return;
            liveTranscript = text;
            notifyListeners();
          },
          onRecognized: acceptChoiceSpeech,
          onUtterance: acceptUtterance,
        );
  }
  final AuthApi api;
  final LessonController avatar;
  final Future<void> Function(String) onSelect;
  final Duration feedbackDelay;
  late final AutomaticReader reader;
  late Map<String, dynamic> catalog;
  final beats = <CurriculumBeat>[];
  final _audio = <String, Map<String, dynamic>>{};
  final _initialWords = <String>{};
  final _visited = <String>{};
  final _helpedBeats = <int>{};
  Future<void> _saves = Future<void>.value();
  Map<String, dynamic>? challenge;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _courses = [];
  int _epoch = 0, _revision = 0, _mediaExpires = 0;
  bool _closed = false, _answering = false;
  CurriculumBeat get beat => beats[coursePosition];
  bool valid(int token) => !_closed && token == _epoch && !coursePaused;
  @override
  CourseInfo get activeCourse {
    final c = _courses.firstWhere((c) => c['id'] == courseId);
    return CourseInfo(courseId, '', c['title'] as String, c['goal'] as String);
  }

  @override
  CourseInfo? get nextCourse {
    final i = _courses.indexWhere((c) => c['id'] == courseId);
    if (i + 1 >= _courses.length) return null;
    final c = _courses[i + 1];
    return CourseInfo(
      c['id'] as String,
      '',
      '00 · ${c['title']}',
      c['goal'] as String,
    );
  }

  @override
  Future<void> selectCourse(String id) => onSelect(id);

  Future<void> initialize() async {
    catalog = await api.request('learning/curriculum');
    if (_closed) return;
    if (catalog['state']['level'] == null) {
      catalog['state'] = await api.request(
        'learning/curriculum/start',
        method: 'POST',
        data: {'level': 1, 'revision': catalog['state']['revision']},
      );
    }
    if (_closed) return;
    final testData = catalog['testData'] as Map? ?? catalog;
    _courses = (testData['courses'] as List)
        .where((c) => c['status'] == 'test' || c['status'] == 'pilot')
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final outerState = catalog['state'] as Map;
    final state = outerState['testData'] as Map? ?? outerState;
    _progress = Map<String, dynamic>.from(state['evidence'] as Map? ?? {});
    _initialWords.addAll(
      (_progress!['words'] as List? ?? [])
          .where((w) => w['learned'] == true)
          .map((w) => w['word'] as String),
    );
    final old = (state['progress'] as List)
        .where((p) => p['course'] == courseId)
        .firstOrNull;
    _revision = old?['revision'] as int? ?? 0;
    final sample = testData['sample'] as Map;
    final steps = (sample['steps'] as List)
        .where((s) => s['course'] == courseId)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final checks = (sample['checks'] as List)
        .where((c) => c['course'] == courseId)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final guided = (sample['guidedLessons'] as Map?)?[courseId] as List?;
    if (guided != null) {
      for (var i = 0; i < guided.length; i++) {
        var step = Map<String, dynamic>.from(guided[i] as Map);
        Map<String, dynamic>? modelStep;
        if (step['phase'] == '示范' && i + 1 < guided.length) {
          final next = Map<String, dynamic>.from(guided[i + 1] as Map);
          if (next['phase'] == '跟读' &&
              next['model'] == step['audio'] &&
              next['check'] != null) {
            modelStep = step;
            step = next;
            i++;
          }
        }
        final check = step['check'] == null
            ? null
            : checks.firstWhere((c) => c['id'] == step['check']);
        beats.add(
          CurriculumBeat(
            step: step,
            check: check,
            modelStep: modelStep,
            audio: modelStep != null
                ? [modelStep['audio'] as String]
                : check == null
                ? (step['audio'] == '' ? [] : [step['audio'] as String])
                : (check['audio'] as List).cast<String>(),
          ),
        );
      }
    } else {
      final assigned = <String>{};
      // Bind assessments to their authored situations; listening tasks use their
      // own recorded questions and are never preceded by an exposed answer.
      for (final s in steps.where((s) => s['phase'] != '收束')) {
        final ids = (s['audio'] as String)
            .split('、')
            .where((id) => id.isNotEmpty)
            .toList();
        final attached = checks
            .where(
              (c) =>
                  !assigned.contains(c['id']) &&
                  (c['kind'] != 'word'
                      ? RegExp('\\b${c['id']}\\b')
                            .hasMatch(s['evidence'] as String)
                      : (s['phase'] == '听辨' || s['phase'] == '欢迎') &&
                            c['variant'] == 'a' &&
                            (c['audio'] as List).any(ids.contains)),
            )
            .toList();
        if (attached.isEmpty) {
          beats.add(CurriculumBeat(step: s, audio: ids));
        } else {
          for (final c in attached) {
            assigned.add(c['id'] as String);
            beats.add(
              CurriculumBeat(
                step: s,
                check: c,
                audio: (c['audio'] as List).cast<String>(),
              ),
            );
          }
        }
      }
      final closing = steps.last;
      for (final c in checks.where((c) => !assigned.contains(c['id']))) {
        beats.add(
          CurriculumBeat(
            step: closing,
            check: c,
            audio: (c['audio'] as List).cast<String>(),
          ),
        );
      }
      beats.add(CurriculumBeat(step: closing));
    }
    courseTotal = beats.length;
    courseChapter = activeCourse.title;
    ready = true;
    notifyListeners();
  }

  Future<void> _media() async {
    if (_mediaExpires > DateTime.now().millisecondsSinceEpoch + 60000) return;
    final r = await api.request('learning/curriculum/media');
    _mediaExpires = (r['expiresAt'] as num).toInt();
    for (final a in r['assets'] as List) {
      _audio[a['id'] as String] = Map<String, dynamic>.from(a as Map);
    }
  }

  Future<void> _visit(Map<String, dynamic> step) =>
      _saves = _saves.catchError((Object _) {}).then((_) async {
        if (_visited.contains(step['id']) || _closed) return;
        final r = await api.request(
          'learning/curriculum/progress',
          method: 'POST',
          data: {
            'course': courseId,
            'step': step['id'],
            'version': catalog['version'],
            'revision': _revision,
          },
        );
        _revision = r['revision'] as int;
        _visited.add(step['id'] as String);
      });
  Future<void> _newChallenge(int token) async {
    final c = beat.check;
    if (c == null) return;
    final next = await api.request(
      'learning/curriculum/challenge',
      method: 'POST',
      data: {
        'course': courseId,
        'check': c['id'],
        'version': catalog['version'],
      },
    );
    if (!valid(token)) return;
    if (_helpedBeats.contains(coursePosition)) {
      await api.request(
        'learning/curriculum/hint',
        method: 'POST',
        data: {'challenge': next['id']},
      );
      if (!valid(token)) return;
      next['helped'] = true;
    }
    challenge = next;
    final options = next['options'] as List?;
    courseOptions = options == null
        ? []
        : [
            for (var i = 0; i < options.length; i++)
              {'id': 'answer_$i', 'label': options[i] as String},
          ];
  }

  @override
  void playCourse({
    String style = 'adult',
    bool restart = false,
    bool skip = false,
  }) {
    if (!ready || _closed || !avatar.ready) return;
    avatar.unlockCurriculumAudio();
    courseMode = true;
    coursePaused = false;
    if (restart) {
      coursePosition = 0;
      confirmedCourseWords = null;
      verifiedCourseClosing = null;
    }
    reader.target('', 'starting');
    reader.playing = true;
    unawaited(reader.start());
    unawaited(_enter());
  }

  Future<void> _enter({bool replay = false}) async {
    final token = ++_epoch;
    avatar.stopCurriculumAudio();
    reader.target('', 'stage:$token');
    reader.playing = true;
    _answering = false;
    challenge = null;
    liveTranscript = '';
    coachSentence = '';
    wordFeedback = [];
    courseOptions = [];
    automaticFeedback = '';
    automaticState = 'listening';
    playing = true;
    courseStep = beat.step['id'] as String;
    hideAnswer = beat.check != null && beat.step['supported'] != true;
    lessonPhase = beat.check == null
        ? switch (beat.step['phase']) {
            '释义' => 'meaning',
            '开场' => 'introduce',
            '带练提示' => 'invite',
            '收束' => 'finish',
            _ => 'demonstrate',
          }
        : hideAnswer
        ? 'recall'
        : 'listen';
    courseText = beat.step['instruction'] as String;
    courseDisplay = beat.step['display'] as String? ?? '';
    if (beat.step['supported'] == true) _helpedBeats.add(coursePosition);
    notifyListeners();
    try {
      if (beat.modelStep != null) {
        await _visit(beat.modelStep!);
        if (!valid(token)) return;
      }
      await _visit(beat.step);
      if (!valid(token)) return;
      if (beat.check != null) {
        await _newChallenge(token);
        if (!valid(token)) return;
      }
      await _media();
      if (!valid(token)) return;
      // Arm the same capture target before the model starts. Audio playback
      // gates capture; completion opens it without a step change or request.
      final captureText =
          _audio[beat.step['model']]?['text'] as String? ?? 'oral response';
      if (beat.check != null) reader.target(captureText, 'answer:$token');
      for (final id in beat.audio) {
        if (beat.check == null && !beat.step.containsKey('display')) {
          courseDisplay = _audio[id]!['text'] as String;
        }
        notifyListeners();
        await avatar.playCurriculumAudio({
          ..._audio[id]!,
          'teachingPhase': beat.check != null ? 'demonstrate' : lessonPhase,
        });
        if (!valid(token)) return;
        if (challenge != null && (beat.check!['audio'] as List).contains(id)) {
          await api.request(
            'learning/curriculum/heard',
            method: 'POST',
            data: {'challenge': challenge!['id'], 'audio': id},
          );
          if (!valid(token)) return;
        }
      }
      playing = false;
      if (coursePosition == beats.length - 1 && beat.check == null) {
        await _finish(token);
        return;
      }
      if (beat.check != null) {
        avatar.setCurriculumPhase(hideAnswer ? 'recall' : 'listen');
        reader.target(captureText, 'answer:$token');
        reader.playing = false;
        automaticReading = reader.enabled;
        if (!reader.enabled && !automaticStarting) {
          automaticState = 'error';
          automaticFeedback = '请允许麦克风，点击人物后重试。';
        }
        notifyListeners();
      } else {
        notifyListeners();
        // Narrated meaning leads straight into its English model.
        if (valid(token)) await _advance();
      }
    } catch (_) {
      if (!valid(token)) return;
      playing = false;
      reader.playing = true;
      automaticState = 'error';
      automaticFeedback = '这段暂时未能完成，请点击人物重试。';
      notifyListeners();
    }
  }

  Future<void> _advance() async {
    if (_closed || coursePaused) return;
    if (coursePosition < beats.length - 1) coursePosition++;
    await _enter();
  }

  Future<void> acceptUtterance(Uint8List wav) async {
    if (_closed ||
        coursePaused ||
        playing ||
        challenge == null ||
        _answering ||
        courseOptions.isNotEmpty) {
      return;
    }
    await _answer({'mode': 'oral', 'wav': base64Encode(wav)});
  }

  void acceptChoiceSpeech(String text) {}

  @override
  void respondToCourse(String action) {}

  Future<void> _answer(Map<String, dynamic> answer) async {
    if (challenge == null) return;
    final token = _epoch, id = challenge!['id'];
    _answering = true;
    reader.playing = true;
    automaticState = 'processing';
    notifyListeners();
    try {
      final r = await api.request(
        'learning/curriculum/oral',
        method: 'POST',
        data: {'challenge': id, ...answer},
      );
      if (!valid(token)) return;
      if (r['progress'] is Map) {
        _progress = Map<String, dynamic>.from(r['progress'] as Map);
      }
      liveTranscript = r['heard'] as String? ?? liveTranscript;
      wordFeedback = (r['wordFeedback'] as List? ?? [])
          .map((w) => Map<String, dynamic>.from(w as Map))
          .toList();
      if (r['matched'] == true) {
        avatar.setCurriculumPhase('success');
        // Learning continues even when evidence is insufficient for mastery.
        automaticState = 'success';
        automaticFeedback = '说出来了，我们接着聊。';
        notifyListeners();
        await Future<void>.delayed(feedbackDelay);
        if (valid(token)) await _advance();
      } else {
        _helpedBeats.add(coursePosition);
        beat.step['supported'] = true;
        await api.request(
          'learning/curriculum/hint',
          method: 'POST',
          data: {'challenge': id},
        );
        if (!valid(token)) return;
        automaticState = 'correction';
        avatar.setCurriculumPhase('support');
        automaticFeedback = '慢慢来，老师再陪你说一次。';
        final model = beat.step['model'] as String?;
        if (model != null && _audio[model] != null) {
          coachSentence = _audio[model]!['text'] as String;
          beat.step['display'] = coachSentence;
          hideAnswer = false;
          playing = true;
          notifyListeners();
          await avatar.playCurriculumAudio({
            ..._audio[model]!,
            'teachingPhase': 'support',
          });
          if (!valid(token)) return;
        }
        await _enter(replay: true);
      }
    } catch (_) {
      if (valid(token)) {
        automaticState = 'error';
        automaticFeedback = '这次没有听清，请再说一次。';
        notifyListeners();
      }
    } finally {
      if (valid(token)) {
        _answering = false;
        reader.playing = false;
      }
    }
  }

  Future<void> _finish(int token) async {
    await reader.stop();
    if (!valid(token)) return;
    final r = await api.request('learning/curriculum');
    if (!valid(token)) return;
    final state = r['state'] as Map;
    _progress = Map<String, dynamic>.from(
      (state['testData'] as Map? ?? state)['evidence'] as Map,
    );
    final words = (_progress!['words'] as List)
        .where((w) => w['learned'] == true)
        .map((w) => w['word'] as String)
        .toSet();
    confirmedCourseWords = words.difference(_initialWords).toList();
    confirmedWordTotal = words.length;
    verifiedCourseClosing = address('本节课我们就学到这里。');
    challenge = null;
    courseStep = 'summary';
    courseOptions = [];
    playing = false;
    automaticReading = false;
    lessonPhase = 'finish';
    avatar.setCurriculumPhase('finish');
    notifyListeners();
  }

  @override
  void navigateCourse(int direction) {
    if (_closed || coursePaused || !courseMode) return;
    if (direction > 0 && courseStep == 'summary') return;
    coursePosition = (coursePosition + (direction < 0 ? -1 : 1)).clamp(
      0,
      beats.length - 1,
    );
    unawaited(
      _enter(),
    ); // Navigation never submits an answer or grants evidence.
  }

  @override
  void replayLesson() {
    avatar.unlockCurriculumAudio();
    if (!reader.enabled) {
      playCourse();
      return;
    }
    if (!coursePaused && courseStep != 'summary') {
      unawaited(_enter(replay: true));
    }
  }

  @override
  void pauseCourse() {
    _epoch++;
    coursePaused = true;
    playing = false;
    automaticReading = false;
    micLevel = 0;
    automaticStarting = false;
    unawaited(reader.stop());
    avatar.stopCurriculumAudio();
    notifyListeners();
  }

  @override
  void previewWord(String raw) {
    avatar.unlockCurriculumAudio();
    unawaited(_previewWord(raw));
  }

  Future<void> _previewWord(String text) async {
    if (_closed || coursePaused || _answering) return;
    final token = ++_epoch;
    reader.target('', 'preview:$token');
    reader.playing = true;
    playing = true;
    avatar.stopCurriculumAudio();
    notifyListeners();
    try {
      if (challenge != null) {
        _helpedBeats.add(coursePosition);
        await api.request(
          'learning/curriculum/hint',
          method: 'POST',
          data: {'challenge': challenge!['id']},
        );
        challenge!['helped'] = true;
      }
      await _media();
      if (!valid(token)) return;
      final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      final match = _audio.values
          .where(
            (a) =>
                (a['text'] as String).toLowerCase().replaceAll(
                  RegExp(r'[^a-z]'),
                  '',
                ) ==
                normalized,
          )
          .firstOrNull;
      if (match != null) {
        await avatar.playCurriculumAudio(match);
      } else {
        avatar.previewWord(text);
      }
      if (!valid(token)) return;
      // Resume the same task with its helped challenge, rather than minting a
      // new independent one after a vocabulary preview.
      playing = false;
      if (courseStep == 'summary') {
        avatar.setCurriculumPhase('finish');
        reader.playing = true;
        notifyListeners();
        return;
      }
      reader.target(
        'oral response',
        'answer:$token',
        recognizeOnly: courseOptions.isNotEmpty,
      );
      reader.playing = false;
      avatar.setCurriculumPhase(hideAnswer ? 'recall' : 'listen');
      notifyListeners();
      if (beat.check == null) {
        await Future<void>.delayed(feedbackDelay);
        if (valid(token)) await _advance();
      }
    } catch (e) {
      if (valid(token)) {
        playing = false;
        automaticState = 'error';
        automaticFeedback = '声音暂时未能播放，请点击人物重试。';
        notifyListeners();
      }
    }
  }

  @override
  String reviewIpa(String word) =>
      const {
        'hello': '/həˈloʊ/',
        'hi': '/haɪ/',
        'goodbye': '/ˌɡʊdˈbaɪ/',
        'bye': '/baɪ/',
        'welcome': '/ˈwelkəm/',
        'good': '/ɡʊd/',
        'ok': '/ˌoʊˈkeɪ/',
        'how': '/haʊ/',
        'are': '/ɑːr/',
        'you': '/juː/',
        'i': '/aɪ/',
        'am': '/æm/',
        'me': '/miː/',
        'li': '/liː/',
        'my': '/maɪ/',
        'your': '/jʊr/',
        'name': '/neɪm/',
        'is': '/ɪz/',
        'country': '/ˈkʌntri/',
        'from': '/frʌm/',
        'where': '/wer/',
        'china': '/ˈtʃaɪnə/',
      }[word] ??
      super.reviewIpa(word);

  @override
  void dispose() {
    _closed = true;
    _epoch++;
    unawaited(reader.dispose());
    avatar.stopCurriculumAudio();
    super.dispose();
  }

  @override
  List<String> get courseReviewWords {
    final result = <String>{};
    for (final b in beats) {
      for (final id in b.audio) {
        final row = (catalog['sample']['audio'] as List)
            .where((a) => a['id'] == id)
            .firstOrNull;
        if (row != null) {
          result.addAll(
            RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?")
                .allMatches(
                  (row['text'] as String)
                      .replaceAll('I’m', 'I am')
                      .replaceAll("I'm", 'I am'),
                )
                .map((m) => m[0]!.toLowerCase()),
          );
        }
      }
    }
    return result.toList();
  }
}
