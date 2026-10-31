import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';
import 'package:snow_speaks/core/avatar/scene/scene_runtime.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/domain/course_lexicon.dart';
import 'package:snow_speaks/features/lesson/domain/ipa_sounds.dart';
import 'package:snow_speaks/features/lesson/domain/pronunciation_feedback.dart';
import 'package:snow_speaks/features/lesson/presentation/ipa_text.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_navigation.dart';
import 'package:snow_speaks/features/lesson/presentation/course_celebration.dart';

TeachingDirector course() => TeachingDirector.fruit(
  (jsonDecode(File('assets/avatar/courses/adult-fruit.json').readAsStringSync())
          as Map)['stages']
      as List,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'navigation skips the whole exercise and leaves success counters untouched',
    () {
      final d = course();
      d.index = d.stages.indexWhere((s) => s.id == 'learn_i_model');
      d.navigate(1);
      expect(d.stage.id, 'learn_want_model');
      d.navigate(-1);
      expect(d.stage.id, 'learn_i_model');
      d.branch = [const Stage('listen', id: 'coach_word')];
      d.navigate(1);
      expect(d.branch, isEmpty);
      expect(d.stage.id, 'learn_want_model');
      expect(d.attempts, isEmpty);
      expect(d.correct, isEmpty);
      d.index = d.stages.indexWhere((s) => s.id == 'scene_apple');
      d.navigate(1);
      expect(d.stage.id, 'extension_gate');
      d.index = 0;
      d.navigate(-1);
      expect(d.index, 0);
      d.index = d.stages.indexWhere((s) => s.id == 'summary');
      expect(d.navigate(1), isFalse);
    },
  );
  test('manual navigation invalidates a pending automatic pass', () async {
    final c = LessonController(), d = course();
    final runtime = SceneRuntime(
      c,
      presentStage: (_) async {},
      feedbackDelay: const Duration(milliseconds: 30),
    );
    d.index = d.stages.indexWhere((s) => s.id == 'learn_i');
    runtime.director = d;
    runtime.automatic.enabled = true;
    runtime.acceptAssessment('I', {
      'result': {
        'PronAccuracy': 95,
        'PronCompletion': 1,
        'Words': [
          {'Word': 'I', 'MatchTag': 0, 'PronAccuracy': 95},
        ],
      },
    });
    await runtime.navigateCourse(1);
    final destination = d.index;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(d.index, destination);
    expect(d.stage.id, 'learn_want_model');
    expect(d.correct, isEmpty);
    runtime.dispose();
    c.dispose();
  });
  test(
    'all course and explanation IPA sounds resolve to independent recordings',
    () {
      final units = jsonDecode(
        File('assets/avatar/audio/pronunciation-units.json').readAsStringSync(),
      ) as Map;
      final rows =
          (jsonDecode(
                File('assets/avatar/courses/adult-fruit.json')
                    .readAsStringSync(),
              ) as Map)['stages']
              as List;
      final texts = [
        ...courseLexicon.values.map((v) => v.ipa),
        ...wordGuide.values,
        ...phoneNames.values.map((s) => '/$s/'),
        ...rows.map((s) => s['text'].toString()),
      ];
      final sounds = ipaSounds.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final text in texts) {
        for (final match in RegExp(r'/[^/\n]+/').allMatches(text)) {
          var body = match[0]!.replaceAll(RegExp(r'[/ˈˌ. ]'), '');
          while (body.isNotEmpty) {
            final matches = sounds.where(body.startsWith);
            expect(matches, isNotEmpty, reason: body);
            final symbol = matches.first,
                unit = units['phoneme_${ipaSounds[symbol]}'];
            expect(unit['reference'], true);
            expect(unit['sourceWord'], isNull);
            body = body.substring(symbol.length);
          }
        }
      }
    },
  );
  testWidgets(
    'explanation IPA is tappable, diphthongs remain intact, arrows have no button chrome',
    (tester) async {
      final c = LessonController()
        ..ready = true
        ..courseMode = true
        ..coursePosition = 4;
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                IpaText('听 /aɪ/、/eɪ/ 和 /ən/。', controller: c),
                LessonNavigation(controller: c),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('aɪ'));
      expect(commands.last['clip'], 'phoneme_ay');
      expect(commands.last['type'], 'course-sound');
      expect(find.text('a'), findsNothing);
      expect(find.text('ɪ'), findsNothing);
      await tester.tap(find.byIcon(Icons.east_rounded));
      expect(commands.last['direction'], 1);
      await tester.tap(find.byIcon(Icons.west_rounded));
      expect(commands.last['direction'], -1);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      c.dispose();
    },
  );
  testWidgets(
    'success is an explicit noninteractive result and respects reduced motion',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(926, 428);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFF50585B),
              body: const CourseCelebration(message: '整句通过！'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('整句通过！'), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: CourseCelebration(message: '读对了！'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('读对了！'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
