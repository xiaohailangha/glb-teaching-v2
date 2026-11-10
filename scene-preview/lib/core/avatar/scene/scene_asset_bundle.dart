import 'dart:convert';

import 'asset_digest.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../app_origin.dart';
import 'asset_cache.dart';

/// The same immutable cloud model contract is used on Web, Android and iOS.
class SceneAssetBundle extends CachingAssetBundle {
  SceneAssetBundle(this.onProgress);
  final void Function(int completed, int total) onProgress;
  final _clients = <http.Client>{};
  final _pending = <String, Future<ByteData>>{};
  bool _closed = false;
  void close() {
    _closed = true;
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
  }

  @override
  Future<ByteData> load(String key) {
    if (!key.startsWith('flutter_scene_generated/scene.storm-performance.') ||
        !key.endsWith('.fsceneb'))
      return rootBundle.load(key);
    if (_closed) return Future.error(StateError('人物加载已取消'));
    return _pending.putIfAbsent(
      key,
      () => _download().whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  Future<ByteData> _download() async {
    final client = http.Client();
    _clients.add(client);
    try {
      final response = await client
          .get(applicationOrigin.resolve('/api/assets/scene-manifest'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw StateError('人物资源暂时不可用，请重试');
      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      validateSceneManifest(manifest);
      final bytes = await downloadSceneParts(
        manifest,
        client: client,
        onProgress: (completed, total) {
          if (!_closed) onProgress(completed, total);
        },
      );
      if (_closed) throw StateError('人物加载已取消');
      return ByteData.sublistView(bytes);
    } finally {
      client.close();
      _clients.remove(client);
    }
  }
}

void validateSceneManifest(Map<String, dynamic> m) {
  final size = m['size'], chunk = m['chunkSize'], parts = m['parts'];
  if (m['version'] != 1 ||
      size is! int ||
      size <= 0 ||
      size > 220 * 1024 * 1024 ||
      chunk is! int ||
      chunk <= 0 ||
      chunk > 4 * 1024 * 1024 ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(m['revision']?.toString() ?? '') ||
      parts is! List ||
      parts.length != (size / chunk).ceil()) {
    throw const FormatException('Invalid scene asset manifest');
  }
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i], uri = Uri.tryParse(part['url']?.toString() ?? '');
    final expected = i == parts.length - 1 ? size - i * chunk : chunk;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        !RegExp(r'^glb-teaching-assets-\d+\.cos\.ap-beijing\.myqcloud\.com$')
            .hasMatch(uri.host) ||
        part['size'] != expected ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(part['sha256']?.toString() ?? '')) {
      throw const FormatException('Invalid scene asset part');
    }
  }
}

Future<Uint8List> downloadSceneParts(
  Map<String, dynamic> manifest, {
  required http.Client client,
  required void Function(int completed, int total) onProgress,
  Future<Uint8List?> Function(String key) cacheRead = readAssetPart,
  Future<void> Function(String key, Uint8List bytes) cacheWrite =
      writeAssetPart,
}) async {
  validateSceneManifest(manifest);
  final parts = manifest['parts'] as List,
      output = Uint8List(manifest['size'] as int);
  var next = 0, completed = 0;
  Future<void> worker() async {
    while (next < parts.length) {
      final index = next++, part = parts[index];
      final cacheKey = applicationOrigin
          .resolve('/scene/asset-cache/${manifest['revision']}/$index')
          .toString();
      Future<bool> valid(Uint8List? data) async =>
          data != null &&
          data.length == part['size'] &&
          await assetDigest(data) == part['sha256'];
      Uint8List? bytes;
      try {
        bytes = await cacheRead(cacheKey).timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!await valid(bytes)) {
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            final response = await client
                .get(Uri.parse(part['url'] as String))
                .timeout(const Duration(seconds: 30));
            if (response.statusCode != 200 || !await valid(response.bodyBytes)) {
              throw const FormatException('Scene asset integrity mismatch');
            }
            bytes = response.bodyBytes;
            break;
          } catch (_) {
            if (attempt == 2) rethrow;
          }
        }
        try {
          await cacheWrite(
            cacheKey,
            bytes!,
          ).timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
      output.setRange(
        index * (manifest['chunkSize'] as int),
        index * (manifest['chunkSize'] as int) + bytes!.length,
        bytes,
      );
      onProgress(++completed, parts.length);
      // Cache hits may all complete in microtasks. Yield so loading feedback,
      // taps and lifecycle changes remain responsive on a warm iPhone load.
      await Future<void>.delayed(Duration.zero);
    }
  }

  await Future.wait(List.generate(3, (_) => worker()));
  if (await assetDigest(output) != manifest['revision']) {
    throw const FormatException('Scene model revision mismatch');
  }
  return output;
}
