import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'secondary_motion.dart';

/// Opt-in development probes; never enabled in the production build.
class AttachmentProbe {
  AttachmentProbe(SecondaryMotion motion)
    : head = motion.head!,
      inverseBindHead = vm.Matrix4.inverted(motion.head!.localTransform),
      positions = {
        for (final node in [...motion.eyes, motion.hair['MSTR-Hair']!.node])
          node: node.position,
      };
  final Node head;
  final vm.Matrix4 inverseBindHead;
  final Map<Node, vm.Vector3> positions;
  final maxErrors = <String, double>{};
  int frames = 0;
  void sample() {
    final delta = head.localTransform * inverseBindHead;
    for (final entry in positions.entries) {
      final error =
          (entry.key.position - delta.transform3(entry.value.clone())).length;
      if (!error.isFinite) throw StateError('Nonfinite attachment probe');
      if (error > (maxErrors[entry.key.name] ?? 0)) {
        maxErrors[entry.key.name] = error;
      }
    }
    if (++frames % 300 == 0) {
      debugPrint(
        'ATTACHMENT_PROBE ${jsonEncode({'frames': frames, 'maxErrorMeters': maxErrors})}',
      );
    }
  }
}

Future<void> probeDisplayCoverage(Scene scene) async {
  try {
    Scene.debugAllowRenderGraphCapture = true;
    final capture = await scene.captureRenderGraph(
      request: const RenderGraphCaptureRequest(
        fullResolution: true,
        thumbnailMaxDim: null,
        onlyKeys: {'display_color'},
      ),
    );
    final outputs = capture.resources
        .where((r) => r.key == 'display_color' && r.snapshot != null)
        .toList();
    if (outputs.isEmpty) throw StateError('No captured display pixels');
    final output = outputs.last, image = output.snapshot!.asImage();
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (pixels == null || pixels.lengthInBytes == 0) {
      throw StateError('Empty display readback');
    }
    var transparent = 0, partial = 0;
    for (var i = 3; i < pixels.lengthInBytes; i += 4) {
      final a = pixels.getUint8(i);
      if (a == 0) {
        transparent++;
      } else if (a < 255) {
        partial++;
      }
    }
    debugPrint(
      'COVERAGE_PROBE ${jsonEncode({'width': output.width, 'height': output.height, 'pixels': pixels.lengthInBytes ~/ 4, 'transparent': transparent, 'partialAlpha': partial})}',
    );
  } catch (error) {
    debugPrint('COVERAGE_PROBE_FAILED $error');
  }
}
