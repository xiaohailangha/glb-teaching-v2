import 'package:flutter/foundation.dart';

import '../domain/lesson_word.dart';
import '../domain/emotion.dart';

typedef AvatarCommand = void Function(Map<String, Object?> command);

class LessonController extends ChangeNotifier {
  final playbackTick = ValueNotifier<int>(0);
  int index = 0, iteration = 0, session = 0;
  bool ready = false, playing = false, repeating = false, closeUp = false;
  bool emotionMode = false, emotionReel = false;
  bool courseMode = false, hideAnswer = false;
  String courseStyle = 'adult', courseText = '', courseStep = '';
  List<Map<String, String>> courseOptions = [];
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
      if (event == 'capture') {
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
        speechFeedback = '';
        activeSound = message['symbol']?.toString() ?? '';
        emotionMode = false;
        if (courseMode) {
          courseText = message['text']?.toString() ?? '';
          courseStep = message['step']?.toString() ?? '';
          hideAnswer = message['hideAnswer'] == true;
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
    progress = 0;
    notifyListeners();
    if (ready) play(reason: 'next');
  }

  void step(int delta) {
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
    lessonPhase = 'introduce';
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

  void playActingStory() {
    if (!ready || error != null) return;
    stop();
    emotionMode = false;
    courseMode = false;
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
    if (playing) {
      stop();
      notifyListeners();
    } else {
      play();
    }
  }

  void replayLesson() {
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
    if (!word.sounds.contains(symbol)) return;
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

  void playCourse({String style = 'adult'}) {
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
      'style': style,
      'rate': rate,
      'session': session,
    });
    notifyListeners();
  }

  void respondToCourse(String action) {
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
