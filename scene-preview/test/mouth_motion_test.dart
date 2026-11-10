import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/teaching_math.dart';

void main() {
  test('real Mandarin narration and English models produce distinct mouth shapes at the audio position', () {
    final content = jsonDecode(
      File('test/fixtures/content/teaching-pilot/current.json').readAsStringSync(),
    ) as Map;
    final assets = (content['assets'] as Map).values.cast<Map>();
    for (final clip in [
      assets.firstWhere((a) => a['language'] == 'zh'),
      assets.firstWhere((a) => a['text'] == 'and'),
    ]) {
      final cues = MouthCue.fromJson(clip['cues']);
      final motion = NaturalMotion();
      final seen = <String>{};
      for (var frame = 0; frame < (cues.last.time + .5) * 60; frame++) {
        motion.update(
          1 / 60,
          cues: cues,
          audioTime: frame / 60,
          speaking: true,
        );
        for (final name in mouthNames) {
          if (motion.weights[name]! > .15) seen.add(name);
        }
      }
      expect(
        seen.length,
        greaterThanOrEqualTo(2),
        reason: clip['text'] as String,
      );
      expect(articulation(motion.weights), lessThan(.001));
      if (clip['language'] == 'zh')
        expect(seen, containsAll(['AA', 'UU', 'MBP']));
    }
  });
}
