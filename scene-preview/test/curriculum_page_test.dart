import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/features/lesson/application/curriculum_lesson_controller.dart';

class CurriculumApi extends AuthApi {
  final Map<String, dynamic> fixture;
  final submissions = <Map<String, dynamic>>[];
  CurriculumApi(this.fixture);
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    if (path == 'learning/curriculum') return fixture;
    if (path.endsWith('/media')) {
      return {
        'expiresAt': 4102444800000,
        'assets': [
          ...jsonDecode(
            File('../data/curriculum/audio-release.json').readAsStringSync(),
          )['assets'],
          ...jsonDecode(
            File('../data/curriculum/teaching-audio.json').readAsStringSync(),
          )['assets'],
        ],
      };
    }
    if (path.endsWith('/start')) {
      fixture['state'] = {
        'level': data!['level'],
        'revision': 1,
        'opened': ['B1.01'],
        'progress': [],
        'evidence': {'words': [], 'completedCourses': []},
      };
      return Map<String, dynamic>.from(fixture['state'] as Map);
    }
    if (path.endsWith('/progress')) {
      return {'revision': (data!['revision'] as int) + 1};
    }
    if (path.endsWith('/challenge')) {
      final c = (fixture['sample']['checks'] as List).firstWhere(
        (c) => c['id'] == data!['check'],
      );
      return {
        'id': 'challenge-${c['id']}',
        'options': c['options'],
        'audio': c['audio'],
      };
    }
    if (path.endsWith('/hint')) return {'hint': '这是本题的示范提示', 'helped': true};
    if (path.endsWith('/heard')) return {'ok': true};
    if (path.endsWith('/answer') || path.endsWith('/oral')) {
      submissions.add(data!);
      return {
        'matched': true,
        'verified': true,
        'wordPassed': true,
        'message': '本次独立证据已保存',
      };
    }
    throw StateError(path);
  }
}

Map<String, dynamic> fixture() {
  Map read(String name) =>
      jsonDecode(File('../data/curriculum/$name.json').readAsStringSync())
          as Map;
  final p = read('plan-3000'), a = read('access'), s = read('sample');
  final checks = jsonDecode(
    File('../data/curriculum/checks.json').readAsStringSync(),
  ) as List;
  return {
    'version': 'test',
    'levels': a['levels'],
    'categories': p['categories'],
    'units': [
      for (final u in p['units'] as List)
        {
          ...u as Map,
          ...(a['units'] as List).firstWhere((v) => v['id'] == u['id']) as Map,
        },
    ],
    'courses': [
      for (final c in p['courses'] as List)
        {...c as Map, 'status': c['unit'] == 'B1.01' ? 'pilot' : 'planned'},
    ],
    'sample': {
      ...s,
      'checks': [
        for (final c in s['checks'] as List)
          {...c as Map, ...checks.firstWhere((r) => r['id'] == c['id']) as Map},
        ...checks.where((c) => c['kind'] == 'teaching'),
        ...(jsonDecode(
          File('../data/curriculum/word-checks.json').readAsStringSync(),
        ) as List),
      ],
    },
    'state': {'level': null, 'revision': 0, 'opened': [], 'progress': []},
  };
}

class Avatar extends LessonController {
  Avatar() {
    ready = true;
  }
  final played = <String>[];
  final teachingPhases = <String>[];
  @override
  void setCurriculumPhase(String phase) => teachingPhases.add(phase);
  @override
  Future<void> playCurriculumAudio(Map<String, dynamic> audio) async {
    played.add(audio['id'] as String);
    teachingPhases.add(audio['teachingPhase'] as String? ?? 'demonstrate');
  }

  @override
  void stopCurriculumAudio() {}
}

class Reader extends AutomaticReader {
  Reader()
    : super((p) => Uri.parse('https://example.test$p'), (_, _) {}, (_, _) {});
  @override
  Future<void> start() async {
    enabled = true;
  }

  @override
  Future<void> stop() async {
    enabled = false;
  }
}

void main() {
  test('test-only runtime reads its own preserved evidence namespace', () async {
    final data = fixture();
    final oldCourses = data['courses'] as List;
    final oldSample = data['sample'];
    data['courses'] = [
      {'id': 'N26-U001-L01', 'status': 'planned'},
    ];
    data['testData'] = {
      'courses': [for (final c in oldCourses.where((c) => c['unit'] == 'B1.01')) {...c as Map, 'status': 'test'}],
      'sample': oldSample,
    };
    data['state'] = {
      'level': 1, 'revision': 1, 'progress': [],
      'evidence': {'words': [], 'completedCourses': []},
      'testData': {
        'progress': [],
        'evidence': {'words': [{'word': 'hello', 'learned': true}], 'completedCourses': []},
      },
    };
    final api = CurriculumApi(data), avatar = Avatar();
    final c = CurriculumLessonController(api: api, avatar: avatar, id: 'B1.01-L01', onSelect: (_) async {}, readerFactory: (_) => Reader());
    addTearDown(c.dispose);addTearDown(api.dispose);addTearDown(avatar.dispose);
    await c.initialize();
    expect(c.beats, isNotEmpty);
    expect(c.activeCourse.id, 'B1.01-L01');
    expect(c.nextCourse?.id, 'B1.01-L02');
  });
  for (final size in [const Size(320, 568), const Size(1360, 850)]) {
    testWidgets(
      'all six courses use formal display and navigation, auto listen and advance at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = CurriculumApi(fixture());
        final avatar = Avatar();
        addTearDown(api.dispose);
        addTearDown(avatar.dispose);
        for (final row in (api.fixture['courses'] as List).where(
          (c) => c['unit'] == 'B1.01',
        )) {
          final c = CurriculumLessonController(
            api: api,
            avatar: avatar,
            id: row['id'] as String,
            onSelect: (_) async {},
            readerFactory: (_) => Reader(),
            feedbackDelay: Duration.zero,
          );
          await c.initialize();
          expect(c.beats.where((b) => b.check?['options'] != null), isEmpty);
          expect(c.beats.where((b) => b.step['supported'] == true), isNotEmpty);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: size.width * .51,
                        child: AnimatedBuilder(
                          animation: c,
                          builder: (_, _) => AdultCoursePanel(controller: c),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: c,
                      builder: (_, _) => LessonNavigation(controller: c),
                    ),
                  ],
                ),
              ),
            ),
          );
          c.playCourse();
          var iterations = 0;
          while (c.courseStep != 'summary' && iterations++ < 150) {
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
            expect(find.byType(Scrollbar), findsNothing);
            for (final label in [
              '继续',
              '听声音',
              '开始录音',
              '结束录音并检查',
              '词汇巩固',
              '文字练习',
            ]) {
              expect(find.text(label), findsNothing);
            }
            if (c.challenge != null && !c.playing) {
              final old = c.coursePosition;
              if (c.courseOptions.isNotEmpty) {
                c.respondToCourse(c.courseOptions.first['id']!);
              } else {
                c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
              }
              await tester.pump(const Duration(milliseconds: 500));
              expect(c.coursePosition, greaterThan(old));
            }
          }
          expect(c.courseStep, 'summary');
          expect(avatar.played, isNotEmpty);
          expect(
            avatar.teachingPhases,
            containsAll([
              'introduce',
              'meaning',
              'demonstrate',
              'listen',
              'success',
              'finish',
            ]),
          );
          avatar.teachingPhases.clear();
          await tester.pumpWidget(const SizedBox());
          c.dispose();
        }
      },
    );
  }
  test(
    'skip does not submit evidence and preview assistance survives a replay',
    () async {
      final api = CurriculumApi(fixture()), avatar = Avatar();
      final c = CurriculumLessonController(
        api: api,
        avatar: avatar,
        id: 'B1.01-L01',
        onSelect: (_) async {},
        readerFactory: (_) => Reader(),
        feedbackDelay: Duration.zero,
      );
      await c.initialize();
      c.playCourse();
      while (c.challenge == null || c.playing) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final pos = c.coursePosition;
      c.previewWord('hello');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      c.replayLesson();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.challenge?['helped'], true);
      c.navigateCourse(1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(api.submissions, isEmpty);
      expect(c.coursePosition, greaterThan(pos));
      c.pauseCourse();
      final stopped = c.coursePosition;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.coursePosition, stopped);
      expect(c.reader.enabled, false);
      c.dispose();
      avatar.dispose();
      api.dispose();
    },
  );
}
