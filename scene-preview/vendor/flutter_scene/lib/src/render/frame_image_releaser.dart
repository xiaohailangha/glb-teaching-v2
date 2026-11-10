import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';

/// Owns the original snapshot handles until CanvasKit has painted their lazy
/// ImageBitmaps. Pictures retain their own handles; the original must be closed.
class FrameImageReleaser {
  final Set<ui.Image> _images = {};
  int get heldImages => _images.length;
  void defer(ui.Image image) {
    _images.add(image);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_images.remove(image)) image.dispose();
      });
    });
  }

  void dispose() {
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
  }
}
