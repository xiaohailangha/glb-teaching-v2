import 'package:flutter/material.dart';

import '../application/app_settings.dart';
import '../../lesson/application/lesson_controller.dart';
import '../../auth/auth_api.dart';
import '../../lesson/domain/course_catalog.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.lesson,
    this.account,
    this.onLeave,
  });
  final AppSettings settings;
  final LessonController lesson;
  final LearnerAccount? account;
  final Future<void> Function()? onLeave;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([settings, lesson]),
    builder: (context, _) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭设置',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('我想要什么 · 成人入门', style: TextStyle(color: Colors.white)),
            for (final course in courseCatalog)
              ListTile(
                dense: true,
                title: Text(course.title),
                subtitle: Text(course.goal),
                trailing: course.id == lesson.courseId
                    ? const Icon(Icons.check, color: Color(0xFFBDE5DD))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  lesson.selectCourse(course.id);
                },
              ),
            const SizedBox(height: 12),
            _NicknameField(lesson: lesson),
            if (onLeave != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account?.phoneMasked ?? '体验模式 · 记录保存在此浏览器',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      try {
                        await onLeave!();
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('暂时无法退出，请稍后重试')),
                        );
                      }
                    },
                    child: Text(account == null ? '注册 / 登录' : '退出登录'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const Text(
              '课程与麦克风',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    lesson.playCourse();
                  },
                  child: const Text('继续课程'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    lesson.playCourse(restart: true);
                  },
                  child: const Text('从头开始'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    lesson.playCourse();
                  },
                  child: const Text('重新连接麦克风'),
                ),
              ],
            ),
            if (lesson.courseOptions.any(
              (o) => ['next', 'attempt'].contains(o['id']),
            ))
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  lesson.playCourse(skip: true);
                },
                child: const Text('跳过当前练习（不计通过）'),
              ),
            const Text(
              '点人物重听。语音在练习时用于实时文字和发音评测；打开设置、离开页面或课程结束会关麦。音标参考使用独立成人录音，整词和句子仍为男童。',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '画面与流畅度',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 14),
            SegmentedButton<RenderPreset>(
              segments: const [
                ButtonSegment(value: RenderPreset.high, label: Text('高')),
                ButtonSegment(value: RenderPreset.medium, label: Text('中')),
                ButtonSegment(value: RenderPreset.low, label: Text('低')),
              ],
              selected: {settings.preset},
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white70,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: const Color(0xFF596B8A),
              ),
              onSelectionChanged: (selection) =>
                  settings.update(quality: selection.first),
            ),
            const SizedBox(height: 12),
            Text(switch (settings.preset) {
              RenderPreset.high => '细节优先 · 设备允许时最高 120 帧',
              RenderPreset.medium => '均衡体验 · 最高 60 帧',
              RenderPreset.low => '节省电量 · 最高 30 帧',
            }, style: const TextStyle(color: Colors.white70, height: 1.6)),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '自动适应性能',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '持续掉帧时降低精度，稳定后逐步恢复。',
                style: TextStyle(color: Colors.white60),
              ),
              value: settings.adaptive,
              onChanged: (value) => settings.update(automatic: value),
            ),
            const Divider(color: Colors.white12, height: 32),
            if (lesson.diagnostics['fps'] case final num fps)
              Text(
                '人物当前渲染 ${fps.round()} 帧/秒',
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 8),
            Text(
              '${lesson.diagnostics['version'] ?? 'Flutter Scene 测试版'} · ${lesson.diagnostics['runtime'] ?? ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              '实际帧率取决于设备、系统和运行环境。设置会自动保存。',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            if (settings.saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  settings.saveError!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NicknameField extends StatefulWidget {
  const _NicknameField({required this.lesson});
  final LessonController lesson;
  @override
  State<_NicknameField> createState() => _NicknameFieldState();
}

class _NicknameFieldState extends State<_NicknameField> {
  late final text = TextEditingController(text: widget.lesson.nickname);
  bool busy = false;
  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.lesson.setNickname(text.text);
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('昵称未保存，请检查后重试')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: text,
    enabled: !busy,
    maxLength: 12,
    style: const TextStyle(color: Colors.white),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => save(),
    decoration: InputDecoration(
      labelText: '昵称',
      counterText: '',
      suffixIcon: IconButton(
        tooltip: '保存昵称',
        onPressed: busy ? null : save,
        icon: const Icon(Icons.check_rounded),
      ),
    ),
  );
}
