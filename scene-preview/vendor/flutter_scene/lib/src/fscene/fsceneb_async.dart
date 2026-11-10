import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:scene/scene.dart';
import 'fsceneb_browser_stub.dart'
    if (dart.library.js_interop) 'fsceneb_browser.dart';

/// Parses a `.fsceneb` container from [bytes] on a background isolate.
///
/// The asynchronous counterpart of [readFsceneb]. Payload chunks are gzipped,
/// so a texture-heavy container can take hundreds of milliseconds to inflate;
/// this keeps that off the calling isolate's frames. Only [bytes] is copied in,
/// and the parsed document is transferred back rather than copied.
///
/// Web uses browser gzip decoding and yields between chunks instead of
/// running the synchronous decoder on the UI thread through [compute].
/// {@category Assets and loading}
Future<SceneDocument> readFscenebAsync(Uint8List bytes) => kIsWeb
    ? readFscenebBrowser(bytes)
    : compute(readFsceneb, bytes, debugLabel: 'readFsceneb');
