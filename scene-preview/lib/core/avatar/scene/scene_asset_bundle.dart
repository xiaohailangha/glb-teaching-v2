import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'asset_cache.dart';

/// Web delivery only. Native builds use their embedded, preprocessed model.
class SceneAssetBundle extends CachingAssetBundle {
  SceneAssetBundle(this.onProgress);
  final void Function(int completed, int total) onProgress;

  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('flutter_scene_generated/scene.storm-performance.') ||
        !key.endsWith('.fsceneb')) {
      return rootBundle.load(key);
    }
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.base.resolve('/api/assets/scene-manifest'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return await rootBundle.load(key);
      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      validateSceneManifest(manifest);
      final bytes = await downloadSceneParts(
        manifest,
        client: client,
        onProgress: onProgress,
      );
      return ByteData.sublistView(bytes);
    } catch (_) {
      debugPrint(
        'Scene cloud assets unavailable; using the same bundled model.',
      );
      return rootBundle.load(key);
    } finally {
      client.close();
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
      final cacheKey = Uri.base
          .resolve('/scene/asset-cache/${manifest['revision']}/$index')
          .toString();
      bool valid(Uint8List? data) =>
          data != null &&
          data.length == part['size'] &&
          sha256.convert(data).toString() == part['sha256'];
      Uint8List? bytes;
      try {
        bytes = await cacheRead(cacheKey);
      } catch (_) {}
      if (!valid(bytes)) {
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            final response = await client
                .get(Uri.parse(part['url'] as String))
                .timeout(const Duration(seconds: 30));
            if (response.statusCode != 200 || !valid(response.bodyBytes)) {
              throw const FormatException('Scene asset integrity mismatch');
            }
            bytes = response.bodyBytes;
            break;
          } catch (_) {
            if (attempt == 2) rethrow;
          }
        }
        try {
          await cacheWrite(cacheKey, bytes!);
        } catch (_) {}
      }
      output.setRange(
        index * (manifest['chunkSize'] as int),
        index * (manifest['chunkSize'] as int) + bytes!.length,
        bytes,
      );
      onProgress(++completed, parts.length);
    }
  }

  await Future.wait(List.generate(3, (_) => worker()));
  if (sha256.convert(output).toString() != manifest['revision']) {
    throw const FormatException('Scene model revision mismatch');
  }
  return output;
}
