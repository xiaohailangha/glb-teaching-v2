import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'speech_client.dart' show pcmToWav;

/// Local endpoint detector. No speech/no target means no upload.
class UtteranceGate {
  BytesBuilder buffer = BytesBuilder(copy: false);
  Uint8List lead = Uint8List(0);
  int voiced = 0, quiet = 0, total = 0;
  void reset() {
    buffer = BytesBuilder(copy: false);
    lead = Uint8List(0);
    voiced = quiet = total = 0;
  }

  Uint8List? add(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    double sum = 0;
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final v = data.getInt16(i, Endian.little) / 32768;
      sum += v * v;
    }
    final speech =
        bytes.isNotEmpty && math.sqrt(sum / (bytes.length / 2)) > .018;
    if (voiced == 0 && !speech) {
      lead = bytes.length <= 6400
          ? Uint8List.fromList(bytes)
          : Uint8List.fromList(bytes.sublist(bytes.length - 6400));
      return null;
    }
    if (voiced == 0) buffer.add(lead);
    buffer.add(bytes);
    total += bytes.length;
    if (speech) {
      voiced += bytes.length;
      quiet = 0;
    } else {
      quiet += bytes.length;
    }
    if ((voiced >= 6400 && quiet >= 25600) || total >= 384000) {
      final out = buffer.takeBytes();
      final enough = voiced >= 6400;
      reset();
      return enough ? out : null;
    }
    if (quiet >= 32000) reset();
    return null;
  }
}

class AutomaticReader {
  AutomaticReader(
    this.endpoint,
    this.onState,
    this.onResult, {
    http.Client? httpClient,
  }) : client = httpClient ?? http.Client();
  final Uri Function(String) endpoint;
  final void Function(String, String) onState;
  final void Function(String, Map<String, dynamic>) onResult;
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  final gate = UtteranceGate();
  final http.Client client;
  StreamSubscription<Uint8List>? subscription;
  bool enabled = false, playing = false, busy = false;
  String text = '', key = '';
  int generation = 0, requestGeneration = 0;
  void target(String nextText, String nextKey) {
    if (nextKey != key || nextText != text) {
      generation++;
      gate.reset();
    }
    text = nextText;
    key = nextKey;
  }

  Future<void> start() async {
    await stop();
    final token = ++generation;
    try {
      if (!await recorder.hasPermission()) throw StateError('请允许麦克风权限后再开启');
      if (token != generation) return;
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      if (token != generation) {
        await recorder.cancel();
        return;
      }
      enabled = true;
      subscription = stream.listen(
        ingestPcm,
        onError: (Object e) {
          enabled = false;
          onState('error', '麦克风中断，请重新开启');
          unawaited(stop());
        },
      );
      onState('listening', '自动跟读已开启；说完稍停即可收到反馈。');
    } catch (e) {
      onState('error', e.toString());
      await stop();
    }
  }

  void ingestPcm(Uint8List bytes) {
    if (!enabled || busy || text.isEmpty || playing) {
      gate.reset();
      return;
    }
    final pcm = gate.add(bytes);
    if (pcm != null) unawaited(_assess(pcm));
  }

  Future<void> _assess(Uint8List pcm) async {
    final token = generation, expectedKey = key, expectedText = text;
    final request = ++requestGeneration;
    busy = true;
    onState('processing', '正在分析刚才这句话…');
    try {
      final response = await client
          .post(
            endpoint(
              '/api/speech/assess?text=${Uri.encodeComponent(expectedText)}',
            ),
            headers: {'Content-Type': 'audio/wav'},
            body: pcmToWav(pcm),
          )
          .timeout(const Duration(seconds: 30));
      if (!enabled || token != generation || expectedKey != key) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw StateError(data['error']?.toString() ?? '暂时无法分析');
      }
      onResult(expectedText, data);
    } catch (e) {
      if (enabled && token == generation) onState('error', '这次没有取得可靠结果，请再试一次。');
    } finally {
      if (request == requestGeneration) {
        busy = false;
        gate.reset();
      }
    }
  }

  Future<void> stop() async {
    enabled = false;
    generation++;
    requestGeneration++;
    busy = false;
    gate.reset();
    await subscription?.cancel();
    subscription = null;
    await _recorder?.cancel();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder?.dispose();
    client.close();
  }
}
