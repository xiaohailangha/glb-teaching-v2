import 'package:flutter/material.dart';

const entryPaper = Color(0xFFF4F2EB);
const entryInk = Color(0xFF252B27);
const entryMuted = Color(0xFF777C73);

/// Identical proportions to the HTML first-frame identity.
class EntryIdentity extends StatelessWidget {
  const EntryIdentity({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'snow speaks，为每一次开口',
    child: ExcludeSemantics(
      child: SizedBox(
        width: 240,
        height: compact ? 98 : 158,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: compact ? 36 : 72,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final height in [26.0, 45.0, 64.0, 45.0, 26.0])
                      Container(
                        width: compact ? 4 : 7,
                        height: compact ? height * .5 : height,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: entryInk,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 14 : 28),
              Text(
                'snow speaks',
                style: TextStyle(
                  color: entryInk,
                  fontSize: compact ? 19 : 23,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: compact ? 10 : 18),
              const Text(
                '为每一次开口',
                style: TextStyle(
                  color: entryMuted,
                  fontSize: 11,
                  height: 1.2,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
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
    height: 50,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: entryInk,
        foregroundColor: entryPaper,
        disabledBackgroundColor: const Color(0xFFE2E3DC),
        disabledForegroundColor: entryMuted,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}

class EntryProgress extends StatelessWidget {
  const EntryProgress({super.key, this.value});
  final double? value;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    width: double.infinity,
    child: LinearProgressIndicator(
      value: value,
      minHeight: 2,
      color: entryInk,
      backgroundColor: const Color(0xFFE2E3DC),
      semanticsLabel: value == null ? '正在准备应用' : '正在准备课堂',
    ),
  );
}
