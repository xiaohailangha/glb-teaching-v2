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
  if (!engaged) return const IntentPose(body: .04, smile: .18, interest: .14);
  final beat = gestureBeat(elapsed),
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
      return const IntentPose(
        body: .02,
        head: -.015,
        roll: .015,
        pitch: -.018,
        interest: .42,
        smile: .22,
      );
    case 'meaning':
    case 'explain':
    case 'transfer':
      return IntentPose(
        body: .13,
        head: .035,
        gaze: .24,
        left: .26 * beat,
        interest: .4,
        smile: .25,
      );
    case 'invite':
      return IntentPose(
        body: .02,
        head: -.025,
        pitch: -.025,
        roll: .025,
        right: .32 * beat,
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
        pitch: .025 * nod,
        right: speaking ? .16 * beat : 0,
        interest: .35,
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
double lessonPoseTime(String phase) => switch (phase) {
  'introduce' => .85,
  'meaning' || 'explain' || 'transfer' => 2.35,
  'demonstrate' || 'phoneme' => 3.8,
  'invite' => 6.4,
  'listen' || 'choice' || 'recall' => 7.55,
  'support' => 8.1,
  'success' || 'encourage' => 1.05,
  _ => 0,
};
