import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Watches only the scene context. No frame-count or timeout heuristic.
class BrowserGraphicsWatch {
  BrowserGraphicsWatch(void Function() onLost, {void Function()? onFrame}) {
    _lost = ((web.Event _) => onLost()).toJS;
    _frame = ((web.Event _) {
      if (_seenFrame) return;
      _seenFrame = true;
      onFrame?.call();
    }).toJS;
    web.window.addEventListener('flutter-scene-context-lost', _lost);
    web.window.addEventListener('flutter-scene-frame-presented', _frame);
  }
  late final JSFunction _lost;
  late final JSFunction _frame;
  bool _seenFrame = false;
  String get lastReason => 'G1';
  void dispose() {
    web.window.removeEventListener('flutter-scene-context-lost', _lost);
    web.window.removeEventListener('flutter-scene-frame-presented', _frame);
  }
}

// Recovery is requested by the user after saving their learning position.
void reloadForGraphicsRecovery() => web.window.location.reload();
