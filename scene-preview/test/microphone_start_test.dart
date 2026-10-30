import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';

class DelayedRecorder implements AudioRecorder {
  final permission = Completer<bool>();
  int starts = 0;
  @override
  Future<bool> hasPermission({bool request = true}) => permission.future;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    starts++;
    return const Stream.empty();
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'normal lesson transitions do not cancel a pending microphone grant',
    () async {
      final recorder = DelayedRecorder();
      final reader = AutomaticReader(
        (p) => Uri.parse('https://example.test$p'),
        (_, _) {},
        (_, _) {},
        audioRecorder: recorder,
      );
      final pending = reader.start();
      await Future<void>.delayed(Duration.zero);
      reader.target('apple', 'apple_practice');
      recorder.permission.complete(true);
      await pending;
      expect(reader.enabled, isTrue);
      expect(recorder.starts, 1);
      await reader.dispose();
    },
  );
  test(
    'pausing during permission prompt prevents later microphone activation',
    () async {
      final recorder = DelayedRecorder();
      final reader = AutomaticReader(
        (p) => Uri.parse('https://example.test$p'),
        (_, _) {},
        (_, _) {},
        audioRecorder: recorder,
      );
      final pending = reader.start();
      await Future<void>.delayed(Duration.zero);
      await reader.stop();
      recorder.permission.complete(true);
      await pending;
      expect(reader.enabled, isFalse);
      expect(recorder.starts, 0);
      await reader.dispose();
    },
  );
}
