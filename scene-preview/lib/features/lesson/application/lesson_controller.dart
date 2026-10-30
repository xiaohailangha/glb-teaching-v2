import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/lesson_word.dart';
import '../domain/emotion.dart';
import '../domain/vocabulary_ledger.dart';
import '../domain/course_lexicon.dart';

typedef AvatarCommand = void Function(Map<String, Object?> command);

class LessonController extends ChangeNotifier {
  final vocabulary = VocabularyLedger();
  bool automaticReading = false, automaticStarting = false;
  String automaticFeedback = '', selectedWord = '';
  String automaticState = '', liveTranscript = '', coachSentence = '';
  double micLevel = 0;
  List<Map<String, dynamic>> wordFeedback = [];
  Future<void> _saveVocabulary() async {
    final data = jsonEncode(vocabulary.toJson());
    _saveQueue = _saveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vocabulary-exposure-v1', data);
      } catch (_) {}
    });
  }

  void expose(String text) {
    if (vocabulary.expose(text)) {
      unawaited(_saveVocabulary());
    }
  }

  void previewWord(String raw) {
    final key = raw.toLowerCase();
    final item = courseLexicon[key];
    if (item == null) return;
    selectedWord = key;
    expose(key);
    previewCourse(item.clip);
    notifyListeners();
  }

  void toggleAutomatic() {
    if (!speechAvailable || !adultCourse || coursePaused) return;
    if (automaticReading || automaticStarting) {
      automaticReading = automaticStarting = false;
      automaticFeedback = '自动跟读已关闭';
      _send?.call({'type': 'auto-stop', 'session': session});
    } else {
      automaticStarting = true;
      automaticFeedback = '请允许麦克风；只上传本次练习的语音片段用于评测。';
      _send?.call({'type': 'auto-start', 'session': session});
    }
    notifyListeners();
  }

  final playbackTick = ValueNotifier<int>(0);
  int index = 0, iteration = 0, session = 0;
  bool ready = false, playing = false, repeating = false, closeUp = false;
  bool emotionMode = false, emotionReel = false;
  bool courseMode = false, hideAnswer = false;
  String courseStyle = 'adult', courseText = '', courseStep = '';
  List<Map<String, String>> courseOptions = [];
  bool coursePaused = false;
  String courseSpeechText = '';
  List<Map<String, String>> courseSegments = [];
  String courseDisplay = '', coursePicture = '', courseChapter = '';
  int coursePosition = 0, courseTotal = 1;
  Map<String, dynamic>? courseCheckpoint;
  bool get adultCourse => courseMode && courseStyle == 'adult';
  Future<void> _saveQueue = Future.value();
  Future<void> loadCourseProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vocab = prefs.getString('vocabulary-exposure-v1');
      if (vocab != null) {
        final data = jsonDecode(vocab);
        if (data is Map) vocabulary.restore(data);
      }
      final saved = prefs.getString('adult-fruit-v2');
      if (!_disposed && courseCheckpoint == null && saved != null) {
        final data = jsonDecode(saved);
        if (data is Map && data['version'] == 1) {
          courseCheckpoint = Map<String, dynamic>.from(data);
          if (vocab == null) {
            for (final word
                in (data['taught'] as List? ?? []).whereType<String>()) {
              vocabulary.expose(word);
            }
            unawaited(_saveVocabulary());
          }
        }
        notifyListeners();
      }
    } catch (_) {
      /* Storage unavailable does not prevent learning. */
    }
  }

  void _saveCourse() {
    final data = jsonEncode(courseCheckpoint);
    _saveQueue = _saveQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('adult-fruit-v2', data);
      } catch (_) {}
    });
  }

  void pauseCourse() {
    if (!adultCourse || coursePaused) return;
    coursePaused = true;
    vocabulary.inCourse = false;
    automaticReading = automaticStarting = false;
    playing = false;
    captureState = 'idle';
    session++;
    _send?.call({'type': 'stop', 'session': session});
    notifyListeners();
  }

  void previewCourse(String clip) {
    if (!adultCourse || coursePaused || !ready) return;
    captureState = 'idle';
    _send?.call({'type': 'course-preview', 'clip': clip, 'session': session});
  }

  int emotionIndex = 0;
  Emotion get emotion => emotions[emotionIndex];
  double rate = 1, progress = 0, level = 0;
  String viseme = '';
  String lessonPhase = 'ready';
  String activeSound = '';
  bool speechAvailable = false;
  String captureState = 'idle', speechFeedback = '';
  bool get capturing => captureState == 'recording';
  bool get processingSpeech => captureState == 'processing';
  bool get canCapture =>
      speechAvailable &&
      !emotionMode &&
      !coursePaused &&
      !(adultCourse && courseStep == 'extension_gate') &&
      (lessonPhase == 'listen' || lessonPhase == 'recall');
  bool get awaitingResponse =>
      !courseMode && !emotionMode && lessonPhase == 'listen';
  String get displayWord => hideAnswer
      ? (lessonPhase == 'recall' ? word.meaning : '…')
      : word.id.toUpperCase();
  String get lessonHeading => switch (lessonPhase) {
    'introduce' => 'LOOK & LISTEN',
    'invite' || 'listen' => 'YOUR TURN',
    'encourage' => 'KEEP GOING',
    _ => 'LISTEN & REPEAT',
  };
  String get lessonHint => courseMode && courseText.isNotEmpty
      ? courseText
      : switch (lessonPhase) {
          'introduce' => '我们一起看看这个单词',
          'demonstrate' => rate < 1 ? '慢慢听，再跟着读' : '听一听它的发音',
          'invite' || 'listen' => '轮到你了，试着说一遍',
          'encourage' => '保持练习，我们继续',
          'phoneme' => '听 /$activeSound/，留意口型',
          'meaning' => '听中文释义',
          _ => '点击单词，开始一起练习',
        };
  String? error;
  Map<String, dynamic> diagnostics = {};
  AvatarCommand? _send;
  Map<String, Object?> _renderSettings = {
    'type': 'render-settings',
    'quality': 'high',
    'adaptive': true,
  };
  void setRenderSettings(Map<String, Object?> value) {
    _renderSettings = Map.of(value);
    if (ready) _send?.call(_renderSettings);
  }

  bool _disposed = false;
  LessonWord get word => lessonWords[index];
  void attach(AvatarCommand send) {
    _send = send;
  }

  void handle(Map<String, dynamic> message) {
    if (_disposed) return;
    final event = message['event'];
    if (event == 'ready') {
      ready = true;
      error = null;
      diagnostics = message;
      expose(word.id);
      speechAvailable = (message['speech'] as Map?)?['configured'] == true;
      _send?.call({'type': 'focus', 'closeUp': closeUp});
      _send?.call(_renderSettings);
    } else if (event == 'error') {
      error = message['message']?.toString() ?? '人物加载失败，请重试';
      playing = false;
    } else if (event == 'stats') {
      diagnostics = {...diagnostics, ...message};
    } else {
      if (message['session'] != session) return;
      if (event == 'mic-signal') {
        micLevel = (message['level'] as num?)?.toDouble() ?? 0;
      } else if (event == 'transcript') {
        liveTranscript = message['text']?.toString() ?? '';
      } else if (event == 'auto-state') {
        automaticReading = message['enabled'] == true;
        if (message['state'] == 'starting') {
          automaticStarting = true;
        } else if (automaticReading || message['state'] == 'error') {
          automaticStarting = false;
        }
        automaticFeedback = message['message']?.toString() ?? '';
        automaticState = message['state']?.toString() ?? automaticState;
        if (message['sentence'] is String) {
          coachSentence = message['sentence'] as String;
        }
        if (message['words'] is List) {
          wordFeedback = (message['words'] as List)
              .whereType<Map>()
              .map((w) => Map<String, dynamic>.from(w))
              .toList();
        }
      } else if (event == 'capture') {
        captureState = message['state']?.toString() ?? 'idle';
        if (captureState == 'recording') speechFeedback = '正在听…';
        if (captureState == 'processing') speechFeedback = '正在处理你的回答…';
        if (captureState == 'error') {
          speechFeedback = message['message']?.toString() ?? '请再试一次';
        }
        if (captureState == 'done') {
          if (message['mode'] == 'recognize') {
            final text = message['text']?.toString().trim() ?? '';
            speechFeedback = text.isEmpty ? '这次没有听清，请再试一次。' : '听到：$text';
            if (adultCourse && text.isNotEmpty) {
              final heard = text
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z ]'), '')
                  .split(' ');
              speechFeedback = courseSpeechText.contains(' ')
                  ? '听到：$text。目标是：$courseSpeechText。请对照内容再练习，识别结果不等于整句发音评分。'
                  : heard.contains(word.id)
                  ? '听到了 ${word.id}，这次想起来了。可以继续，也可以再练。'
                  : '听到：$text。和目标词还不一致，可以再试或听提示。';
            }
          } else {
            final result = message['result'] as Map? ?? {};
            final score = (result['PronAccuracy'] as num?)?.toDouble();
            speechFeedback = score == null || score < 0
                ? '这次读音未能匹配，请听示范后再试。'
                : '本次发音参考：${score.toStringAsFixed(0)} 分';
          }
        }
      } else if (event == 'speech-error') {
        playing = false;
        speechFeedback = message['message']?.toString() ?? '语音暂时不可用，请重试';
      } else if (event == 'speech-loading') {
        speechFeedback = '正在准备示范…';
      } else if (event == 'lesson-phase') {
        final phase = message['phase']?.toString();
        if (!const [
          'ready',
          'introduce',
          'demonstrate',
          'invite',
          'listen',
          'encourage',
          'phoneme',
          'meaning',
          'explain',
          'choice',
          'recall',
          'support',
          'success',
          'transfer',
          'finish',
        ].contains(phase)) {
          return;
        }
        lessonPhase = phase!;
        playing = message['speaking'] == true;
        selectedWord = '';
        speechFeedback = '';
        activeSound = message['symbol']?.toString() ?? '';
        emotionMode = false;
        if (courseMode) {
          if (message['checkpoint'] is Map) {
            courseCheckpoint = Map<String, dynamic>.from(
              message['checkpoint'] as Map,
            );
            coursePosition = (message['stageIndex'] as num?)?.toInt() ?? 0;
            courseTotal = (message['stageCount'] as num?)?.toInt() ?? 1;
            courseDisplay = message['display']?.toString() ?? '';
            courseSpeechText = message['speechText']?.toString() ?? '';
            courseSegments = [
              for (final o in message['segments'] as List? ?? [])
                Map<String, String>.from(o as Map),
            ];
            coursePicture = message['picture']?.toString() ?? '';
            courseChapter = message['chapter']?.toString() ?? '';
            final nextWord = lessonWords.indexWhere(
              (w) => w.id == message['word'],
            );
            if (nextWord >= 0) index = nextWord;
            _saveCourse();
          }
          courseText = message['text']?.toString() ?? '';
          courseStep = message['step']?.toString() ?? '';
          hideAnswer = message['hideAnswer'] == true;
          if (!hideAnswer && phase != 'phoneme') {
            expose(courseDisplay);
            expose(courseText.replaceAll(RegExp(r'/[^/]+/'), ''));
          }
          if (courseStep == 'summary') {
            unawaited(_saveVocabulary());
          }
          courseOptions = (message['options'] as List? ?? [])
              .whereType<Map>()
              .map(
                (o) => {
                  'id': o['id'].toString(),
                  'label': o['label'].toString(),
                },
              )
              .toList();
        }
      } else if (event == 'emotion') {
        final next = emotions.indexWhere((e) => e.id == message['emotion']);
        if (next < 0) return;
        emotionMode = true;
        emotionIndex = next;
      } else if (event == 'playing' || event == 'progress') {
        if (event == 'playing' && message['text'] is String) {
          expose(message['text'] as String);
        }
        if (speechFeedback == '正在准备示范…') speechFeedback = '';
        final stateChanged =
            !playing ||
            iteration != ((message['iteration'] as num?)?.toInt() ?? 1);
        playing = true;
        progress = ((message['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1);
        level = (message['level'] as num?)?.toDouble() ?? 0;
        iteration = (message['iteration'] as num?)?.toInt() ?? 1;
        viseme = message['viseme']?.toString() ?? '';
        playbackTick.value++;
        if (!stateChanged) return;
      } else if (event == 'ended' || event == 'stopped') {
        playing = false;
        progress = event == 'ended' ? 1 : 0;
        level = 0;
        viseme = '';
        activeSound = '';
      }
    }
    notifyListeners();
  }

  void select(int value) {
    stop();
    emotionMode = false;
    index = value.clamp(0, lessonWords.length - 1);
    expose(word.id);
    progress = 0;
    notifyListeners();
    if (ready) play(reason: 'next');
  }

  void step(int delta) {
    if (adultCourse) return;
    if (emotionMode) {
      playEmotion((emotionIndex + delta) % emotions.length);
    } else {
      select((index + delta) % lessonWords.length);
    }
  }

  void play({String reason = 'start'}) {
    if (!ready || error != null) return;
    if (courseMode) {
      playCourse(style: courseStyle);
      return;
    }
    if (emotionMode) {
      playEmotion(emotionIndex);
      return;
    }
    session++;
    playing = true;
    progress = 0;
    iteration = 1;
    lessonPhase = 'demonstrate';
    activeSound = '';
    _send?.call({
      'type': 'play',
      'word': word.id,
      'rate': rate,
      'repeat': repeating ? 3 : 1,
      'session': session,
      'reason': reason,
    });
    notifyListeners();
  }

  void playWord() {
    if (!ready || error != null) return;
    if (adultCourse) {
      previewCourse(word.id);
      return;
    }
    stop();
    emotionMode = false;
    play();
  }

  void playActingStory() {
    if (!ready || error != null) return;
    stop();
    emotionMode = false;
    courseMode = false;
    coursePaused = false;
    index = 0;
    closeUp = false;
    session++;
    playing = true;
    iteration = 1;
    _send?.call({'type': 'focus', 'closeUp': false});
    _send?.call({'type': 'acting-story', 'session': session});
    notifyListeners();
  }

  void playPerformance() {
    if (!ready || error != null) return;
    stop();
    emotionMode = false;
    index = 0;
    closeUp = false;
    _send?.call({'type': 'focus', 'closeUp': false});
    session++;
    playing = true;
    iteration = 1;
    _send?.call({'type': 'performance', 'session': session});
    notifyListeners();
  }

  void showEmotions() {
    stop();
    emotionMode = true;
    notifyListeners();
    if (ready) playEmotion(emotionIndex);
  }

  void playEmotion(int value, {bool all = false}) {
    if (!ready || error != null || value < 0 || value >= emotions.length) {
      return;
    }
    stop();
    emotionMode = true;
    emotionReel = all;
    emotionIndex = value;
    closeUp = false;
    _send?.call({'type': 'focus', 'closeUp': false});
    session++;
    playing = true;
    iteration = 1;
    _send?.call({
      'type': 'emotion',
      'emotion': emotion.id,
      'all': all,
      'session': session,
    });
    notifyListeners();
  }

  void stop() {
    vocabulary.inCourse = false;
    automaticReading = automaticStarting = false;
    coursePaused = false;
    captureState = 'idle';
    speechFeedback = '';
    session++;
    playing = false;
    progress = 0;
    level = 0;
    viseme = '';
    lessonPhase = 'ready';
    activeSound = '';
    courseMode = false;
    hideAnswer = false;
    courseText = '';
    courseStep = '';
    courseOptions = [];
    _send?.call({'type': 'stop', 'session': session});
  }

  void togglePlayback() {
    if (adultCourse) {
      if (coursePaused) {
        playCourse();
      } else {
        pauseCourse();
      }
      return;
    }
    if (playing) {
      stop();
      notifyListeners();
    } else {
      play();
    }
  }

  void replayLesson() {
    if (adultCourse) {
      if (coursePaused) {
        playCourse();
        return;
      }
      _send?.call({'type': 'course-replay', 'session': session});
      return;
    }
    if (courseMode) {
      if (courseOptions.any((o) => o['id'] == 'help')) {
        respondToCourse('help');
      } else {
        playCourse(style: courseStyle);
      }
      return;
    }
    if (lessonPhase == 'phoneme') {
      playPhoneme(activeSound);
    } else if (lessonPhase == 'meaning') {
      playMeaning();
    } else {
      play(reason: 'retry');
    }
  }

  void playPhoneme(String symbol) {
    if (!word.sounds.contains(symbol) || ['əl', 'oʊ'].contains(symbol)) return;
    _playPronunciation('phoneme', symbol);
  }

  void playMeaning() => _playPronunciation('meaning', '');

  void _playPronunciation(String kind, String symbol) {
    if (!ready || error != null) return;
    stop();
    emotionMode = false;
    lessonPhase = kind;
    activeSound = symbol;
    playing = true;
    iteration = 1;
    _send?.call({
      'type': 'pronunciation',
      'kind': kind,
      'symbol': symbol,
      'word': word.id,
      'session': session,
    });
    notifyListeners();
  }

  void completeAttempt() {
    if (!awaitingResponse) return;
    if (captureState != 'idle') _send?.call({'type': 'capture-cancel'});
    captureState = 'idle';
    lessonPhase = 'encourage';
    _send?.call({'type': 'lesson-response', 'session': session});
    notifyListeners();
  }

  void playCourse({
    String style = 'adult',
    bool restart = false,
    bool skip = false,
  }) {
    if (!ready || error != null) return;
    if (!const [
      'adult',
      'child46',
      'child79',
      'child1012',
      'correction',
    ].contains(style)) {
      return;
    }
    stop();
    coachSentence = '';
    wordFeedback = [];
    liveTranscript = '';
    automaticState = 'starting';
    automaticStarting = true;
    if (restart) courseCheckpoint = null;
    if (style == 'adult') {
      vocabulary.begin(restart: restart || courseCheckpoint == null);
      unawaited(_saveVocabulary());
    }
    coursePaused = false;
    courseMode = true;
    courseStyle = style;
    emotionMode = false;
    index = 0;
    playing = true;
    iteration = 1;
    lessonPhase = 'introduce';
    courseText = '先听声音，再试着读。';
    _send?.call({
      'type': 'course',
      'skip': skip,
      'style': style,
      'rate': rate,
      'session': session,
      if (style == 'adult') 'checkpoint': courseCheckpoint,
    });
    notifyListeners();
  }

  void respondToCourse(String action) {
    if (coursePaused) return;
    if (!courseMode || !courseOptions.any((o) => o['id'] == action)) return;
    if (captureState != 'idle') _send?.call({'type': 'capture-cancel'});
    captureState = 'idle';
    courseOptions = [];
    _send?.call({
      'type': 'lesson-response',
      'action': action,
      'session': session,
    });
    notifyListeners();
  }

  void setRate(double value) {
    final resume = playing;
    final wasCourse = courseMode;
    stop();
    rate = value;
    if (resume) {
      if (wasCourse) {
        playCourse(style: courseStyle);
      } else {
        play(reason: 'retry');
      }
    } else {
      notifyListeners();
    }
  }

  void toggleRepeat() {
    repeating = !repeating;
    if (playing) {
      play();
    } else {
      notifyListeners();
    }
  }

  void toggleFocus() {
    closeUp = !closeUp;
    _send?.call({'type': 'focus', 'closeUp': closeUp});
    notifyListeners();
  }

  void toggleCapture() {
    if (!canCapture || processingSpeech) return;
    if (capturing) {
      captureState = 'processing';
      _send?.call({'type': 'capture-stop', 'session': session});
    } else {
      captureState = 'starting';
      _send?.call({'type': 'capture-start', 'session': session});
    }
    notifyListeners();
  }

  void retry() {
    error = null;
    ready = false;
    _send?.call({'type': 'retry'});
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _send?.call({'type': 'stop'});
    playbackTick.dispose();
    super.dispose();
  }
}
