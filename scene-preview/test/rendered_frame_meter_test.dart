import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/rendered_frame_meter.dart';

void main() {
  test('held images do not turn five new frames a second into 60 FPS', () {
    final meter = RenderedFrameMeter();
    // The UI may tick 60 times a second while the GPU supplies only five
    // genuinely new frames. Only those new frames call record().
    for (var tick = 0; tick <= 180; tick++) {
      if (tick % 12 == 0) meter.record(tick / 60);
    }
    expect(meter.fps(3), closeTo(5, .001));
    expect(meter.fps(7), 0);
  });
  test(
    'long visible frame intervals stay in the measurement; resume resets it',
    () {
      final meter = RenderedFrameMeter();
      for (final time in [0.0, 2.0, 4.0]) {
        meter.record(time);
      }
      expect(meter.fps(4), .5);
      meter.reset();
      for (var i = 0; i <= 120; i++) {
        meter.record(20 + i / 60);
      }
      expect(meter.fps(22), closeTo(60, .001));
    },
  );
  test(
    'invalid or backwards clocks fail rather than producing a passing FPS',
    () {
      final meter = RenderedFrameMeter()..record(1);
      expect(() => meter.record(double.nan), throwsArgumentError);
      expect(() => meter.record(.5), throwsArgumentError);
      expect(() => meter.fps(0), throwsArgumentError);
    },
  );
}
