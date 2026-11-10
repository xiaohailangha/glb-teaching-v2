import 'dart:io';
import 'dart:typed_data';

import 'course_resources.dart';

import 'package:just_audio/just_audio.dart';

class SpeechPlayer extends AudioPlayer {
  int _sourceGeneration = 0;
  Future<void> setVerifiedBytes(Uint8List bytes, String hash) async {
    final generation = ++_sourceGeneration;
    final file = File(
      '${Directory.systemTemp.path}/snow-speaks-audio/$hash.wav',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    if (generation != _sourceGeneration) return;
    await setFilePath(file.path);
  }

  @override
  Future<void> stop() {
    ++_sourceGeneration;
    return super.stop();
  }

  @override
  Future<void> dispose() {
    ++_sourceGeneration;
    return super.dispose();
  }

  Future<void> setCourseAsset(String path) async {
    final generation = ++_sourceGeneration;
    final data = await CourseResources.instance.load(path);
    final hash = CourseResources.instance.assets[path]!['sha256'];
    final file = File(
      '${Directory.systemTemp.path}/snow-speaks-audio/$hash.wav',
    );
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    if (generation != _sourceGeneration) return;
    await setFilePath(file.path);
  }

  Future<void> unlockFromGesture() async {}
  Future<void> preloadAssets(
    List<String> paths, {
    bool strict = false,
    void Function(int, int)? onProgress,
  }) async {
    onProgress?.call(paths.length, paths.length);
  }
}
