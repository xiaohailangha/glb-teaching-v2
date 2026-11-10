import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

// Use the browser's asynchronous SHA-256 implementation. Both cached parts
// and the assembled model still undergo the same integrity checks.
Future<String> assetDigest(Uint8List bytes) async {
  final result = await web.window.crypto.subtle
      .digest('SHA-256'.toJS, bytes.toJS)
      .toDart;
  return (result as JSArrayBuffer).toDart.asUint8List()
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
