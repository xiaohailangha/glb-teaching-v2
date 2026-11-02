import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';

void main() {
  final plan = jsonDecode(File('../data/curriculum/plan.json').readAsStringSync()) as Map;
  for (final group in plan['categories'] as List) {
    for (final course in group['lessons'] as List) {
      if (course['legacy'] == true) continue;
      final rows = (jsonDecode(File('assets/avatar/courses/${course['asset']}.json').readAsStringSync()) as Map)['stages'] as List;
      test('${course['id']}: complete, retry choice, help, and resume all reach the correct stage', () {
        final director = TeachingDirector.fruit(rows, courseId: course['id'] as String);
        var steps = 0, choices = 0, practice = 0;
        while (director.stage.phase != 'finish' && steps++ < 200) {
          final stage = director.stage;
          if (stage.answer.isNotEmpty) {
            choices++;
            final wrong = stage.options.firstWhere((o) => o['id'] != stage.answer)['id']!;
            director.respond(wrong);
            expect(director.stage.phase, 'support');
            expect(director.stage.clip, stage.practiceClip);
            expect(director.stage.picture, isEmpty);
            director.advance();
            expect(director.stage.id, stage.id);
            director.respond(stage.answer);
            expect(director.stage.phase, 'success');
            director.advance();
          } else if (stage.options.isNotEmpty) {
            practice++;
            director.respond('help');
            expect(director.stage.clip, stage.practiceClip);
            director.advance();
            final restored = TeachingDirector.fruit(rows, courseId: course['id'] as String, saved: director.checkpoint);
            expect(restored.stage.id, stage.id);
            expect(director.respond('attempt'), isNotNull);
          } else {
            expect(stage.clip, isNotNull, reason: 'Automatic stages must have audio');
            director.advance();
          }
        }
        expect(director.stage.id, 'summary');
        expect(choices, 2);
        expect(practice, greaterThanOrEqualTo(13));
        expect(director.correct, isEmpty, reason: 'An assisted choice is not an unaided correct answer');
      });
    }
  }
}
