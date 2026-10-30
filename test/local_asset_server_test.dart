import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/local_asset_server.dart';

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/avatar/index.html') throw StateError('missing');
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode('bundled Storm')),
    );
  }
}

void main() {
  late HttpServer upstream;
  late LocalAssetServer assets;
  late HttpClient client;
  late Uri origin;
  late List<Map<String, Object?>> calls;

  setUp(() async {
    calls = [];
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      calls.add({
        'method': request.method,
        'uri': request.uri.toString(),
        'origin': request.headers.value('origin'),
        'body': body,
        'authorization': request.headers.value('authorization'),
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'configured': true,
          'audioUrl': '/api/speech/audio/${'a' * 64}.wav',
        }),
      );
      await request.response.close();
    });
    assets = LocalAssetServer(
      speechOrigin: Uri.parse('http://127.0.0.1:${upstream.port}'),
      bundle: _Assets(),
    );
    origin = await assets.start();
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await assets.close();
    await upstream.close(force: true);
  });

  test(
    'native assets stay bundled and speech uses only the configured backend',
    () async {
      final page = await (await client.getUrl(origin)).close();
      expect(await utf8.decoder.bind(page).join(), 'bundled Storm');
      final request = await client.postUrl(origin.resolve('/api/speech/tts'));
      request.headers.contentType = ContentType.json;
      request.headers.set('origin', origin.origin);
      request.headers.set('authorization', 'private-client-header');
      request.write('{"text":"apple"}');
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(
        (jsonDecode(await utf8.decoder.bind(response).join())
            as Map)['audioUrl'],
        startsWith('/api/speech/audio/'),
      );
      expect(calls.single['uri'], '/api/speech/tts');
      expect(calls.single['origin'], 'http://127.0.0.1:${upstream.port}');
      expect(calls.single['body'], '{"text":"apple"}');
      expect(calls.single['authorization'], isNull);
    },
  );

  test(
    'status and assessment query are forwarded without exposing a general proxy',
    () async {
      for (final path in [
        '/api/speech/status',
        '/api/speech/assess?text=I%20like%20apples.',
      ]) {
        final request = await client.openUrl(
          path.contains('assess') ? 'POST' : 'GET',
          origin.resolve(path),
        );
        final response = await request.close();
        expect(response.statusCode, 200);
        await response.drain<void>();
      }
      expect(calls[1]['uri'], '/api/speech/assess?text=I%20like%20apples.');
      final denied = await (await client.getUrl(
        origin.resolve('/api/assets/model-manifest'),
      )).close();
      expect(denied.statusCode, 404);
      await denied.drain<void>();
      expect(calls.length, 2);
    },
  );

  test(
    'cross-origin microphone spending and oversized audio are rejected locally',
    () async {
      final hostile = await client.postUrl(origin.resolve('/api/speech/tts'));
      hostile.headers.set('origin', 'https://example.org');
      final forbidden = await hostile.close();
      expect(forbidden.statusCode, 403);
      await forbidden.drain<void>();
      final oversized = await client.postUrl(
        origin.resolve('/api/speech/recognize'),
      );
      oversized.add(Uint8List(651 * 1024));
      final tooLarge = await oversized.close();
      expect(tooLarge.statusCode, 413);
      await tooLarge.drain<void>();
      expect(calls, isEmpty);
    },
  );
}
