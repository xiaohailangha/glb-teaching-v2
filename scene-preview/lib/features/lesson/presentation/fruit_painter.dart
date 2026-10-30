import 'package:flutter/material.dart';

class FruitPainter extends CustomPainter {
  final String fruit;
  const FruitPainter(this.fruit);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 42, size.height / 40);
    if (fruit == 'apple') {
      final body = Path()
        ..moveTo(21, 12)
        ..cubicTo(5, 3, 2, 22, 12, 34)
        ..cubicTo(16, 38, 19, 33, 21, 34)
        ..cubicTo(25, 38, 30, 37, 35, 25)
        ..cubicTo(42, 9, 28, 5, 21, 12);
      canvas.drawPath(body, Paint()..color = const Color(0xFFE9907D));
      canvas.drawLine(
        const Offset(21, 12),
        const Offset(23, 3),
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 2,
      );
      canvas.drawOval(
        const Rect.fromLTWH(24, 3, 10, 5),
        Paint()..color = const Color(0xFFB0C798),
      );
    } else {
      final body = Path()
        ..moveTo(7, 7)
        ..cubicTo(6, 28, 25, 31, 36, 12)
        ..cubicTo(35, 38, 8, 43, 5, 18)
        ..close();
      canvas.drawPath(body, Paint()..color = const Color(0xFFE8CF83));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FruitPainter oldDelegate) => oldDelegate.fruit != fruit;
}
