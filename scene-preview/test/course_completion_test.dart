import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';
import 'package:snow_speaks/core/avatar/scene/course_resources.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/features/lesson/application/curriculum_lesson_controller.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';
import 'package:snow_speaks/features/lesson/presentation/lesson_navigation.dart';

const release =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const course = 'N26-U001-L01';
const nextCourse = 'N26-U001-L02';

class Avatar extends LessonController {
  Avatar() {
    ready = true;
  }
  Completer<void>? audio;
  final played = <Map<String, dynamic>>[];
  @override
  Future<void> playCurriculumAudio(Map<String, dynamic> value) async {
    played.add(Map<String, dynamic>.from(value));
    await audio?.future;
  }
}

class Reader extends AutomaticReader {
  Reader()
    : super((p) => Uri.parse('https://example.test/$p'), (_, _) {}, (_, _) {});
  @override
  Future<void> start() async {
    enabled = true;
  }

  @override
  Future<void> stop() async {
    enabled = false;
  }
}

class Fixture {
  final visited = <String>{'s1', 's3'};
  final skipped = <String>{};
  bool continued = false;
  bool oralMatched = false, oralPassed = false;
  int oralCalls = 0, challengeCount = 0;
  int phonemeRequests = 0;
  int revision = 7;
  String step = 's3';
  final saved = <String>[];
  Completer<void>? saveGate;
  late final client = MockClient((r) async {
    final route = r.url.path.split('/').last;
    Map<String, dynamic> data = {};
    if (r.body.isNotEmpty) data = jsonDecode(r.body) as Map<String, dynamic>;
    Object body;
    switch (route) {
      case 'state':
        body = {
          'level': 1,
          'revision': 1,
          'progress': [
            {
              'course': course,
              'step': step,
              'revision': revision,
              'visitedSteps': {...visited, ...skipped}.toList(),
              'skippedSteps': skipped.toList(),
              'pendingStep': !visited.contains('s1')
                  ? 's1'
                  : !continued && !oralPassed && !skipped.contains('s2')
                  ? 's2'
                  : !visited.contains('s3')
                  ? 's3'
                  : null,
            },
          ],
          'evidence': {
            'words': [],
            'completedCourses':
                (continued || oralPassed || skipped.contains('s2')) &&
                    {...visited, ...skipped}.length == 3
                ? [course]
                : [],
          },
        };
      case 'course':
        body = {
          'release': release,
          'course': course,
          'resource': {
            'url':
                'https://glb-teaching-assets-1252505198.cos.ap-beijing.myqcloud.com/courses/releases/$release/runtime/lessons/test.json',
            'size': document.length,
            'sha256': sha256.convert(document).toString(),
          },
        };
      case 'test.json':
        return http.Response.bytes(document, 200);
      case 'media':
        body = {
          'release': release,
          'expiresAt': 4102444800000,
          'assets': [
            for (final id in ['voice', 'hint']) {'id': id, 'text': 'hello'},
          ],
        };
      case 'challenge':
        body = {
          'id': 'challenge-${++challengeCount}',
          'audio': ['voice'],
        };
      case 'heard':
      case 'hint':
        body = {'ok': true};
      case 'phoneme':
        phonemeRequests++;
        body = {
          'release': release,
          'course': course,
          'asset': {
            'kind': 'phonetic-reference',
            'voice': 'phonetic-reference',
            'symbol': r.url.queryParameters['symbol'],
            'id': 'phoneme_ae',
          },
        };
      case 'continue':
        continued = true;
        body = {'continued': true};
      case 'oral':
        oralCalls++;
        oralPassed = oralPassed || oralMatched;
        body = {
          'matched': oralMatched,
          'heard': oralMatched ? 'hello' : 'wrong',
        };
      case 'progress':
      case 'skip':
        await saveGate?.future;
        expect(data['revision'], revision);
        step = data['step'] as String;
        if (route == 'skip') {
          skipped.add(step);
        } else {
          visited.add(step);
          saved.add(step);
        }
        body = {
          'revision': ++revision,
          if (route == 'skip') 'skippedSteps': [step],
        };
      default:
        throw StateError(r.url.toString());
    }
    return http.Response(jsonEncode(body), 200);
  });
  final document = utf8.encode(
    jsonEncode({
      'schema': 'snow-speaks.cloud-lesson/1',
      'audio': [],
      'lesson': {
        'courseId': course,
        'actualWords': [],
        'steps': [
          {'id': 's1', 'phase': '开场', 'audio': 'voice', 'instruction': '开场'},
          {
            'id': 's2',
            'phase': '情境',
            'audio': '',
            'model': 'voice',
            'check': 'c1',
            'instruction': '回应',
          },
          {'id': 's3', 'phase': '收束', 'audio': 'voice', 'instruction': '结束'},
        ],
        'checks': [
          {
            'id': 'c1',
            'audio': ['voice'],
          },
        ],
        'helpBranches': [
          {
            'forStep': 's2',
            'audio': 'hint',
            'onRepeatedDifficulty': {
              'audio': 'hint',
              'allowListenAndContinue': true,
            },
          },
        ],
      },
    }),
  );
}

Future<void> settle(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(done(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    CourseResources.instance.release = release;
    CourseResources.instance.catalog = {
      'courses': [
        for (final id in [course, nextCourse])
          {'id': id, 'title': id, 'goal': '目标'},
      ],
    };
  });
  tearDown(() {
    CourseResources.instance.release = null;
    CourseResources.instance.catalog = {};
  });
  Future<CurriculumLessonController> create(
    Fixture fixture,
    Avatar avatar, {
    Future<void> Function(String)? onSelect,
  }) async {
    final api = AuthApi(
      client: fixture.client,
      origin: Uri.parse('https://example.test'),
    );
    final c = CurriculumLessonController(
      api: api,
      avatar: avatar,
      id: course,
      onSelect: onSelect ?? (_) async {},
      readerFactory: (_) => Reader(),
      feedbackDelay: Duration.zero,
    );
    addTearDown(c.dispose);
    addTearDown(avatar.dispose);
    addTearDown(api.dispose);
    await c.initialize();
    return c;
  }

  test('refresh resumes a skipped exercise and next course follows persisted completion', () async {
    final fixture = Fixture();
    String? selected;
    final c = await create(
      fixture,
      Avatar(),
      onSelect: (id) async => selected = id,
    );
    expect(c.coursePosition, 1);
    expect(c.courseProgress, closeTo(2 / 3, .001));
    c.playCourse();
    await settle(() => c.challenge != null && !c.playing);
    expect(c.courseOptions, isEmpty);
    c.respondToCourse('listen_continue');
    await Future<void>.delayed(Duration.zero);
    expect(c.courseStep, 's2');
    c.navigateCourse(1);
    c.navigateCourse(1); // Rapid double tap records only one skip.
    await settle(() => c.courseStep == 'summary');
    expect(fixture.saved, isEmpty);
    expect(fixture.skipped, {'s2'});
    expect(fixture.continued, false);
    expect(c.courseProgress, 1);
    expect(c.confirmedWordTotal, 0);
    await c.selectCourse(c.nextCourse!.id);
    expect(selected, nextCourse);
    final reopened = await create(fixture, Avatar());
    expect(reopened.catalog['state']['evidence']['completedCourses'], [course]);
  });

  test('reaching closing with missing evidence returns to the exercise without a false summary', () async {
    final fixture = Fixture();
    final c = await create(fixture, Avatar());
    c.coursePosition =
        2; // A legacy client can have reached the closing out of order.
    c.playCourse();
    await settle(() => c.courseStep == 's2' && !c.playing);
    expect(c.courseStep, isNot('summary'));
    expect(c.courseProgress, lessThan(1));
    expect(fixture.continued, false);
    expect(fixture.saved, isEmpty);
  });

  test('right arrow interrupts audio and records a skip without faking a heard step', () async {
    final fixture = Fixture()..visited.clear();
    final avatar = Avatar()..audio = Completer<void>();
    final c = await create(fixture, avatar);
    expect(c.coursePosition, 0);
    c.playCourse();
    c.navigateCourse(1);
    await settle(() => c.coursePosition == 1);
    expect(fixture.saved, isEmpty);
    expect(fixture.skipped, {'s1'});
    avatar.audio!.complete();
    await settle(() => c.courseStep == 's2' && !c.playing);
    expect(fixture.saved, isEmpty);
    expect(c.courseProgress, closeTo(1 / 3, .001));
  });

  test('course selection waits for an in-flight progress save', () async {
    final fixture = Fixture()..saveGate = Completer<void>();
    var selected = false;
    final c = await create(
      fixture,
      Avatar(),
      onSelect: (_) async {
        selected = true;
      },
    );
    c.playCourse();
    await settle(() => c.challenge != null && !c.playing);
    c.navigateCourse(1);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final select = c.selectCourse(nextCourse);
    expect(selected, false);
    fixture.saveGate!.complete();
    await select;
    expect(fixture.saved, isEmpty);
    expect(fixture.skipped, {'s2'});
    expect(selected, true);
    c.pauseCourse();
  });

  test('left arrow returns to the previous beat without marking the current exercise skipped', () async {
    final fixture = Fixture(), avatar = Avatar();
    final c = await create(fixture, avatar);
    c.playCourse();
    await settle(() => c.challenge != null && !c.playing);
    avatar.audio = Completer<void>();
    c.navigateCourse(-1);
    await settle(() => c.coursePosition == 0);
    expect(fixture.skipped, isEmpty);
    expect(fixture.saved, isEmpty);
    c.pauseCourse();
    avatar.audio!.complete();
  });

  test('each wrong answer plays exactly one correction and opens a fresh helped retry', () async {
    final fixture = Fixture(), avatar = Avatar();
    final c = await create(fixture, avatar);
    c.playCourse();
    await settle(() => c.challenge != null && !c.playing);
    expect(avatar.played, hasLength(1));
    final originalChallenge = c.challenge!['id'];
    await c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
    expect(avatar.played, hasLength(2));
    expect(avatar.played.last['teachingPhase'], 'support');
    expect(c.challenge!['id'], isNot(originalChallenge));
    expect(c.challenge!['helped'], true);
    expect(c.courseStep, 's2');
    expect(c.automaticState, 'correction');
    expect(c.coachSentence, 'hello');
    expect(c.reader.playing, false);
    expect(fixture.saved, isEmpty);
    expect(fixture.skipped, isEmpty);
    await c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
    expect(avatar.played, hasLength(3));
    expect(fixture.oralCalls, 2);
    fixture.oralMatched = true;
    await c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
    expect(c.courseStep, 'summary');
    expect(fixture.saved, ['s2']);
    expect(c.confirmedWordTotal, 0);
  });

  test('correction audio gates capture and pause prevents a second playback or reopening', () async {
    final fixture = Fixture(), avatar = Avatar();
    final c = await create(fixture, avatar);
    c.playCourse();
    await settle(() => c.challenge != null && !c.playing);
    avatar.audio = Completer<void>();
    final answer = c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
    await settle(() => avatar.played.length == 2);
    expect(c.reader.playing, true);
    await c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
    expect(fixture.oralCalls, 1);
    c.pauseCourse();
    avatar.audio!.complete();
    await answer;
    expect(avatar.played, hasLength(2));
    expect(c.coursePaused, true);
    expect(c.reader.enabled, false);
    expect(fixture.saved, isEmpty);
  });

  test('formal IPA preview reaches the real avatar audio path and returns to the same helped challenge', () async {
    final fixture = Fixture(), avatar = Avatar();
    final c = await create(fixture, avatar);
    c.playCourse();
    await settle(() => c.challenge != null && !c.playing);
    final challenge = c.challenge!['id'];
    c.previewIpa('æ');
    await settle(() => avatar.played.length == 2 && !c.playing);
    expect(avatar.played.last['kind'], 'phonetic-reference');
    expect(avatar.played.last['symbol'], 'æ');
    expect(c.challenge!['id'], challenge);
    expect(c.challenge!['helped'], true);
    expect(c.courseStep, 's2');
    expect(c.reader.playing, false);
    expect(fixture.saved, isEmpty);
    expect(fixture.skipped, isEmpty);
    c.previewIpa('æ');
    await settle(() => avatar.played.length == 3 && !c.playing);
    expect(fixture.phonemeRequests, 1);
  });

  testWidgets(
    'right arrow advances the real panel and the retired help button is absent',
    (tester) async {
      final fixture = Fixture();
      final c = await create(fixture, Avatar());
      c.playCourse();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: c,
              builder: (_, _) => Column(
                children: [
                  Expanded(child: AdultCoursePanel(controller: c)),
                  LessonNavigation(controller: c),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Also suppress an option left in an old controller snapshot.
      c.courseOptions = [
        {'id': 'listen_continue', 'label': '先听一遍，再继续'},
      ];
      c.notifyListeners();
      await tester.pump();
      expect(find.text('先听一遍，再继续'), findsNothing);
      expect(find.byTooltip('返回上一小段'), findsOneWidget);
      await tester.tap(find.byTooltip('跳过当前小段'));
      await tester.pumpAndSettle();
      expect(
        c.courseStep,
        'summary',
        reason:
            'mode=${c.courseMode}, paused=${c.coursePaused}, position=${c.coursePosition}, feedback=${c.automaticFeedback}, skipped=${fixture.skipped}',
      );
      expect(find.text('+0'), findsOneWidget);
      expect(fixture.skipped, {'s2'});
    },
  );
}
