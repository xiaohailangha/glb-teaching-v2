export 'avatar_view_unsupported.dart'
    if (dart.library.js_interop) 'avatar_view_web.dart'
    if (dart.library.io) 'avatar_view_native.dart';
