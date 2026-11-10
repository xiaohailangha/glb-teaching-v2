import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/avatar/scene/automatic_reader.dart';
import '../../auth/auth_api.dart';
import '../domain/course_catalog.dart';
import 'lesson_controller.dart';

/// A board belongs to a teaching stage; audio changes only its speaking state.
class TeachingTrialController extends LessonController {
  TeachingTrialController({
    required this.api,
    required this.avatar,
    required String id,
    required this.onSelect,
    AutomaticReader Function(TeachingTrialController)? readerFactory,
    this.feedbackDelay = const Duration(milliseconds: 650),
    this.narrationGap = const Duration(milliseconds: 900),
  }) {
    courseId = id;
    reader =
        readerFactory?.call(this) ??
        AutomaticReader(
          (p) => api.origin.resolve(p),
          (s, m) {
            if (closed) return;
            automaticReading = reader.enabled;
            automaticStarting = s == 'starting';
            if (s == 'error') {
              automaticState = 'error';
              automaticFeedback = m;
            }
            notifyListeners();
          },
          (_, _) {},
          onSignal: (v) {
            if (!closed) {
              micLevel = v;
              notifyListeners();
            }
          },
          onUtterance: acceptUtterance,
          liveTranscription: false,
          wordPauseMs: 350,
          sentencePauseMs: 650,
          utteranceGate: UtteranceGate(threshold: .010, preRollBytes: 12800),
        );
  }
  final AuthApi api;
  final LessonController avatar;
  final Future<void> Function(String) onSelect;
  final Duration feedbackDelay, narrationGap;
  late final AutomaticReader reader;
  Map<String, dynamic> document = {}, learningSummary = {};
  final steps = <Map<String, dynamic>>[],
      audio = <String, Map<String, dynamic>>{};
  final visits = <String, String>{},
      review = <String, String>{},
      achievements = <String, String>{},
      spokenExamples = <String, String>{};
  final wordEvidence = <String>{}, firstPass = <String>{};
  final attemptsByStep = <String, int>{};
  Future<void> saves = Future.value();
  Map<String, dynamic>? repair, lastTiming;
  List<dynamic> board = [], _queue = [];
  bool closed = false, answering = false, _previewing = false;
  int epoch = 0, answerSerial = 0, _queueIndex = 0;
  String chosenPrompt = '',
      activeAudioId = '',
      activeAudioText = '',
      activeAudioLanguage = '',
      _afterQueue = 'idle';
  String? assistedAttempt, selectedReviewSource;
  Map<String, dynamic> get currentCard => steps[coursePosition];
  bool get hasSpeechTarget =>
      chosenPrompt.isNotEmpty && currentCard['summary'] != true;
  String get fullPrompt => chosenPrompt;
  bool valid(int token) => !closed && !coursePaused && token == epoch;
  @override
  CourseInfo get activeCourse =>
      CourseInfo(courseId, '', document['title'] ?? '', document['goal'] ?? '');
  @override
  CourseInfo? get nextCourse => null;
  @override
  Future<void> selectCourse(String id) => onSelect(id);
  @override
  double get courseProgress =>
      currentCard['summary'] == true ? 1 : coursePosition / steps.length;
  @override
  int get reviewPageCount => super.reviewPageCount + 1;
  @override
  bool get canNavigateForward =>
      currentCard['summary'] != true || reviewPage < reviewPageCount - 1;
  @override
  bool get canNavigateBackward =>
      coursePosition > 0 || currentCard['summary'] == true && reviewPage > 0;
  @override
  String get forwardNavigationLabel =>
      currentCard['summary'] == true ? '下一页单词' : '跳过当前小段';
  @override
  String get backwardNavigationLabel =>
      currentCard['summary'] == true && reviewPage > 0 ? '上一页单词' : '返回上一小段';
  @override
  Map<String, dynamic>? get teachingCard => !ready
      ? null
      : {
          ...currentCard,
          'board': board,
          'display': courseDisplay,
          'targetDisplay': fullPrompt,
          'repair': repair,
          'summary': currentCard['summary'] == true,
          'paused': coursePaused,
          'state': automaticState,
          'feedback': automaticFeedback,
          'learningSummary': learningSummary,
          'review': review.values.toList(),
          'achievements': {...achievements},
          'timings': lastTiming,
          'hasSpeechTarget': hasSpeechTarget,
          'reviewSource': selectedReviewSource,
        };
  Future<Map<String, dynamic>> request(
    String route, {
    Map<String, dynamic>? data,
  }) => api.request(
    'learning/pilot/$route',
    method: data == null ? 'GET' : 'POST',
    data: data == null
        ? null
        : {'revision': document['revision'], 'course': courseId, ...data},
  );
  Future<void> initialize() async {
    document = await request('course?course=$courseId');
    steps.addAll(
      (document['steps'] as List).map((s) => Map<String, dynamic>.from(s)),
    );
    for (final v in document['visits'] as List) {
      visits[v['step']] = v['outcome'];
    }
    for (final e in document['flowEvidence'] as List? ?? []) {
      recordEvidence(Map<String, dynamic>.from(e), step: e['step']);
    }
    final first = steps.indexWhere((s) => !visits.containsKey(s['id']));
    coursePosition = first < 0 ? 0 : first;
    courseTotal = steps.length;
    courseChapter = '试教 · ${document['title']}';
    prepareStage();
    ready = true;
    notifyListeners();
  }

  void recordEvidence(Map<String, dynamic> r, {required String step}) {
    attemptsByStep[step] = (attemptsByStep[step] ?? 0) + 1;
    if (r['status'] != 'passed') firstPass.remove(step);
    if (['repair', 'assisted', 'guided-complete'].contains(r['status']))
      review[step] =
          '${r['word'] ?? '当前表达'}${r['type'] == 'structure' ? '（结构）' : ''}';
    if (r['status'] != 'passed' || r['returnToSentence'] == true) return;
    achievements[step] = r['evidenceLevel'] ?? 'supported-expression';
    if (r['heard'] is String) spokenExamples[step] = r['heard'];
    if (attemptsByStep[step] == 1) firstPass.add(step);
    if (r['evidenceLevel'] != 'assisted') {
      review.remove(step);
      review.remove(r['reviewSource']);
      for (final w in r['wordFeedback'] as List? ?? []) {
        if (w['status'] == 'good') wordEvidence.add(w['word']);
      }
    }
  }

  bool conditionNeeded(Map condition) {
    if (condition['unknown'] is String)
      return !wordEvidence.contains(condition['unknown']);
    if (condition['smooth'] is List)
      return (condition['smooth'] as List).every(firstPass.contains) &&
          (condition['words'] as List).every(wordEvidence.contains);
    return true;
  }

  String normalized(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  void prepareStage() {
    final card = currentCard;
    courseStep = card['summary'] == true ? 'summary' : card['id'];
    chosenPrompt = card['display'] ?? '';
    board = List<dynamic>.from(card['board']);
    selectedReviewSource = null;
    if (card['preferSuccessful'] is List) {
      for (final id in card['preferSuccessful']) {
        if (!achievements.containsKey(id) || achievements[id] == 'assisted')
          continue;
        final spoken=spokenExamples[id];
        if(spoken==null)continue;
        final candidate=(card['answers'] as List).where((a)=>normalized(a)==normalized(spoken)).firstOrNull;
        if(candidate!=null){chosenPrompt=candidate;break;}
      }
      board = List<dynamic>.from(
        card['expressionBoards'][chosenPrompt] ?? board,
      );
    }
    if (card['id'] == 'B14') {
      final expression = spokenExamples['B13'];
      if (expression != null) {
        final boards = card['expressionBoards'] as Map;
        final match = boards.keys
            .where((k) => normalized(k) == normalized(expression))
            .firstOrNull;
        if (match != null) board = List<dynamic>.from(boards[match]);
      }
      if (board.isEmpty)
        board = [
          {'kind': 'meaning', 'text': '先留住这次用过的表达，其他说法以后再逐渐熟悉。'},
        ];
    }
    if (card['reviewTarget'] == true) {
      selectedReviewSource = (card['reviewCandidates'] as List)
          .where(review.containsKey)
          .firstOrNull;
      chosenPrompt = selectedReviewSource == null
          ? ''
          : steps.firstWhere((s) => s['id'] == selectedReviewSource)['display'];
    }
    courseDisplay = chosenPrompt;
    courseText = card['body'];
  }

  Future<void> save(String outcome, {String? attempt}) {
    final id = currentCard['id'] as String;
    return saves = saves.catchError((Object _) {}).then((_) async {
      await request(
        'progress',
        data: {
          'step': id,
          'outcome': outcome,
          if (attempt != null) 'attempt': attempt,
        },
      );
      visits[id] = outcome;
    });
  }

  void queueSave(String outcome, {String? attempt}) {
    unawaited(
      save(outcome, attempt: attempt).catchError((Object _) {
        if (!closed) {
          automaticFeedback = '当前进度暂未保存，请检查网络。';
          notifyListeners();
        }
      }),
    );
  }

  Future<void> flushProgress() => saves;
  @override
  void playCourse({
    String style = 'adult',
    bool restart = false,
    bool skip = false,
  }) {
    if (!ready || !avatar.ready || closed) return;
    avatar.unlockCurriculumAudio();
    courseMode = true;
    reader.playing = true;
    if (!reader.enabled) unawaited(reader.start());
    if (coursePaused && !restart) {
      coursePaused = false;
      final t = ++epoch;
      playing = true;
      unawaited(runQueue(_queue.skip(_queueIndex).toList(), _afterQueue, t));
      return;
    }
    coursePaused = false;
    if (restart) coursePosition = 0;
    unawaited(enter());
  }

  Future<void> enter() async {
    final t = ++epoch;
    avatar.stopCurriculumAudio();
    reader.playing = true;
    repair = null;
    assistedAttempt = null;
    answering = false;
    wordFeedback = [];
    liveTranscript = '';
    automaticFeedback = '';
    reviewPage = 0;
    prepareStage();
    if (currentCard['condition'] is Map &&
        !conditionNeeded(currentCard['condition'])) {
      queueSave('not-needed');
      if (coursePosition < steps.length - 1) {
        coursePosition++;
        await enter();
      }
      return;
    }
    playing = true;
    automaticState = 'listening';
    reader.target('', 'narration:$t');
    notifyListeners();
    final ids = [
      ...currentCard['beforeAudio'] as List,
      if (selectedReviewSource != null) ...currentCard['reviewAudio'] as List,
    ];
    await runQueue(
      ids,
      currentCard['summary'] == true
          ? 'finish'
          : hasSpeechTarget
          ? 'listen'
          : currentCard['holdAfter'] == true
          ? 'rest'
          : 'heard',
      t,
    );
  }

  void waitForSpeech(int t) {
    if (!valid(t) || !hasSpeechTarget) return;
    reader.target(repair?['target'] ?? chosenPrompt, 'trial:$t');
    answerSerial++;
    answering = false;
    reader.resumeCapture();
    playing = false;
    automaticState = 'waiting';
    automaticReading = reader.enabled;
    if (!reader.enabled && !automaticStarting) {
      automaticState = 'error';
      automaticFeedback = '请允许麦克风，再点人物继续。可以先看提示、听示范。';
    }
    avatar.setCurriculumPhase('listen');
    notifyListeners();
  }

  Future<Map<String, dynamic>> audioFor(String id) async =>
      audio[id] ??= Map<String, dynamic>.from(
        (await request(
          'audio?course=$courseId&id=${Uri.encodeComponent(id)}',
        ))['asset'],
      );
  Future<void> runQueue(List<dynamic> ids, String after, int t) async {
    _queue = List.of(ids);
    _queueIndex = 0;
    _afterQueue = after;
    reader.playing = true;
    playing = true;
    var opened = false;
    void open() {
      if (!opened && valid(t)) {
        opened = true;
        waitForSpeech(t);
      }
    }

    if (after == 'listen')
      reader.target(repair?['target'] ?? chosenPrompt, 'trial:$t');
    try {
      for (var i = 0; i < ids.length; i++) {
        if (!valid(t)) return;
        _queueIndex = i;
        final item = await audioFor(ids[i]);
        if (!valid(t)) return;
        activeAudioId = ids[i];
        activeAudioText = item['text'] ?? '';
        activeAudioLanguage = item['language'] ?? '';
        notifyListeners();
        await avatar.playCurriculumAudio({
          ...item,
          'teachingPhase': repair == null ? 'demonstrate' : 'support',
          if (after == 'listen' && i == ids.length - 1) 'onSpeechReady': open,
        });
        if (!valid(t)) return;
        _queueIndex = i + 1;
      }
      if (!valid(t)) return;
      activeAudioId = activeAudioText = activeAudioLanguage = '';
      if (after == 'listen') {
        open();
        return;
      }
      if (after == 'preview') return;
      playing = false;
      if (after == 'finish') {
        await finish(t);
        return;
      }
      if (after == 'heard' || after == 'rest') queueSave('heard');
      if (after == 'rest' || after == 'idle') {
        automaticState = 'rest';
        avatar.setCurriculumPhase('listen');
        notifyListeners();
        return;
      }
      await Future<void>.delayed(
        after == 'advance' ? feedbackDelay : narrationGap,
      );
      if (valid(t)) {
        coursePosition++;
        await enter();
      }
    } catch (_) {
      if (valid(t)) {
        playing = false;
        automaticState = 'error';
        automaticFeedback = '这一段暂时未能播放，点人物重试，或用右箭头继续。';
        notifyListeners();
      }
    }
  }

  Future<void> acceptUtterance(Uint8List wav) async {
    if (closed || coursePaused || playing || answering || !hasSpeechTarget)
      return;
    final t = epoch, serial = ++answerSerial;
    answering = true;
    reader.playing = true;
    automaticState = 'processing';
    notifyListeners();
    try {
      final r = await request(
        'oral',
        data: {
          'step': currentCard['id'],
          'attempt': 'trial-${DateTime.now().microsecondsSinceEpoch}-$t',
          'wav': base64Encode(wav),
          if (repair != null) 'repair': repair!['repair'],
          if (assistedAttempt != null) 'assistance': assistedAttempt,
          'reference': repair?['target'] ?? chosenPrompt,
          'hint': 'full',
        },
      );
      if (!valid(t)) return;
      lastTiming = {...?r['timings'] as Map?, ...reader.lastCaptureTimings};
      liveTranscript = r['heard'] ?? '';
      recordEvidence(r, step: currentCard['id']);
      wordFeedback = (r['wordFeedback'] as List? ?? [])
          .map((w) => Map<String, dynamic>.from(w))
          .toList();
      automaticFeedback = r['message'] ?? '';
      switch (r['status']) {
        case 'passed':
          repair = null;
          if (r['returnToSentence'] == true) {
            courseDisplay = chosenPrompt;
            automaticState = 'return';
            notifyListeners();
            await runQueue(r['audio'] ?? [], 'listen', t);
          } else {
            automaticState = 'success';
            avatar.setCurriculumPhase('success');
            queueSave(
              r['evidenceLevel'] == 'assisted' ? 'assisted' : 'passed',
              attempt: r['attempt'],
            );
            if (currentCard['afterBoard'] is List)
              board = List.of(currentCard['afterBoard']);
            notifyListeners();
            await runQueue(currentCard['afterAudio'] ?? [], 'advance', t);
          }
        case 'repair':
          repair = Map<String, dynamic>.from(r);
          courseDisplay = r['target'];
          automaticState = 'correction';
          notifyListeners();
          await runQueue(r['audio'] ?? [], 'listen', t);
        case 'assisted':
          assistedAttempt = r['attempt'];
          repair = null;
          courseDisplay = chosenPrompt;
          automaticState = 'assisted';
          notifyListeners();
          await runQueue(r['audio'] ?? [], 'listen', t);
        case 'guided-complete':
          queueSave('assisted', attempt: r['attempt']);
          repair = null;
          await runQueue(r['responseAudio'] ?? [], 'advance', t);
        default:
          waitForSpeech(t);
      }
    } catch (e) {
      if (valid(t)) {
        playing = false;
        automaticState = 'error';
        automaticFeedback = e is AuthFailure
            ? e.message
            : '这次请求未完成，不算读错。请检查网络后再试。';
        reader.playing = false;
        notifyListeners();
      }
    } finally {
      if (valid(t) && serial == answerSerial) answering = false;
    }
  }

  Future<void> finish(int t) async {
    try {
      await saves;
      if (!valid(t)) return;
      learningSummary = await request('summary?course=$courseId');
      if (!valid(t)) return;
      final ids = learningSummary['audio'] as List? ?? [];
      if (ids.isNotEmpty) await runQueue(ids, 'idle', t);
      if (!valid(t)) return;
      queueSave('heard');
      await reader.stop();
      if (!valid(t)) return;
      playing = false;
      automaticState = 'success';
      avatar.setCurriculumPhase('finish');
      notifyListeners();
    } catch (_) {
      if (valid(t)) {
        automaticFeedback = '本次小结暂未同步，可以先查看完整词表。';
        playing = false;
        notifyListeners();
      }
    }
  }

  @override
  void navigateCourse(int direction) {
    if (closed || direction == 0) return;
    if (currentCard['summary'] == true) {
      if (direction > 0 && reviewPage < reviewPageCount - 1 ||
          direction < 0 && reviewPage > 0) {
        reviewPage += direction > 0 ? 1 : -1;
        notifyListeners();
        return;
      }
      if (direction > 0) return;
    }
    if (direction < 0 && coursePosition == 0) return;
    epoch++;
    answerSerial++;
    reader.playing = true;
    reader.target('', 'navigate:$epoch');
    avatar.stopCurriculumAudio();
    if (direction > 0 && !visits.containsKey(currentCard['id']))
      queueSave('skipped');
    coursePosition += direction > 0 ? 1 : -1;
    coursePaused = false;
    answering = false;
    if (!reader.enabled) unawaited(reader.start());
    unawaited(enter());
  }

  @override
  void pauseCourse() {
    epoch++;
    answerSerial++;
    coursePaused = true;
    playing = false;
    answering = false;
    reader.playing = true;
    avatar.stopCurriculumAudio();
    unawaited(reader.stop());
    notifyListeners();
  }

  @override
  void replayLesson() {
    if (answering) return;
    if (coursePaused || !courseMode) {
      playCourse();
      return;
    }
    avatar.unlockCurriculumAudio();
    if (!reader.enabled) unawaited(reader.start());
    if (repair != null) {
      final t = ++epoch;
      avatar.stopCurriculumAudio();
      unawaited(runQueue(repair!['audio'] ?? [], 'listen', t));
    } else if (automaticState == 'error') {
      final t = ++epoch;
      unawaited(runQueue(_queue.skip(_queueIndex).toList(), _afterQueue, t));
    } else
      unawaited(enter());
  }

  @override
  void previewWord(String text) {
    final map = document['englishIds'] as Map;
    final id = text.toLowerCase() == 'a'
        ? map['a banana']
        : map[text] ?? map[text.toLowerCase()];
    if (id != null) unawaited(preview([id]));
  }

  @override
  void previewIpa(String symbol) {
    unawaited(previewPhoneme(symbol));
  }

  Future<void> previewPhoneme(String symbol) async {
    if (closed || coursePaused || answering || _previewing) return;
    final original = epoch;
    try {
      final key = 'ipa:$symbol';
      if (!audio.containsKey(key)) {
        final r = await request(
          'phoneme?course=$courseId&symbol=${Uri.encodeComponent(symbol)}',
        );
        if (!valid(original)) return;
        audio[key] = Map<String, dynamic>.from(r['asset']);
      }
      await preview([key]);
    } catch (_) {
      if (valid(original)) {
        automaticFeedback = '这个音标暂时没有独立声音。';
        notifyListeners();
      }
    }
  }

  Future<void> preview(List<dynamic> ids) async {
    if (closed || coursePaused || answering || _previewing) return;
    final remaining = _queue.skip(_queueIndex).toList(),
        after = _afterQueue,
        waiting = !playing && hasSpeechTarget,
        wasPlaying = playing,
        t = ++epoch;
    _previewing = true;
    reader.playing = true;
    avatar.unlockCurriculumAudio();
    avatar.stopCurriculumAudio();
    try {
      await runQueue(ids, 'preview', t);
      if (!valid(t)) return;
      if (wasPlaying)
        await runQueue(remaining, after, t);
      else if (waiting) {
        _queue = [];
        _queueIndex = 0;
        _afterQueue = 'listen';
        waitForSpeech(t);
      } else {
        playing = false;
        _queue = remaining;
        _queueIndex = 0;
        _afterQueue = after;
        notifyListeners();
      }
    } finally {
      _previewing = false;
    }
  }

  @override
  String reviewIpa(String word) =>
      (document['words'] as List)
          .where(
            (w) => (w['word'] as String).toLowerCase() == word.toLowerCase(),
          )
          .firstOrNull?['ipa'] ??
      '';
  @override
  List<String> get courseReviewWords =>
      (document['words'] as List).map((w) => w['word'] as String).toList();
  @override
  void dispose() {
    closed = true;
    epoch++;
    unawaited(reader.dispose());
    avatar.stopCurriculumAudio();
    super.dispose();
  }
}
