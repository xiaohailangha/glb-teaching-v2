import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
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
