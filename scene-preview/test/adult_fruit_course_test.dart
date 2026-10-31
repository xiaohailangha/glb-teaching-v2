import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_director.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';

List<dynamic> rows() =>
    (jsonDecode(
          File('assets/avatar/courses/adult-fruit.json').readAsStringSync(),
        ) as Map)['stages']
        as List;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('nickname persists separately from English teaching targets', () async {
    final c = LessonController();
    await c.loadCourseProgress();
    expect(c.nickname, '莉莉');
    final cheer = c.closingCheer;
    expect(c.closingSpeech, '莉莉，本节课我们就学到这里。$cheer');
    c.ready = true;
    c.playCourse(restart: true);
    expect(c.closingCheer, isNot(cheer));
    final nextCheer = c.closingCheer;
    c.playCourse();
    expect(c.closingCheer, nextCheer);
    await c.setNickname('  小雨  ');
    final restored = LessonController();
    await restored.loadCourseProgress();
    expect(restored.address('本节课我们就学到这里。'), '小雨，本节课我们就学到这里。');
    await restored.setNickname('');
    expect(restored.address('你好'), '你好');
    c.dispose();
    restored.dispose();
  });
  test('sentence help returns to the same full-sentence target', () {
    final d = TeachingDirector.fruit(rows());
    d.index = d.stages.indexWhere((s) => s.id == 'eat_banana');
    final at = d.index;
    expect(d.stage.speechText, 'I want to eat a banana.');
    expect(d.stage.segments.length, 3);
    d.respond('help');
    expect(d.stage.clip, 'eat_banana');
    expect(d.stage.display, 'I want to eat a banana.');
    expect(d.respond('next'), isNull);
    d.advance();
    expect(d.index, at);
    expect(d.stage.speechText, 'I want to eat a banana.');
  });
  test('both personal choices lead to their own recall and optional extension can be skipped', () {
    for (final word in ['apple', 'banana']) {
      final d = TeachingDirector.fruit(rows());
      d.index = d.stages.indexWhere((s) => s.id == 'scene_pick');
      d.respond('choose_$word');
      expect(d.stage.id, 'scene_$word');
      expect(d.stage.hideAnswer, true);
      d.respond('attempt');
      expect(d.stage.id, 'extension_gate');
      expect(d.expressions, {'scene_$word'});
      expect(d.correct, isEmpty);
      d.respond('skip');
      expect(d.stage.id, 'summary');
      expect(d.stage.phase, 'finish');
      expect(d.stage.options, isEmpty);
    }
  });
  test('old course indexes are rejected and sentence checkpoints restore', () {
    final old = TeachingDirector.fruit(
      rows(),
      saved: {'version': 1, 'index': 27},
    );
    expect(old.index, 0);
    old.index = old.stages.indexWhere((s) => s.id == 'red_sentence');
    final resumed = TeachingDirector.fruit(rows(), saved: old.checkpoint);
    expect(resumed.stage.id, 'red_sentence');
    expect(resumed.stage.speechText, 'I want to eat a red apple.');
  });
  test(
    'complete course visits both words, three choices and a quiet summary',
    () {
      final d = TeachingDirector.fruit(rows());
      var turns = 0;
      while (d.stage.id != 'summary' && turns++ < 180) {
        final s = d.stage;
        if (s.options.isNotEmpty) {
          d.respond(
            s.id == 'scene_pick'
                ? 'choose_banana'
                : s.answer.isNotEmpty
                ? s.answer
                : s.phase == 'recall'
                ? 'attempt'
                : 'next',
          );
        } else {
          d.advance();
        }
      }
      expect(turns, lessThan(180));
      expect(d.stage.phase, 'finish');
      expect(d.taught, {'apple', 'banana'});
      expect(d.correct.length, 3);
      expect(d.attempts, {'apple', 'banana'});
    },
  );
  test('wrong answers, hints and repeated responses do not skip or count as unaided evidence', () {
    final d = TeachingDirector.fruit(rows());
    d.index = d.stages.indexWhere((s) => s.id == 'hear_banana');
    final at = d.index;
    expect(d.stage.hideAnswer, true);
    d.respond('apple');
    expect(d.stage.phase, 'support');
    expect(d.word, 'banana');
    expect(d.respond('banana'), isNull);
    d.advance();
    expect(d.index, at);
    expect(d.stage.hideAnswer, true);
    d.respond('banana');
    expect(d.correct, isEmpty);
    expect(d.stage.phase, 'success');
    expect(d.respond('banana'), isNull);
    final saved = jsonDecode(jsonEncode(d.checkpoint)) as Map<String, dynamic>;
    final resumed = TeachingDirector.fruit(rows(), saved: saved);
    expect(resumed.index, at + 1);
    expect(resumed.helped, contains('hear_banana'));
  });
  test(
    'pause invalidates old playback; reload restores the saved chapter',
    () async {
      final c = LessonController(), commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      c.handle({'event': 'ready'});
      c.playCourse();
      final old = c.session;
      c.handle({
        'event': 'lesson-phase',
        'session': old,
        'phase': 'recall',
        'step': 'recall_banana',
        'word': 'banana',
        'checkpoint': {
          'version': 1,
          'index': 13,
          'taught': ['apple', 'banana'],
        },
        'stageIndex': 13,
        'stageCount': 32,
        'hideAnswer': true,
      });
      c.pauseCourse();
      c.handle({'event': 'playing', 'session': old});
      expect(c.playing, false);
      c.playCourse();
      expect(commands.last['checkpoint'], containsPair('index', 13));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final other = LessonController();
      await other.loadCourseProgress();
      expect(other.courseCheckpoint?['index'], 13);
      c.dispose();
      other.dispose();
    },
  );
  for (final size in [const Size(300, 310), const Size(240, 240)]) {
    testWidgets(
      'course panel fits and hides English in a recall stage at $size',
      (tester) async {
        final c = LessonController()..ready = true;
        c.playCourse();
        c.handle({
          'event': 'lesson-phase',
          'session': c.session,
          'phase': 'recall',
          'step': 'recall_banana',
          'text': '看图试着说出英文。',
          'word': 'banana',
          'picture': 'banana',
          'display': 'banana',
          'chapter': '看图回忆',
          'checkpoint': {'version': 1, 'index': 13},
          'stageIndex': 13,
          'stageCount': 32,
          'hideAnswer': true,
          'options': [
            {'id': 'attempt', 'label': '我尝试过了'},
            {'id': 'reveal', 'label': '想不起来，听提示'},
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: AdultCoursePanel(controller: c),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('banana'), findsNothing);
        expect(find.text('我尝试过了'), findsNothing);
        expect(find.text('手动跟读'), findsNothing);
        expect(find.text('开启自动跟读'), findsNothing);
        c.dispose();
      },
    );
  }
}
