import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snow_speaks/core/avatar/scene/asset_digest.dart';
import 'package:snow_speaks/core/avatar/scene/scene_asset_bundle.dart';

void main() {
  test('SHA-256 preserves exact typed-array slice boundaries', () async {
    final bytes = Uint8List.fromList(utf8.encode('_abc_'));
    expect(await assetDigest(Uint8List.sublistView(bytes, 1, 4)),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(await assetDigest(Uint8List(0)),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  });

  final bytes = Uint8List.fromList([1, 2, 3, 4]);
  Map<String, dynamic> manifest() => {
    'version': 1, 'size': 4, 'chunkSize': 4,
    'revision': sha256.convert(bytes).toString(),
    'parts': [{'url': 'https://glb-teaching-assets-123.cos.ap-beijing.myqcloud.com/test',
      'size': 4, 'sha256': sha256.convert(bytes).toString()}],
  };
  test('corrupt cached model part is fetched and verified again', () async {
    var requests = 0, writes = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response.bytes(bytes, 200);
    });
    addTearDown(client.close);
    final result = await downloadSceneParts(manifest(), client: client,
      onProgress: (_, _) {},
      cacheRead: (_) async => Uint8List.fromList([4, 3, 2, 1]),
      cacheWrite: (_, value) async { expect(value, bytes); writes++; });
    expect(result, bytes);
    expect(requests, 1);
    expect(writes, 1);
  });
  test('valid cached parts still require matching assembled revision', () async {
    final client = MockClient((_) async => throw StateError('Unexpected download'));
    addTearDown(client.close);
    final invalid = manifest()..['revision'] = '0' * 64;
    await expectLater(downloadSceneParts(invalid, client: client,
      onProgress: (_, _) {}, cacheRead: (_) async => bytes),
      throwsFormatException);
  });
}
