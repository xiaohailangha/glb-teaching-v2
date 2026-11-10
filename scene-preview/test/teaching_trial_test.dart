import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';
import 'package:snow_speaks/features/lesson/application/teaching_trial_controller.dart';

import 'package:snow_speaks/core/avatar/scene/speech_client.dart';
import 'course_completion_test.dart' show Reader, Avatar;

final content = jsonDecode(
  File('test/fixtures/content/teaching-pilot/current.json').readAsStringSync(),
) as Map<String, dynamic>;

class TrialFixture {
  TrialFixture(this.id);
  final String id;
  int answers = 0;
  Completer<void>? saveGate, oralGate;
  final saves = <Map<String, dynamic>>[],
      routes = <String>[],
      flowEvidence = <Map<String, dynamic>>[],
      responses = <Map<String, dynamic>>[];
  Map<String, dynamic> get lesson => Map<String, dynamic>.from(
    (content['lessons'] as List).firstWhere((l) => l['id'] == id),
  );
  late final api = AuthApi(
    origin: Uri.parse('https://example.test'),
    client: MockClient((r) async {
      final route = r.url.path.split('/').last;
      routes.add(route);
      final d = r.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(r.body) as Map<String, dynamic>;
      Object result;
      if (route == 'course') {
        result = {
          ...lesson,
          'revision': content['revision'],
          'words': jsonDecode(
            File('test/fixtures/trial-vocabulary.json').readAsStringSync(),
          )[id],
          'flowEvidence': flowEvidence,
          'visits': [],
          'englishIds': content['englishIds'],
        };
      } else if (route == 'summary') {
        result = {
          'counts': {'follow': answers, 'supported': 0, 'transfer': 0},
          'review': [],
          'audio': [],
        };
      } else if (route == 'audio') {
        result = {'asset': content['assets'][r.url.queryParameters['id']]};
      } else if (route == 'progress') {
        await saveGate?.future;
        saves.add(d);
        result = {'ok': true};
      } else if (route == 'phoneme') {
        result = {
          'asset': content['assets'].values.firstWhere(
            (a) => a['language'] == 'en',
          ),
        };
      } else if (route == 'oral') {
        answers++;
        await oralGate?.future;
        final step = (lesson['steps'] as List).firstWhere(
          (s) => s['id'] == d['step'],
        );
        result = responses.isNotEmpty
            ? responses.removeAt(0)
            : {
                'status': 'passed',
                'attempt': d['attempt'],
                'heard': d['reference'],
                'evidenceLevel': step['transfer'] == true
                    ? 'transfer'
                    : (step['models'] as List).isEmpty
                    ? 'supported-expression'
                    : 'followed-model',
                'wordFeedback': [
                  for (final w in RegExp(
                    r'[a-z]+',
                  ).allMatches((d['reference'] as String).toLowerCase()))
                    {'word': w[0], 'status': 'good'},
                ],
              };
      } else {
        throw StateError('Unexpected route $route');
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode(result)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  late final avatar = Avatar();
  late final c = TeachingTrialController(
    api: api,
    avatar: avatar,
    id: id,
    onSelect: (_) async {},
    readerFactory: (_) => Reader(),
    feedbackDelay: Duration.zero,
    narrationGap: Duration.zero,
  );
  Future<void> settle() async {
    for (var i = 0; i < 1000; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      if (!c.playing && !c.answering) {
        await Future<void>.delayed(const Duration(milliseconds: 3));
        if (!c.playing && !c.answering) return;
      }
    }
  }

  Future<void> stage(String id) async {
    c.coursePosition = c.steps.indexWhere((s) => s['id'] == id);
    c.courseMode = true;
    c.coursePaused = false;
    if (!c.reader.enabled) await c.reader.start();
    await c.enter();
  }

  void close() {
    c.dispose();
    avatar.dispose();
    api.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real verified speech accepts this revision and rejects retired or tampered assets',() async {
    final client=SpeechClient();
    for(final lang in ['zh','en']){
      final a=Map<String,dynamic>.from((content['assets'] as Map).values.firstWhere((a)=>a['language']==lang));
      final bytes=File('test/fixtures/content/teaching-pilot/${a['file']}').readAsBytesSync();
      final item={...a,'kind':'teaching-pilot','revision':content['revision'],'inlineAudio':base64Encode(bytes)};
      final clip=await client.prepareVerified(item);expect(clip.bytes,bytes);expect(clip.cues,isNotEmpty);
      await expectLater(client.prepareVerified({...item,'revision':'teacher-plan-20261106-v5'}),throwsStateError);
      await expectLater(client.prepareVerified({...item,'sha256':'0'*64}),throwsStateError);
    }
  });
  test('quiet onset stays in pre-roll until the word pause completes', () {
    Uint8List pcm(int length, int sample) {
      final bytes = Uint8List(length);
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i < length; i += 2) {
        view.setInt16(i, sample, Endian.little);
      }
      return bytes;
    }

    final gate = UtteranceGate(threshold: .010, preRollBytes: 12800);
    gate.pauseBytes = 11200;
    for (var i = 0; i < 10; i++) {
      gate.add(pcm(1600, 200));
    }
    expect(gate.lead.length, 12800);
    gate.add(pcm(3200, 1500));
    final result = gate.add(pcm(11200, 0));
    expect(result, isNotNull);
    expect(result!.length, greaterThan(3200));
  });
  test('board survives every clip and the real speech-end callback without changing the target', () async {
    final f = TrialFixture('N26-U084-L01');
    addTearDown(f.close);
    await f.c.initialize();
    f.c.coursePosition = f.c.steps.indexWhere((s) => s['id'] == 'B06');
    f.c.prepareStage();
    final board = jsonEncode(f.c.teachingCard!['board']);
    final hold = Completer<void>();
    f.avatar.audio = hold;
    f.c.playCourse();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(jsonEncode(f.c.teachingCard!['board']), board);
    hold.complete();
    await f.settle();
    expect(f.c.courseDisplay, 'despite the difficulty');
    expect(f.c.automaticState, 'waiting');
    expect(jsonEncode(f.c.teachingCard!['board']), board);
    expect(f.avatar.played.map((a) => a['text']).last, contains('你来一次'));
    expect(
      f.avatar.played.where((a) => a['language'] == 'en').map((a) => a['text']),
      ['despite', 'despite the difficulty'],
    );
    final callback = f.avatar.played.last['onSpeechReady'] as void Function();
    final generation = f.c.reader.requestGeneration;
    callback();
    expect(f.c.reader.requestGeneration, generation);
  });
  test('local success returns to the full expression without another English model', () async {
    final f = TrialFixture('N26-U006-L04');
    addTearDown(f.close);
    await f.c.initialize();
    await f.stage('A03');
    f.responses.addAll([
      {
        'status': 'repair',
        'attempt': 'local-first',
        'repair': 'local-first',
        'target': 'banana',
        'original': f.c.chosenPrompt,
        'word': 'banana',
        'message': '改法：中间音节重一些。',
        'audio': [content['englishIds']['banana']],
      },
      {
        'status': 'passed',
        'returnToSentence': true,
        'original': f.c.chosenPrompt,
        'message': '这一处清楚了，回到原表达。',
        'audio': [],
      },
    ]);
    await f.c.acceptUtterance(Uint8List(100));
    expect(f.c.courseDisplay, 'banana');
    final before = f.avatar.played.length;
    await f.c.acceptUtterance(Uint8List(100));
    expect(f.c.courseDisplay, 'I want an apple and a banana.');
    expect(f.avatar.played.length, before);
    expect(f.c.automaticState, 'waiting');
    expect(f.saves.where((s) => s['outcome'] == 'passed'), isEmpty);
  });
  test('arrows switch immediately while audio, progress and assessment are pending', () async {
    final f = TrialFixture('N26-U006-L04');
    addTearDown(f.close);
    await f.c.initialize();
    final hold = Completer<void>();
    f.avatar.audio = hold;
    f.saveGate = Completer<void>();
    f.c.playCourse();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    f.c.navigateCourse(1);
    expect(f.c.currentCard['id'], 'A02');
    f.c.navigateCourse(1);
    expect(f.c.currentCard['id'], 'A03');
    hold.complete();
    f.avatar.audio = null;
    await f.settle();
    f.oralGate = Completer<void>();
    final submitted = f.c.acceptUtterance(Uint8List(100));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    f.c.navigateCourse(1);
    expect(f.c.currentCard['id'], 'A04');
    f.oralGate!.complete();
    await submitted;
    await f.settle();
    expect(f.c.currentCard['id'], 'A04');
    f.saveGate!.complete();
    await f.c.flushProgress();
  });
  test('word audition preserves the authored board and resumes the current listening turn', () async {
    final f = TrialFixture('N26-U006-L04');
    addTearDown(f.close);
    await f.c.initialize();
    await f.stage('A03');
    final original = jsonEncode(f.c.teachingCard!['board']);
    final count = f.avatar.played.length;
    await f.c.preview([content['englishIds']['and']]);
    expect(f.avatar.played.length, count + 1);
    expect(f.c.courseDisplay, f.c.chosenPrompt);
    expect(f.c.automaticState, 'waiting');
    expect(jsonEncode(f.c.teachingCard!['board']), original);
    expect(f.saves, isEmpty);
  });
  test('though only asks for the word, optional word never counts down and both rests hold', () async {
    final f = TrialFixture('N26-U084-L01');
    addTearDown(f.close);
    await f.c.initialize();
    await f.stage('B04');
    expect(f.c.chosenPrompt, 'though');
    expect(
      f.avatar.played.where((a) => a['language'] == 'en').last['text'],
      'Though this is difficult, I can try.',
    );
    await f.stage('B11');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(f.c.currentCard['id'], 'B11');
    expect(f.c.automaticState, 'waiting');
    for (final id in ['B09', 'B14']) {
      await f.stage(id);
      expect(f.c.currentCard['id'], id);
      expect(f.c.automaticState, 'rest');
    }
  });
  test('supported use selects an actual successful full expression and review only selects unresolved evidence', () async {
    final f = TrialFixture('N26-U084-L01');
    addTearDown(f.close);
    await f.c.initialize();
    f.c.achievements['B04'] = 'followed-model';
    f.c.spokenExamples['B04']='though';
    await f.stage('B13');
    expect(f.c.chosenPrompt, 'Although this is difficult, I can try.');
    f.c.achievements['B10']='followed-model';
    f.c.spokenExamples['B10']='This is difficult. However, I can try.';
    await f.stage('B13');
    expect(f.c.chosenPrompt,'This is difficult. However, I can try.');
    await f.stage('B20');
    expect(f.c.hasSpeechTarget, false);
    expect(f.c.currentCard['summary'], true);
    f.c.review['B18'] = 'among';
    await f.stage('B20');
    expect(f.c.chosenPrompt, 'among friends');
    expect(f.c.selectedReviewSource, 'B18');
  });
  test('two complete lessons use the new order and keep full vocabulary at the end', () async {
    for (final id in ['N26-U006-L04', 'N26-U084-L01']) {
      final f = TrialFixture(id);
      await f.c.initialize();
      f.c.playCourse();
      await f.settle();
      for (var i = 0; i < 50 && f.c.currentCard['summary'] != true; i++) {
        if (f.c.automaticState == 'rest' || f.c.currentCard['optional'] == true)
          f.c.navigateCourse(1);
        else if (f.c.hasSpeechTarget)
          await f.c.acceptUtterance(Uint8List(100));
        await f.settle();
      }
      expect(
        f.c.currentCard['summary'],
        true,
        reason:
            '${f.c.currentCard['id']} ${f.c.automaticState} ${f.c.automaticFeedback} answers=${f.answers}',
      );
      await f.c.flushProgress();
      expect(f.c.courseReviewWords.length, id.contains('006') ? 8 : 19);
      expect(f.routes, isNot(contains('action')));
      expect(f.c.achievements.values, isNot(contains('independent')));
      f.close();
    }
  });
}
