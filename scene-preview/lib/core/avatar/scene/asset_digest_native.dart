import 'dart:typed_data';
import 'package:crypto/crypto.dart';

Future<String> assetDigest(Uint8List bytes) async {
  final result = _DigestSink();
  final hasher = sha256.startChunkedConversion(result);
  for (var start = 0; start < bytes.length; start += 4 * 1024 * 1024) {
    final end = (start + 4 * 1024 * 1024).clamp(0, bytes.length);
    hasher.add(Uint8List.sublistView(bytes, start, end));
    await Future<void>.delayed(Duration.zero);
  }
  hasher.close();
  return result.value!.toString();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
