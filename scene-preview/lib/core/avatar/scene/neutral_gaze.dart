import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';

import 'secondary_motion.dart';

// Frontal source/GLB renders show both pupils sitting toward the nasal edge
// of the visible aperture even though the source optical axes are parallel.
// Bake the original, coordinated outward-gaze correction into the neutral
// surface on each side. All authored expression channels remain available.
const neutralGazeCorrection = .60;
void calibrateNeutralGaze(Node model) {
  for (final node in descendants(model)) {
    if (node.mesh == null) continue;
    for (final primitive in node.mesh!.primitives) {
      final geometry = primitive.geometry;
      if (geometry is! MorphedSkinnedGeometry) continue;
      final morph = geometry.morphTargets;
      final right = morph.targetNames.indexOf('GazeRight');
      final left = morph.targetNames.indexOf('GazeLeft');
      if (right < 0 || left < 0) continue;
      final data = geometry.copyVertexData(), vertices = data.vertices;
      if (vertices.length != data.vertexCount * 26) {
        throw StateError('Unexpected gaze geometry layout');
      }
      for (var v = 0; v < data.vertexCount; v++) {
        final vertex = v * 26;
        final target = vertices[vertex] >= 0 ? right : left;
        final delta = (target * data.vertexCount + v) * 3;
        for (var axis = 0; axis < 3; axis++) {
          vertices[vertex + axis] +=
              morph.positionDeltas[delta + axis] * neutralGazeCorrection;
          final normals = morph.normalDeltas;
          if (normals != null) {
            vertices[vertex + 3 + axis] +=
                normals[delta + axis] * neutralGazeCorrection;
          }
        }
        final length = math.sqrt(
          vertices[vertex + 3] * vertices[vertex + 3] +
              vertices[vertex + 4] * vertices[vertex + 4] +
              vertices[vertex + 5] * vertices[vertex + 5],
        );
        if (length > 1e-8) {
          for (var axis = 3; axis < 6; axis++) {
            vertices[vertex + axis] /= length;
          }
        }
      }
      geometry.uploadVertexData(
        vertices,
        data.vertexCount,
        data.indices,
        indexType: data.indexType,
      );
    }
  }
}
