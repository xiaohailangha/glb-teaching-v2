import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One stage grid owns both outside margins, the character and reading lane.
class LessonLayout {
  LessonLayout(Size size, {EdgeInsets safe = EdgeInsets.zero}) {
    final w = size.width, h = size.height;
    stacked = w < 700 && h > w;
    margin = math.max(
      math.max(safe.left, safe.right),
      (w * .075).clamp(20, 240),
    );
    final top = math.max(safe.top + 52, h * .14);
    final bottom = safe.bottom + controlSize(size) + 16;
    if (stacked) {
      final split = math.max(210.0, h * .39);
      avatar = Rect.fromLTWH(
        margin,
        safe.top + 40,
        w - margin * 2,
        split - safe.top - 40,
      );
      reading = Rect.fromLTRB(margin, split + 12, w - margin, h - bottom);
    } else {
      final gap = (w * .05).clamp(24.0, 120.0);
      final available = w - margin * 2 - gap;
      final personWidth = available * .46;
      avatar = Rect.fromLTRB(
        margin,
        safe.top + 20,
        margin + personWidth,
        h - safe.bottom,
      );
      reading = Rect.fromLTRB(avatar.right + gap, top, w - margin, h - bottom);
    }
  }
  late final bool stacked;
  late final double margin;
  late final Rect avatar, reading;
  static double controlSize(Size size) =>
      (size.shortestSide * .072).clamp(56.0, 80.0);
}

class LessonType {
  LessonType(this.size);
  final Size size;
  double get scale =>
      math.sqrt(size.width / 600 * size.height / 600).clamp(.86, 1.65);
  bool get compact => size.height < 380;
  double get body => compact ? 16 : (18 * scale).clamp(16, 26);
  double get caption => compact ? 13 : (14 * scale).clamp(13, 18);
  double get title => compact ? 17 : (18 * scale).clamp(17, 27);
  double get ipa => compact ? 20 : (size.width * .033).clamp(22, 34);
  double get header => (size.height * .12).clamp(38, 112);
  double get gap => (size.height * .024).clamp(8, 24);
  double main(String text) {
    final words = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?").allMatches(text).length;
    final width = words <= 1
        ? .12
        : words <= 3
        ? .10
        : words <= 6
        ? .08
        : .06;
    final height = words <= 1
        ? .17
        : words <= 3
        ? .15
        : .13;
    return math
        .min(size.width * width, size.height * height)
        .clamp(
          26,
          words <= 1
              ? 128
              : words <= 3
              ? 100
              : 72,
        );
  }
}
