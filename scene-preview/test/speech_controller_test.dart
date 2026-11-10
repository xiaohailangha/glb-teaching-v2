import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  test(
    'verified curriculum playback completes only on the avatar callback',
    () async {
      final c = LessonController();
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      c.handle({
        'event': 'ready',
        'speech': {'configured': true},
      });
      var ended = false;
      final future = c
          .playCurriculumAudio({'id': 'hello'})
          .then((_) => ended = true);
      expect(commands.last['type'], 'curriculum-audio');
      expect(ended, false);
      final finish = commands.last['complete'] as void Function(Object?);
      finish(null);
      finish(null);
      await future;
      expect(ended, true);
      final failed = c.playCurriculumAudio({'id': 'hello'});
      final assertion = expectLater(failed, throwsStateError);
      (commands.last['complete'] as void Function(Object?))(
        StateError('cancelled'),
      );
      await assertion;
      c.stopCurriculumAudio();
      expect(commands.last['type'], 'stop');
      c.dispose();
    },
  );
  test(
    'microphone only starts in a response stage and stale results are ignored',
    () {
      final c = LessonController();
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      c.handle({
        'event': 'ready',
        'speech': {'configured': true},
      });
      c.play();
      expect(c.canCapture, false);
      c.toggleCapture();
      expect(commands.last['type'], 'play');
      final session = c.session;
      c.handle({
        'event': 'lesson-phase',
        'session': session,
        'phase': 'listen',
      });
      c.toggleCapture();
      expect(commands.last['type'], 'capture-start');
      c.handle({'event': 'capture', 'session': session, 'state': 'recording'});
      expect(c.capturing, true);
      c.toggleCapture();
      expect(commands.last['type'], 'capture-stop');
      c.handle({
        'event': 'capture',
        'session': session,
        'state': 'done',
        'mode': 'assess',
        'result': {'PronAccuracy': -1},
      });
      expect(c.speechFeedback, contains('未能匹配'));
      expect(c.lessonPhase, 'listen');
      c.select(1);
      c.handle({
        'event': 'capture',
        'session': session,
        'state': 'done',
        'mode': 'recognize',
        'text': 'apple',
      });
      expect(c.speechFeedback, isEmpty);
      c.playPhoneme(c.word.sounds.first);
      expect(c.canCapture, false);
      c.dispose();
    },
  );
}
