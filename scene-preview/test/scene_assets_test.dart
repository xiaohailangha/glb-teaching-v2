import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snow_speaks/core/avatar/scene/scene_asset_bundle.dart';

void main() {
  final source = Uint8List.fromList(List.generate(2500, (i) => i % 251));
  Map<String, dynamic> fixture() => {
    'version': 1,
    'size': source.length,
    'chunkSize': 1024,
    'revision': sha256.convert(source).toString(),
    'parts': List.generate(3, (i) {
      final part = source.sublist(
        i * 1024,
        i == 2 ? source.length : (i + 1) * 1024,
      );
      return {
        'url':
            'https://glb-teaching-assets-123.cos.ap-beijing.myqcloud.com/part-$i?signature=first',
        'size': part.length,
        'sha256': sha256.convert(part).toString(),
      };
    }),
  };
  test(
    'scene parts verify bytes and reuse version cache after signed URLs renew',
    () async {
      final cache = <String, Uint8List>{};
      var requests = 0, progress = 0;
      final client = MockClient((request) async {
        requests++;
        final index = int.parse(request.url.path.split('-').last);
        return http.Response.bytes(
          source.sublist(
            index * 1024,
            index == 2 ? source.length : (index + 1) * 1024,
          ),
          200,
        );
      });
      Future<Uint8List> download(Map<String, dynamic> manifest) =>
          downloadSceneParts(
            manifest,
            client: client,
            onProgress: (done, total) {
              progress = done;
              expect(total, 3);
            },
            cacheRead: (key) async => cache[key],
            cacheWrite: (key, bytes) async {
              cache[key] = bytes;
            },
          );
      final manifest = fixture();
      expect(await download(manifest), source);
      expect(requests, 3);
      expect(progress, 3);
      final renewed = jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
      for (final part in renewed['parts']) {
        part['url'] = part['url'].replaceAll('first', 'renewed');
      }
      expect(await download(renewed), source);
      expect(requests, 3);
    },
  );
  test('corrupt or foreign model parts are rejected', () async {
    final manifest = fixture();
    await expectLater(
      downloadSceneParts(
        manifest,
        client: MockClient(
          (_) async => http.Response.bytes(Uint8List(1024), 200),
        ),
        onProgress: (_, _) {},
      ),
      throwsFormatException,
    );
    manifest['parts'][0]['url'] = 'https://example.org/model';
    expect(() => validateSceneManifest(manifest), throwsFormatException);
    expect(
      () => validateSceneManifest({...fixture(), 'size': 500 * 1024 * 1024}),
      throwsFormatException,
    );
  });
  test('unavailable browser cache does not block a validated model', () async {
    final client = MockClient((request) async {
      final i = int.parse(request.url.path.split('-').last);
      return http.Response.bytes(
        source.sublist(i * 1024, i == 2 ? source.length : (i + 1) * 1024),
        200,
      );
    });
    expect(
      await downloadSceneParts(
        fixture(),
        client: client,
        onProgress: (_, _) {},
        cacheRead: (_) async => throw StateError('quota'),
        cacheWrite: (_, _) async => throw StateError('quota'),
      ),
      source,
    );
  });
}
