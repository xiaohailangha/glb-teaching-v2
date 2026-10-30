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
import 'teaching_math.dart';
import 'scene_asset_bundle.dart';
import 'corneal_highlights.dart';
import 'rendered_frame_meter.dart';

class SceneRuntime extends ChangeNotifier {
  SceneRuntime(this.controller) {
    scene = _measuredScene();
    controller.attach(command);
    speech.onPlaybackError = (error) {
      playingAudio = false;
      emit('speech-error', {
        'session': session,
        'message': '语音播放失败，请再点击一次：$error',
      });
    };
  }
  final LessonController controller;
  late Scene scene;
  final frameMeter = RenderedFrameMeter();
  Scene _measuredScene() => _MeasuredScene(() {
    if (loaded && !disposed) frameMeter.record(now);
  });
  Node? model;
  final speech = SpeechClient(), motion = NaturalMotion();
  final stopwatch = Stopwatch()..start();
  final timings = <String, dynamic>{};
  Map<String, dynamic> units = {};
  SecondaryMotion? secondary;
  CornealHighlights? highlights;
  AnimationClip? teachingClip, emotionClip;
  List<Node> meshes = [];
  final faceSmoothed = <String, double>{};
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
      model!.scale = vm.Vector3.all(1.5);
      scene.add(model!);
      for (final file in [
        'timings',
        'teaching-prompts',
        'pronunciation-units',
        'course-prompts',
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
      final rig = jsonDecode(
        await rootBundle.loadString('assets/avatar/models/storm-rig.json'),
      ) as Map<String, dynamic>;
      secondary = SecondaryMotion(model!, rig);
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
      loading = '';
      emit('ready', {
        'triangles': 425144,
        'morphCount': 52,
        'modelBytes': 153334024,
        'speech': {'configured': speech.configured},
        'runtime': kIsWeb
            ? 'flutter_scene · WebGL2'
            : 'Flutter GPU · flutter_scene',
        'version': 'scene-0.2.0-r2',
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
    final gesture =
        [
          'play',
          'course',
          'pronunciation',
          'performance',
        ].contains(data['type'])
        ? speech.player.unlockFromGesture()
        : Future<void>.value();
    unawaited(_commandAfterGesture(data, gesture));
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
          notifyListeners();
        case 'focus':
          closeUp = c['closeUp'] == true;
        case 'stop':
          await stop();
        case 'play':
          await stop();
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
          session = c['session'] as int;
          word = 'apple';
          mode = 'course';
          director = TeachingDirector.apple(
            style: c['style']?.toString() ?? 'adult',
            rate: (c['rate'] as num? ?? 1).toDouble(),
            variation: visits++ % 3,
          );
          await _enterStage();
        case 'pronunciation':
          await stop();
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
          session = c['session'] as int;
          word = 'performance';
          mode = 'performance';
          phaseStarted = now;
          await _play('performance', 1, curated: true);
        case 'acting-story':
          await stop();
          session = c['session'] as int;
          mode = 'story';
          phaseStarted = now;
        case 'emotion':
          await stop();
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
        case 'capture-start':
          if (c['session'] != session ||
              !waiting ||
              !['listen', 'recall'].contains(phase)) {
            return;
          }
          await speech.startCapture(
            session: session,
            emit: emit,
            text: director?.word ?? word,
            mode: phase == 'recall' ? 'recognize' : 'assess',
          );
        case 'capture-stop':
          await speech.finishCapture(
            session: session,
            emit: emit,
            text: director?.word ?? word,
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
          faceSmoothed.clear();
          secondary = null;
          highlights = null;
          scene.dispose();
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
    await speech.stop();
  }

  Future<void> _enterStage() async {
    final stage = director!.stage, token = ++stageGeneration;
    speech.generation++;
    playingAudio = false;
    await speech.player.stop();
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
    phaseStarted = now;
    iteration = stage.iteration;
    emit('lesson-phase', {
      'session': session,
      'phase': stage.phase,
      'iteration': iteration,
      'symbol': stage.symbol,
      'course': director!.course,
      'step': stage.id,
      'text': stage.text,
      'options': stage.options,
      'hideAnswer': stage.hideAnswer,
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
    if (director != null) {
      director!.advance();
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
        final p = loadingAudio ? 0.0 : progress,
            pose = coursePose(
              phase,
              p,
              age,
              director!.variation,
              director!.style,
            );
        teachingClip!
          ..weight = 1 - pose.accent
          ..seek(pose.time);
        emotionClip!
          ..weight = pose.accent
          ..seek(pose.accentTime);
        applyCourseFace(w, phase, p, age, director!.variation, director!.style);
        for (final name in faceNames) {
          faceSmoothed[name] = damp(
            faceSmoothed[name] ?? w[name]!,
            w[name]!,
            12,
            frameDt,
          );
          w[name] = faceSmoothed[name]!;
        }
        w['SmileLeft'] = math.min(w['SmileLeft']!, 1 - .78 * articulation(w));
        w['SmileRight'] = math.min(w['SmileRight']!, 1 - .78 * articulation(w));
      } else {
        teachingClip!.weight = 0;
        emotionClip!.weight = 0;
      }
    }
    secondary?.restore();
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

  void applyProceduralPose() {
    if (!loaded) return;
    secondary?.update(
      frameDt,
      motion.weights,
      speaking: playingAudio && !loadingAudio,
      engaged: mode != 'idle',
      emoting: mode == 'emotion',
      phase: phase,
      storyTime: mode == 'story' ? now - phaseStarted : null,
    );
    for (final node in meshes) {
      final names = node.morphTargetNames;
      if (names.isEmpty) continue;
      for (var i = 0; i < names.length; i++) {
        if (names[i].startsWith('Gaze') && node.name.contains('eye')) continue;
        node.setMorphWeight(i, motion.weights[names[i]] ?? 0);
      }
    }
    highlights?.update(camera(), motion.weights);
  }

  PerspectiveCamera camera() {
    final baseDistance = closeUp ? .78 : 1.51;
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
    unawaited(speech.dispose());
    scene.dispose();
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
  void tick(double dt) => runtime.applyProceduralPose();
}

class _TeachingProjection extends PerspectiveProjection {
  _TeachingProjection()
    : super(fovRadiansY: 30 * math.pi / 180, near: .05, far: 12);
  @override
  vm.Matrix4 getProjectionMatrix(double aspectRatio, {vm.Vector2? jitter}) {
    final m = super.getProjectionMatrix(aspectRatio, jitter: jitter);
    m[8] -= .45;
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
