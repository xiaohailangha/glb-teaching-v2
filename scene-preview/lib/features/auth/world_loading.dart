import 'package:flutter/material.dart';

import '../lesson/application/lesson_controller.dart';
import 'entry_design.dart';

class WorldLoading extends StatelessWidget {
  const WorldLoading({
    super.key,
    required this.controller,
    required this.retry,
    this.cancel,
  });
  final LessonController controller;
  final VoidCallback retry;
  final VoidCallback? cancel;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: entryPaper,
    child: AnimatedBuilder(
      animation: controller.resourceTick,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          const Center(child: EntryIdentity()),
          if (cancel != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              right: 16,
              child: IconButton(
                tooltip: '返回',
                onPressed: cancel,
                icon: const Icon(
                  Icons.close_rounded,
                  color: entryMuted,
                  size: 20,
                ),
              ),
            ),
          Positioned(
            left: 28,
            right: 28,
            bottom: MediaQuery.paddingOf(context).bottom + 30,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: controller.error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '准备中断，请再试一次',
                            style: TextStyle(color: entryMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          EntryButton('重新准备', onPressed: retry),
                        ],
                      )
                    : Semantics(
                        liveRegion: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                controller.resourceLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: entryMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${(controller.resourceProgress * 100).floor()}%',
                              style: const TextStyle(
                                color: entryMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (controller.error == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: EntryProgress(value: controller.resourceProgress),
            ),
        ],
      ),
    ),
  );
}
