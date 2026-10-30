import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/src/geometry/morph_targets.dart';
import 'package:flutter_scene/src/texture/half_float.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';
import 'package:snow_speaks/core/avatar/scene/teaching_math.dart';
import 'package:snow_speaks/core/avatar/scene/speech_client.dart';

void main() {
  test('Dart course, performance and emotion mathematics match existing approved tracks', () {
    final fixtures = jsonDecode(
      File('test/fixtures/three-math-parity.json').readAsStringSync(),
    ) as List;
    expect(fixtures.length, greaterThan(300));
    for (final f in fixtures) {
      final w = <String, double>{'AA': .22, 'EE': .07, 'FF': .03, 'MBP': 0};
      switch (f['kind']) {
        case 'course':
          final p = (f['progress'] as num).toDouble(),
              elapsed = (f['elapsed'] as num).toDouble();
          applyCourseFace(
            w,
            f['phase'],
            p,
            elapsed,
            f['variation'],
            f['style'],
          );
          final pose = coursePose(
            f['phase'],
            p,
            elapsed,
            f['variation'],
            f['style'],
          );
          expect(pose.time, closeTo(f['pose']['time'], 1e-8));
          expect(pose.accent, closeTo(f['pose']['accent'], 1e-8));
          expect(pose.accentTime, closeTo(f['pose']['accentTime'], 1e-8));
        case 'performance':
          applyPerformanceFace(w, (f['time'] as num).toDouble());
        case 'emotion':
          applyEmotionFace(w, f['id'], (f['time'] as num).toDouble());
      }
      for (final e in (f['weights'] as Map).entries) {
        expect(
          w[e.key] ?? 0,
          closeTo(e.value as num, 1e-8),
          reason: '${f['kind']}/${f['phase']}/${e.key}',
        );
      }
    }
  });
  test('word taps contain only the selected word and a silent recording opportunity', () {
    for (final word in [
      'apple',
      'banana',
      'cat',
      'dog',
      'fish',
      'moon',
      'sun',
      'book',
      'hello',
      'thank',
    ]) {
      final d = TeachingDirector.word(word: word);
      expect(d.stage.clip, word);
      expect(d.stages.where((s) => s.clip != null).map((s) => s.clip), [word]);
      expect(d.advance().phase, 'listen');
    }
  });
  test('apple course keeps explicit listening, help branches and unassessed attempts', () {
    final d = TeachingDirector.apple(style: 'adult');
    for (var i = 0; i < 7; i++) {
      d.advance();
    }
    expect(d.stage.phase, 'choice');
    expect(d.advance().phase, 'choice');
    d.respond('banana');
    expect(d.stage.phase, 'support');
    d.advance();
    d.advance();
    expect(d.stage.phase, 'choice');
    d.respond('apple');
    expect(d.stage.phase, 'success');
    d.advance();
    d.advance();
    expect(d.stage.phase, 'recall');
    d.respond('help');
    d.advance();
    d.advance();
    expect(d.stage.phase, 'recall');
    d.respond('attempt');
    d.advance();
    d.advance();
    d.advance();
    expect(d.stage.phase, 'listen');
  });
  test('52 facial channels fit the expanded GPU budget without silently selecting only eight', () {
    final weights = Float32List.fromList(
      List.generate(52, (i) => (i + 1) / 52),
    );
    expect(MorphTargetData.selectActiveTargets(weights).length, 52);
    final data = MorphTargetData(
      vertexCount: 1,
      targetCount: 52,
      positionDeltas: Float32List(156),
      normalDeltas: Float32List(156),
    );
    final packing = computeMorphTexturePacking(data)!;
    expect(
      buildMorphTextureHalfPayload(data, packing).lengthInBytes,
      buildMorphTexturePayload(data, packing).lengthInBytes ~/ 2,
    );
    expect(
      (83137 / 4096).ceil() * 2 * 52,
      lessThanOrEqualTo(kMorphTextureMaxDimension),
    );
    expect(halfBitsToDouble(floatToHalfBits(.125)), .125);
  });
  test('same-clock visemes close lips and PCM is packaged as valid 16 kHz mono WAV', () {
    final out = List<double>.filled(8, 0),
        cues = [MouthCue(0, 1), MouthCue(.1, 21), MouthCue(.2, 0)];
    sampleTimeline(cues, .15, 1, out);
    expect(out[5], greaterThan(.9));
    expect(out[0], lessThan(.01));
    final wav = pcmToWav(Uint8List(16000)), header = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(wav.length, 16044);
  });
}
