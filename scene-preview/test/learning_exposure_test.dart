import 'dart:typed_data';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snow_speaks/features/lesson/domain/vocabulary_ledger.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:snow_speaks/features/lesson/presentation/adult_course_panel.dart';
import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Uint8List voice() {
    final pcm = Uint8List(16000), d = ByteData(16000);
    for (var i = 0; i < 16000; i += 2) {
      d.setInt16(i, i % 4 == 0 ? 4000 : -4000, Endian.little);
    }
    pcm.setAll(0, d.buffer.asUint8List());
    return pcm;
  }

  test('automatic capture ignores playback, sends current target, and drops a late result after changing exercise', () async {
    final pending = Completer<http.Response>();
    var requests = 0, results = 0;
    final reader = AutomaticReader(
      (p) => Uri.parse('https://example.test$p'),
      (_, _) {},
      (_, _) {
        results++;
      },
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.queryParameters['text'], 'I want an apple.');
        expect(String.fromCharCodes(request.bodyBytes.take(4)), 'RIFF');
        return pending.future;
      }),
    );
    reader.enabled = true;
    reader.target('I want an apple.', 'apple');
    reader.playing = true;
    reader.ingestPcm(voice());
    reader.ingestPcm(Uint8List(25600));
    expect(requests, 0);
    reader.playing = false;
    reader.ingestPcm(voice());
    reader.ingestPcm(Uint8List(25600));
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0); // A sentence permits a short thinking pause.
    reader.ingestPcm(Uint8List(12800));
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    reader.target('I want a banana.', 'banana');
    expect(reader.busy, isFalse); // Old assessment cannot block the new target.
    pending.complete(http.Response('{"result":{"PronAccuracy":99}}', 200));
    await Future<void>.delayed(Duration.zero);
    expect(results, 0);
    await reader.stop();
    reader.ingestPcm(voice());
    reader.ingestPcm(Uint8List(25600));
    expect(requests, 1);
    await reader.dispose();
  });
  test(
    'actual microphone meter is live during playback without scoring it',
    () async {
      final levels = <double>[];
      var uploads = 0;
      final reader = AutomaticReader(
        (p) => Uri.parse('https://example.test$p'),
        (_, _) {},
        (_, _) {},
        onSignal: levels.add,
        httpClient: MockClient((_) async {
          uploads++;
          return http.Response('{}', 200);
        }),
      );
      reader.enabled = true;
      reader.playing = true;
      reader.target('apple', 'apple');
      reader.ingestPcm(voice());
      expect(levels.last, greaterThan(.1));
      expect(uploads, 0);
      reader.busy = true;
      reader.ingestPcm(Uint8List(3200));
      expect(levels.last, 0);
      await reader.stop();
      expect(levels.last, 0);
      await reader.dispose();
    },
  );
  test('idle progress cannot turn the model speaking state back on', () {
    final c = LessonController()..ready = true;
    c.playCourse();
    c.handle({
      'event': 'playing',
      'session': c.session,
      'text': 'I want',
      'wordTimings': [
        {'word': 'want', 'start': .3, 'end': .7},
      ],
    });
    c.handle({
      'event': 'progress',
      'session': c.session,
      'speaking': true,
      'time': .4,
    });
    expect(c.spokenWord, 'want');
    c.handle({
      'event': 'progress',
      'session': c.session,
      'speaking': false,
      'time': .8,
    });
    expect(c.playing, false);
    expect(c.spokenWord, isEmpty);
    c.dispose();
  });
  test(
    'speaker playback is ignored and following speech receives feedback',
    () async {
      var results = 0;
      final reader = AutomaticReader(
        (p) => Uri.parse('https://example.test$p'),
        (_, _) {},
        (text, result) {
          results++;
          expect(text, 'apple');
        },
        httpClient: MockClient(
          (request) async =>
              http.Response('{"result":{"PronAccuracy":90}}', 200),
        ),
      );
      reader.enabled = true;
      reader.playing = true;
      reader.target('apple', 'apple');
      reader.ingestPcm(voice());
      reader.ingestPcm(Uint8List(25600));
      await Future<void>.delayed(Duration.zero);
      expect(results, 0);
      reader.playing = false;
      reader.ingestPcm(voice());
      reader.ingestPcm(Uint8List(25600));
      await Future<void>.delayed(Duration.zero);
      expect(results, 1);
      await reader.dispose();
    },
  );
  test('exposure is case-insensitive, persists, and only genuinely new words grow the course total', () {
    final v = VocabularyLedger()..begin(restart: true);
    v.expose('I want to eat an apple.');
    v.expose('APPLE!');
    expect(v.seen.length, 6);
    expect(v.newThisCourse.length, 6);
    final restored = VocabularyLedger()..restore(v.toJson());
    restored.begin();
    restored.expose('I want a banana.');
    expect(restored.newThisCourse.length, 8);
    restored.begin(restart: true);
    restored.expose('I want to eat an apple.');
    expect(restored.newThisCourse, isEmpty);
    expect(restored.seen.length, 8);
    restored.expose('I want to eat a red apple.');
    expect(restored.newThisCourse, {'red'});
  });
  testWidgets('microphone bars follow signal samples and clear on disconnect', (
    tester,
  ) async {
    Widget page(double level, bool active) => MaterialApp(
      home: Scaffold(
        body: MicWave(level: level, active: active),
      ),
    );
    await tester.pumpWidget(page(0, true));
    await tester.pumpWidget(page(.8, true));
    await tester.pump(const Duration(milliseconds: 100));
    final bars = tester.widgetList<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(bars.any((b) => b.constraints!.maxHeight > 20), isTrue);
    await tester.pumpWidget(page(0, false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .every((b) => b.constraints!.maxHeight == 3),
      isTrue,
    );
  });
  test('silence never uploads; voice is emitted once after trailing silence and reset discards old input', () {
    final gate = UtteranceGate(),
        quiet = Uint8List(3200),
        voice = Uint8List(3200);
    final data = ByteData.sublistView(voice);
    for (var i = 0; i < voice.length; i += 2) {
      data.setInt16(i, i % 4 == 0 ? 4000 : -4000, Endian.little);
    }
    for (var i = 0; i < 25; i++) {
      expect(gate.add(quiet), isNull);
    }
    for (var i = 0; i < 5; i++) {
      expect(gate.add(voice), isNull);
    }
    for (var i = 0; i < 7; i++) {
      expect(gate.add(quiet), isNull);
    }
    expect(gate.add(quiet), isNotNull);
    expect(gate.add(quiet), isNull);
    gate.add(voice);
    gate.reset();
    for (var i = 0; i < 15; i++) {
      expect(gate.add(quiet), isNull);
    }
  });
  testWidgets(
    'sentence words are individually playable and panel has no scroll view',
    (tester) async {
      final c = LessonController()..ready = true;
      final commands = <Map<String, Object?>>[];
      c.attach(commands.add);
      c.playCourse();
      c.handle({
        'event': 'lesson-phase',
        'session': c.session,
        'phase': 'listen',
        'step': 'eat_apple',
        'display': 'I want to eat an apple.',
        'speechText': 'I want to eat an apple.',
        'text': '我想吃一个苹果。',
        'hideAnswer': false,
        'checkpoint': {'version': 1},
        'stageCount': 62,
        'options': [
          {'id': 'next', 'label': '继续'},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 360,
              child: AdultCoursePanel(controller: c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      // A stale choice/extension phase must not expose legacy control actions.
      c.lessonPhase = 'choice';
      c.courseStep = 'extension_gate';
      c.courseOptions = [
        {'id': 'next', 'label': '继续'},
        {'id': 'attempt', 'label': '我读好了'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdultCoursePanel(key: UniqueKey(), controller: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('继续'), findsNothing);
      expect(find.text('我读好了'), findsNothing);
      await tester.tap(find.text('want'));
      expect(commands.last['clip'], 'part_want');
      expect(
        c.vocabulary.seen,
        containsAll(['i', 'want', 'to', 'eat', 'an', 'apple']),
      );
      c.dispose();
    },
  );
  test('hidden recall target is not counted merely because its answer exists in the lesson', () {
    final c = LessonController()..ready = true;
    c.playCourse();
    c.handle({
      'event': 'lesson-phase',
      'session': c.session,
      'phase': 'recall',
      'step': 'recall_test',
      'display': 'unseen',
      'text': '请回忆',
      'hideAnswer': true,
      'checkpoint': {'version': 1},
      'options': [],
    });
    expect(c.vocabulary.seen, isNot(contains('unseen')));
    c.dispose();
  });
}
