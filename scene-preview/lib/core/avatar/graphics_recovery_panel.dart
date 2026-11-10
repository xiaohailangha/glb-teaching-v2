import 'package:flutter/material.dart';

class GraphicsRecoveryPanel extends StatefulWidget {
  const GraphicsRecoveryPanel({
    super.key,
    required this.onRecover,
    this.reason = '',
  });
  final Future<void> Function() onRecover;
  final String reason;
  @override
  State<GraphicsRecoveryPanel> createState() => _GraphicsRecoveryPanelState();
}

class _GraphicsRecoveryPanelState extends State<GraphicsRecoveryPanel> {
  bool busy = false;
  bool failed = false;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xDDF4F2EB),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('人物显示已中断', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            const Text('恢复后可从当前学习位置继续。', textAlign: TextAlign.center),
            if (widget.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '显示检查：${widget.reason}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 20),
            if (failed)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('学习位置暂未保存，请稍后重试。', textAlign: TextAlign.center),
              ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        failed = false;
                      });
                      try {
                        await widget.onRecover();
                      } catch (_) {
                        if (mounted) setState(() => failed = true);
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(busy ? '正在保存学习位置…' : '恢复页面'),
            ),
          ],
        ),
      ),
    ),
  );
}
