import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/teaching_math.dart';

void main() {
  test(
    'all 40 verified clips articulate on the audio clock and settle after stop',
    () {
      final release = jsonDecode(
        File('../data/curriculum/audio-release.json').readAsStringSync(),
      ) as Map;
      final assets = release['assets'] as List;
      expect(assets.length, 40);
      for (final asset in assets) {
        final motion = NaturalMotion();
        final cues = MouthCue.fromJson(asset['cues']);
        var moved = false;
        for (var t = 0.0; t < (asset['duration'] as num); t += 1 / 60) {
          motion.update(1 / 60, cues: cues, audioTime: t, speaking: true);
          moved |= motion.mouth.any((v) => v > .05);
        }
        expect(moved, true, reason: asset['id'] as String);
        for (var i = 0; i < 60; i++) {
          motion.update(1 / 60, cues: cues, audioTime: .3, speaking: false);
        }
        expect(
          motion.mouth.every((v) => v == 0),
          true,
          reason: asset['id'] as String,
        );
      }
    },
  );
}
