import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lesson/presentation/lesson_page.dart';
import 'auth_api.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.api});
  final AuthApi? api;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final api = widget.api ?? AuthApi();
  final nickname = TextEditingController(),
      phone = TextEditingController(),
      code = TextEditingController();
  bool loading = true,
      busy = false,
      smsReady = false,
      login = false,
      inLesson = false;
  bool newlyRegistered = false;
  int step = 0, cooldown = 0;
  DateTime? resendAt;
  String error = '', challenge = '', registrationToken = '';
  LearnerAccount? user;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final results = await Future.wait([
        api.request('status'),
        api.request('me'),
      ]);
      if (!mounted) return;
      smsReady = results[0]['smsReady'] == true;
      if (results[1]['user'] is Map) {
        user = LearnerAccount.fromJson(results[1]['user'] as Map);
        step = 4;
      }
    } catch (_) {
      /* Keep the existing preview available even if auth is unavailable. */
    }
    if (mounted) setState(() => loading = false);
  }

  void _go(int value) {
    setState(() {
      step = value;
      error = '';
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => error = e.message);
        if (e.retryAfter > 0) _countdown(e.retryAfter);
      }
    } catch (_) {
      if (mounted) setState(() => error = '暂时无法完成，请稍后再试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _countdown(int seconds) {
    resendAt = DateTime.now().add(Duration(seconds: seconds));
    cooldown = seconds;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(
        () => cooldown =
            ((resendAt!.difference(DateTime.now()).inMilliseconds + 999) ~/
                    1000)
                .clamp(0, 3600),
      );
      if (cooldown == 0) t.cancel();
    });
  }

  Future<void> _send() => _perform(() async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text.trim())) {
      throw const AuthFailure('请输入正确的手机号');
    }
    final result = await api.request(
      'code',
      method: 'POST',
      data: {'phone': phone.text.trim()},
    );
    if (!mounted) return;
    challenge = result['challengeId'] as String;
    code.clear();
    registrationToken = '';
    _countdown((result['retryAfter'] as num).toInt());
    _go(3);
  });
  Future<void> _verify() => _perform(() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text)) {
      throw const AuthFailure('请输入 6 位验证码');
    }
    final result = await api.request(
      'verify',
      method: 'POST',
      data: {'challengeId': challenge, 'code': code.text},
    );
    if (!mounted) return;
    if (result['user'] is Map) {
      user = LearnerAccount.fromJson(result['user'] as Map);
      _go(4);
      return;
    }
    registrationToken = result['registrationToken'] as String;
    if (!login && nickname.text.trim().isNotEmpty) {
      await _register();
    } else {
      _go(1);
    }
  });
  Future<void> _register() async {
    final result = await api.request(
      'register',
      method: 'POST',
      data: {
        'registrationToken': registrationToken,
        'nickname': nickname.text.trim(),
      },
    );
    if (!mounted) return;
    user = LearnerAccount.fromJson(result['user'] as Map);
    newlyRegistered = true;
    _go(4);
  }

  void _nextName() {
    if (nickname.text.trim().isEmpty) {
      setState(() => error = '告诉我怎么称呼你吧');
      return;
    }
    if (registrationToken.isNotEmpty) {
      _perform(_register);
    } else {
      _go(2);
    }
  }

  Future<void> _leave() async {
    if (user != null) await api.logout();
    if (!mounted) return;
    setState(() {
      user = null;
      newlyRegistered = false;
      inLesson = false;
      step = 0;
      error = '';
      nickname.clear();
      phone.clear();
      code.clear();
      registrationToken = '';
      challenge = '';
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    nickname.dispose();
    phone.dispose();
    code.dispose();
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (inLesson) {
      return LessonPage(
        key: ValueKey(user?.id ?? 'guest'),
        account: user,
        auth: api,
        onLeave: _leave,
      );
    }
    final narrow = MediaQuery.sizeOf(context).width < 680;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 28 : 64,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (box.maxHeight - 48).clamp(0, double.infinity),
              ),
              child: Center(
                child: SizedBox(
                  width: 980,
                  child: narrow
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _art(true),
                            const SizedBox(height: 28),
                            _form(),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _art(false)),
                            const SizedBox(width: 76),
                            Expanded(child: _form()),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _art(bool small) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        label: '从小小的开口开始',
        child: SizedBox(
          height: small ? 105 : 230,
          width: small ? 160 : 300,
          child: CustomPaint(painter: _WelcomeArt()),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '开口，\n就是开始。',
        style: TextStyle(
          fontSize: small ? 32 : 46,
          height: 1.22,
          letterSpacing: -1.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF243D36),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        '每一次尝试，都算数。',
        style: TextStyle(fontSize: 15, color: Color(0xFF718179)),
      ),
    ],
  );
  Widget _form() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 280),
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.centerLeft,
      children: [
        for (final child in previous)
          IgnorePointer(child: ExcludeSemantics(child: child)),
        ?current,
      ],
    ),
    child: Container(
      key: ValueKey(step),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step > 0 && step < 4) ...[
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF537A65),
              ),
              onPressed: busy
                  ? null
                  : () {
                      if (registrationToken.isNotEmpty) {
                        registrationToken = '';
                        _go(2);
                      } else {
                        _go(step == 2 && login ? 0 : step - 1);
                      }
                    },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('返回'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 1; i <= 3; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? const Color(0xFF537A65)
                            : const Color(0xFFE2E7DE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (step == 0) ...[
            _title('很高兴认识你'),
            _hint('一个昵称，一个手机号。\n把每一次进步，留在你的名字下。'),
            _button(
              loading ? '正在准备' : '开始我的学习',
              loading
                  ? null
                  : () {
                      login = false;
                      _go(1);
                    },
            ),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF537A65),
                ),
                onPressed: loading
                    ? null
                    : () {
                        login = true;
                        nickname.clear();
                        _go(2);
                      },
                child: const Text('已有账号，登录'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF537A65),
                ),
                onPressed: () => setState(() {
                  user = null;
                  inLesson = true;
                }),
                child: const Text(
                  '先体验课程',
                  style: TextStyle(color: Color(0xFF7C887F)),
                ),
              ),
            ),
          ],
          if (step == 1) ...[
            _title('怎么称呼你？'),
            _hint('课堂里，我会这样叫你。'),
            _input(
              nickname,
              '你的昵称',
              maxLength: 12,
              action: TextInputAction.next,
              submit: _nextName,
            ),
            const SizedBox(height: 24),
            _button(
              registrationToken.isEmpty ? '下一步' : '开始学习',
              busy ? null : _nextName,
            ),
          ],
          if (step == 2) ...[
            _title(login ? '欢迎回来' : '${nickname.text.trim()}，你好'),
            _hint('用手机号验证身份，不用记密码。'),
            _input(
              phone,
              '手机号',
              maxLength: 11,
              digits: true,
              prefix: '+86  ',
              action: TextInputAction.done,
              submit: () {
                if (smsReady && cooldown == 0) _send();
              },
            ),
            const SizedBox(height: 24),
            _button(
              busy
                  ? '正在发送'
                  : cooldown > 0
                  ? '${cooldown}s 后可重发'
                  : '获取验证码',
              busy || !smsReady || cooldown > 0 ? null : _send,
            ),
            if (!smsReady) ...[
              const SizedBox(height: 16),
              const Text(
                '短信登录即将开放，你可以先体验课程。',
                style: TextStyle(fontSize: 13, color: Color(0xFF7C887F)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF537A65),
                ),
                onPressed: () => setState(() {
                  user = null;
                  inLesson = true;
                }),
                child: const Text('先体验课程'),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              '手机号用于验证身份和找回账号，不在课堂公开。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF839087),
              ),
            ),
          ],
          if (step == 3) ...[
            _title('输入验证码'),
            _hint(
              '已发送至 +86 ${phone.text.substring(0, 3)} **** ${phone.text.substring(7)}',
            ),
            _input(
              code,
              '6 位验证码',
              maxLength: 6,
              digits: true,
              action: TextInputAction.done,
              submit: _verify,
              autofill: const [AutofillHints.oneTimeCode],
            ),
            const SizedBox(height: 24),
            _button(busy ? '正在验证' : '验证并继续', busy ? null : _verify),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF537A65),
              ),
              onPressed: busy || cooldown > 0 ? null : _send,
              child: Text(cooldown > 0 ? '${cooldown}s 后重新获取' : '重新获取验证码'),
            ),
          ],
          if (step == 4 && user != null) ...[
            _title('${user!.nickname}，${newlyRegistered ? '很高兴认识你' : '欢迎回来'}'),
            _hint(newlyRegistered ? '准备好了，就从第一声英语开始。' : '准备好了，就从这里继续。'),
            _button('进入课堂', () => setState(() => inLesson = true)),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF537A65),
              ),
              onPressed: busy ? null : () => _perform(_leave),
              child: const Text('换个账号'),
            ),
          ],
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Color(0xFFA6533D),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 28,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: Color(0xFF243D36),
      ),
    ),
  );
  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.8,
        color: Color(0xFF718179),
      ),
    ),
  );
  Widget _button(String text, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF355F4C),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFDDE4DC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
  );
  Widget _input(
    TextEditingController controller,
    String label, {
    required int maxLength,
    bool digits = false,
    String? prefix,
    required TextInputAction action,
    required VoidCallback submit,
    Iterable<String>? autofill,
  }) => TextField(
    controller: controller,
    maxLength: maxLength,
    enabled: !busy,
    keyboardType: digits ? TextInputType.phone : TextInputType.name,
    textInputAction: action,
    autofillHints: autofill,
    inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
    onSubmitted: (_) => submit(),
    style: const TextStyle(
      fontSize: 21,
      color: Color(0xFF243D36),
      letterSpacing: 1,
    ),
    decoration: InputDecoration(
      labelText: label,
      prefixText: prefix,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF7E9E83), width: 1.5),
      ),
    ),
  );
}

class _WelcomeArt extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 230);
    final p = Paint();
    canvas.drawCircle(
      const Offset(133, 117),
      95,
      p..color = const Color(0xFFE9EDDC),
    );
    canvas.drawCircle(
      const Offset(236, 45),
      24,
      p..color = const Color(0xFFF0CD75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(35, 67, 168, 103),
        const Radius.circular(36),
      ),
      p..color = const Color(0xFF70937D),
    );
    canvas.drawPath(
      Path()
        ..moveTo(66, 157)
        ..lineTo(67, 190)
        ..quadraticBezierTo(100, 178, 111, 157)
        ..close(),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(139, 128, 115, 70),
        const Radius.circular(26),
      ),
      p..color = const Color(0xFFDCE6D2),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(83 + i * 35, 118),
        6,
        p..color = const Color(0xFFF9F9F2),
      );
    }
    canvas.drawArc(
      const Rect.fromLTWH(170, 147, 49, 26),
      .2,
      2.7,
      false,
      p
        ..color = const Color(0xFF5E7965)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
