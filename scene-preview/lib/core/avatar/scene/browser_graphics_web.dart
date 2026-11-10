import 'dart:js_interop';

import 'package:web/web.dart' as web;

class BrowserGraphicsWatch {
  BrowserGraphicsWatch(void Function() onLost) {
    _callback = ((web.Event event) {
      onLost();
    }).toJS;
    web.window.addEventListener('flutter-scene-context-lost', _callback);
    // Also observe the framework's visible canvas; the offscreen character
    // context dispatches the explicit event above from the renderer backend.
    web.window.addEventListener('webglcontextlost', _callback, true.toJS);
  }
  late final JSFunction _callback;
  void dispose() {
    web.window.removeEventListener('flutter-scene-context-lost', _callback);
    web.window.removeEventListener('webglcontextlost', _callback, true.toJS);
  }
}

// Only called by the user's recovery button, after checkpoint persistence.
// Context loss, visibility and ordinary render errors never reload the page.
void reloadForGraphicsRecovery() => web.window.location.reload();
