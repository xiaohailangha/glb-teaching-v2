import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../auth/auth_api.dart';

/// Only the selected lesson is fetched; its version and bytes are pinned.
Future<Map<String, dynamic>> loadCloudLesson(
  AuthApi api,
  String course,
  String release,
) async {
  final descriptor = await api.request(
    'learning/curriculum/course?course=$course&release=$release',
  );
  if (descriptor['release'] != release || descriptor['course'] != course) {
    throw const FormatException('课程版本不一致');
  }
  final inline = descriptor['inlineDocument'];
  if (inline != null) {
    if (inline is! Map ||
        inline['base64'] is! String ||
        (inline['base64'] as String).length > 2700000 ||
        inline['size'] is! int ||
        inline['size'] < 0 ||
        inline['size'] > 2000000) {
      throw const FormatException('课程修订资源无效');
    }
    final bytes = base64Decode(inline['base64'] as String);
    if (bytes.length != inline['size'] ||
        sha256.convert(bytes).toString() != inline['sha256']) {
      throw const FormatException('课程修订校验失败');
    }
    return _document(bytes, course);
  }
  final resource = descriptor['resource'] as Map;
  final uri = Uri.parse(resource['url'] as String);
  if (uri.scheme != 'https' ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      uri.host !=
          'glb-teaching-assets-1252505198.cos.ap-beijing.myqcloud.com' ||
      !uri.path.startsWith('/courses/releases/$release/runtime/lessons/') ||
      resource['size'] is! int ||
      resource['size'] > 2000000) {
    throw const FormatException('课程资源无效');
  }
  final response = await api.client
      .get(uri)
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200 ||
      response.bodyBytes.length != resource['size'] ||
      sha256.convert(response.bodyBytes).toString() != resource['sha256']) {
    throw const FormatException('课程内容校验失败');
  }
  return _document(response.bodyBytes, course);
}

Map<String, dynamic> _document(List<int> bytes, String course) {
  final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  if (document['schema'] != 'snow-speaks.cloud-lesson/1' ||
      document['lesson']['courseId'] != course) {
    throw const FormatException('课程内容与课号不一致');
  }
  return document;
}
