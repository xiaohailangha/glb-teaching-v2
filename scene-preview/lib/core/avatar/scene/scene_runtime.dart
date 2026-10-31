import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:vector_math/vector_math.dart' as vm;

import '../../../features/lesson/application/lesson_controller.dart';
import 'lesson_director.dart';
import 'secondary_motion.dart';
import 'speech_client.dart';
import 'automatic_reader.dart';
import '../../../features/lesson/domain/course_lexicon.dart';
import '../../../features/lesson/domain/pronunciation_feedback.dart';
import 'teaching_math.dart';
import 'scene_asset_bundle.dart';
import 'corneal_highlights.dart';
import 'rendered_frame_meter.dart';
import 'teaching_background.dart';
import 'scene_diagnostics.dart';
import 'clothing_bindings.dart';
import 'intent_motion.dart';
import 'neutral_gaze.dart';

class SceneRuntime extends ChangeNotifier {
  SceneRuntime(
    this.controller, {
    this.presentStage,
    this.feedbackDelay = const Duration(milliseconds: 1900),
  }) {
    if (presentStage == null) scene = _measuredScene();
    controller.attach(command);
    automatic = AutomaticReader(
      speech.endpoint,
      (state, message) => emit('auto-state', {
        'session': session,
        'enabled': automatic.enabled,
        'state': state,
        'message': message,
      }),
      acceptAssessment,
      onSignal: (level) =>
          emit('mic-signal', {'session': session, 'level': level}),
      onTranscript: (text) =>
          emit('transcript', {'session': session, 'text': text}),
      onRecognized: _recognized,
    );
    speech.onPlaybackError = (error) {
      playingAudio = false;
      emit('speech-error', {
        'session': session,
        'message': '语音播放失败，请再点击一次：$error',
      });
    };
  }
  Stage? coachingOriginal;
  List<Stage>? previewReturn;
  String coachingWord = '';
  int retryCount = 0;
  void _feedback(
    String message, {
    String state = 'listening',
    List<Map<String, Object>>? words,
    String? sentence,
  }) {
    emit('auto-state', {
      'session': session,
      'enabled': automatic.enabled,
      'state': state,
      'message': message,
      'words': ?words,
      'sentence': ?sentence,
    });
  }

  void _recognized(String heard) {
    final d = director;
    if (d == null || !d.fruitCourse || d.branch.isNotEmpty) return;
    final text = heard.toLowerCase();
    String? action;
    if (d.stage.id == 'extension_gate') {
      if (RegExp(r'红|学习|继续|yes|red').hasMatch(text)) action = 'next';
      if (RegExp(r'复习|跳过|no|skip').hasMatch(text)) action = 'skip';
    } else {
      final apple = RegExp(r'apple|苹果').hasMatch(text),
          banana = RegExp(r'banana|香蕉').hasMatch(text);
      if (apple != banana) {
        final word = apple ? 'apple' : 'banana';
        action = d.stage.id == 'scene_pick'
            ? 'choose_$word'
            : d.stage.id == 'phrase_select'
            ? 'phrase_$word'
            : word;
      }
    }
    if (action != null && d.stage.options.any((o) => o['id'] == action)) {
      d.respond(action);
      unawaited(_enterStage());
    } else {
      _feedback('没听清你的选择，可以说水果名称，也可以点图片。');
    }
  }

  void acceptAssessment(String target, Map<String, dynamic> data) {
    final d = director;
    if (d == null || !d.fruitCourse || !automatic.enabled) return;
    final stage = d.stage;
    if (!['listen', 'recall'].contains(stage.phase)) return;
    final report = PronunciationFeedback(target, data['result'] as Map? ?? {});
    if (report.passed) {
      automatic.playing = true;
      background.celebrate(now);
      retryCount = 0;
      _feedback(
        stage.id.startsWith('coach_')
            ? '这一小段读对了！'
            : RegExp(r'[.!?]$').hasMatch(target.trim())
            ? '整句通过！'
            : target.trim().split(' ').length > 1
            ? '这一小段读对了！'
            : '读对了！',
        state: 'success',
        words: report.words.map((w) => w.toJson()).toList(),
      );
      final token = stageGeneration;
      unawaited(
        Future<void>.delayed(feedbackDelay, () {
          if (disposed ||
              token != stageGeneration ||
              director != d ||
              !automatic.enabled) {
            return;
          }
          if (stage.id == 'coach_word') {
            final original = coachingOriginal!;
            final chunks = original.segments
                .where(
                  (c) =>
                      RegExp(r"[a-z]+(?:'[a-z]+)?")
                          .allMatches(c['label']!.toLowerCase())
                          .any((m) => m[0] == coachingWord),
                )
                .toList();
            if (chunks.isNotEmpty &&
                chunks.first['label']!.split(' ').length > 1) {
              _coach(
                chunks.first['label']!,
                chunks.first['clip']!,
                'coach_chunk',
              );
              return;
            }
            _returnToSentence();
            return;
          }
          if (stage.id == 'coach_chunk') {
            _returnToSentence();
            return;
          }
          coachingOriginal = null;
          coachingWord = '';
          final action = stage.options.any((o) => o['id'] == 'attempt')
              ? 'attempt'
              : 'next';
          d.respond(action);
          unawaited(_enterStage());
        }),
      );
      return;
    }
    retryCount++;
    final sentence = coachingOriginal?.speechText.isNotEmpty == true
        ? coachingOriginal!.speechText
        : target;
    _feedback(
      report.message + (retryCount >= 3 ? ' 不着急，随时可以在设置里暂停。' : ''),
      state: 'correction',
      words: report.words.map((w) => w.toJson()).toList(),
      sentence: sentence,
    );
    if (!report.reliable) return;
    final focus = report.focus;
    if (!stage.id.startsWith('coach_') &&
        focus != null &&
        courseLexicon.containsKey(focus.word)) {
      coachingOriginal = stage;
      coachingWord = focus.word;
      if (const {'a', 'an', 'to'}.contains(focus.word)) {
        // A brief reduced word is not a useful standalone scoring gate.
        final chunks = stage.segments
            .where(
              (c) => c['label']!.toLowerCase().split(' ').contains(focus.word),
            )
            .toList();
        if (chunks.isNotEmpty) {
          _coach(chunks.first['label']!, chunks.first['clip']!, 'coach_chunk');
        } else {
          _coach(stage.speechText, stage.practiceClip, 'coach_chunk');
        }
      } else {
        _coach(focus.word, courseLexicon[focus.word]!.clip, 'coach_word');
      }
    } else if (coachingOriginal != null && stage.id.startsWith('coach_')) {
      _coach(stage.speechText, stage.practiceClip, stage.id);
    } else {
      unawaited(_command({'type': 'course-replay', 'session': session}));
    }
  }

  void _coach(String target, String clip, String id) {
    final d = director, original = coachingOriginal;
    if (d == null || original == null || clip.isEmpty) return;
    d.branch = [
      if (timings.containsKey('coach_$coachingWord'))
        Stage(
          'explain',
          clip: 'coach_$coachingWord',
          wordId: d.word,
          chapter: '一起练习',
          display: target,
          text: wordGuide[coachingWord] ?? '',
          picture: original.picture,
        ),
      Stage(
        'demonstrate',
        clip: clip,
        wordId: d.word,
        chapter: '一起练习',
        display: target,
        text: wordGuide[coachingWord] ?? '',
        picture: original.picture,
      ),
      Stage(
        'listen',
        id: id,
        wordId: d.word,
        chapter: '一起练习',
        display: target,
        speechText: target,
        practiceClip: clip,
        text: wordGuide[coachingWord] ?? '',
        picture: original.picture,
        options: const [
          {'id': 'next', 'label': '继续'},
        ],
      ),
    ];
    unawaited(_enterStage());
  }

  void _returnToSentence() {
    final d = director;
    if (d == null) return;
    d.branch = [];
    _feedback('把刚才的小段放回整句，再完整说一次。', state: 'listening');
    final original = coachingOriginal!;
    final clip = original.practiceClip.isNotEmpty
        ? original.practiceClip
        : d.word;
    d.branch = [
      Stage(
        'explain',
        clip: 'coach_sentence',
        wordId: d.word,
        display: original.speechText,
        chapter: '回到整句',
        text: '把小段放回整句，再完整说一次。',
      ),
      Stage(
        'demonstrate',
        clip: clip,
        wordId: d.word,
        display: original.speechText,
        chapter: original.chapter,
        text: original.text,
        picture: original.picture,
      ),
    ];
    unawaited(_enterStage());
  }

  final Future<void> Function(Stage)? presentStage;
  Future<void> navigateCourse(int direction) async {
    final d = director;
    if (d == null || !d.fruitCourse) return;
    final wasFinished = d.stage.phase == 'finish';
    if (!d.navigate(direction)) return;
    background.cancel();
    stageGeneration++; // Invalidate delayed passes before any asynchronous stop.
    previewReturn = null;
    coachingOriginal = null;
    coachingWord = '';
    retryCount = 0;
    automatic.target('', 'navigation:$stageGeneration');
    _feedback('', words: [], sentence: '');
    emit('transcript', {'session': session, 'text': ''});
    if (wasFinished) unawaited(automatic.start());
    await _enterStage();
  }

  final Duration feedbackDelay;
  final LessonController controller;
  late Scene scene;
  final frameMeter = RenderedFrameMeter();
  final background = TeachingBackground();
  Scene _measuredScene() => _MeasuredScene(() {
    if (loaded && !disposed) frameMeter.record(now);
  });
  Node? model;
  late final AutomaticReader automatic;
  final speech = SpeechClient(), motion = NaturalMotion();
  final stopwatch = Stopwatch()..start();
  final timings = <String, dynamic>{};
  Map<String, dynamic> units = {};
  List<dynamic> fruitStages = [];
  SecondaryMotion? secondary;
  AttachmentProbe? attachmentProbe;
  CornealHighlights? highlights;
  AnimationClip? teachingClip, emotionClip;
  List<Node> meshes = [];
  StreamSubscription? endedSubscription;
  bool loaded = false,
      disposed = false,
      closeUp = false,
      playingAudio = false,
      loadingAudio = false;
  String loading = '正在准备 Flutter Scene…', quality = 'high';
  double frameDt = .016,
      aspect = 16 / 9,
      lastStats = 0,
      lastProgress = 0,
      phaseStarted = 0,
      emotionStarted = 0;
  double targetFps = 120, playRate = 1;
  int session = 0,
      stageGeneration = 0,
      visits = 0,
      emotionIndex = 0,
      iteration = 1,
      triangles = 0;
  bool emotionAll = false;
  String mode = 'idle', word = 'apple';
  TeachingDirector? director;
  List<MouthCue> cues = [];
  SpeechClip? currentClip;
  double get now => stopwatch.elapsedMicroseconds / 1e6;
  String get phase =>
      director?.stage.phase ?? (mode == 'idle' ? 'idle' : 'demonstrate');
  bool get waiting => director?.stage.clip == null || loadingAudio;
  double get progress => speech.duration > 0
      ? (speech.seconds / speech.duration).clamp(0.0, 1.0)
      : 0;
  void emit(String event, [Map<String, dynamic> data = const {}]) {
    if (!disposed) controller.handle({'event': event, ...data});
  }

  Future<void> init() async {
    try {
      final speechInit = speech.init();
      await Scene.initializeStaticResources();
      if (!(const bool.fromEnvironment('SCENE_DIAGNOSTICS') &&
          Uri.base.queryParameters['background'] == 'transparent')) {
        scene.addRenderPass(background);
      }
      scene
        ..antiAliasingMode = AntiAliasingMode.fxaa
        ..environmentIntensity = .8
        ..exposure = 1;
      scene.sceneColorCaptureBatches = 1;
      scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(2, -3.8, 4),
        color: vm.Vector3(1, .93, .85),
        intensity: 2.7,
        castsShadow: true,
        shadowCascadeCount: 1,
        shadowMapResolution: 512,
        shadowMaxDistance: 9,
        shadowDepthBias: .00008,
        shadowNormalBias: .001,
      );
      scene.renderQuality
        ..adaptive = true
        ..targetFrameRate = 60
        ..minRenderScale = .75;
      loading = '正在加载 Storm 人物…';
      notifyListeners();
      model = await loadScene(
        'assets/avatar/models/storm-performance.glb',
        bundle: kIsWeb
            ? SceneAssetBundle((completed, total) {
                loading =
                    '正在下载 Storm 人物… ${(completed / total * 100).round()}%';
                if (!disposed) notifyListeners();
              })
            : null,
      );
      if (disposed) return;
      await repairClothingBindings(model!);
      calibrateNeutralGaze(model!);
      model!.scale = vm.Vector3.all(1.5);
      scene.add(model!);
      for (final file in [
        'timings',
        'teaching-prompts',
        'pronunciation-units',
        'course-prompts',
        'fruit-prompts',
        'coach-prompts',
      ]) {
        final json = jsonDecode(
          await rootBundle.loadString('assets/avatar/audio/$file.json'),
        ) as Map<String, dynamic>;
        timings.addAll(json);
        if (file == 'pronunciation-units') units = json;
      }
      timings['performance'] = jsonDecode(
        await rootBundle.loadString(
          'assets/avatar/audio/performance-cues.json',
        ),
      );
      fruitStages =
          (jsonDecode(
                await rootBundle.loadString(
                  'assets/avatar/courses/adult-fruit.json',
                ),
              ) as Map)['stages']
              as List;
      final rig = jsonDecode(
        await rootBundle.loadString('assets/avatar/models/storm-rig.json'),
      ) as Map<String, dynamic>;
      secondary = SecondaryMotion(model!, rig);
      if (const bool.fromEnvironment('SCENE_DIAGNOSTICS') &&
          Uri.base.queryParameters['probe'] == '1') {
        attachmentProbe = AttachmentProbe(secondary!);
      }
      model!.addComponent(RestoreSecondaryMotion(secondary!));
      final teaching = model!.findAnimationByName('Teaching_Apple_10s'),
          emotions = model!.findAnimationByName('Emotion_Reel');
      if (teaching == null || emotions == null) {
        throw StateError('Storm 教学或情绪动画未完整导入');
      }
      teachingClip = model!.createAnimationClip(teaching)
        ..pause()
        ..weight = 0;
      emotionClip = model!.createAnimationClip(emotions)
        ..pause()
        ..weight = 0;
      meshes = descendants(model!).where((n) => n.mesh != null).toList();
      for (final node in meshes) {
        for (final primitive in node.mesh!.primitives) {
          final geometry = primitive.geometry;
          if (geometry is MorphedSkinnedGeometry && !geometry.usesGpuMorphing) {
            throw StateError('${node.name} 表情退回 CPU，停止加载以避免误报 GPU 适配成功');
          }
          final mat = primitive.material;
          if (node.name.contains('eye')) primitive.castsShadow = false;
          if (mat is PhysicallyBasedMaterial) {
            if (node.name.contains('cornea')) {
              // A zero-thickness cornea needs a clear surface, not a second
              // screen-color capture. The WebGL transmission path obscures
              // this skinned shell; thin alpha preserves the underlying iris.
              mat
                ..roughnessFactor = .035
                ..ior = 1.376
                ..transmission = 0
                ..alphaMode = AlphaMode.blend
                ..baseColorFactor = vm.Vector4(1, 1, 1, .035)
                ..doubleSided = true;
              primitive.castsShadow = false;
            } else if (RegExp(r'eye[._][LR]').hasMatch(node.name)) {
              mat
                ..roughnessFactor = .32
                ..metallicFactor = 0;
            }
          }
        }
      }
      highlights = CornealHighlights(model!, secondary!.eyes);
      final driver = Node(name: 'Teaching_pose_after_animation')
        ..addComponent(_PoseDriver(this));
      model!.add(driver);
      model!.children.remove(driver);
      model!.children.insert(0, driver);
      await speechInit;
      endedSubscription = speech.player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed &&
            playingAudio &&
            !loadingAudio) {
          playingAudio = false;
          _audioEnded();
        }
      });
      loaded = true;
      if (const bool.fromEnvironment('SCENE_DIAGNOSTICS') &&
          Uri.base.queryParameters['capture'] == '1') {
        Future<void>.delayed(
          const Duration(seconds: 3),
          () => probeDisplayCoverage(scene),
        );
      }
      loading = '';
      emit('ready', {
        'triangles': 425144,
        'morphCount': 52,
        'modelBytes': 153334024,
        'speech': {'configured': speech.configured},
        'runtime': kIsWeb
            ? 'flutter_scene · WebGL2'
            : 'Flutter GPU · flutter_scene',
        'version': 'scene-0.2.0-r15-responsive',
      });
      notifyListeners();
    } catch (e, stack) {
      loading = '人物加载失败：$e';
      emit('error', {'message': loading});
      debugPrint('$e\n$stack');
      notifyListeners();
    }
  }

  void command(Map<String, Object?> data) {
    if (![
      'play',
      'course',
      'pronunciation',
      'performance',
      'course-replay',
      'course-preview',
      'course-sound',
      'course-navigate',
    ].contains(data['type'])) {
      // The controller sends stop immediately before a new play command.
      // Pause now, before the new gesture unlock, so an older queued stop
      // cannot abort Safari's play promise.
      unawaited(_command(data));
      return;
    }
    unawaited(_commandAfterGesture(data, speech.player.unlockFromGesture()));
  }

  Future<void> _commandAfterGesture(
    Map<String, Object?> data,
    Future<void> gesture,
  ) async {
    try {
      await gesture;
      if (disposed) return;
      if (data['session'] is int && data['session'] != controller.session) {
        return;
      }
      await _command(data);
    } catch (error) {
      emit('speech-error', {
        'session': data['session'],
        'message': '请再次点击播放：$error',
      });
    }
  }

  Future<void> _command(Map<String, Object?> c) async {
    try {
      switch (c['type']) {
        case 'render-settings':
          quality = c['quality']?.toString() ?? 'high';
          targetFps =
              {'high': 120.0, 'medium': 60.0, 'low': 30.0}[quality] ?? 120;
          scene.renderQuality
            ..adaptive = c['adaptive'] == true
            ..targetFrameRate = math.min(targetFps, 60)
            ..tier = quality == 'low'
                ? RenderQualityTier.low
                : quality == 'medium'
                ? RenderQualityTier.medium
                : RenderQualityTier.high;
          scene.antiAliasingMode = quality == 'low'
              ? AntiAliasingMode.none
              : AntiAliasingMode.fxaa;
          if (const bool.fromEnvironment('SCENE_DIAGNOSTICS') &&
              Uri.base.queryParameters['aa'] == 'off') {
            scene.antiAliasingMode = AntiAliasingMode.none;
          }
          notifyListeners();
        case 'focus':
          closeUp = c['closeUp'] == true;
        case 'stop':
          await stop();
        case 'play':
          await stop();
          if (c['session'] != controller.session) return;
          session = c['session'] as int;
          word = c['word'] as String;
          mode = 'lesson';
          director = TeachingDirector.word(
            word: word,
            rate: (c['rate'] as num? ?? 1).toDouble(),
            repeat: c['repeat'] as int? ?? 1,
            reason: c['reason']?.toString() ?? 'start',
            variation: visits++ % 3,
          );
          await _enterStage();
        case 'course':
          await stop();
          if (c['session'] != controller.session) return;
          session = c['session'] as int;
          word = 'apple';
          mode = 'course';
          director = c['style'] == 'adult'
              ? TeachingDirector.fruit(
                  fruitStages,
                  rate: (c['rate'] as num? ?? 1).toDouble(),
                  saved: c['checkpoint'] as Map<String, dynamic>?,
                )
              : TeachingDirector.apple(
                  style: c['style']?.toString() ?? 'adult',
                  rate: (c['rate'] as num? ?? 1).toDouble(),
                  variation: visits++ % 3,
                );
          if (c['skip'] == true && director!.fruitCourse) {
            final d = director!;
            final stage = d.stage;
            if (stage.phase == 'listen' || stage.phase == 'recall') {
              if (stage.id.startsWith('scene_')) {
                d.index = d.stages.indexWhere((s) => s.id == 'extension_gate');
              } else {
                d.index++;
              }
            }
          }
          if (c['style'] == 'adult') unawaited(automatic.start());
          await _enterStage();
        case 'course-navigate':
          if (c['session'] != session) return;
          await navigateCourse((c['direction'] as num?)?.toInt() ?? 1);
        case 'course-replay':
        case 'course-preview':
        case 'course-sound':
          if (c['session'] != session || director?.fruitCourse != true) return;
          unawaited(speech.cancelCapture());
          final d = director!;
          if (c['type'] != 'course-replay' || d.stage.clip == null) {
            final original = d.stage;
            if (original.answer.isNotEmpty) d.helped.add(original.id);
            final clip =
                c['clip']?.toString() ??
                (original.practiceClip.isNotEmpty
                    ? original.practiceClip
                    : original.answer.startsWith('phrase_')
                    ? original.answer
                    : d.word);
            if (!timings.containsKey(clip)) return;
            previewReturn ??= List.of(d.branch);
            final soundOnly = c['type'] == 'course-sound';
            d.branch = [
              Stage(
                clip.startsWith('phoneme_') || clip.startsWith('group_')
                    ? 'phoneme'
                    : 'demonstrate',
                clip: clip,
                wordId: d.word,
                chapter: original.chapter,
                display: soundOnly
                    ? original.display
                    : timings[clip]?['symbol']?.toString() ??
                          timings[clip]?['text']?.toString() ??
                          original.display,
                picture: original.picture,
                hide: original.hideAnswer,
                text: soundOnly ? original.text : '再听一次，然后回到练习。',
                symbol: soundOnly ? c['symbol']?.toString() ?? '' : '',
              ),
            ];
          }
          await _enterStage();
        case 'pronunciation':
          await stop();
          if (c['session'] != controller.session) return;
          session = c['session'] as int;
          word = c['word'] as String;
          mode = 'lesson';
          final kind = c['kind'] as String,
              symbol = c['symbol']?.toString() ?? '';
          final clip = kind == 'meaning'
              ? 'meaning_$word'
              : units.keys.cast<String?>().firstWhere(
                  (key) =>
                      ['phoneme', 'group'].contains(units[key]['kind']) &&
                      units[key]['symbol'] == symbol,
                  orElse: () => null,
                );
          if (clip == null) throw StateError('音标音频缺失');
          director = TeachingDirector.pronunciation(
            word: word,
            kind: kind,
            clip: clip,
            symbol: symbol,
          );
          await _enterStage();
        case 'lesson-response':
          if (c['session'] != session) return;
          final next = director?.respond(c['action']?.toString() ?? 'attempt');
          if (next != null) await _enterStage();
        case 'performance':
          await stop();
          if (c['session'] != controller.session) return;
          session = c['session'] as int;
          word = 'performance';
          mode = 'performance';
          phaseStarted = now;
          await _play('performance', 1, curated: true);
        case 'acting-story':
          await stop();
          if (c['session'] != controller.session) return;
          session = c['session'] as int;
          mode = 'story';
          phaseStarted = now;
        case 'emotion':
          await stop();
          if (c['session'] != controller.session) return;
          session = c['session'] as int;
          mode = 'emotion';
          emotionStarted = now;
          emotionIndex = emotionIds
              .indexOf(c['emotion'] as String)
              .clamp(0, 11);
          emotionAll = c['all'] == true;
          emit('emotion', {
            'session': session,
            'emotion': emotionIds[emotionIndex],
          });
        case 'auto-start':
          if (c['session'] != session) return;
          await speech.cancelCapture();
          await automatic.start();
        case 'auto-stop':
          await automatic.stop();
        case 'capture-start':
          await automatic.stop();
          if (c['session'] != session ||
              !waiting ||
              !['listen', 'recall'].contains(phase)) {
            return;
          }
          await speech.startCapture(
            session: session,
            emit: emit,
            text: director?.stage.speechText.isNotEmpty == true
                ? director!.stage.speechText
                : director?.word ?? word,
            mode: phase == 'recall' ? 'recognize' : 'assess',
          );
        case 'capture-stop':
          await speech.finishCapture(
            session: session,
            emit: emit,
            text: director?.stage.speechText.isNotEmpty == true
                ? director!.stage.speechText
                : director?.word ?? word,
            mode: phase == 'recall' ? 'recognize' : 'assess',
          );
        case 'capture-cancel':
          await speech.cancelCapture();
        case 'retry':
          await stop();
          await endedSubscription?.cancel();
          endedSubscription = null;
          teachingClip = null;
          emotionClip = null;
          meshes = [];
          secondary = null;
          highlights = null;
          if (presentStage == null) scene.dispose();
          scene = _measuredScene();
          frameMeter.reset();
          loaded = false;
          notifyListeners();
          await init();
      }
    } catch (e) {
      emit('error', {'message': e.toString(), 'session': session});
    }
  }

  Future<void> stop() async {
    stageGeneration++;
    director = null;
    mode = 'idle';
    playingAudio = false;
    loadingAudio = false;
    currentClip = null;
    cues = [];
    coachingOriginal = null;
    previewReturn = null;
    background.cancel();
    coachingWord = '';
    retryCount = 0;
    await automatic.stop();
    await speech.stop();
  }

  Future<void> _enterStage() async {
    final stage = director!.stage, token = ++stageGeneration;
    if (coachingOriginal != null &&
        director!.branch.isEmpty &&
        stage.id != coachingOriginal!.id) {
      coachingOriginal = null;
      coachingWord = '';
      emit('auto-state', {
        'session': session,
        'enabled': automatic.enabled,
        'message': '',
        'words': <Map<String, Object>>[],
        'sentence': '',
      });
    }
    if (presentStage != null) {
      automatic.playing = stage.clip != null;
      await presentStage!(stage);
      return;
    }
    speech.generation++;
    playingAudio = false;
    await speech.player.stop();
    if (disposed || token != stageGeneration || director == null) return;
    playingAudio = false;
    loadingAudio = false;
    if (stage.phase == 'finished') {
      final finishedSession = session;
      director = null;
      mode = 'idle';
      emit('lesson-phase', {'session': finishedSession, 'phase': 'ready'});
      emit('ended', {'session': finishedSession, 'progress': 1});
      return;
    }
    if (stage.phase == 'finish') {
      await automatic.stop();
      emit('auto-state', {
        'session': session,
        'enabled': false,
        'message': '课程已结束，麦克风已关闭。',
      });
    }
    if (disposed || token != stageGeneration || director == null) return;
    phaseStarted = now;
    if (coachingOriginal == null) {
      _feedback(
        '',
        state: stage.clip == null ? 'listening' : 'model',
        words: [],
        sentence: '',
      );
    } else if (controller.automaticState == 'success') {
      _feedback('', state: stage.clip == null ? 'listening' : 'model');
    }
    if (stage.clip == null &&
        ['listen', 'recall', 'choice'].contains(stage.phase)) {
      emit('transcript', {'session': session, 'text': ''});
    }
    String autoText = '', autoKey = '';
    if (director!.fruitCourse) {
      if (['listen', 'recall'].contains(stage.phase) &&
          stage.id != 'extension_gate') {
        autoText = stage.speechText.isNotEmpty
            ? stage.speechText
            : director!.word;
        autoKey = stage.id;
      } else if (director!.branch.isEmpty &&
          stage.phase == 'demonstrate' &&
          director!.index + 1 < director!.stages.length) {
        final next = director!.stages[director!.index + 1];
        if (next.phase == 'listen') {
          autoText = next.speechText.isNotEmpty
              ? next.speechText
              : director!.word;
          autoKey = next.id;
        }
      }
    }
    if (director!.fruitCourse &&
        stage.clip == null &&
        (stage.phase == 'choice' || stage.id == 'extension_gate')) {
      autoText = 'choice';
      autoKey = stage.id;
    }
    automatic.target(autoText, autoKey, recognizeOnly: autoText == 'choice');
    automatic.playing = stage.clip != null;
    word = director!.word;
    iteration = stage.iteration;
    emit('lesson-phase', {
      'session': session,
      'phase': stage.phase,
      'speaking': stage.clip != null,
      'iteration': iteration,
      'symbol': stage.symbol,
      'course': director!.course,
      'step': stage.id,
      'text': stage.text,
      'options': stage.options,
      'hideAnswer': stage.hideAnswer,
      if (director!.fruitCourse) ...{
        'word': word,
        'display': stage.display,
        'speechText': stage.speechText,
        'segments': stage.segments,
        'picture': stage.picture,
        'chapter': stage.chapter,
        'checkpoint': director!.checkpoint,
        'stageIndex': director!.index,
        'stageCount': director!.stages.length,
      },
    });
    if (stage.clip == null) return;
    final clip = stage.clip!,
        curated = ['phoneme', 'group'].contains(units[clip]?['kind']);
    await _play(clip, stage.rate, curated: curated, stageToken: token);
  }

  Future<void> _play(
    String key,
    double rate, {
    bool curated = false,
    int? stageToken,
  }) async {
    final token = stageToken ?? ++stageGeneration,
        audioGeneration = ++speech.generation,
        expectedSession = session;
    loadingAudio = true;
    automatic.playing = true;
    emit('speech-loading', {'session': session});
    try {
      final clip = await speech.prepare(
        key,
        Map<String, dynamic>.from(timings[key] ?? {}),
        curated: curated,
      );
      if (disposed || token != stageGeneration || session != expectedSession) {
        return;
      }
      cues = clip.cues;
      currentClip = clip;
      playRate = rate;
      await speech.play(clip, rate, audioGeneration);
      if (disposed || token != stageGeneration || session != expectedSession) {
        return;
      }
      phaseStarted = now;
      loadingAudio = false;
      playingAudio = true;
      emit('playing', {
        'session': session,
        'iteration': iteration,
        'text': timings[key]?['text']?.toString() ?? '',
        'wordTimings': timings[key]?['wordTimings'] ?? [],
        'progress': 0,
      });
    } catch (e) {
      if (token == stageGeneration) {
        loadingAudio = false;
        playingAudio = false;
        emit('speech-error', {'session': session, 'message': e.toString()});
      }
    }
  }

  void _audioEnded() {
    playingAudio = false;
    automatic.playing = false;
    if (director != null) {
      if (director!.stage.options.isNotEmpty) return;
      if (director!.fruitCourse && ['support', 'success'].contains(phase)) {
        final token = stageGeneration, current = director;
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 900), () {
            if (disposed || token != stageGeneration || current != director) {
              return;
            }
            director!.advance();
            unawaited(_enterStage());
          }),
        );
        return;
      }
      director!.advance();
      if (director!.branch.isEmpty && previewReturn != null) {
        director!.branch = previewReturn!;
        previewReturn = null;
      }
      unawaited(_enterStage());
    } else if (mode == 'performance') {
      mode = 'idle';
      emit('ended', {'session': session, 'progress': 1});
    }
  }

  void tick(Duration elapsed, double dt) {
    if (!loaded || disposed) return;
    frameDt = dt.clamp(0.0, .06);
    final at = now;
    background.time = at;
    if (const bool.fromEnvironment('SCENE_DIAGNOSTICS')) {
      if (Uri.base.queryParameters['celebration'] == '1' &&
          at - background.started > 3.5) {
        background.celebrate(at);
      }
    }
    final speaking = playingAudio && !loadingAudio;
    motion.update(
      frameDt,
      cues: cues,
      audioTime: speech.seconds,
      rate: playRate,
      speaking: speaking,
    );
    final w = motion.weights;
    if (mode == 'performance') {
      teachingClip!
        ..weight = 1
        ..seek(speech.seconds.clamp(0.0, 9.999));
      emotionClip!.weight = 0;
      applyPerformanceFace(w, speech.seconds);
    } else if (mode == 'emotion') {
      final age = at - emotionStarted,
          total = emotionAll ? (12 - emotionIndex) * 6 : 6;
      if (age >= total) {
        mode = 'idle';
        emit('ended', {'session': session, 'progress': 1});
      } else {
        final index = emotionIndex + (emotionAll ? age ~/ 6 : 0);
        teachingClip!.weight = 0;
        emotionClip!
          ..weight = 1
          ..seek(index * 6 + age % 6);
        applyEmotionFace(w, emotionIds[index], age % 6);
      }
    } else {
      final age = at - phaseStarted;
      if (mode == 'story') {
        if (age >= 24) {
          mode = 'idle';
          emit('ended', {'session': session, 'progress': 1});
        }
        teachingClip!
          ..weight = 1
          ..seek(math.min(age, 18) / 18 * 9.999);
        emotionClip!.weight = 0;
        applyPerformanceFace(w, math.min(age, 18) / 18 * 9.999);
      } else if (director != null) {
        final p = loadingAudio ? 0.0 : progress;
        // Select one coherent authored gesture per thought; do not scrub or
        // loop the whole ten-second reel on each spoken word.
        teachingClip!
          ..weight = 1
          ..seek(lessonPoseTime(phase, age));
        emotionClip!.weight = 0;
        applyCourseFace(w, phase, p, age, director!.variation, director!.style);
        w['SmileLeft'] = math.min(w['SmileLeft']!, 1 - .78 * articulation(w));
        w['SmileRight'] = math.min(w['SmileRight']!, 1 - .78 * articulation(w));
      } else {
        teachingClip!.weight = 0;
        emotionClip!.weight = 0;
      }
    }
    if (at - lastProgress > .1 && mode != 'idle') {
      emit('progress', {
        'session': session,
        'progress': mode == 'emotion'
            ? ((at - emotionStarted) /
                      (emotionAll ? (12 - emotionIndex) * 6 : 6))
                  .clamp(0.0, 1.0)
            : mode == 'story'
            ? ((at - phaseStarted) / 24).clamp(0.0, 1.0)
            : progress,
        'time': speech.seconds,
        'speaking': playingAudio && !loadingAudio,
        'iteration': iteration,
      });
      lastProgress = at;
    }
    if (at - lastStats > 3) {
      final fps = frameMeter.fps(at);
      emit('stats', {
        'fps': double.parse(fps.toStringAsFixed(1)),
        'runtime': kIsWeb
            ? 'flutter_scene · WebGL2'
            : 'Flutter GPU · flutter_scene',
        'triangles': 425144,
        'morphCount': 52,
        'hairBones': secondary?.hair.length ?? 0,
        'hairPeakRadians': secondary?.hairPeak ?? 0,
        'quality': quality,
        'targetFps': targetFps,
        'renderScale': scene.renderScale * scene.adaptiveRenderScale,
        'sourceClock': 'audio playback position',
        'fpsSource': 'new scene draws, excluding held GPU frames',
        'modelBytes': 153334024,
      });
      lastStats = at;
    }
  }

  void applyProceduralPose(double dt) {
    if (!loaded) return;
    secondary?.update(
      dt.clamp(0.0, .06),
      motion.weights,
      speaking: playingAudio && !loadingAudio,
      engaged: mode != 'idle',
      emoting: mode == 'emotion',
      phase: phase,
      storyTime: mode == 'story' ? now - phaseStarted : null,
      stageElapsed: now - phaseStarted,
    );
    for (final node in meshes) {
      final names = node.morphTargetNames;
      if (names.isEmpty) continue;
      for (var i = 0; i < names.length; i++) {
        node.setMorphWeight(i, motion.weights[names[i]] ?? 0);
      }
    }
    highlights?.update(camera(), motion.weights);
    if (const bool.fromEnvironment('SCENE_DIAGNOSTICS')) {
      attachmentProbe?.sample();
    }
  }

  PerspectiveCamera camera() {
    final baseDistance = closeUp ? .78 : 1.68;
    final distance = baseDistance * math.max(1, .59 / (aspect * .55));
    return _TeachingCamera(distance, 1.64 - (distance - baseDistance) * .195);
  }

  void resetFrameSamples() {
    frameMeter.reset();
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(endedSubscription?.cancel());
    unawaited(automatic.dispose());
    unawaited(speech.dispose());
    if (presentStage == null) scene.dispose();
    super.dispose();
  }
}

final class _MeasuredScene extends Scene {
  _MeasuredScene(this.onRenderedFrame);
  final void Function() onRenderedFrame;
  @override
  void renderViews(
    List<RenderView> views,
    ui.Canvas canvas, {
    ui.Rect? region,
    double? pixelRatio,
  }) {
    final before = renderStats.frameCount;
    super.renderViews(views, canvas, region: region, pixelRatio: pixelRatio);
    final frame = renderStats.latest;
    if (renderStats.frameCount > before &&
        frame != null &&
        frame.views.any((view) => !view.offscreen && view.counters.draws > 0)) {
      onRenderedFrame();
    }
  }
}

class _PoseDriver extends Component {
  _PoseDriver(this.runtime);
  final SceneRuntime runtime;
  @override
  void tick(double dt) => runtime.applyProceduralPose(dt);
}

class _TeachingProjection extends PerspectiveProjection {
  _TeachingProjection()
    : super(fovRadiansY: 30 * math.pi / 180, near: .05, far: 12);
  @override
  vm.Matrix4 getProjectionMatrix(double aspectRatio, {vm.Vector2? jitter}) {
    final m = super.getProjectionMatrix(aspectRatio, jitter: jitter);
    m[8] -= .56;
    return m;
  }
}

class _TeachingCamera extends PerspectiveCamera {
  _TeachingCamera(double distance, double height)
    : super(
        position: vm.Vector3(.025, height, -distance),
        target: vm.Vector3(0, height - .02, 0),
      );
  @override
  PerspectiveProjection get projection => _TeachingProjection();
}
