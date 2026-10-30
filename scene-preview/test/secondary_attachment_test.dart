import 'dart:convert';
import 'dart:io';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:snow_speaks/core/avatar/scene/secondary_motion.dart';

void main() {
  test(
    'attached-vector rotation agrees with the matrix used to render a node',
    () {
      for (final q in [
        authoredRotation(.2, .7, -.1),
        authoredRotation(-.4, -.9, .2),
      ]) {
        final node = Node()..rotation = q;
        for (final v in [vm.Vector3(1, 2, 3), vm.Vector3(0, 0, -1)]) {
          expect(
            (rotateAttachedVector(q, v) -
                    node.localTransform.transform3(v.clone()))
                .length,
            lessThan(1e-6),
          );
        }
      }
    },
  );
  test(
    'real Storm eye centers and scalp root follow the rendered head matrix',
    () {
      final fixture = jsonDecode(
        File('test/fixtures/storm-joint-bind.json').readAsStringSync(),
      );
      final model = Node(name: 'Storm');
      final byName = <String, Node>{};
      for (final data in fixture['nodes']) {
        final p = List<double>.from(
          (data['position'] as List).map((x) => (x as num).toDouble()),
        );
        final q = List<double>.from(
          (data['rotation'] as List).map((x) => (x as num).toDouble()),
        );
        final s = List<double>.from(
          (data['scale'] as List).map((x) => (x as num).toDouble()),
        );
        final n = Node(name: data['name'])
          ..position = vm.Vector3(p[0], p[1], -p[2])
          ..rotation = vm.Quaternion(-q[0], -q[1], q[2], q[3])
          ..scale = vm.Vector3(s[0], s[1], s[2]);
        model.add(n);
        byName[n.name] = n;
      }
      final motion = SecondaryMotion(
        model,
        Map<String, dynamic>.from(fixture['rig']),
      );
      final head = motion.head!, before = vm.Matrix4.copy(head.localTransform);
      final attached = [...motion.eyes, byName['MSTR-Hair']!];
      final positions = {for (final node in attached) node: node.position};
      final errors = <double>[];
      for (var frame = 0; frame < 600; frame++) {
        motion.restore();
        motion.update(1 / 60, {'Blink': 0}, engaged: true, phase: 'listen');
        final headDelta = head.localTransform * vm.Matrix4.inverted(before);
        for (final node in attached) {
          final expected = headDelta.transform3(positions[node]!.clone());
          final error = (node.position - expected).length;
          errors.add(error);
          expect(
            error,
            lessThan(0.00001),
            reason: '${node.name} detached at frame $frame',
          );
        }
      }
      expect(errors.length, 1800);

      // Reproduce a changing authored head rotation. Independently lerping
      // each sibling's position makes the eyes/scalp cut different chords.
      final binds = {
        for (final part in motion.headParts)
          part.node: vm.Matrix4.copy(part.node.localTransform),
      };
      motion.restore();
      for (final part in motion.headParts) {
        binds[part.node] = vm.Matrix4.copy(part.node.localTransform);
      }
      for (var frame = 0; frame < 300; frame++) {
        motion.restore();
        final authoredDelta = vm.Matrix4.compose(
          vm.Vector3.zero(),
          authoredRotation(.1, frame.isEven ? .6 : -.4, -.08),
          vm.Vector3.all(1),
        );
        for (final entry in binds.entries) {
          final p = vm.Vector3.zero(), s = vm.Vector3.zero();
          final q = vm.Quaternion.identity();
          (authoredDelta * entry.value).decompose(p, q, s);
          entry.key.position = p;
          entry.key.rotation = q;
          entry.key.scale = s;
        }
        // Baked translation keys can cut a chord through a quaternion turn;
        // the rigid centers must remain anchored despite that input error.
        for (final eye in motion.eyes) {
          eye.position = eye.position + vm.Vector3(.0015, -.0003, .0004);
        }
        for (final record in motion.hair.values) {
          record.node.position =
              record.node.position + vm.Vector3(.0006, .0002, -.0001);
        }
        motion.update(1 / 60, {'Blink': 0}, engaged: true, phase: 'listen');
        final headDelta = head.localTransform * vm.Matrix4.inverted(before);
        for (final node in attached) {
          expect(
            (node.position - headDelta.transform3(positions[node]!.clone()))
                .length,
            lessThan(.00001),
            reason: 'Authored transition detached ${node.name}',
          );
        }
      }

      // The GPU can ask for extra paints without another UI tick. Exercise
      // the actual pre-animation restore component, including zero-delta
      // repaints, instead of relying on an external ticker to restore joints.
      model.addComponent(RestoreSecondaryMotion(motion));
      final driver = Node()..addComponent(_MotionPass(motion));
      model.add(driver);
      model.children.remove(driver);
      model.children.insert(0, driver);
      for (var frame = 0; frame < 600; frame++) {
        model.scenePrePass(frame % 3 == 0 ? 1 / 60 : 0);
        final headDelta = head.localTransform * vm.Matrix4.inverted(before);
        for (final node in attached) {
          expect(
            (node.position - headDelta.transform3(positions[node]!.clone()))
                .length,
            lessThan(.00001),
            reason: 'Extra repaint detached ${node.name}',
          );
        }
      }
    },
  );
}

class _MotionPass extends Component {
  _MotionPass(this.motion);
  final SecondaryMotion motion;
  @override
  void tick(double deltaSeconds) =>
      motion.update(deltaSeconds, {'Blink': 0}, engaged: true, phase: 'listen');
}
