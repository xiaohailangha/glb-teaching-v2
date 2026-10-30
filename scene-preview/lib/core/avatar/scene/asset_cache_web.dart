import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List?> readAssetPart(String key) async {
  try {
    final cache = await web.window.caches.open('glb-scene-parts-v1').toDart;
    final response = await cache.match(key.toJS).toDart;
    if (response == null) return null;
    return (await response.arrayBuffer().toDart).toDart.asUint8List();
  } catch (_) {
    return null;
  }
}

Future<void> writeAssetPart(String key, Uint8List bytes) async {
  try {
    final cache = await web.window.caches.open('glb-scene-parts-v1').toDart;
    await cache.put(key.toJS, web.Response(bytes.toJS)).toDart;
  } catch (_) {
    /* Private browsing or quota limits must not block loading. */
  }
}
