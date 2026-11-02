import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

File _file(String key) => File(
  '${Directory.systemTemp.path}/snow-speaks-assets/${sha256.convert(utf8.encode(key))}',
);
Future<Uint8List?> readAssetPart(String key) async {
  final file = _file(key);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> writeAssetPart(String key, Uint8List bytes) async {
  final file = _file(key);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}
