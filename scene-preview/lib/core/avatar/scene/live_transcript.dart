import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Streams actual PCM while speaking; text is only supplied by ASR.
class LiveTranscript {
  LiveTranscript(this.endpoint, this.onText) {
    queue = _start();
  }
  final Uri Function(String) endpoint;
  final void Function(String) onText;
  final client = http.Client();
  late Future<void> queue;
  final buffer = BytesBuilder(copy: false);
  String id = '', text = '';
  bool cancelled = false, failed = false;
  Uri url(String action) =>
      endpoint('/api/speech/recognize?live=$action&id=$id');
  Future<void> _start() async {
    try {
      final r = await client
          .post(url('start'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) throw StateError('live unavailable');
      id = (jsonDecode(r.body) as Map)['id'] as String;
      if (cancelled) await _close();
    } catch (_) {
      failed = true;
    }
  }

  void add(Uint8List bytes) {
    if (cancelled || failed) return;
    buffer.add(bytes);
    if (buffer.length >= 6400) _flush();
  }

  void _flush() {
    if (buffer.isEmpty) return;
    final bytes = buffer.takeBytes();
    queue = queue.then((_) async {
      if (cancelled || failed) return;
      try {
        final r = await client
            .post(
              url('chunk'),
              headers: {'Content-Type': 'application/octet-stream'},
              body: bytes,
            )
            .timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) throw StateError('live unavailable');
        _accept(r.body);
      } catch (_) {
        failed = true;
      }
    });
  }

  void _accept(String body) {
    final data = jsonDecode(body) as Map;
    if (data['error'] != null) failed = true;
    if (!cancelled && data['text'] is String) {
      text = data['text'] as String;
      onText(text);
    }
  }

  Future<String> finish() async {
    _flush();
    await queue;
    if (!cancelled && !failed) {
      try {
        final r = await client
            .post(url('end'))
            .timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) _accept(r.body);
      } catch (_) {
        failed = true;
      }
    }
    await _close();
    client.close();
    return text;
  }

  Future<void> _close() async {
    if (id.isEmpty) return;
    try {
      await client.post(url('cancel')).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  void cancel() {
    cancelled = true;
    buffer.clear();
    unawaited(
      queue.then((_) async {
        await _close();
        client.close();
      }),
    );
  }
}
