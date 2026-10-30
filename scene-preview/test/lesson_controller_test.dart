import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  test('word preview preserves the adult course and its position', () {
    final c = LessonController();
    final commands = <Map<String, Object?>>[];
    c.attach(commands.add);
    c.handle({'event': 'ready'});
    c.playCourse();
    final old = c.session;
    c.playWord();
    expect(c.courseMode, true);
    expect(c.session, old);
    expect(commands.last['type'], 'course-preview');
    c.dispose();
  });
  test('course responses are gated and cancelled sessions cannot reveal an old answer', () {
    final c = LessonController();
    final commands = <Map<String, Object?>>[];
    c.attach(commands.add);
    c.handle({'event': 'ready'});
    c.playCourse(style: 'adult');
    final session = c.session;
    expect(commands.last['type'], 'course');
    c.handle({
      'event': 'lesson-phase',
      'session': session,
      'phase': 'choice',
      'hideAnswer': true,
      'step': 'choice',
      'text': '刚才听到的是什么？',
      'options': [
        {'id': 'apple', 'label': '苹果'},
        {'id': 'help', 'label': '再听一次'},
      ],
    });
    expect(c.hideAnswer, true);
    expect(c.displayWord, '…');
    final count = commands.length;
    c.respondToCourse('banana');
    expect(commands.length, count);
    c.respondToCourse('apple');
    expect(commands.last['action'], 'apple');
    expect(c.courseOptions, isEmpty);
    c.respondToCourse('apple');
    expect(commands.length, count + 1);
    c.playPhoneme('æ');
    expect(c.courseMode, false);
    expect(c.hideAnswer, false);
    c.handle({
      'event': 'lesson-phase',
      'session': session,
      'phase': 'recall',
      'hideAnswer': true,
    });
    expect(c.lessonPhase, 'phoneme');
    expect(c.hideAnswer, false);
    c.playCourse(style: 'child46');
    c.setRate(.75);
    expect(commands.last['type'], 'course');
    expect(commands.last['style'], 'child46');
    c.stop();
    expect(c.courseOptions, isEmpty);
    expect(c.courseMode, false);
    c.dispose();
  });
  test('ordinary word teaching waits for an explicit attempt and rejects stale lesson phases', () {
    final c = LessonController();
    final commands = <Map<String, Object?>>[];
    c.attach(commands.add);
    c.handle({'event': 'ready'});
    c.play();
    final first = c.session;
    c.completeAttempt();
    expect(commands.last['type'], 'play');
    c.handle({'event': 'lesson-phase', 'session': first, 'phase': 'listen'});
    expect(c.awaitingResponse, isTrue);
    c.completeAttempt();
    expect(commands.last['type'], 'lesson-response');
    expect(c.lessonPhase, 'encourage');
    c.select(1);
    expect(c.word.id, 'banana');
    expect(c.playing, isTrue);
    expect(commands.last, containsPair('reason', 'next'));
    c.handle({'event': 'lesson-phase', 'session': first, 'phase': 'listen'});
    expect(c.lessonPhase, 'demonstrate');
    c.replayLesson();
    expect(commands.last, containsPair('reason', 'retry'));
    c.dispose();
  });
  test(
    'emotion selection cancels stale sessions and tracks the running reel',
    () {
      final controller = LessonController();
      final commands = <Map<String, Object?>>[];
      controller.attach(commands.add);
      controller.handle({'event': 'ready'});
      controller.playEmotion(0, all: true);
      final first = controller.session;
      expect(commands.last, containsPair('all', true));
      controller.handle({
        'event': 'emotion',
        'session': first,
        'emotion': 'sad',
      });
      expect(controller.emotion.id, 'sad');
      controller.playEmotion(3);
      controller.handle({
        'event': 'emotion',
        'session': first,
        'emotion': 'happy',
      });
      expect(controller.emotion.id, 'afraid');
      expect(controller.emotionReel, isFalse);
      controller.playPerformance();
      expect(controller.emotionMode, isFalse);
      controller.dispose();
    },
  );
  test('teaching performance selects apple, resets closeup and ignores a cancelled session', () {
    final c = LessonController();
    final commands = <Map<String, Object?>>[];
    c.attach(commands.add);
    c.playPerformance();
    expect(commands, isEmpty);
    c.handle({'event': 'ready'});
    c.select(4);
    c.toggleFocus();
    c.playPerformance();
    expect(c.word.id, 'apple');
    expect(c.closeUp, isFalse);
    expect(c.playing, isTrue);
    expect(commands.last['type'], 'performance');
    final performanceSession = c.session;
    c.select(1);
    c.handle({
      'event': 'progress',
      'session': performanceSession,
      'progress': .7,
    });
    expect(c.playing, isTrue);
    expect(c.word.id, 'banana');
    c.dispose();
  });
  test(
    'audio progress updates the HUD without rebuilding the whole lesson',
    () {
      final controller = LessonController();
      controller.handle({'event': 'ready'});
      controller.play();
      var lessonChanges = 0;
      var progressChanges = 0;
      controller.addListener(() => lessonChanges++);
      controller.playbackTick.addListener(() => progressChanges++);
      for (var i = 0; i < 10; i++) {
        controller.handle({
          'event': 'progress',
          'session': controller.session,
          'progress': i / 10,
          'iteration': 1,
        });
      }
      expect(lessonChanges, 0);
      expect(progressChanges, 10);
      expect(controller.progress, .9);
      controller.handle({'event': 'ended', 'session': controller.session});
      expect(lessonChanges, 1);
      expect(controller.playing, isFalse);
      controller.dispose();
    },
  );
  test('switching words ignores late progress from the previous audio', () {
    final controller = LessonController();
    final commands = <Map<String, Object?>>[];
    controller.attach(commands.add);
    controller.handle({'event': 'ready'});
    controller.play();
    final first = controller.session;
    controller.select(4);
    controller.handle({'event': 'progress', 'session': first, 'progress': .8});
    expect(controller.word.id, 'fish');
    expect(controller.playing, isTrue);
    expect(controller.progress, 0);
    expect(commands.last['type'], 'play');
    controller.dispose();
  });
  test(
    'slow mode restarts the current clip with matching speed and repeat count',
    () {
      final controller = LessonController();
      final commands = <Map<String, Object?>>[];
      controller.attach(commands.add);
      controller.handle({'event': 'ready'});
      controller.toggleRepeat();
      controller.play();
      final first = controller.session;
      controller.setRate(.75);
      expect(commands.last, containsPair('rate', .75));
      expect(commands.last, containsPair('repeat', 3));
      expect(controller.session, greaterThan(first));
      controller.handle({'event': 'ended', 'session': first});
      expect(controller.playing, isTrue);
      controller.handle({'event': 'ended', 'session': controller.session});
      expect(controller.playing, isFalse);
      expect(controller.progress, 1);
      controller.dispose();
    },
  );
  test('navigation wraps and playback waits for avatar readiness', () {
    final controller = LessonController();
    controller.play();
    expect(controller.playing, isFalse);
    controller.step(-1);
    expect(controller.word.id, 'thank');
    controller.step(1);
    expect(controller.word.id, 'apple');
    controller.dispose();
  });
}
