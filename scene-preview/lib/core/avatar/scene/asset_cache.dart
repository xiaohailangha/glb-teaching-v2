export 'asset_cache_stub.dart'
    if (dart.library.io) 'asset_cache_native.dart'
    if (dart.library.js_interop) 'asset_cache_web.dart';
