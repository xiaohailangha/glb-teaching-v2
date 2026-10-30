import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/intent_motion.dart';

void main() {
  test(
    'waiting holds an attentive target rather than oscillating across time',
    () {
      for (final phase in ['listen', 'choice', 'recall']) {
        final start = teachingIntent(phase, 2);
        for (final time in [4.0, 9.0, 18.0, 37.0]) {
          final pose = teachingIntent(phase, time);
          expect(pose.body, start.body);
          expect(pose.head, start.head);
          expect(pose.left, 0);
          expect(pose.right, 0);
          expect(pose.body.abs(), lessThan(.03));
        }
      }
    },
  );
  test('gestures attack promptly once, hold and release without repeating', () {
    expect(gestureBeat(.30), closeTo(1, 1e-6));
    expect(gestureBeat(.50), 1);
    for (final time in [1.2, 3.0, 9.0, 18.0, 36.0]) {
      expect(gestureBeat(time), 0);
      final pose = teachingIntent('explain', time);
      expect(pose.left, 0);
      expect(pose.right, 0);
    }
    expect(teachingIntent('explain', .4).gaze, greaterThan(0));
    expect(teachingIntent('listen', .4).gaze, 0);
    expect(lessonPoseTime('explain'), 2.35);
    expect(lessonPoseTime('listen'), 7.55);
    expect(lessonPoseTime('invite'), isNot(lessonPoseTime('listen')));
  });
}
