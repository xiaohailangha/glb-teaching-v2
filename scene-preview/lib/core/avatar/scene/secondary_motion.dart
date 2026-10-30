import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'authored_tracks.dart';
import 'teaching_math.dart';

// Mirror the authored Three.js XYZ rotations into Scene's left-handed basis.
vm.Quaternion authoredRotation(double x, double y, double z) {
  final c1 = math.cos(x / 2),
      c2 = math.cos(y / 2),
      c3 = math.cos(z / 2),
      s1 = math.sin(x / 2),
      s2 = math.sin(y / 2),
      s3 = math.sin(z / 2);
  return vm.Quaternion(
    -(s1 * c2 * c3 + c1 * s2 * s3),
    -(c1 * s2 * c3 - s1 * c2 * s3),
    c1 * c2 * s3 + s1 * s2 * c3,
    c1 * c2 * c3 - s1 * s2 * s3,
  );
}

vm.Quaternion lerpRotation(vm.Quaternion a, vm.Quaternion b, double t) {
  final sign = a.dot(b) < 0 ? -1.0 : 1.0;
  return vm.Quaternion(
    a.x + (b.x * sign - a.x) * t,
    a.y + (b.y * sign - a.y) * t,
    a.z + (b.z * sign - a.z) * t,
    a.w + (b.w * sign - a.w) * t,
  )..normalize();
}

List<Node> descendants(Node root) => [
  root,
  for (final child in root.children) ...descendants(child),
];

class BonePose {
  BonePose(this.node) : p = node.position, q = node.rotation, s = node.scale;
  final Node node;
  vm.Vector3 p, s;
  vm.Quaternion q;
  void capture() {
    p = node.position;
    q = node.rotation;
    s = node.scale;
  }

  void restore() {
    node.position = p;
    node.rotation = q;
    node.scale = s;
  }
}

class Spring {
  double value = 0, velocity = 0;
  double step(
    double drive,
    double dt, {
    double frequency = 10,
    double damping = .72,
    double limit = .075,
  }) {
    final steps = math.max(1, (math.min(dt, .1) * 120).ceil()),
        h = math.min(dt, .1) / steps;
    for (var i = 0; i < steps; i++) {
      velocity +=
          (-frequency * frequency * value -
              2 * damping * frequency * velocity +
              drive) *
          h;
      value += velocity * h;
      if (value.abs() > limit) {
        value = value.sign * limit;
        velocity *= .25;
      }
    }
    return value;
  }
}

class HairRecord extends BonePose {
  HairRecord(super.node, this.parentName);
  final String? parentName;
  final x = Spring(), y = Spring(), z = Spring();
  bool done = false;
  vm.Matrix4 base = vm.Matrix4.identity(),
      inverse = vm.Matrix4.identity(),
      delta = vm.Matrix4.identity();
}

class SecondaryMotion {
  SecondaryMotion(this.model, Map<String, dynamic> rig) {
    final nodes = descendants(model),
        byName = {for (final n in nodes) n.name: n};
    head = byName[rig['head']];
    eyes = [
      for (final name in rig['eyes'] as List)
        if (byName[name] != null) byName[name]!,
    ];
    final parts = {
      rig['head'],
      ...(rig['eyes'] as List),
      for (final h in rig['hair'] as List) h['name'],
    };
    headParts = [
      for (final node in nodes)
        if (parts.contains(node.name)) BonePose(node),
    ];
    for (final item in rig['hair'] as List) {
      final node = byName[item['name']];
      if (node != null) {
        hair[node.name] = HairRecord(node, item['parent'] as String?);
      }
    }
    for (final side in ['L', 'R']) {
      final elbow = byName['DEF-Forearm_1.$side'];
      if (elbow != null) {
        arms.add((
          side: side,
          elbow: elbow,
          records: [
            for (final n in nodes)
              if (n.name.endsWith(side) &&
                  RegExp(r'^DEF-(Forearm_|Wrist|Finger)').hasMatch(n.name))
                BonePose(n),
          ],
        ));
      }
    }
    smoothed = [
      for (final n in nodes)
        if (n.mesh == null && n != model) BonePose(n),
    ];
  }
  final Node model;
  Node? head;
  late List<Node> eyes;
  late List<BonePose> headParts, smoothed;
  final hair = <String, HairRecord>{};
  final arms = <({String side, Node elbow, List<BonePose> records})>[];
  final saved = <Node, BonePose>{};
  vm.Quaternion? lastHeadWorld;
  double time = 0,
      yaw = .30,
      headYaw = 0,
      roll = 0,
      pitch = 0,
      gaze = 0,
      hairPeak = 0;
  final face = <String, double>{},
      affect = <String, double>{},
      armAmount = <String, double>{};
  bool smoothingStarted = false;
  void restore() {
    for (final p in saved.values) {
      p.restore();
    }
    saved.clear();
  }

  void remember(Node n) {
    saved.putIfAbsent(n, () => BonePose(n));
  }

  void update(
    double dt,
    Map<String, double> w, {
    bool speaking = false,
    bool engaged = false,
    bool emoting = false,
    String phase = 'idle',
    double? storyTime,
  }) {
    for (final p in smoothed) {
      if (smoothingStarted) {
        final blend = 1 - math.exp(-dt * 18);
        p.p = p.p + (p.node.position - p.p) * blend;
        p.q = lerpRotation(p.q, p.node.rotation, blend);
        p.s = p.s + (p.node.scale - p.s) * blend;
        p.restore();
      } else {
        p.capture();
      }
    }
    smoothingStarted = true;
    time += dt;
    final t = ((storyTime ?? time) % 18 + 18) % 18,
        gain = engaged || storyTime != null ? 1.0 : .60;
    double track(String name, double at) => curve(actingTracks[name], at);
    final listening = ['listen', 'choice', 'recall'].contains(phase);
    final spin = storyTime == null
        ? 0.0
        : curve([
            [0, 0],
            [14, 0],
            [14.6, -.18],
            [15.2, 0],
            [18.8, math.pi * 2],
            [24, math.pi * 2],
          ], storyTime);
    var bodyTarget = track('turn', math.max(0, t - .32)) * gain;
    if (listening) bodyTarget *= .35;
    if (['meaning', 'explain', 'transfer'].contains(phase)) {
      bodyTarget = .40 + track('turn', math.max(0, t - .32)) * .22;
    }
    bodyTarget += spin;
    yaw +=
        math.atan2(math.sin(bodyTarget - yaw), math.cos(bodyTarget - yaw)) *
        (1 - math.exp(-dt * 4));
    headYaw = damp(
      headYaw,
      (listening ? -.18 : (track('turn', t) - .30) * .35 - .12) * gain,
      7,
      dt,
    );
    roll = damp(roll, track('lean', t) * gain, 5, dt);
    pitch = damp(pitch, track('nod', t) * gain, 6, dt);
    model.rotation = authoredRotation(0, yaw, roll * .32);
    model.position = vm.Vector3(
      .018 * math.sin(time * .43) * gain + .025 * math.sin(spin),
      .0025 * math.sin(time * 1.7) - .012 * math.pow(math.sin(spin * .5), 2),
      0,
    );
    if (head != null) {
      final pivot = head!.position - vm.Vector3(0, .035, 0),
          q = authoredRotation(pitch, headYaw, roll);
      for (final p in headParts) {
        remember(p.node);
        p.node.position = q.rotated(p.node.position - pivot) + pivot;
        p.node.rotation = q * p.node.rotation;
      }
    }
    for (final arm in arms) {
      final shift = arm.side == 'L' ? 0.30 : 0.0;
      final target =
          curve([
            [0, 0],
            [2 + shift, 0],
            [3.7 + shift, .52],
            [5.1 + shift, .70],
            [6.7 + shift, 0],
            [12, 0],
            [14, .46],
            [16, .64],
            [19, .15],
            [21, 0],
            [24, 0],
          ], storyTime ?? time % 18) *
          (engaged && !listening && !emoting ? 1 : 0);
      final gesture = armAmount[arm.side] = damp(
        armAmount[arm.side] ?? 0,
        target,
        7,
        dt,
      );
      final pivot = arm.elbow.position,
          q = authoredRotation(
            -gesture,
            0,
            gesture * (arm.side == 'L' ? -.12 : .12),
          );
      for (final p in arm.records) {
        remember(p.node);
        p.node.position = q.rotated(p.node.position - pivot) + pivot;
        p.node.rotation = q * p.node.rotation;
      }
    }
    if (!emoting) {
      final a = articulation(w),
          s = track('smile', t),
          interest = track('interest', t);
      final desired = {
        'SmileLeft': s * (1 - .78 * a),
        'SmileRight': (s * .82 + .025) * (1 - .78 * a),
        'SmileEyes': .22 + s * .78,
        'BrowLeft': .08 + interest * .47,
        'BrowRight': .04 + interest * .28,
        'Curious': .05 + interest * .25,
        'Attentive': listening ? 0.36 : .10 + interest * .18,
      };
      for (final entry in desired.entries) {
        final target = engaged
            ? (w[entry.key] ?? 0) * .38 + entry.value * .62
            : entry.value;
        face[entry.key] = damp(
          face[entry.key] ?? target,
          target,
          entry.key.startsWith('Brow') ? 7 : 4.5,
          dt,
        );
        w[entry.key] = face[entry.key]!;
      }
      w['SmileLeft'] = math.min(w['SmileLeft']!, 1 - .78 * a);
      w['SmileRight'] = math.min(w['SmileRight']!, 1 - .78 * a);
      gaze = damp(
        gaze,
        listening ? 0 : (track('turn', t + .18) - .30) * gain * .9,
        24,
        dt,
      );
      w['GazeRight'] = math.max(0, gaze);
      w['GazeLeft'] = math.max(0, -gaze);
      w['GazeDown'] = .025 + .025 * interest;
      w['GazeUp'] = 0;
      double pulse(double a, double b, double c, double d) => curve([
        [0, 0],
        [a, 0],
        [b, 1],
        [c, .72],
        [d, 0],
        [18, 0],
      ], t);
      final accents = {
        'curious': pulse(2.1, 3.5, 4.5, 6) * .30,
        'confused': pulse(5.7, 7, 8, 9.5) * .27,
        'relieved': pulse(11, 12.7, 13.4, 15) * .22,
        'happy': pulse(13.5, 14.7, 15.3, 17.4) * .22,
      };
      for (final e in accents.entries) {
        affect[e.key] = damp(
          affect[e.key] ?? 0,
          speaking ? 0 : e.value * gain,
          speaking ? 30 : 6,
          dt,
        );
        w['Emotion_${e.key}'] = affect[e.key]! * (1 - a);
        w['EmotionBlink_${e.key}'] = (w['Blink'] ?? 0) * w['Emotion_${e.key}']!;
      }
      for (final start in [2, 5.6, 9, 12.5, 16.6]) {
        final d = t - start;
        if (d >= 0 && d < .23) {
          w['Blink'] = math.max(
            w['Blink'] ?? 0,
            curve([
              [0, 0],
              [.065, 1],
              [.095, 1],
              [.23, 0],
            ], d),
          );
        }
      }
    }
    _eyeAim(w);
    _hair(dt);
  }

  void _eyeAim(Map<String, double> w) {
    if (eyes.length != 2) return;
    final center = (eyes[0].position + eyes[1].position) * .5;
    var target =
        head?.rotation.rotated(vm.Vector3(0, 0, -3)) ?? vm.Vector3(0, 0, -3);
    final learner = vm.Vector3(-3 * math.sin(yaw), 0, -3 * math.cos(yaw));
    target = target + (learner - target) * .68;
    target +=
        center +
        vm.Vector3(
          .65 * ((w['GazeRight'] ?? 0) - (w['GazeLeft'] ?? 0)),
          .4 * ((w['GazeUp'] ?? 0) - (w['GazeDown'] ?? 0)),
          0,
        );
    for (final eye in eyes) {
      remember(eye);
      final q = eye.rotation,
          forward = q.rotated(vm.Vector3(0, 0, -1))..normalize(),
          direction = (target - eye.position)..normalize();
      var delta = vm.Quaternion.fromTwoVectors(forward, direction);
      final angle = 2 * math.acos(math.min(1, delta.w.abs()));
      if (angle > .35) {
        delta = lerpRotation(vm.Quaternion.identity(), delta, .35 / angle);
      }
      eye.rotation = delta * q;
    }
  }

  void _hair(double dt) {
    if (head == null || dt <= 0) return;
    final world = vm.Quaternion.identity();
    head!.globalTransform.decompose(
      vm.Vector3.zero(),
      world,
      vm.Vector3.zero(),
    );
    final change = lastHeadWorld == null
        ? vm.Quaternion.identity()
        : lastHeadWorld!.conjugated() * world;
    if (change.w < 0) change.scale(-1);
    final angle = 2 * math.acos(math.min(1, change.w)),
        s = math.sqrt(math.max(0, 1 - change.w * change.w));
    final speed = lastHeadWorld != null && s > 1e-6
        ? math.min(6, angle / dt) / s
        : 0.0;
    lastHeadWorld = world;
    for (final r in hair.values) {
      remember(r.node);
      r.capture();
      r.base = vm.Matrix4.compose(r.p, r.q, r.s);
      r.inverse = vm.Matrix4.inverted(r.base);
      r.done = false;
    }
    void solve(HairRecord r) {
      if (r.done) return;
      r.done = true;
      final parent = hair[r.parentName];
      if (parent != null) solve(parent);
      final working = parent == null ? r.base.clone() : parent.delta * r.base;
      final p = vm.Vector3.zero(),
          q = vm.Quaternion.identity(),
          scale = vm.Vector3.all(1);
      working.decompose(p, q, scale);
      final anchored = r.node.name == 'MSTR-Hair',
          tip = RegExp(r'_\d$|2\.').hasMatch(r.node.name),
          frequency = tip ? 8.0 : 11.0,
          gain = tip ? 10.0 : 6.0;
      // Angular velocity is already in Scene coordinates; no second basis flip.
      final ax = r.x.step(
        anchored ? 0 : -change.x * speed * gain,
        dt,
        frequency: frequency,
        limit: tip ? 0.15 : .075,
      );
      final ay = r.y.step(
        anchored ? 0 : -change.y * speed * gain,
        dt,
        frequency: frequency,
        limit: tip ? 0.13 : .065,
      );
      final az = r.z.step(
        anchored ? 0 : -change.z * speed * gain,
        dt,
        frequency: frequency,
        limit: tip ? 0.15 : .075,
      );
      final bend =
          vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), ax) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), ay) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), az);
      r.node.position = p;
      r.node.rotation = bend * q;
      r.node.scale = scale;
      r.delta = r.node.localTransform * r.inverse;
      hairPeak = math.max(
        hairPeak,
        math.max(ax.abs(), math.max(ay.abs(), az.abs())),
      );
    }

    for (final r in hair.values) {
      solve(r);
    }
  }
}
