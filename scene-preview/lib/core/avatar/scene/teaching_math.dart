import 'dart:math' as math;

import 'authored_tracks.dart';

double clamp(double x) => x.clamp(0.0, 1.0);
double smooth(double x) {
  x = clamp(x);
  return x * x * (3 - 2 * x);
}

double damp(double a, double b, double speed, double dt) =>
    a + (b - a) * (1 - math.exp(-speed * dt));
double curve(List<dynamic> keys, double time) {
  if (time <= (keys.first[0] as num)) return (keys.first[1] as num).toDouble();
  for (var i = 1; i < keys.length; i++) {
    if (time <= (keys[i][0] as num)) {
      final a = (keys[i - 1][0] as num).toDouble(),
          b = (keys[i][0] as num).toDouble();
      final x = (keys[i - 1][1] as num).toDouble(),
          y = (keys[i][1] as num).toDouble();
      return x + (y - x) * smooth((time - a) / (b - a));
    }
  }
  return (keys.last[1] as num).toDouble();
}

const mouthNames = ['AA', 'EE', 'OO', 'UU', 'FF', 'MBP', 'TH', 'L'];
const emotionIds = [
  'happy',
  'sad',
  'frustrated',
  'afraid',
  'angry',
  'surprised',
  'curious',
  'confused',
  'shy',
  'proud',
  'disgusted',
  'relieved',
];
double articulation(Map<String, double> w) => clamp(
  (w['AA'] ?? 0) +
      (w['EE'] ?? 0) +
      (w['OO'] ?? 0) +
      (w['UU'] ?? 0) +
      (w['MBP'] ?? 0) +
      .5 * (w['FF'] ?? 0) +
      .5 * (w['TH'] ?? 0) +
      .3 * (w['L'] ?? 0),
);

class MouthCue {
  MouthCue(this.time, this.id);
  final double time;
  final int id;
  static List<MouthCue> fromJson(dynamic list, {String word = ''}) {
    var first = true;
    return [
      for (final item in list as List? ?? [])
        () {
          var id = (item['id'] as num).toInt();
          if (id != 0 && first) {
            if ((word == 'thank' || word == 'phoneme_th') && id == 19) id = 17;
            first = false;
          }
          return MouthCue((item['time'] as num).toDouble(), id);
        }(),
    ];
  }
}

double boundaryRadius(List<MouthCue> cues, int i, double rate) => math.min(
  .0325 * rate,
  math.min(
    (cues[i].time - cues[i - 1].time) * .35,
    i + 1 < cues.length
        ? (cues[i + 1].time - cues[i].time) * .35
        : double.infinity,
  ),
);
int sampleTimeline(
  List<MouthCue> cues,
  double time,
  double rate,
  List<double> out,
) {
  out.fillRange(0, out.length, 0);
  if (cues.isEmpty) return 0;
  var index = 0;
  while (index + 1 < cues.length && cues[index + 1].time <= time) {
    index++;
  }
  var a = cues[index], b = a, blend = 0.0;
  final previousRadius = index > 0 ? boundaryRadius(cues, index, rate) : 0.0;
  final next = index + 1 < cues.length ? cues[index + 1] : null,
      nextRadius = next != null ? boundaryRadius(cues, index + 1, rate) : 0.0;
  if (index > 0 && time < cues[index].time + previousRadius) {
    a = cues[index - 1];
    b = cues[index];
    blend = smooth(
      (time - b.time + previousRadius) / math.max(.001, previousRadius * 2),
    );
  } else if (next != null && time >= next.time - nextRadius) {
    b = next;
    blend = smooth(
      (time - next.time + nextRadius) / math.max(.001, nextRadius * 2),
    );
  }
  final poses = mouthData['poses'] as List;
  var total = 0.0;
  for (var i = 0; i < 8; i++) {
    final x = ((poses[a.id] as Map)[mouthNames[i]] as num? ?? 0).toDouble(),
        y = ((poses[b.id] as Map)[mouthNames[i]] as num? ?? 0).toDouble();
    out[i] = x + (y - x) * blend;
    total += out[i];
  }
  final closure = out[5];
  if (closure > 0) {
    for (var i = 0; i < 8; i++) {
      if (i != 5) out[i] *= (1 - closure) * (1 - closure);
    }
  }
  if (total > 1) {
    for (var i = 0; i < 8; i++) {
      out[i] /= total;
    }
  }
  return cues[index].id;
}

class NaturalMotion {
  final weights = <String, double>{};
  final mouth = List<double>.filled(8, 0), target = List<double>.filled(8, 0);
  double time = 0, nextBlink = 3, blinkAt = -10;
  int update(
    double dt, {
    List<MouthCue> cues = const [],
    double audioTime = 0,
    double rate = 1,
    bool speaking = false,
  }) {
    dt = dt.clamp(0.0, .05);
    time += dt;
    var id = 0;
    if (speaking) {
      id = sampleTimeline(cues, audioTime, rate, target);
    } else {
      target.fillRange(0, 8, 0);
    }
    for (var i = 0; i < 8; i++) {
      mouth[i] = damp(
        mouth[i],
        target[i],
        i == 5 && target[i] > mouth[i] ? 58 : 42,
        dt,
      );
      if (mouth[i] < .0005) mouth[i] = 0;
      weights[mouthNames[i]] = mouth[i];
    }
    if (time >= nextBlink) {
      blinkAt = time;
      nextBlink = time + 3.4 + .7 * math.sin(time * .83);
    }
    final t = time - blinkAt;
    var blink = 0.0;
    if (t < .07) {
      blink = smooth(t / .07);
    } else if (t < .095) {
      blink = 1;
    } else if (t < .24) {
      blink = 1 - smooth((t - .095) / .145);
    }
    weights['Blink'] = .10 + .90 * blink;
    weights['Breathe'] =
        .22 + .12 * math.sin(time * 1.15) + .025 * math.sin(time * .47);
    weights['HeadNod'] = .04;
    weights['Gesture'] = 0;
    weights['SmileLeft'] = .38 * (1 - .7 * articulation(weights));
    weights['SmileRight'] = .33 * (1 - .7 * articulation(weights));
    weights['SmileEyes'] = .28;
    weights['BrowLeft'] = .12;
    weights['BrowRight'] = .07;
    for (final name in [
      'GazeRight',
      'GazeLeft',
      'GazeUp',
      'GazeDown',
      'Curious',
      'Attentive',
      'Warm',
      'BrowUp',
      'BrowRelax',
      'Smile',
      'LookLeft',
      'LookRight',
    ]) {
      weights[name] = 0;
    }
    for (final name in emotionIds) {
      weights['Emotion_$name'] = 0;
      weights['EmotionBlink_$name'] = 0;
    }
    return id;
  }
}

void applyPerformanceFace(Map<String, double> w, double time) {
  final t = time.clamp(0.0, 10.0);
  double track(String name) => curve(performanceTracks[name], t);
  final gaze = track('gaze');
  w['GazeRight'] = math.max(0, gaze);
  w['GazeLeft'] = math.max(0, -gaze);
  w['GazeDown'] = track('down');
  w['GazeUp'] = 0;
  for (final n in [
    'HeadNod',
    'LookRight',
    'LookLeft',
    'Gesture',
    'Breathe',
    'BrowUp',
    'BrowRelax',
    'Smile',
    'Warm',
  ]) {
    w[n] = 0;
  }
  w['SmileEyes'] = track('warm');
  w['Curious'] = track('curious');
  w['BrowLeft'] = track('left');
  w['BrowRight'] = track('right');
  w['Attentive'] = curve([
    [0, .1],
    [.5, .32],
    [1.3, .05],
    [2.2, .18],
    [3.4, .05],
    [4.4, .3],
    [5.5, 0],
    [6.6, .15],
    [8.2, .08],
    [9.4, 0],
    [10, .1],
  ], t);
  w['SmileLeft'] = track('smile') * (1 - .7 * articulation(w));
  w['SmileRight'] = w['SmileLeft']! * .90;
  var blink = 0.0;
  for (final start in [1.62, 2.81, 5.70, 8.35]) {
    final d = t - start;
    if (d >= 0 && d < .23) {
      blink = math.max(
        blink,
        curve([
          [0, 0],
          [.07, 1],
          [.095, 1],
          [.23, 0],
        ], d),
      );
    }
  }
  w['Blink'] = blink;
}

void applyEmotionFace(Map<String, double> w, String id, double time) {
  for (final name in w.keys.toList()) {
    w[name] = 0;
  }
  final t = time.clamp(0.0, 6.0),
      strength =
          smooth(t / (['afraid', 'surprised'].contains(id) ? 0.55 : 1.15)) *
          (1 - smooth((t - 4.65) / 1.35));
  w['Emotion_$id'] = strength;
  final start = ['afraid', 'surprised'].contains(id) ? 3.5 : 2.8;
  final blink = curve([
    [0, 0],
    [start, 0],
    [start + .07, 1],
    [start + .1, 1],
    [start + .25, 0],
    [6, 0],
  ], t);
  w['EmotionBlink_$id'] = blink * strength;
  w['Blink'] = blink * (1 - strength);
  w['GazeDown'] =
      ({'sad': .65, 'frustrated': .2, 'shy': .45, 'relieved': .08}[id] ?? 0) *
      strength;
  final gaze =
      ({
            'afraid': .32,
            'curious': .26,
            'confused': .38,
            'shy': .45,
            'disgusted': .5,
          }[id] ??
          0) *
      strength *
      curve([
        [0, 0],
        [.8, 1],
        [2, 1],
        [2.4, -.65],
        [3.5, -.65],
        [4.2, .2],
        [6, 0],
      ], t);
  w['GazeRight'] = math.max(0, gaze);
  w['GazeLeft'] = math.max(0, -gaze);
}

({double time, double accent, double accentTime}) lessonPose(
  String phase,
  double p,
  double elapsed,
  int variation,
) {
  p = clamp(p);
  final v = variation % 3;
  var time = 7.5, accent = 0.0, accentTime = 38.0;
  switch (phase) {
    case 'introduce':
      time = 1.55 + 1.8 * p;
      accent = .12;
      accentTime = (v == 1 ? 36 : 0) + 1.4 + p;
    case 'demonstrate':
      time = 3.65 + 2.05 * p;
      accent = v == 1 ? 0.24 : .12;
      accentTime = (v == 1 ? 36 : 0) + 1.8 + p * .6;
    case 'invite':
      time = 5.8 + 1.4 * p;
      accent = .1;
    case 'listen':
      time = 7.3 + .8 * (.5 + .5 * math.sin(elapsed * .65));
      accent = .14;
      accentTime = 38 + .25 * math.sin(elapsed * .8);
    case 'encourage':
      time = 8.85 + 1.149 * p;
      accent = .28 * math.sin(math.pi * p);
      accentTime = 1.5 + p * 2;
    case 'phoneme' || 'meaning':
      time = 3.7 + math.min(1.8, elapsed);
      accent = .12;
      accentTime = 37.6 + math.min(.8, elapsed * .4);
  }
  return (time: time, accent: accent, accentTime: accentTime);
}

const intents = {
  'introduce': 'welcome',
  'meaning': 'discover',
  'explain': 'explain',
  'demonstrate': 'model',
  'phoneme': 'model',
  'invite': 'invite',
  'listen': 'listen',
  'choice': 'recall',
  'recall': 'recall',
  'support': 'support',
  'success': 'confirm',
  'encourage': 'acknowledge',
  'transfer': 'transfer',
  'finish': 'close',
};
const basePhases = {
  'welcome': 'introduce',
  'discover': 'introduce',
  'explain': 'demonstrate',
  'model': 'demonstrate',
  'invite': 'invite',
  'listen': 'listen',
  'recall': 'listen',
  'support': 'invite',
  'confirm': 'encourage',
  'acknowledge': 'encourage',
  'transfer': 'introduce',
  'close': 'listen',
};
({double time, double accent, double accentTime}) coursePose(
  String phase,
  double p,
  double elapsed,
  int variation,
  String style,
) {
  final intent = intents[phase] ?? 'listen',
      base = lessonPose(basePhases[intent] ?? 'listen', p, elapsed, variation);
  var time = base.time, accent = base.accent, accentTime = base.accentTime;
  if (['discover', 'explain', 'transfer'].contains(intent)) {
    accent = .22 + .12 * math.sin(math.pi * clamp(p));
    accentTime = 37.2 + clamp(p) * 2.6;
  } else if (intent == 'support') {
    accent = .24;
    accentTime = 67.2 + clamp(p) * 2.5;
  } else if (intent == 'confirm') {
    accent = .22 + .15 * math.sin(math.pi * clamp(p));
    accentTime = 1.1 + clamp(p) * 3;
  } else if (['listen', 'recall'].contains(intent)) {
    time = 7.45 + .3 * math.sin(elapsed * .52) + .12 * math.sin(elapsed * .21);
    accent = .14;
    accentTime = 37.6 + .3 * math.sin(elapsed * .35);
  }
  final energy =
      {'child46': 1.2, 'child79': 1.1, 'child1012': 1.02}[style] ?? 1;
  return (
    time: time,
    accent: math.min(.48, accent * energy),
    accentTime: accentTime,
  );
}

void applyLessonFace(
  Map<String, double> w,
  String phase,
  double p,
  double elapsed,
  int variation,
) {
  p = clamp(p);
  final spoken = articulation(w);
  var smile = .50, eyes = .45, brow = .20, curious = .08, gaze = 0.0;
  if (phase == 'introduce') {
    gaze = curve([
      [0, 0],
      [.16, .12],
      [.4, .75],
      [.68, .65],
      [.85, 0],
      [1, 0],
    ], p);
    eyes = .52;
    brow = .18 + .20 * math.sin(p * math.pi);
    smile = .58;
  }
  if (['demonstrate', 'phoneme', 'meaning'].contains(phase)) {
    eyes = .45;
    brow = .15 + .22 * math.pow(math.sin(p * math.pi * 2), 2);
    smile = .48;
    gaze = .035 * math.sin(elapsed * 1.7);
  }
  if (phase == 'invite') {
    eyes = .58;
    brow = .22;
    curious = .18;
    smile = .65;
  }
  if (phase == 'listen') {
    eyes = .38;
    brow = .12;
    curious = .12;
    smile = .42;
    gaze = .065 * math.sin(elapsed * .7) * math.sin(elapsed * .31);
  }
  if (phase == 'encourage') {
    smile = .72 + .12 * math.sin(p * math.pi);
    eyes = .78;
    brow = .25;
  }
  for (final name in [
    'HeadNod',
    'LookLeft',
    'LookRight',
    'Breathe',
    'Gesture',
    'Warm',
    'BrowRelax',
    'BrowUp',
    'Smile',
  ]) {
    w[name] = 0;
  }
  w['SmileLeft'] = smile * (1 - .78 * spoken);
  w['SmileRight'] = w['SmileLeft']! * (variation == 1 ? 0.86 : .94);
  w['SmileEyes'] = eyes;
  w['BrowLeft'] = brow;
  w['BrowRight'] = brow * .65;
  w['Curious'] = curious;
  w['Attentive'] = phase == 'listen' ? 0.38 : .18;
  w['GazeRight'] = math.max(0, gaze);
  w['GazeLeft'] = math.max(0, -gaze);
  w['GazeDown'] = 0;
  w['GazeUp'] = 0;
}

const faceNames = [
  'SmileLeft',
  'SmileRight',
  'SmileEyes',
  'BrowLeft',
  'BrowRight',
  'Curious',
  'Attentive',
  'GazeRight',
  'GazeLeft',
  'GazeUp',
  'GazeDown',
];
void applyCourseFace(
  Map<String, double> w,
  String phase,
  double p,
  double elapsed,
  int variation,
  String style,
) {
  final intent = intents[phase] ?? 'listen';
  applyLessonFace(
    w,
    intent == 'support' ? 'listen' : basePhases[intent] ?? 'listen',
    p,
    elapsed,
    variation,
  );
  final gazeGain = {'child46': 1.08, 'child79': 1.04}[style] ?? 1.0,
      smileGain =
          {
            'child46': 1.15,
            'child79': 1.07,
            'child1012': 1.02,
            'correction': .94,
          }[style] ??
          1.0;
  final pulse = math.sin(math.pi * clamp(p)),
      micro = math.sin(elapsed * 1.7 + variation) * .025;
  if (['discover', 'explain', 'transfer'].contains(intent)) {
    w['Curious'] = .22 + .14 * pulse;
    w['BrowLeft'] = .23 + .20 * pulse;
    w['BrowRight'] = .12 + .10 * pulse;
    w['GazeRight'] = clamp(
      math.sin(math.pi * clamp((p - .06) / .74)) * .52 * gazeGain,
    );
    w['GazeLeft'] = 0;
    w['SmileEyes'] = .44;
  }
  if (intent == 'support') {
    w.addAll({
      'SmileEyes': .50,
      'Curious': .10,
      'Attentive': .46,
      'BrowLeft': .19,
      'BrowRight': .14,
    });
  }
  if (intent == 'recall') {
    w.addAll({
      'Curious': .23,
      'Attentive': .48,
      'BrowLeft': .23 + micro,
      'BrowRight': .12,
    });
  }
  if (intent == 'confirm') {
    w.addAll({
      'SmileEyes': .79,
      'BrowLeft': .25 + .1 * pulse,
      'BrowRight': .19,
    });
  }
  if (intent == 'acknowledge') {
    w['SmileEyes'] = .55;
    w['SmileLeft'] = w['SmileLeft']! * .8;
    w['SmileRight'] = w['SmileRight']! * .8;
  }
  w['BrowLeft'] = clamp(w['BrowLeft']! + micro);
  w['BrowRight'] = clamp(w['BrowRight']! - micro * .5);
  w['SmileLeft'] = clamp(w['SmileLeft']! * smileGain);
  w['SmileRight'] = clamp(w['SmileRight']! * smileGain);
  for (final name in faceNames) {
    w[name] = clamp(w[name] ?? 0);
  }
}
