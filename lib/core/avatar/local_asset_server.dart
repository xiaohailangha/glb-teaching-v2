import 'dart:io';
import 'package:flutter/services.dart';

/// Serve bundled avatar assets on loopback only, avoiding file:// fetch restrictions.
class LocalAssetServer {
  LocalAssetServer({Uri? speechOrigin, AssetBundle? bundle})
    : _speechOrigin = speechOrigin ?? Uri.parse('https://49.233.179.83'),
      _bundle = bundle ?? rootBundle;

  final Uri _speechOrigin;
  final AssetBundle _bundle;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  HttpServer? _server;
  Future<Uri> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final localOrigin = 'http://127.0.0.1:${server.port}';
      if (request.headers.value(HttpHeaders.hostHeader) !=
              '127.0.0.1:${server.port}' ||
          (request.headers.value('origin') != null &&
              request.headers.value('origin') != localOrigin)) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      if (request.uri.path.startsWith('/api/')) {
        await _speech(request);
        return;
      }
      final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
      if (path.contains('..') || request.method != 'GET') {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      try {
        final bytes = await _bundle.load('assets/avatar$path');
        final mime = path.endsWith('.js')
            ? 'text/javascript'
            : path.endsWith('.html')
            ? 'text/html'
            : path.endsWith('.json')
            ? 'application/json'
            : path.endsWith('.glb')
            ? 'model/gltf-binary'
            : path.endsWith('.wav')
            ? 'audio/wav'
            : 'application/octet-stream';
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          '$mime; charset=utf-8',
        );
        request.response.contentLength = bytes.lengthInBytes;
        request.response.add(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } catch (_) {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });
    return Uri.parse('http://127.0.0.1:${server.port}/index.html');
  }

  Future<void> _speech(HttpRequest request) async {
    final path = request.uri.path;
    final allowedGet =
        path == '/api/speech/status' ||
        RegExp(r'^/api/speech/audio/[a-f0-9]{64}\.wav$').hasMatch(path);
    final allowedPost = const {
      '/api/speech/tts',
      '/api/speech/assess',
      '/api/speech/recognize',
    }.contains(path);
    if (!(request.method == 'GET' && allowedGet) &&
        !(request.method == 'POST' && allowedPost)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      final body = <int>[];
      await for (final chunk in request) {
        if (body.length + chunk.length > 650 * 1024) {
          request.response.statusCode = HttpStatus.requestEntityTooLarge;
          await request.response.close();
          return;
        }
        body.addAll(chunk);
      }
      final target = _speechOrigin.replace(
        path: path,
        query: path == '/api/speech/assess' ? request.uri.query : null,
      );
      final outgoing = await _client.openUrl(request.method, target);
      outgoing.followRedirects = false;
      outgoing.headers.set('origin', _speechOrigin.origin);
      final contentType = request.headers.contentType;
      if (contentType != null) {
        outgoing.headers.set(
          HttpHeaders.contentTypeHeader,
          contentType.toString(),
        );
      }
      outgoing.add(body);
      final upstream = await outgoing.close().timeout(
        const Duration(seconds: 100),
      );
      request.response.statusCode = upstream.statusCode;
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.headers.contentType = upstream.headers.contentType;
      await request.response.addStream(
        upstream.timeout(const Duration(seconds: 100)),
      );
    } catch (_) {
      request.response.statusCode = HttpStatus.badGateway;
    }
    await request.response.close();
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _client.close(force: true);
  }
}
