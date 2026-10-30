import 'dart:async';
import 'dart:js_interop';

import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:web/web.dart' as web;

/// Keep one audio element for the whole lesson. Safari's gesture permission
/// belongs to that element, so stopping a session must not replace it.
class SpeechPlayer {
  SpeechPlayer() {
    _audio
      ..preload = 'auto'
      ..src = _assetUrl('assets/avatar/audio/silence.wav');
    _audio.addEventListener('ended', _onEnded);
    _audio.load();
  }

  final _audio = web.HTMLAudioElement();
  final _states = StreamController<ProcessingState>.broadcast();
  late final JSFunction _onEnded = ((web.Event _) {
    _states.add(ProcessingState.completed);
  }).toJS;
  Future<void>? _unlocking;
  bool _unlocked = false;

  Stream<ProcessingState> get processingStateStream => _states.stream;
  Duration get position => Duration(
    microseconds: (_audio.currentTime * Duration.microsecondsPerSecond).round(),
  );
  Duration? get duration => _audio.duration.isFinite
      ? Duration(
          microseconds: (_audio.duration * Duration.microsecondsPerSecond)
              .round(),
        )
      : null;

  String _assetUrl(String path) => Uri.base.resolve('assets/$path').toString();

  /// Called synchronously from the original tap, before any network request.
  Future<void> unlockFromGesture() {
    if (_unlocked) return Future.value();
    if (_unlocking != null) return _unlocking!;
    return _unlocking = _audio
        .play()
        .toDart
        .then((_) {
          _unlocked = true;
        })
        .whenComplete(() {
          _unlocking = null;
        });
  }

  Future<void> setAsset(String path) => setUrl(_assetUrl(path));
  Future<void> setUrl(String url) async {
    _audio.pause();
    _audio.src = url;
    _audio.load();
    // play() waits for buffering itself; leaving this synchronous keeps rapid
    // replacement ordered without a late load future resetting a newer clip.
  }

  Future<void> setSpeed(double rate) async {
    _audio.playbackRate = rate;
  }

  Future<void> play() async {
    await _audio.play().toDart;
  }

  Future<void> stop() async {
    _audio.pause();
    _audio.currentTime = 0;
  }

  Future<void> dispose() async {
    _audio.pause();
    _audio.removeEventListener('ended', _onEnded);
    _audio.removeAttribute('src');
    _audio.load();
    await _states.close();
  }
}
