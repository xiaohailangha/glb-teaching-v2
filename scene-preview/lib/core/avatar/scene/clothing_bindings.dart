import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';

import 'secondary_motion.dart';

Future<void> repairClothingBindings(Node model) async {
  const prefix = 'assets/avatar/models/storm-clothing-bindings';
  final manifest = jsonDecode(await rootBundle.loadString('$prefix.json'));
  final data = await rootBundle.load('$prefix.bin');
  if (sha256
          .convert(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          )
          .toString() !=
      manifest['bindingsSha256']) {
    throw StateError('Clothing binding checksum mismatch');
  }
  final nodes = {for (final n in descendants(model)) n.name: n};
  for (final part in manifest['parts']) {
    final node = nodes[part['node']];
    if (node?.skin == null || node?.mesh == null) {
      throw StateError('Missing clothing skin');
    }
    final skin = node!.skin!,
        geometry = node.mesh!.primitives[part['primitive']].geometry;
    if (geometry is! SkinnedGeometry) {
      throw StateError('Clothing is not skinned');
    }
    final names = List<String>.from(manifest['jointNames']);
    final remap = [
      for (final name in names)
        skin.joints.indexWhere((joint) => joint?.name == name),
    ];
    if (remap.any((index) => index < 0)) {
      throw StateError('Clothing rig differs from source');
    }
    final count = part['vertices'] as int, offset = part['floatOffset'] as int;
    final bindings = Float32List(count * 8);
    for (var i = 0; i < bindings.length; i++) {
      final value = data.getFloat32((offset + i) * 4, Endian.little);
      bindings[i] = i % 8 < 4 ? remap[value.toInt()].toDouble() : value;
    }
    geometry.rebindSkin(bindings, skin.joints.length);
  }
}
