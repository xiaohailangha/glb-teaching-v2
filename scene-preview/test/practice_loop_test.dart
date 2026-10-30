import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/scene_runtime.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

Map<String, dynamic> scored(String text, {String? bad}) => {
  'result': {
    'PronAccuracy': bad == null ? 90 : 70,
    'PronCompletion': 1.0,
    'Words': text
        .replaceAll('.', '')
        .split(' ')
        .map(
          (w) => {
            'Word': w,
            'MatchTag': 0,
            'PronAccuracy': w.toLowerCase() == bad ? 30 : 90,
          },
        )
        .toList(),
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('correction rehearses word, phrase and full sentence; only full pass advances', () async {
    final c = LessonController();
    final runtime = SceneRuntime(
      c,
      presentStage: (_) async {},
      feedbackDelay: Duration.zero,
    );
    final rows =
        (jsonDecode(
              File('assets/avatar/courses/adult-fruit.json').readAsStringSync(),
            ) as Map)['stages']
            as List;
    final d = TeachingDirector.fruit(rows);
    d.index = d.stages.indexWhere((s) => s.id == 'eat_apple');
    runtime.director = d;
    runtime.automatic.enabled = true;
    final start = d.index;
    runtime.acceptAssessment(
      'I want to eat an apple.',
      scored('I want to eat an apple.', bad: 'apple'),
    );
    expect(d.index, start);
    expect(d.branch.last.id, 'coach_word');
    while (d.stage.clip != null) {
      d.advance();
    }
    runtime.acceptAssessment('apple', scored('apple'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(d.index, start);
    expect(d.branch.last.id, 'coach_chunk');
    while (d.stage.clip != null) {
      d.advance();
    }
    runtime.acceptAssessment('an apple', scored('an apple'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    while (d.stage.clip != null) {
      d.advance();
    }
    expect(d.index, start);
    expect(d.stage.id, 'eat_apple');
    // A different weak word on the second full attempt restarts coaching correctly.
    runtime.acceptAssessment(
      'I want to eat an apple.',
      scored('I want to eat an apple.', bad: 'want'),
    );
    expect(d.branch.last.id, 'coach_word');
    expect(d.branch.last.speechText, 'want');
    expect(d.index, start);
    d.branch = [];
    runtime.acceptAssessment(
      'I want to eat an apple.',
      scored('I want to eat an apple.'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(d.index, start + 1);
    expect(d.branch, isEmpty);
    runtime.dispose();
    c.dispose();
  });
  test('leaving the exercise invalidates delayed automatic advance', () async {
    final c = LessonController();
    final runtime = SceneRuntime(
      c,
      presentStage: (_) async {},
      feedbackDelay: const Duration(milliseconds: 15),
    );
    final rows =
        (jsonDecode(
              File('assets/avatar/courses/adult-fruit.json').readAsStringSync(),
            ) as Map)['stages']
            as List;
    final d = TeachingDirector.fruit(rows);
    d.index = d.stages.indexWhere((s) => s.id == 'apple_practice');
    runtime.director = d;
    runtime.automatic.enabled = true;
    final start = d.index;
    runtime.acceptAssessment('apple', scored('apple'));
    runtime.stageGeneration++;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(d.index, start);
    runtime.dispose();
    c.dispose();
  });
}
