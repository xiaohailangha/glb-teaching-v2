import 'dart:async';

import '../../lesson/application/app_session_clock.dart';

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/app_settings.dart';
import '../../lesson/application/lesson_controller.dart';
import '../../auth/auth_api.dart';

const _ink = Color(0xFFF5F5F0);
const _muted = Color(0xFFB5BFBD);

Future<bool?> showLearningSettings(
  BuildContext context, {
  required AppSettings settings,
  required LessonController lesson,
  LearnerAccount? account,
  Future<void> Function()? onLeave,
  Future<Map<String, dynamic>> Function()? loadSummary,
}) => Navigator.of(context).push<bool>(
  PageRouteBuilder<bool>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260),
    reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => MyLearningPage(
      loadSummary: loadSummary,
      settings: settings,
      lesson: lesson,
      account: account,
      onLeave: onLeave,
    ),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);

class _DisplayPreferences extends StatelessWidget {
  const _DisplayPreferences({required this.settings});
  final AppSettings settings;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => Column(
      children: [
        Row(
          children: [
            const Text('画质', style: TextStyle(color: _ink, fontSize: 16)),
            const SizedBox(width: 24),
            Expanded(
              child: Row(
                children: [
                  for (final item in [
                    (RenderPreset.high, '清晰'),
                    (RenderPreset.medium, '均衡'),
                    (RenderPreset.low, '省电'),
                  ])
                    Expanded(
                      child: Semantics(
                        selected: settings.preset == item.$1,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => settings.update(quality: item.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: settings.preset == item.$1
                                  ? Colors.white.withValues(alpha: .10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: settings.preset == item.$1
                                    ? Colors.white30
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              item.$2,
                              style: TextStyle(
                                color: settings.preset == item.$1
                                    ? _ink
                                    : _muted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text('自动调节', style: TextStyle(color: _ink, fontSize: 16)),
            ),
            Switch.adaptive(
              value: settings.adaptive,
              activeTrackColor: const Color(0xFFA8CFC4),
              activeThumbColor: const Color(0xFF203C35),
              inactiveThumbColor: _muted,
              inactiveTrackColor: Colors.white12,
              onChanged: (value) => settings.update(automatic: value),
            ),
          ],
        ),
        if (settings.saveError != null)
          Text(
            settings.saveError!,
            style: const TextStyle(color: Color(0xFFFFC6AB), fontSize: 12),
          ),
      ],
    ),
  );
}

class MyLearningPage extends StatefulWidget {
  const MyLearningPage({
    super.key,
    required this.settings,
    required this.lesson,
    this.account,
    this.onLeave,
    this.loadSummary,
  });
  final AppSettings settings;
  final LessonController lesson;
  final LearnerAccount? account;
  final Future<void> Function()? onLeave;
  final Future<Map<String, dynamic>> Function()? loadSummary;
  @override
  State<MyLearningPage> createState() => _MyLearningPageState();
}

class _MyLearningPageState extends State<MyLearningPage> {
  Timer? ticker;
  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  String get sessionTime {
    final duration = widget.account == null
        ? Duration.zero
        : AppSessionClock.elapsed;
    final seconds = duration.inSeconds.clamp(0, 999999999);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  late Future<Map<String, dynamic>?> summary = _load();
  Future<Map<String, dynamic>?> _load() async {
    if (widget.account == null) return null;
    if (widget.loadSummary != null) return widget.loadSummary!();
    final api = AuthApi();
    try {
      return await api.request('learning/summary');
    } finally {
      api.dispose();
    }
  }

  Widget metric(
    String value,
    String label, {
    bool time = false,
    Key? valueKey,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: time ? 30 : 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              key: valueKey,
              style: TextStyle(
                color: _ink,
                fontSize: time ? 24 : 30,
                fontWeight: FontWeight.w300,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
    ],
  );
  Widget _stats(Map<String, dynamic>? data) {
    final trend = (data?['trend'] as List? ?? []).cast<Map>();
    final maxMs = trend.fold<double>(
      60000,
      (n, r) => (r['learningMs'] as num).toDouble() > n
          ? (r['learningMs'] as num).toDouble()
          : n,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('学习时长', style: TextStyle(color: _ink, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          key: const ValueKey('duration-metrics'),
          children: [
            Expanded(
              child: metric(
                sessionTime,
                '本次',
                time: true,
                valueKey: const ValueKey('session-duration'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: metric(
                data == null
                    ? '—'
                    : ((data['learningMs'] as num) / 3600000).toStringAsFixed(
                        2,
                      ),
                '累计 · 小时',
                time: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: metric(
                data == null
                    ? '—'
                    : (data['averageDailyHours'] as num).toStringAsFixed(2),
                '近7日日均 · 小时',
                time: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          key: const ValueKey('content-metrics'),
          children: [
            Expanded(
              child: metric(data?['chapters']?.toString() ?? '—', '探索分类'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: metric(data?['courses']?.toString() ?? '—', '学过课程'),
            ),
            const SizedBox(width: 12),
            Expanded(child: metric(data?['words']?.toString() ?? '—', '接触单词')),
          ],
        ),
        if (data != null) ...[
          const SizedBox(height: 10),
          Text(
            '已完成 ${data['completedCourses']} 节课',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ],
        if (data != null) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text('近7天', style: TextStyle(color: _ink, fontSize: 14)),
              ),
              Text(
                '累计学习 ${data['learningDays']} 天',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in trend)
                  Expanded(
                    child: Semantics(
                      label:
                          '${day['date']}，学习 ${((day['learningMs'] as num) / 60000).toStringAsFixed(1)} 分钟',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 14,
                            height: 3 + 36 * (day['learningMs'] as num) / maxMs,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA8CFC4).withValues(
                                alpha: (day['learningMs'] as num) > 0
                                    ? .85
                                    : .16,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (day['date'] as String)
                                .substring(5)
                                .replaceAll('-', '/'),
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          const Text(
            '登录后查看学习记录',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _creditLink(String label, String url) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: _muted,
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 44),
    ),
    onPressed: () async {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
      }
    },
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColoredBox(
          color: const Color(0xFF111D26).withValues(alpha: .48),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 3, 10, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '我的',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭我的',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: _ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: true),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _NicknameField(lesson: widget.lesson),
                                if (widget.account != null)
                                  Text(
                                    widget.account!.phoneMasked,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: summary,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const SizedBox(
                                        height: 240,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _muted,
                                          ),
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return TextButton(
                                        onPressed: () =>
                                            setState(() => summary = _load()),
                                        child: const Text(
                                          '学习记录暂未同步，点击重试',
                                          style: TextStyle(color: _muted),
                                        ),
                                      );
                                    }
                                    return _stats(snapshot.data);
                                  },
                                ),
                                const SizedBox(height: 18),
                                const Divider(height: 1, color: Colors.white12),
                                Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    iconColor: _muted,
                                    collapsedIconColor: _muted,
                                    title: const Text(
                                      '画面设置',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    children: [
                                      _DisplayPreferences(
                                        settings: widget.settings,
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.onLeave != null)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: _muted,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(64, 48),
                                      alignment: Alignment.centerLeft,
                                    ),
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      Navigator.pop(context, true);
                                      try {
                                        await widget.onLeave!();
                                      } catch (_) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('暂时无法退出，请稍后重试'),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      widget.account == null ? '登录' : '退出登录',
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                const Text(
                                  '鸣谢',
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Storm Rig (CC) Blender Foundation | studio.blender.org',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                                const Text(
                                  'Storm v1.1 · 已作格式转换、材质及动画适配',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    height: 1.6,
                                  ),
                                ),
                                Wrap(
                                  spacing: 16,
                                  children: [
                                    _creditLink(
                                      '模型来源',
                                      'https://studio.blender.org/characters/storm/v1/',
                                    ),
                                    _creditLink(
                                      'CC BY 4.0',
                                      'https://creativecommons.org/licenses/by/4.0/',
                                    ),
                                    _creditLink(
                                      'CMU 发音词典与许可',
                                      'https://github.com/cmusphinx/cmudict/blob/master/LICENSE',
                                    ),
                                    _creditLink(
                                      '独立音素参考 · CC0',
                                      'https://github.com/NewDanishPhonetics/IPA-sound-files',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    style: const TextStyle(
      color: _ink,
      fontSize: 30,
      fontWeight: FontWeight.w600,
    ),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => save(),
    decoration: InputDecoration(
      hintText: '昵称',
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      counterText: '',
      suffixIcon: IconButton(
        tooltip: '保存昵称',
        onPressed: busy ? null : save,
        icon: const Icon(Icons.check_rounded, color: _ink),
      ),
    ),
  );
}
