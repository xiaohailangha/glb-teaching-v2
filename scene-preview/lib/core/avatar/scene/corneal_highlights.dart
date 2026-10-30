import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Small studio reflections sit on the curved eye surface and are depth
/// tested by the lids. They follow the view/light half-vector, not the pupil.
class CornealHighlights {
  CornealHighlights(this.model, this.eyes) {
    final geometry = SphereGeometry(radius: .0017, segments: 8, rings: 4);
    final material = UnlitMaterial()..baseColorFactor = vm.Vector4.all(1);
    for (final eye in eyes) {
      final mesh = Mesh(geometry, material);
      mesh.primitives.single.castsShadow = false;
      final spot = Node(name: 'Corneal_softbox_${eye.name}')..mesh = mesh;
      model.add(spot);
      spots.add(spot);
    }
  }
  final Node model;
  final List<Node> eyes;
  final spots = <Node>[];
  void update(Camera camera, Map<String, double> weights) {
    final inverse = vm.Matrix4.copy(model.globalTransform)..invert();
    final viewer = inverse.transform3(camera.position.clone());
    final light = inverse.transform3(vm.Vector3(-2, 3, -6));
    final blink = weights.entries
        .where((e) => e.key == 'Blink' || e.key.startsWith('EmotionBlink_'))
        .fold<double>(0, (value, e) => math.max(value, e.value));
    for (var i = 0; i < spots.length; i++) {
      final view = (viewer - eyes[i].position)..normalize();
      final half = ((light - eyes[i].position)..normalize()) + view;
      half.normalize();
      spots[i]
        ..position = eyes[i].position + half * .0437
        ..scale = vm.Vector3.all((1 - blink * 4).clamp(0.0, 1.0))
        ..visible = blink < .25;
    }
  }
}
