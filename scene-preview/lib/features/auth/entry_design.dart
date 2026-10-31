import 'dart:math' as math;

import 'package:flutter/material.dart';

const entryPaper = Color(0xFFF4F2EB);
const entryInk = Color(0xFF252B27);
const entryMuted = Color(0xFF777C73);
const entryLime = Color(0xFFDCEA9F);

class EntryBrand extends StatelessWidget {
  const EntryBrand({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 158,
    child: FittedBox(
      alignment: Alignment.centerLeft,
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded, color: entryInk, size: 25),
          SizedBox(width: 9),
          Text(
            'snow speaks',
            style: TextStyle(
              color: entryInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.7,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Native illustration: two conversational turns, not a screenshot or web card.
class HelloComposition extends StatelessWidget {
  const HelloComposition({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = math.min(box.maxWidth / 330, box.maxHeight / 280);
      return Center(
        child: SizedBox(
          width: 330 * scale,
          height: 280 * scale,
          child: FittedBox(
            child: SizedBox(
              width: 330,
              height: 280,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    right: 30,
                    child: Text(
                      'A LITTLE EVERY DAY',
                      style: TextStyle(
                        color: entryMuted.withValues(alpha: .7),
                        fontSize: 9,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 32,
                    child: Transform.rotate(
                      angle: -.09,
                      child: Container(
                        width: 260,
                        height: 158,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: entryLime,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'YOUR FIRST WORD',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                    color: entryInk,
                                  ),
                                ),
                                Icon(
                                  Icons.volume_up_outlined,
                                  size: 18,
                                  color: entryInk,
                                ),
                              ],
                            ),
                            Spacer(),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Hello.',
                                style: TextStyle(
                                  color: entryInk,
                                  fontSize: 64,
                                  height: 1,
                                  letterSpacing: -4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 15,
                    child: Transform.rotate(
                      angle: .07,
                      child: Container(
                        width: 234,
                        height: 115,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 23,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: entryInk,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '你好，世界。',
                              style: TextStyle(
                                color: entryPaper,
                                fontSize: 25,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  color: entryLime,
                                  size: 22,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '从这一声开始',
                                  style: TextStyle(
                                    color: Color(0xFFBFC8BA),
                                    fontSize: 11,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 17,
                    bottom: 19,
                    child: Icon(
                      Icons.north_east_rounded,
                      size: 29,
                      color: entryInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class EntryButton extends StatelessWidget {
  const EntryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: entryInk,
        foregroundColor: entryPaper,
        disabledBackgroundColor: const Color(0xFFD5D7CF),
        disabledForegroundColor: entryMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: entryMuted,
              ),
            )
          else
            const Icon(Icons.arrow_forward_rounded, size: 20),
        ],
      ),
    ),
  );
}
