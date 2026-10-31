import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';
import 'package:snow_speaks/features/lesson/domain/course_lexicon.dart';
import 'package:snow_speaks/features/lesson/domain/vocabulary_ledger.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('each new course has complete audio, lexicon, pictures and a reachable calm ending', () {
    final audio = <String, dynamic>{};
    for (final file in [
      'timings',
      'fruit-prompts',
      'unit-one-prompts',
      'unit-two-prompts',
    ]) {
      audio.addAll(
        jsonDecode(File('assets/avatar/audio/$file.json').readAsStringSync()),
      );
    }
    for (final c in courseCatalog.skip(1)) {
      final data = jsonDecode(
        File('assets/avatar/courses/${c.asset}.json').readAsStringSync(),
      );
      expect(data['id'], c.id);
      final rows = data['stages'] as List;
      expect(rows.map((r) => r['id']).toSet().length, rows.length);
      for (final row in rows) {
        for (final key in ['clip', 'practiceClip']) {
          if (row[key] == null) continue;
          expect(
            audio.containsKey(row[key]),
            true,
            reason: '${c.id}: ${row[key]}',
          );
          expect(
            File('assets/avatar/audio/${row[key]}.wav').existsSync(),
            true,
          );
        }
        for (final part in row['segments'] as List? ?? []) {
          expect(
            audio.containsKey(part['clip']),
            true,
            reason: '${c.id}: ${part['clip']}',
          );
          expect(
            File('assets/avatar/audio/${part['clip']}.wav').existsSync(),
            true,
          );
        }
        if ((row['picture'] ?? '').isNotEmpty) {
          expect(
            File('assets/avatar/images/${row['picture']}.svg').existsSync(),
            true,
          );
        }
        if (row['speechText'] != null) {
          for (final word in VocabularyLedger.words(row['speechText'])) {
            expect(courseLexicon.containsKey(word), true, reason: word);
          }
        }
      }
      final d = TeachingDirector.fruit(rows, courseId: c.id);
      var steps = 0;
      while (d.stage.id != 'summary' && steps++ < 200) {
        if (d.stage.options.isNotEmpty) {
          d.respond('next');
        } else {
          d.advance();
        }
      }
      expect(d.stage.id, 'summary');
      expect(d.checkpoint['courseId'], c.id);
      expect(
        TeachingDirector.fruit(
          rows,
          courseId: c.id,
          saved: {'version': 1, 'courseId': 'adult-fruit-v2', 'index': 10},
        ).index,
        0,
      );
      final back = TeachingDirector.fruit(rows, courseId: c.id);
      expect(back.navigate(1), true);
      expect(back.index, greaterThan(0));
    }
  });
  test('switching courses preserves separate checkpoints and cross-course exposure', () async {
    SharedPreferences.setMockInitialValues({
      'adult-fruit-v2': jsonEncode({
        'version': 1,
        'courseId': 'adult-fruit-v2',
        'index': 9,
      }),
      'adult-drinks-v1': jsonEncode({
        'version': 1,
        'courseId': 'adult-drinks-v1',
        'index': 4,
      }),
    });
    final c = LessonController();
    await c.loadCourseProgress();
    expect(c.courseCheckpoint?['index'], 9);
    c.expose('I want an apple');
    await c.selectCourse('adult-drinks-v1');
    expect(c.courseCheckpoint?['index'], 4);
    expect(c.vocabulary.seen.contains('want'), true);
    c.vocabulary.begin(restart: true);
    c.expose('I want some water');
    expect(c.vocabulary.newThisCourse, {'some', 'water'});
    await c.selectCourse('adult-fruit-v2');
    expect(c.courseCheckpoint?['index'], 9);
    await c.bindAccount(id: 'another');
    expect(c.courseId, 'adult-fruit-v2');
    expect(c.courseCheckpoint, isNull);
    expect(c.vocabulary.seen, isEmpty);
    c.dispose();
  });
}
