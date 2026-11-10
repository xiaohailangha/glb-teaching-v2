import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A viewport selects one scale. The amount of copy never changes that scale.
class TrialType {
  TrialType(Size size)
    : scale = math.min(size.width / 500, size.height / 350).clamp(.70, 2.0),
      compact = size.height < 340;
  final double scale;
  final bool compact;
  double get title => math.max(16, 19 * scale);
  double get label => math.max(14.5, 17 * scale);
  double get body => math.max(14.5, 18 * scale);
  double get caption => math.max(12.5, 14 * scale);
  double get word => math.max(29, 42 * scale);
  double get sentence => math.max(22, 28 * scale);
  double get phrase => math.max(22, 27 * scale);
  double get ipa => math.max(20, 25 * scale);
  // All teaching blocks use exactly this one responsive gap.
  double get gap => 8 * scale;
  double get headerRow => math.max(title * 1.2, math.max(22, caption * 1.5));
  double get header => headerRow + gap * 2 + 1.5;
}
