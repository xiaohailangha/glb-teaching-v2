import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../features/lesson/domain/course_catalog.dart';
import '../../../features/lesson/domain/course_lexicon.dart';
import 'asset_cache.dart';

/// One immutable course release per app session; signatures may be renewed.
class CourseResources extends CachingAssetBundle {
  CourseResources({http.Client? client, Uri? origin})
    : client = client ?? http.Client(),
      origin = origin ?? Uri.base;
  static final instance = CourseResources();
  final http.Client client;
  final Uri origin;
  final ready = Completer<void>();
  final Map<String, Map<String, dynamic>> assets = {};
  final Map<String, Future<ByteData>> pending = {};
  String? release, preview;
  int expiresAt = 0;
  Future<void>? refreshing;

  Future<void> initialize({String? previewToken}) async {
    if (release != null) return;
    preview = previewToken;
    await _refresh();
    if (!ready.isCompleted) ready.complete();
  }

  Future<void> _refresh() =>
      refreshing ??= _fetchManifest().whenComplete(() => refreshing = null);
  Future<void> _fetchManifest() async {
    final uri = origin
        .resolve('/api/auth/content')
        .replace(
          queryParameters: {
            'release': ?release,
            'preview': ?preview,
          },
        );
    final response = await client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw StateError('课程加载未完成，请重试');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['schema'] != 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['id']?.toString() ?? '') ||
        (release != null && data['id'] != release)) {
      throw const FormatException('课程版本不一致');
    }
    final next = <String, Map<String, dynamic>>{};
    for (final raw in data['assets'] as List) {
      final asset = Map<String, dynamic>.from(raw as Map),
          url = Uri.parse(asset['url'] as String);
      if (!RegExp(
            r'^assets/avatar/(audio|images|courses)/[a-zA-Z0-9_.-]+\.(json|wav|svg|txt)$',
          ).hasMatch(asset['path'] as String) ||
          url.scheme != 'https' ||
          url.userInfo.isNotEmpty ||
          url.port != 443 ||
          !RegExp(r'^glb-teaching-assets-\d+\.cos\.ap-beijing\.myqcloud\.com$')
              .hasMatch(url.host) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(asset['sha256'] as String) ||
          asset['size'] is! int ||
          asset['size'] < 0 ||
          asset['size'] > 20000000 ||
          next.containsKey(asset['path'])) {
        throw const FormatException('课程资源无效');
      }
      next[asset['path'] as String] = asset;
    }
    final catalog = Map<String, dynamic>.from(data['catalog'] as Map);
    if (release == null) {
      installCourseLexicon(catalog);
      installCourseCatalog(catalog);
    }
    assets
      ..clear()
      ..addAll(next);
    release = data['id'] as String;
    expiresAt = data['expiresAt'] as int;
  }

  bool handles(String key) =>
      RegExp(r'^assets/avatar/(audio|images|courses)/').hasMatch(key);
  @override
  Future<ByteData> load(String key) {
    if (!handles(key) || release == null) return rootBundle.load(key);
    return pending.putIfAbsent(
      key,
      () => _load(key).whenComplete(() { pending.remove(key); }),
    );
  }

  Future<ByteData> _load(String key) async {
    final asset = assets[key];
    if (asset == null) throw StateError('当前版本缺少资源：$key');
    final cacheKey = origin
        .resolve('/scene/course-cache/$release/${asset['sha256']}')
        .toString();
    bool valid(Uint8List? bytes) =>
        bytes != null &&
        bytes.length == asset['size'] &&
        sha256.convert(bytes).toString() == asset['sha256'];
    Uint8List? bytes;
    try {
      bytes = await readAssetPart(cacheKey);
    } catch (_) {}
    if (!valid(bytes)) {
      if (expiresAt < DateTime.now().millisecondsSinceEpoch + 60000) {
        await _refresh();
      }
      // A transient connection failure must not leave a visible cover blank.
      // Only transport failures are retried; integrity failures remain fatal.
      late http.Response response;
      for (var attempt = 0; ; attempt++) {
        try {
          response = await client
              .get(Uri.parse(assets[key]!['url'] as String))
              .timeout(const Duration(seconds: 30));
          break;
        } on Exception {
          if (attempt >= 2) rethrow;
          await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
        }
      }
      if (response.statusCode != 200 || !valid(response.bodyBytes)) {
        throw StateError('课程资源校验失败，请重试');
      }
      bytes = response.bodyBytes;
      try {
        await writeAssetPart(cacheKey, bytes);
      } catch (_) {}
    }
    return ByteData.sublistView(bytes!);
  }
}
