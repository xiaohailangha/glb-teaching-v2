import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'teaching_math.dart';
import 'speech_player.dart';

class SpeechClip {
  SpeechClip(this.path, this.cues, {this.remote = false});
  final String path;
  final List<MouthCue> cues;
  final bool remote;
}

class SpeechClient {
  final SpeechPlayer player = SpeechPlayer();
  void Function(Object error)? onPlaybackError;
  final http.Client client = http.Client();
  AudioRecorder? _recorder;
  final cache = <String, SpeechClip>{};
  final Uri origin = kIsWeb
      ? Uri.base.replace(path: '', query: '', fragment: '')
      : Uri.parse('https://49.233.179.83');
  bool configured = false;
  int generation = 0;
  Timer? _limit;
  StreamSubscription<Uint8List>? _capture;
  BytesBuilder? _pcm;
  Completer<void>? _captureDone;
  int? recordingSession;
  bool finishing = false;
  Uri endpoint(String path) => origin.resolve(path);
  Future<void> init() async {
    unawaited(
      player.preloadAssets([
        for (final word in [
          'apple',
          'banana',
          'cat',
          'dog',
          'fish',
          'moon',
          'sun',
          'book',
          'hello',
          'thank',
        ])
          'assets/avatar/audio/$word.wav',
      ]),
    );
    try {
      final r = await client
          .get(endpoint('/api/speech/status'))
          .timeout(const Duration(seconds: 15));
      configured =
          r.statusCode == 200 && jsonDecode(r.body)['configured'] == true;
    } catch (_) {
      configured = false;
    }
  }

  Future<SpeechClip> prepare(
    String key,
    Map<String, dynamic> item, {
    bool curated = false,
  }) async {
    if (item['bundled'] == true &&
        (item['voice'] == 403008 || item['reference'] == true)) {
      return SpeechClip(key, MouthCue.fromJson(item['cues'], word: key));
    }
    if (curated || !configured || item['text'] == null) {
      throw StateError('同声线示范音频尚未准备好');
    }
    final text = item['text'].toString(),
        language = RegExp(r'[\u3400-\u9fff]').hasMatch(text) ? 'zh' : 'en';
    final cacheKey = '403008:$language:$text';
    if (cache.containsKey(cacheKey)) return cache[cacheKey]!;
    final response = await client
        .post(
          endpoint('/api/speech/tts'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'language': language,
            'voice': 403008,
            'speed': 0,
          }),
        )
        .timeout(const Duration(seconds: 100));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || data['usable'] != true) {
      throw StateError(data['error']?.toString() ?? '语音或口型时间数据不可用');
    }
    final path = data['audioUrl']?.toString() ?? '';
    if (!RegExp(r'^/api/speech/audio/[a-f0-9]{64}\.wav$').hasMatch(path)) {
      throw StateError('无效的语音地址');
    }
    return cache[cacheKey] = SpeechClip(
      endpoint(path).toString(),
      MouthCue.fromJson(data['cues']),
      remote: true,
    );
  }

  Future<void> play(SpeechClip clip, double rate, int token) async {
    if (token != generation) return;
    if (clip.remote) {
      await player.setUrl(clip.path);
    } else {
      await player.setAsset('assets/avatar/audio/${clip.path}.wav');
    }
    if (token != generation) return;
    await player.setSpeed(rate);
    if (token != generation) return;
    final playback = player.play();
    if (kIsWeb) {
      // The browser promise resolves when sound starts, so mouth motion must
      // wait for it instead of animating while a new clip is buffering.
      await playback;
    } else {
      // just_audio's native Future completes when playback ends or pauses.
      unawaited(
        playback.catchError((Object error) {
          if (token == generation) onPlaybackError?.call(error);
        }),
      );
    }
  }

  Future<void> stop() async {
    generation++;
    await player.stop();
    await cancelCapture();
  }

  double get seconds => player.position.inMicroseconds / 1e6;
  double get duration => (player.duration?.inMicroseconds ?? 0) / 1e6;
  Future<void> startCapture({
    required int session,
    required void Function(String, Map<String, dynamic>) emit,
    required String text,
    required String mode,
  }) async {
    await cancelCapture();
    final token = generation;
    recordingSession = session;
    finishing = false;
    final recorder = _recorder ??= AudioRecorder();
    try {
      if (!await recorder.hasPermission()) throw StateError('请允许使用麦克风后再试');
      if (recordingSession != session || token != generation) return;
      _pcm = BytesBuilder(copy: false);
      _captureDone = Completer<void>();
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      if (recordingSession != session || token != generation) {
        await recorder.cancel();
        return;
      }
      _capture = stream.listen(
        (bytes) {
          if (recordingSession == session) _pcm?.add(bytes);
        },
        onDone: () {
          if (!(_captureDone?.isCompleted ?? true)) _captureDone!.complete();
        },
      );
      emit('capture', {'session': session, 'state': 'recording', 'mode': mode});
      _limit = Timer(
        const Duration(seconds: 15),
        () =>
            finishCapture(session: session, emit: emit, text: text, mode: mode),
      );
    } catch (e) {
      if (recordingSession == session) {
        await cancelCapture();
        emit('capture', {
          'session': session,
          'state': 'error',
          'message': e.toString(),
        });
      }
    }
  }

  Future<void> finishCapture({
    required int session,
    required void Function(String, Map<String, dynamic>) emit,
    required String text,
    required String mode,
  }) async {
    if (recordingSession != session || finishing) return;
    finishing = true;
    _limit?.cancel();
    try {
      await _recorder?.stop();
      await _captureDone?.future.timeout(const Duration(seconds: 2));
      if (recordingSession != session) return;
      final pcm = _pcm?.takeBytes() ?? Uint8List(0);
      _pcm = null;
      if (pcm.length < 8000) throw StateError('录音太短，请再试一次');
      emit('capture', {
        'session': session,
        'state': 'processing',
        'mode': mode,
      });
      final path = mode == 'recognize'
          ? '/api/speech/recognize'
          : '/api/speech/assess?text=${Uri.encodeComponent(text)}';
      final response = await client
          .post(
            endpoint(path),
            headers: {'Content-Type': 'audio/wav'},
            body: pcmToWav(pcm),
          )
          .timeout(const Duration(seconds: 100));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (recordingSession != session) return;
      if (response.statusCode != 200) {
        throw StateError(data['error']?.toString() ?? '语音处理失败');
      }
      recordingSession = null;
      emit('capture', {
        'session': session,
        'state': 'done',
        'mode': mode,
        ...data,
      });
    } catch (e) {
      if (recordingSession == session) {
        recordingSession = null;
        emit('capture', {
          'session': session,
          'state': 'error',
          'message': e.toString(),
        });
      }
    }
  }

  Future<void> cancelCapture() async {
    recordingSession = null;
    _limit?.cancel();
    _pcm = null;
    finishing = false;
    await _recorder?.cancel();
    await _capture?.cancel();
    _capture = null;
    if (!(_captureDone?.isCompleted ?? true)) _captureDone!.complete();
    _captureDone = null;
  }

  Future<void> dispose() async {
    generation++;
    await cancelCapture();
    await _recorder?.dispose();
    await player.dispose();
    client.close();
  }
}

Uint8List pcmToWav(Uint8List pcm) {
  final out = Uint8List(44 + pcm.length), v = ByteData.sublistView(out);
  void text(int at, String s) {
    out.setAll(at, ascii.encode(s));
  }

  text(0, 'RIFF');
  v.setUint32(4, 36 + pcm.length, Endian.little);
  text(8, 'WAVEfmt ');
  v.setUint32(16, 16, Endian.little);
  v.setUint16(20, 1, Endian.little);
  v.setUint16(22, 1, Endian.little);
  v.setUint32(24, 16000, Endian.little);
  v.setUint32(28, 32000, Endian.little);
  v.setUint16(32, 2, Endian.little);
  v.setUint16(34, 16, Endian.little);
  text(36, 'data');
  v.setUint32(40, pcm.length, Endian.little);
  out.setAll(44, pcm);
  return out;
}
