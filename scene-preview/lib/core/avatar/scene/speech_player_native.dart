import 'package:just_audio/just_audio.dart';

class SpeechPlayer extends AudioPlayer {
  Future<void> unlockFromGesture() async {}
  Future<void> preloadAssets(
    List<String> paths, {
    bool strict = false,
    void Function(int, int)? onProgress,
  }) async {
    onProgress?.call(paths.length, paths.length);
  }
}
