import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snow_speaks/core/avatar/scene/course_resources.dart';
import 'package:snow_speaks/features/lesson/domain/course_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'authenticated manifest pins a release and rejects corrupt course bytes',
    () async {
      final original = [...courseCatalog], types = [...courseTypes];
      addTearDown(() {
        courseCatalog
          ..clear()
          ..addAll(original);
        courseTypes
          ..clear()
          ..addAll(types);
      });
      final bytes = utf8.encode('{"stages":[]}');
      final resource = CourseResources(
        origin: Uri.parse('https://test.invalid'),
        client: MockClient((req) async {
          if (req.url.path == '/api/auth/content') {
            return http.Response(
              jsonEncode({
                'schema': 1,
                'id': 'a' * 64,
                'expiresAt': DateTime.now().millisecondsSinceEpoch + 3300000,
                'catalog': {
                  'courses': [
                    {
                      'id': 'adult-fruit-v2',
                      'status': 'published',
                      'asset': 'fruit',
                      'title': 'Fruit',
                      'goal': 'Start',
                    },
                  ],
                },
                'assets': [
                  {
                    'path': 'assets/avatar/courses/fruit.json',
                    'size': bytes.length,
                    'sha256': sha256.convert(bytes).toString(),
                    'url': 'https://glb-teaching-assets-123.cos.ap-beijing.myqcloud.com/fruit',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('corrupt', 200);
        }),
      );
      await resource.initialize();
      expect(resource.release, 'a' * 64);
      expect(courseCatalog.single.title, 'Fruit');
      await expectLater(
        resource.load('assets/avatar/courses/fruit.json'),
        throwsStateError,
      );
    },
  );
  test('cover download recovers from a transient transport failure', () async {
    final bytes = utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>');
    var requests = 0;
    final origin = Uri.parse(
      'https://cover-retry-${DateTime.now().microsecondsSinceEpoch}.invalid',
    );
    final resource = CourseResources(
      origin: origin,
      client: MockClient((_) async {
        requests++;
        if (requests == 1) throw http.ClientException('Failed to fetch');
        return http.Response.bytes(bytes, 200);
      }),
    );
    resource.release = 'b' * 64;
    resource.expiresAt = DateTime.now().millisecondsSinceEpoch + 3300000;
    resource.assets['assets/avatar/images/cover-food-01.svg'] = {
      'size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'url': 'https://glb-teaching-assets-123.cos.ap-beijing.myqcloud.com/cover-food-01.svg',
    };
    final cacheKey = origin
        .resolve(
          '/scene/course-cache/${resource.release}/${sha256.convert(bytes)}',
        )
        .toString();
    final cacheFile = File(
      '${Directory.systemTemp.path}/snow-speaks-assets/${sha256.convert(utf8.encode(cacheKey))}',
    );
    addTearDown(() async {
      if (await cacheFile.exists()) await cacheFile.delete();
    });
    final loaded = await resource.load(
      'assets/avatar/images/cover-food-01.svg',
    );
    expect(loaded.buffer.asUint8List(), bytes);
    expect(requests, 2);
    expect(resource.pending, isEmpty);
  });
  test('anonymous access does not complete course readiness', () async {
    final resource = CourseResources(
      origin: Uri.parse('https://test.invalid'),
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(resource.initialize(), throwsStateError);
    expect(resource.ready.isCompleted, false);
    expect(resource.release, isNull);
  });
}
