import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';

class PermissionRecorder extends Fake implements AudioRecorder {
  final permission = Completer<bool>();
  final stream = StreamController<Uint8List>();
  bool blockCancellation = true, streamStarted = false;
  int cancellations = 0;
  @override
  Future<bool> hasPermission({bool request = true}) => permission.future;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    streamStarted = true;
    return stream.stream;
  }

  @override
  Future<void> cancel() {
    cancellations++;
    return blockCancellation ? Completer<void>().future : Future.value();
  }

  @override
  Future<void> dispose() async {
    unawaited(stream.close());
  }
}

void main() {
  test('unanswered permission never blocks switching lessons or starts a late capture', () async {
    final recorder = PermissionRecorder();
    final reader = AutomaticReader(
      (p) => Uri.parse('https://example.test$p'),
      (_, _) {},
      (_, _) {},
      audioRecorder: recorder,
    );
    final pending = reader.start();
    await Future<void>.delayed(Duration.zero);
    await reader.stop().timeout(const Duration(milliseconds: 200));
    expect(recorder.cancellations, 0);
    recorder.permission.complete(true);
    await pending;
    expect(recorder.streamStarted, false);
    expect(reader.enabled, false);
      await reader.dispose();
  });

  test(
    'switching lessons still cancels a microphone that really started',
    () async {
      final recorder = PermissionRecorder()..blockCancellation = false;
      recorder.permission.complete(true);
      final reader = AutomaticReader(
        (p) => Uri.parse('https://example.test$p'),
        (_, _) {},
        (_, _) {},
        audioRecorder: recorder,
      );
      await reader.start();
      expect(reader.enabled, true);
      await reader.stop();
      expect(recorder.cancellations, 1);
      expect(reader.enabled, false);
      await reader.dispose();
    },
  );
}
