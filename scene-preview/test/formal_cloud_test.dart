import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snow_speaks/features/auth/auth_api.dart';
import 'package:snow_speaks/features/lesson/application/cloud_lesson.dart';
import 'package:snow_speaks/core/avatar/scene/scene_asset_bundle.dart';

void main() {
  test('public model load completes and coalesces simultaneous requests', () async {
    final bytes = Uint8List.fromList([3, 1, 4, 15, 9]);
    final digest = sha256.convert(bytes).toString();
    final cacheKey = 'https://49.233.179.83/scene/asset-cache/$digest/0';
    final cacheFile = File(
      '${Directory.systemTemp.path}/snow-speaks-assets/${sha256.convert(utf8.encode(cacheKey))}',
    );
    if (await cacheFile.exists()) await cacheFile.delete();
    addTearDown(() async {
      if (await cacheFile.exists()) await cacheFile.delete();
    });
    var manifests = 0, parts = 0;
    final client = MockClient((r) async {
      if (r.url.path == '/api/assets/scene-manifest') {
        manifests++;
        return http.Response(
          jsonEncode({
            'version': 1,
            'size': bytes.length,
            'chunkSize': 1048576,
            'revision': digest,
            'parts': [
              {
                'size': bytes.length,
                'sha256': digest,
                'url':
                    'https://glb-teaching-assets-1252505198.cos.ap-beijing.myqcloud.com/models/scene-storm/$digest/part-0.bin',
              },
            ],
          }),
          200,
        );
      }
      parts++;
      return http.Response.bytes(bytes, 200);
    });
    await http.runWithClient(() async {
      final bundle = SceneAssetBundle((_, _) {});
      addTearDown(bundle.close);
      const key =
          'flutter_scene_generated/scene.storm-performance.test.fsceneb';
      final first = bundle.load(key), second = bundle.load(key);
      expect(identical(first, second), isTrue);
      final results = await Future.wait([first, second])
          .timeout(const Duration(seconds: 5));
      expect(results[0].buffer.asUint8List(), bytes);
      expect(results[1].buffer.asUint8List(), bytes);
      expect(manifests, 1);
      expect(parts, 1);
    }, () => client);
  });
  const release =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const course = 'N26-U001-L01';
  test('revised inline lesson uses checked bytes and never falls back to retired cloud content', () async {
    final bytes = utf8.encode(
      jsonEncode({
        'schema': 'snow-speaks.cloud-lesson/1',
        'lesson': {'courseId': course, 'steps': []},
      }),
    );
    var changedHash = false, requests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'release': release,
            'course': course,
            'inlineDocument': {
              'base64': base64Encode(bytes),
              'size': bytes.length,
              'sha256': changedHash
                  ? release
                  : sha256.convert(bytes).toString(),
            },
          }),
          200,
        );
      }),
      origin: Uri.parse('https://app.example'),
    );
    addTearDown(api.dispose);
    expect(
      (await loadCloudLesson(api, course, release))['lesson']['steps'],
      isEmpty,
    );
    expect(requests, 1);
    changedHash = true;
    await expectLater(
      loadCloudLesson(api, course, release),
      throwsFormatException,
    );
    expect(requests, 2);
  });
  test('selected Chinese lesson uses UTF8 byte count and rejects a changed hash', () async {
    final bytes = utf8.encode(
      jsonEncode({
        'schema': 'snow-speaks.cloud-lesson/1',
        'lesson': {'courseId': course, 'title': '苹果与香蕉'},
      }),
    );
    var badHash = false;
    final client = MockClient((request) async {
      if (request.url.path.startsWith('/api/')) {
        return http.Response(
          jsonEncode({
            'release': release,
            'course': course,
            'resource': {
              'url':
                  'https://glb-teaching-assets-1252505198.cos.ap-beijing.myqcloud.com/courses/releases/$release/runtime/lessons/$course.json',
              'size': bytes.length,
              'sha256': badHash ? release : sha256.convert(bytes).toString(),
            },
          }),
          200,
        );
      }
      return http.Response.bytes(bytes, 200);
    });
    final api = AuthApi(
      client: client,
      origin: Uri.parse('https://app.example'),
    );
    expect(
      (await loadCloudLesson(api, course, release))['lesson']['title'],
      '苹果与香蕉',
    );
    badHash = true;
    await expectLater(
      loadCloudLesson(api, course, release),
      throwsFormatException,
    );
  });
  test(
    'selected lesson rejects another session release before downloading data',
    () async {
      var requests = 0;
      final api = AuthApi(
        client: MockClient((r) async {
          requests++;
          return http.Response(
            jsonEncode({'release': 'other', 'course': course}),
            200,
          );
        }),
        origin: Uri.parse('https://app.example'),
      );
      await expectLater(
        loadCloudLesson(api, course, release),
        throwsFormatException,
      );
      expect(requests, 1);
    },
  );
  test('cloud model validates cold bytes and reuses verified warm cache without requests', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]),
        digest = sha256.convert([1, 2, 3, 4]).toString();
    final manifest = {
      'version': 1,
      'size': 4,
      'chunkSize': 1048576,
      'revision': digest,
      'parts': [
        {
          'size': 4,
          'sha256': digest,
          'url':
              'https://glb-teaching-assets-1252505198.cos.ap-beijing.myqcloud.com/models/scene-storm/$digest/part-0.bin',
        },
      ],
    };
    final cache = <String, Uint8List>{};
    var requests = 0;
    final client = MockClient((r) async {
      requests++;
      return http.Response.bytes(bytes, 200);
    });
    Future<Uint8List> load() => downloadSceneParts(
      manifest,
      client: client,
      onProgress: (_, _) {},
      cacheRead: (key) async => cache[key],
      cacheWrite: (key, data) async {
        cache[key] = data;
      },
    );
    expect(await load(), bytes);
    expect(requests, 1);
    expect(await load(), bytes);
    expect(requests, 1);
    final corrupt = Uint8List.fromList([4, 3, 2, 1]);
    cache.updateAll((key, value) => corrupt);
    expect(await load(), bytes);
    expect(requests, 2);
  });
}
