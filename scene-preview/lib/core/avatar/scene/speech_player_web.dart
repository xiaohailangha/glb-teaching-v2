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
    // Discard an ended event queued for a source that has been replaced.
    if (_audio.ended) _states.add(ProcessingState.completed);
  }).toJS;
  bool _unlocked = false;
  bool _disposed = false;
  final _assetBlobs = <String, String>{};

  Future<void> preloadAssets(
    List<String> paths, {
    bool strict = false,
    void Function(int, int)? onProgress,
  }) async {
    var cursor = 0, completed = 0;
    Future<void> worker() async {
      while (cursor < paths.length) {
        final path = paths[cursor++];
        if (_disposed) return;
        try {
          if (!_assetBlobs.containsKey(path)) {
            final response = await web.window
                .fetch(_assetUrl(path).toJS)
                .toDart
                .timeout(const Duration(seconds: 30));
            if (!response.ok) throw StateError('Audio unavailable');
            final blob = await response.blob().toDart.timeout(
              const Duration(seconds: 30),
            );
            if (_disposed) return;
            _assetBlobs[path] = web.URL.createObjectURL(blob);
          }
        } catch (_) {
          if (strict) throw StateError('课程声音暂时未能准备完成，请重试');
        }
        completed++;
        onProgress?.call(completed, paths.length);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
  }

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
    // A new tap gets a new play promise, even if a previous tap was cancelled
    // before playback began. Reusing an aborted promise would reject it too.
    return _audio.play().toDart.then((_) {
      _unlocked = true;
    });
  }

  Future<void> setAsset(String path) =>
      setUrl(_assetBlobs[path] ?? _assetUrl(path));
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
    _disposed = true;
    _audio.pause();
    _audio.removeEventListener('ended', _onEnded);
    _audio.removeAttribute('src');
    _audio.load();
    for (final url in _assetBlobs.values) {
      web.URL.revokeObjectURL(url);
    }
    _assetBlobs.clear();
    await _states.close();
  }
}
