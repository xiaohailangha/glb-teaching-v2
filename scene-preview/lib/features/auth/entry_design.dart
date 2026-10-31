import 'dart:math' as math;

import 'package:flutter/material.dart';

const entryPaper = Color(0xFFF4F2EB);
const entryInk = Color(0xFF252B27);
const entryMuted = Color(0xFF777C73);

class EntryIdentity extends StatefulWidget {
  const EntryIdentity({super.key, this.compact = false});
  final bool compact;
  @override
  State<EntryIdentity> createState() => _EntryIdentityState();
}

class _EntryIdentityState extends State<EntryIdentity>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
    value: (DateTime.now().millisecondsSinceEpoch % 3800) / 3800,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
    } else if (!motion.isAnimating) {
      motion.repeat();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '为每一次开口',
    child: ExcludeSemantics(
      child: SizedBox(
        width: 240,
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 72,
              child: AnimatedBuilder(
                animation: motion,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Container(
                        key: ValueKey('voice-bar-$i'),
                        width: 7,
                        height:
                            [26.0, 45.0, 64.0, 45.0, 26.0][i] *
                            (MediaQuery.disableAnimationsOf(context)
                                ? .9
                                : .86 +
                                      .14 *
                                          math.sin(
                                            motion.value * math.pi * 2 -
                                                (i - 2).abs() * .65,
                                          )),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: entryInk,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '为每一次开口',
              style: TextStyle(
                color: entryMuted,
                fontSize: 12,
                height: 1.2,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class GuidedActions extends StatefulWidget {
  const GuidedActions({
    super.key,
    required this.showBack,
    required this.showNext,
    required this.canNext,
    required this.merged,
    required this.busy,
    required this.onBack,
    required this.onNext,
    required this.onExplore,
  });
  final bool showBack, showNext, canNext, merged, busy;
  final VoidCallback onBack, onNext, onExplore;
  @override
  State<GuidedActions> createState() => _GuidedActionsState();
}

class _GuidedActionsState extends State<GuidedActions>
    with SingleTickerProviderStateMixin {
  late final merge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.merged ? 1 : 0,
  );
  @override
  void didUpdateWidget(GuidedActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merged != widget.merged) {
      if (MediaQuery.disableAnimationsOf(context)) {
        merge.value = widget.merged ? 1 : 0;
      } else {
        merge.animateTo(widget.merged ? 1 : 0, curve: Curves.easeInOutCubic);
      }
    }
  }

  @override
  void dispose() {
    merge.dispose();
    super.dispose();
  }

  Widget arrow(bool back, double t) => Transform.translate(
    offset: Offset((back ? -72 : (widget.showBack ? 72 : 0)) * (1 - t), 0),
    child: Opacity(
      opacity: 1 - t,
      child: IgnorePointer(
        ignoring: widget.merged,
        child: ExcludeSemantics(
          excluding: widget.merged,
          child: IconButton(
            key: ValueKey(back ? 'guide-back' : 'guide-next'),
            tooltip: back ? '上一步' : '下一步',
            onPressed: widget.busy || (!back && !widget.canNext)
                ? null
                : (back ? widget.onBack : widget.onNext),
            color: entryInk,
            disabledColor: entryInk.withValues(alpha: .18),
            iconSize: 25,
            icon: Icon(
              back ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    height: 56,
    child: AnimatedBuilder(
      animation: merge,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showBack) arrow(true, merge.value),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            child: widget.showNext
                ? SizedBox(
                    key: const ValueKey('show-next'),
                    width: 240,
                    height: 48,
                    child: Center(child: arrow(false, merge.value)),
                  )
                : const SizedBox(
                    key: ValueKey('hide-next'),
                    width: 240,
                    height: 48,
                  ),
          ),
          Opacity(
            opacity: merge.value,
            child: IgnorePointer(
              ignoring: !widget.merged,
              child: ExcludeSemantics(
                excluding: !widget.merged,
                child: TextButton(
                  key: const ValueKey('guide-explore'),
                  onPressed: widget.busy ? null : widget.onExplore,
                  style: TextButton.styleFrom(
                    foregroundColor: entryInk,
                    minimumSize: const Size(150, 48),
                  ),
                  child: const Text(
                    '开始探索',
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
  Widget build(BuildContext context) => TextButton(
    onPressed: busy ? null : onPressed,
    style: TextButton.styleFrom(foregroundColor: entryInk),
    child: Text(label),
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

/// A visual invitation to type, without requesting focus or opening a keyboard.
class EntryIdleCaret extends StatefulWidget {
  const EntryIdleCaret({super.key});
  @override
  State<EntryIdleCaret> createState() => _EntryIdleCaretState();
}

class _EntryIdleCaretState extends State<EntryIdleCaret>
    with SingleTickerProviderStateMixin {
  late final blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  @override
  void dispose() {
    blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: blink,
      builder: (context, _) => Opacity(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? .65
            : .15 + .65 * Curves.easeInOut.transform(blink.value),
        child: Container(
          key: const ValueKey('idle-input-caret'),
          width: 1.5,
          height: 25,
          decoration: BoxDecoration(
            color: entryInk,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    ),
  );
}
