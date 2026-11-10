import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/automatic_reader.dart';

void main() {
  test('formal utterance gate suppresses playback and sends one completed WAV to account evidence', () async {
    var calls = 0;
    final reader = AutomaticReader(
      (p) => Uri.parse('https://example.test$p'),
      (_, _) {},
      (_, _) => fail('must not use anonymous scoring'),
      onUtterance: (wav) async {
        calls++;
        expect(String.fromCharCodes(wav.take(4)), 'RIFF');
      },
    );
    final voiced = Uint8List(8000);
    final data = ByteData.sublistView(voiced);
    for (var i = 0; i < 8000; i += 2) {
      data.setInt16(i, 4000, Endian.little);
    }
    reader.enabled = true;
    reader.target('oral response', 'check');
    reader.playing = true;
    reader.ingestPcm(voiced);
    reader.ingestPcm(Uint8List(40000));
    expect(calls, 0);
    reader.playing = false;
    reader.ingestPcm(Uint8List(40000));
    expect(calls, 0);
    reader.ingestPcm(voiced);
    reader.ingestPcm(Uint8List(40000));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    reader.enabled = false;
    reader.ingestPcm(voiced);
    reader.ingestPcm(Uint8List(40000));
    expect(calls, 1);
    await reader.dispose();
  });
}
