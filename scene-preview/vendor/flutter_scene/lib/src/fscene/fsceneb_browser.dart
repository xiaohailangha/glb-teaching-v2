import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:archive/archive.dart';
import 'package:scene/scene.dart';
import 'fsceneb_yielding.dart';

Future<SceneDocument> readFscenebBrowser(Uint8List bytes) =>
    readFscenebYielding(bytes, inflate: _inflate);

Future<Uint8List> _inflate(Uint8List bytes) async {
  try {
    // Safari/Chromium implement this in the browser, without a long Dart gzip
    // loop blocking input and the loading UI on the main thread.
    final decoder = web.DecompressionStream('gzip');
    final stream = web.Blob([bytes.toJS].toJS).stream().pipeThrough(
      web.ReadableWritablePair(
        readable: decoder.readable,
        writable: decoder.writable,
      ),
    );
    return (await web.Response(
      stream,
    ).arrayBuffer().toDart).toDart.asUint8List();
  } catch (_) {
    // Older browsers still receive the same validated container, chunk by chunk.
    return Uint8List.fromList(const GZipDecoder().decodeBytes(bytes));
  }
}
