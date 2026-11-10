import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/avatar/scene/automatic_reader.dart';
import '../../auth/auth_api.dart';
import '../domain/course_catalog.dart';
import '../domain/ipa_sounds.dart';
import 'lesson_controller.dart';
import 'cloud_lesson.dart';
import '../../../core/avatar/scene/course_resources.dart';

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
          (path) => api.origin.resolve(path),
          (state, message) {
            if (_closed) return;
            automaticState = state;
            automaticFeedback = message;
            automaticReading = reader.enabled;
            automaticStarting = state == 'starting';
            notifyListeners();
          },
          (_, _) {},
          liveTranscription: false,
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
  List<Map<String, dynamic>> _actualWords = [];
  String? _resumeStep;
  Future<Map<String, dynamic>> _request(
    String route, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) => api.request(
    route,
    method: method,
    data: method == 'GET'
        ? data
        : {'version': catalog['version'], 'course': courseId, ...?data},
  );
  bool _closed = false, _answering = false, _navigating = false;
  Future<void> flushProgress() => _saves.catchError((Object _) {});
  @override
  double get courseProgress {
    if (courseStep == 'summary') return 1;
    if (beats.isEmpty) return 0;
    final completed = beats
        .where(
          (b) =>
              _visited.contains(b.step['id']) &&
              (b.modelStep == null || _visited.contains(b.modelStep!['id'])),
        )
        .length;
    return (completed / beats.length).clamp(0.0, .99);
  }

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
  Future<void> selectCourse(String id) async {
    await flushProgress();
    if (!_closed) await onSelect(id);
  }

  Future<void> initialize() async {
    final release = CourseResources.instance.release;
    if (release == null) throw StateError('正式课程尚未载入');
    catalog = {
      ...CourseResources.instance.catalog,
      'version': release,
      'state': await api.request(
        'learning/curriculum/state?release=' + release,
      ),
    };
    if (_closed) return;
    if (catalog['state']['level'] == null) {
      catalog['state'] = await _request(
        'learning/curriculum/start',
        method: 'POST',
        data: {'level': 1, 'revision': catalog['state']['revision']},
      );
    }
    _courses = (catalog['courses'] as List)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final state = catalog['state'] as Map;
    _progress = Map<String, dynamic>.from(state['evidence'] as Map);
    final old = (state['progress'] as List)
        .where((p) => p['course'] == courseId)
        .firstOrNull;
    _revision = old?['revision'] as int? ?? 0;
    _resumeStep = old?['step'] as String?;
    _visited.addAll((old?['visitedSteps'] as List? ?? []).cast<String>());
    final doc = await loadCloudLesson(
      api,
      courseId,
      catalog['version'] as String,
    );
    if (_closed) return;
    final lesson = doc['lesson'] as Map;
    _actualWords = (lesson['actualWords'] as List)
        .map((w) => Map<String, dynamic>.from(w as Map))
        .toList();
    catalog['sample'] = {'audio': doc['audio']};
    final steps = (lesson['steps'] as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    final checks = (lesson['checks'] as List)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final guided = steps;
    {
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
                : step['model'] is String &&
                      (step['model'] as String).isNotEmpty
                ? [step['model'] as String]
                : (check['audio'] as List).cast<String>(),
          ),
        );
      }
    }
    courseTotal = beats.length;
    final pendingStep = old?['pendingStep'] as String?;
    if (pendingStep != null) {
      final i = beats.indexWhere(
        (b) => b.step['id'] == pendingStep || b.modelStep?['id'] == pendingStep,
      );
      if (i >= 0) coursePosition = i;
    } else if (_resumeStep != null) {
      final i = beats.indexWhere(
        (b) => b.step['id'] == _resumeStep || b.modelStep?['id'] == _resumeStep,
      );
      if (i >= 0)
        coursePosition = (i + (beats[i].step['id'] == _resumeStep ? 1 : 0))
            .clamp(0, beats.length - 1);
    }
    courseChapter = activeCourse.title;
    ready = true;
    notifyListeners();
  }

  Future<void> _media() async {
    if (_mediaExpires > DateTime.now().millisecondsSinceEpoch + 60000) return;
    final r = await _request(
      'learning/curriculum/media?course=$courseId&release=${catalog['version']}',
    );
    if (r['release'] != catalog['version'])
      throw const FormatException('课程版本不一致');
    _mediaExpires = (r['expiresAt'] as num).toInt();
    for (final a in r['assets'] as List) {
      _audio[a['id'] as String] = {
        ...Map<String, dynamic>.from(a as Map),
        'release': r['release'],
      };
    }
  }

  Future<void> _visit(Map<String, dynamic> step) =>
      _saves = _saves.catchError((Object _) {}).then((_) async {
        if (_visited.contains(step['id']) || _closed) return;
        final r = await _request(
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
    final next = await _request(
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
      await _request(
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

  Future<void> _enter({bool correction = false}) async {
    final token = ++_epoch;
    avatar.stopCurriculumAudio();
    reader.target('', 'stage:$token');
    reader.playing = true;
    _answering = false;
    challenge = null;
    liveTranscript = '';
    coachSentence = correction
        ? (_audio[beat.step['model']]?['text'] as String? ?? '')
        : '';
    wordFeedback = [];
    courseOptions = [];
    automaticFeedback = correction ? '慢慢来，老师再陪你说一次。' : '';
    automaticState = correction ? 'correction' : 'listening';
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
          'teachingPhase': beat.check != null
              ? (correction ? 'support' : 'demonstrate')
              : lessonPhase,
        });
        if (!valid(token)) return;
        {
          final heard = <String, dynamic>{'step': beat.step['id'], 'audio': id};
          if (challenge != null && (challenge!['audio'] as List).contains(id))
            heard['challenge'] = challenge!['id'];
          await _request(
            'learning/curriculum/heard',
            method: 'POST',
            data: heard,
          );
          if (!valid(token)) return;
        }
      }
      if (beat.modelStep != null) await _visit(beat.modelStep!);
      if (beat.check == null) await _visit(beat.step);
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
        courseOptions.any((o) => o['id']!.startsWith('answer_'))) {
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
      final r = await _request(
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
        await _visit(beat.step);
        await Future<void>.delayed(feedbackDelay);
        if (valid(token)) await _advance();
      } else {
        _helpedBeats.add(coursePosition);
        beat.step['supported'] = true;
        await _request(
          'learning/curriculum/hint',
          method: 'POST',
          data: {'challenge': id},
        );
        if (!valid(token)) return;
        // Re-entering prepares the next helped challenge and plays its model
        // once. A separate correction playback here used to double the clip.
        await _enter(correction: true);
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
    await _saves;
    if (!valid(token)) return;
    final r = {
      'state': await _request(
        'learning/curriculum/state?release=' + catalog['version'].toString(),
      ),
    };
    if (!valid(token)) return;
    final state = r['state'] as Map;
    catalog['state'] = state;
    if (!(state['evidence']['completedCourses'] as List).contains(courseId)) {
      final progress = (state['progress'] as List)
          .where((p) => p['course'] == courseId)
          .firstOrNull;
      final pendingStep = progress?['pendingStep'];
      final i = beats.indexWhere(
        (b) => b.step['id'] == pendingStep || b.modelStep?['id'] == pendingStep,
      );
      if (pendingStep == null || i < 0) {
        throw StateError('课程进度尚未确认，请重新打开本课');
      }
      coursePosition = i;
      await _enter();
      return;
    }
    await reader.stop();
    if (!valid(token)) return;
    _progress = Map<String, dynamic>.from(state['evidence'] as Map);
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
    if (_closed || coursePaused || !courseMode || _navigating) return;
    if (direction > 0 && courseStep == 'summary' ||
        direction < 0 && coursePosition == 0)
      return;
    unawaited(_navigate(direction));
  }

  Future<void> _navigate(int direction) async {
    _navigating = true;
    final token = ++_epoch, current = beat;
    reader.target('', 'navigate:$token');
    reader.playing = true;
    avatar.stopCurriculumAudio();
    playing = true;
    challenge = null;
    courseOptions = [];
    notifyListeners();
    try {
      await flushProgress();
      if (!valid(token)) return;
      if (direction > 0 && !_visited.contains(current.step['id'])) {
        _saves =
            _request(
              'learning/curriculum/skip',
              method: 'POST',
              data: {'step': current.step['id'], 'revision': _revision},
            ).then((r) {
              _revision = r['revision'] as int;
              _visited.addAll((r['skippedSteps'] as List).cast<String>());
            });
        await _saves;
      }
      if (!valid(token)) return;
      if (direction > 0 && coursePosition == beats.length - 1) {
        await _finish(token);
      } else {
        coursePosition += direction < 0 ? -1 : 1;
        if (!reader.enabled) unawaited(reader.start());
        unawaited(_enter());
      }
    } catch (_) {
      if (valid(token)) {
        playing = false;
        automaticState = 'error';
        automaticFeedback = '切换暂时未能保存，请再次点击箭头。';
        notifyListeners();
      }
    } finally {
      _navigating = false;
    }
  }

  @override
  void replayLesson() {
    avatar.unlockCurriculumAudio();
    if (!reader.enabled) {
      playCourse();
      return;
    }
    if (!coursePaused && courseStep != 'summary') {
      unawaited(_enter());
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
        await _request(
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
        throw StateError('当前课程没有该词的独立示范');
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
        recognizeOnly: courseOptions.any((o) => o['id']!.startsWith('answer_')),
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

  final _phonemes = <String, Map<String, dynamic>>{};
  @override
  void previewIpa(String symbol) {
    if (!ipaSounds.containsKey(symbol) || _closed || coursePaused || _answering)
      return;
    avatar.unlockCurriculumAudio();
    unawaited(_previewIpa(symbol));
  }

  Future<void> _previewIpa(String symbol) async {
    final resumeModel = playing, summary = courseStep == 'summary';
    final token = ++_epoch;
    reader.target('', 'ipa:$token');
    reader.playing = true;
    avatar.stopCurriculumAudio();
    playing = true;
    notifyListeners();
    try {
      if (challenge != null) {
        await _request(
          'learning/curriculum/hint',
          method: 'POST',
          data: {'challenge': challenge!['id']},
        );
        if (!valid(token)) return;
        challenge!['helped'] = true;
      }
      var asset = _phonemes[symbol];
      if (asset == null) {
        final result = await _request(
          'learning/curriculum/phoneme?course=$courseId&release=${catalog['version']}&symbol=${Uri.encodeComponent(symbol)}',
        );
        if (result['release'] != catalog['version'] ||
            result['course'] != courseId ||
            result['asset']['symbol'] != symbol)
          throw const FormatException('音标资料不一致');
        asset = Map<String, dynamic>.from(result['asset'] as Map);
        _phonemes[symbol] = asset;
      }
      if (!valid(token)) return;
      await avatar.playCurriculumAudio({...asset, 'teachingPhase': 'phoneme'});
      if (!valid(token)) return;
      playing = false;
      if (summary) {
        avatar.setCurriculumPhase('finish');
        notifyListeners();
      } else if (resumeModel || beat.check == null) {
        await _enter();
      } else {
        reader.target(
          _audio[beat.step['model']]?['text'] as String? ?? 'oral response',
          'answer:$token',
        );
        reader.playing = false;
        avatar.setCurriculumPhase(hideAnswer ? 'recall' : 'listen');
        notifyListeners();
      }
    } catch (_) {
      if (valid(token)) {
        playing = false;
        automaticState = 'error';
        automaticFeedback = '音标声音暂时未能播放，请再点一次。';
        notifyListeners();
      }
    }
  }

  @override
  String reviewIpa(String word) =>
      _actualWords
              .where(
                (w) =>
                    (w['word'] as String).toLowerCase() == word.toLowerCase(),
              )
              .firstOrNull?['ipa']
          as String? ??
      '';

  @override
  void dispose() {
    _closed = true;
    _epoch++;
    unawaited(reader.dispose());
    avatar.stopCurriculumAudio();
    super.dispose();
  }

  @override
  List<String> get courseReviewWords => _actualWords
      .where((w) => w['standalonePreview'] != false)
      .map((w) => w['word'] as String)
      .toSet()
      .toList();
}
