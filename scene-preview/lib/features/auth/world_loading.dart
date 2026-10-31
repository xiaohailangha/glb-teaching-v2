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
    child: SafeArea(
      child: AnimatedBuilder(
        animation: controller.resourceTick,
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (box.maxHeight - 50).clamp(0, double.infinity),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const EntryBrand(),
                      if (cancel != null)
                        IconButton(
                          tooltip: '返回',
                          onPressed: cancel,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: entryInk,
                            size: 21,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: box.maxHeight > 560 ? box.maxHeight * .14 : 20,
                  ),
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: controller.resourceProgress,
                            strokeWidth: 2,
                            color: entryInk,
                            backgroundColor: const Color(0xFFDDDFD4),
                          ),
                        ),
                        Container(
                          width: 116,
                          height: 116,
                          decoration: const BoxDecoration(
                            color: entryLime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 48,
                            color: entryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    controller.error != null ? '再准备一下。' : '让课堂，准备好。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: entryInk,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.error != null
                        ? '网络似乎慢了一点，请重试。'
                        : '人物、声音，还有你的第一句话。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: entryMuted, fontSize: 13),
                  ),
                  SizedBox(
                    height: box.maxHeight > 560 ? box.maxHeight * .12 : 24,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: controller.error != null
                        ? EntryButton('重新准备', onPressed: retry)
                        : Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      controller.resourceLabel,
                                      style: const TextStyle(
                                        color: entryMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(controller.resourceProgress * 100).floor()}%',
                                    style: const TextStyle(
                                      color: entryInk,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: controller.resourceProgress,
                                  minHeight: 2,
                                  color: entryInk,
                                  backgroundColor: const Color(0xFFDDDFD4),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                '首次准备需要一点时间，下次会更快',
                                style: TextStyle(
                                  color: entryMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
