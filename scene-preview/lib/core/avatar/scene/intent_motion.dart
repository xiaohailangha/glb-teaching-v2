import 'dart:math' as math;

import 'teaching_math.dart';

double gestureBeat(
  double t, {
  double at = .12,
  double attack = .18,
  double hold = .38,
  double release = .28,
}) {
  if (t < at || t >= at + attack + hold + release) return 0;
  if (t < at + attack) return smooth((t - at) / attack);
  if (t < at + attack + hold) return 1;
  return 1 - smooth((t - at - attack - hold) / release);
}

/// One short thought per lesson event, followed by a held attentive pose.
/// The eyes acquire the target first; head and shoulders settle behind them.
class IntentPose {
  const IntentPose({
    this.body = .06,
    this.head = 0,
    this.roll = 0,
    this.pitch = 0,
    this.gaze = 0,
    this.left = 0,
    this.right = 0,
    this.interest = .22,
    this.smile = .24,
  });
  final double body, head, roll, pitch, gaze, left, right, interest, smile;
}

IntentPose teachingIntent(
  String phase,
  double elapsed, {
  bool engaged = true,
  bool speaking = false,
}) {
  // Quiet attention has occasional target changes, never a rocking root loop.
  final glance = gestureBeat(
    elapsed % 13.7,
    at: 5.1,
    attack: .16,
    hold: .65,
    release: .36,
  );
  if (!engaged) {
    return IntentPose(
      body: .04,
      head: .025 * glance,
      gaze: .13 * glance,
      smile: .18,
      interest: .14 + .08 * glance,
    );
  }
  final beat = gestureBeat(elapsed),
      follow = speaking
          ? gestureBeat(elapsed, at: 1.65, attack: .28, hold: .35, release: .5)
          : 0.0,
      nod = gestureBeat(
        elapsed,
        at: .16,
        attack: .09,
        hold: .035,
        release: .17,
      );
  switch (phase) {
    case 'listen':
    case 'choice':
    case 'recall':
      final welcome = gestureBeat(
        elapsed,
        at: .1,
        attack: .3,
        hold: .4,
        release: .65,
      );
      return IntentPose(
        body: .02,
        head: -.015 + .035 * glance,
        gaze: .16 * glance,
        roll: .015 + .012 * welcome,
        pitch: -.018 + .035 * nod,
        right: .24 * welcome,
        interest: .42 + .08 * welcome,
        smile: .22 + .08 * welcome,
      );
    case 'meaning':
    case 'explain':
    case 'transfer':
      return IntentPose(
        body: .07,
        head:
            .055 *
            gestureBeat(elapsed, at: .12, attack: .3, hold: .55, release: .45),
        gaze:
            .24 *
            gestureBeat(elapsed, at: 0, attack: .12, hold: .65, release: .3),
        left: .42 * beat,
        right: .28 * follow,
        interest: .4 + .12 * follow,
        smile: .25,
      );
    case 'invite':
      return IntentPose(
        body: .02,
        head: -.025,
        pitch: -.025,
        roll: .025,
        right: .44 * beat,
        interest: .52,
        smile: .34,
      );
    case 'success':
    case 'encourage':
      return IntentPose(
        body: .04,
        pitch: .065 * nod,
        left: .30 * beat,
        right: .18 * beat,
        smile: .48,
        interest: .48,
      );
    case 'support':
      return IntentPose(
        body: .025,
        roll: -.02,
        right: .22 * beat,
        interest: .32,
        smile: .30,
      );
    case 'demonstrate':
    case 'phoneme':
      return IntentPose(
        body: .055,
        head: .025 * beat,
        pitch: .04 * nod,
        right: speaking ? .32 * beat : 0,
        left: .20 * follow,
        interest: .35 + .1 * beat,
        smile: .17,
      );
    default:
      return IntentPose(
        body: .06,
        head: .015,
        left: .22 * beat,
        interest: .32,
        smile: .30,
      );
  }
}

double boundedGaze(double gaze) => gaze.clamp(-.38, .38);
double breathingOffset(double time) => .0008 * math.sin(time * 1.7);

/// Select an authored whole-body thought instead of looping the entire clip.
/// Event transitions are blended by the joint smoother. The hand/shoulder
/// composition stays intact and a held thought does not become another turn.
double lessonPoseTime(String phase, [double elapsed = 0]) {
  final base = switch (phase) {
    'introduce' => .85,
    'meaning' || 'explain' || 'transfer' => 2.35,
    'demonstrate' || 'phoneme' => 3.8,
    'invite' => 6.4,
    'listen' || 'choice' || 'recall' => 7.55,
    'support' => 8.1,
    'success' || 'encourage' => 1.05,
    _ => 0,
  };
  // Play a bounded authored phrase forward through anticipation and release.
  // Never wrap the source reel, reverse it, or sweep through unrelated turns.
  final travel = switch (phase) {
    'meaning' || 'explain' || 'transfer' => .65,
    'invite' => .72,
    'demonstrate' || 'phoneme' => .42,
    'success' || 'encourage' => .48,
    'listen' || 'choice' || 'recall' => .24,
    _ => .32,
  };
  return base + travel * smooth((elapsed / 1.65).clamp(0, 1));
}
