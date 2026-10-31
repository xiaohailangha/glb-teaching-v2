import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/domain/course_lexicon.dart';
import 'package:snow_speaks/features/lesson/domain/pronunciation_feedback.dart';
import 'package:snow_speaks/features/lesson/domain/vocabulary_ledger.dart';

List<dynamic> stages(CourseInfo c) =>
    jsonDecode(
          File('assets/avatar/courses/${c.asset}.json').readAsStringSync(),
        )['stages']
        as List;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'rapid lesson selection and character tap never start the previous lesson',
    () async {
      final c = LessonController()..ready = true;
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      await c.selectCourse('adult-numbers-v1');
      c.playCourse();
      commands.clear();
      final pending = c.selectCourse('adult-describe-review-v1');
      c.playCourse();
      expect(commands.where((v) => v['type'] == 'course'), isEmpty);
      await pending;
      c.playCourse();
      expect(commands.last['courseId'], 'adult-describe-review-v1');
      commands.clear();
      await Future.wait([
        c.selectCourse('adult-colors-v1'),
        c.selectCourse('adult-sizes-v1'),
      ]);
      expect(c.courseId, 'adult-sizes-v1');
      c.playCourse();
      expect(commands.last['courseId'], 'adult-sizes-v1');
      c.dispose();
    },
  );

  test('unit two teaches new words before phrases, then offers hidden recall', () {
    final known = <String>{};
    for (final c in courseCatalog) {
      final rows = stages(c);
      for (final row in rows) {
        final text =
            row['speechText'] as String? ?? row['display'] as String? ?? '';
        final words = VocabularyLedger.words(text).toList();
        if (courseCatalog.indexOf(c) >= 4 && words.length > 1) {
          expect(
            words.every(known.contains),
            true,
            reason: '${c.id}: $text before single words',
          );
        }
        // The existing first four lessons supply the vocabulary for this unit.
        known.addAll(words);
      }
      if (courseCatalog.indexOf(c) < 4) continue;
      final recalls = rows.where((r) => r['phase'] == 'recall').toList();
      expect(recalls.length, greaterThanOrEqualTo(2));
      final director = TeachingDirector.fruit(rows, courseId: c.id);
      for (final row in recalls) {
        director.index = rows.indexOf(row);
        expect(director.stage.hideAnswer, true);
        expect(director.stage.practiceClip, isNotEmpty);
        final position = director.index;
        director.respond('help');
        expect(director.stage.phase, 'support');
        expect(director.stage.clip, row['practiceClip']);
        director.advance();
        expect(director.index, position);
        expect(director.stage.hideAnswer, true);
        director.navigate(1);
        expect(director.correct, isEmpty);
      }
    }
  });

  test(
    'review adds no vocabulary; inflections do not increase exposure count',
    () {
      final ledger = VocabularyLedger()..begin();
      for (final c in courseCatalog.take(7)) {
        for (final row in stages(c)) {
          ledger.expose(
            row['speechText'] as String? ?? row['display'] as String? ?? '',
          );
        }
      }
      ledger.begin(restart: true);
      for (final row in stages(courseCatalog.last)) {
        ledger.expose(
          row['speechText'] as String? ?? row['display'] as String? ?? '',
        );
      }
      expect(ledger.newThisCourse, isEmpty);
      expect(
        ledger.seen,
        containsAll(['apple', 'banana', 'five', 'small', 'blue']),
      );
      expect(ledger.seen, isNot(contains('apples')));
      final restored = VocabularyLedger()
        ..restore({
          'seen': ['apple', 'apples', 'bananas'],
          'new': ['apple', 'apples'],
          'inCourse': true,
        });
      expect(restored.seen, {'apple', 'banana'});
      expect(restored.newThisCourse, {'apple'});
      expect(restored.hasSeen('APPLES'), true);
      expect(restored.expose('bananas apples'), false);
    },
  );

  test('all new speech has aligned words and independently tappable forms', () {
    final manifest = jsonDecode(
      File('assets/avatar/audio/unit-two-prompts.json').readAsStringSync(),
    ) as Map;
    for (final item in manifest.entries) {
      final data = item.value as Map;
      final expected = VocabularyLedger.words(data['text']).toList();
      final timings = data['wordTimings'] as List;
      expect(
        timings.map((t) => t['word']).toList(),
        expected,
        reason: item.key,
      );
      var end = 0.0;
      for (final t in timings) {
        expect((t['start'] as num).toDouble(), greaterThanOrEqualTo(end - .03));
        expect(t['end'], greaterThan(t['start']));
        expect(t['end'], lessThanOrEqualTo(data['duration'] + .15));
        end = (t['end'] as num).toDouble();
      }
      expect(data['cues'], isNotEmpty);
    }
    for (final key in [
      'green',
      'yellow',
      'blue',
      'big',
      'small',
      'one',
      'two',
      'three',
      'four',
      'five',
      'apples',
      'bananas',
    ]) {
      final entry = courseLexicon[key]!;
      expect(manifest[entry.clip]['text'], key);
      expect(File('assets/avatar/audio/${entry.clip}.wav').existsSync(), true);
    }
  });

  test(
    'number and plural errors stay visible in whole sentence assessment',
    () {
      Map report(List<String> words) => {
        'PronAccuracy': 95,
        'PronCompletion': 1,
        'Words': [
          for (final w in words) {'Word': w, 'MatchTag': 0, 'PronAccuracy': 95},
        ],
      };
      const target = 'I want two green apples, please.';
      final good = ['I', 'want', 'two', 'green', 'apples', 'please'];
      expect(PronunciationFeedback(target, report(good)).passed, true);
      expect(
        PronunciationFeedback(
          target,
          report(['I', 'want', 'two', 'green', 'apple', 'please']),
        ).passed,
        false,
      );
      expect(
        PronunciationFeedback(
          target,
          report(['I', 'want', 'three', 'green', 'apples', 'please']),
        ).passed,
        false,
      );
      expect(PronunciationFeedback(target, report(['apples'])).passed, false);
    },
  );

  test(
    'new lessons resume separately and switching accounts clears exposure',
    () async {
      final controller = LessonController();
      await controller.selectCourse('adult-colors-v1');
      controller.vocabulary.begin();
      controller.expose('green apple');
      await controller.selectCourse('adult-numbers-v1');
      controller.vocabulary.begin();
      controller.expose('two apples');
      expect(controller.vocabulary.newThisCourse, {'two'});
      await controller.selectCourse('adult-colors-v1');
      expect(controller.vocabulary.newThisCourse, {'green', 'apple'});
      await controller.bindAccount(id: 'unit-two-other');
      expect(controller.vocabulary.seen, isEmpty);
      expect(controller.courseId, 'adult-fruit-v2');
      controller.dispose();
    },
  );
}
