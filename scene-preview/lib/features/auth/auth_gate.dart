import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lesson/presentation/lesson_page.dart';
import 'auth_api.dart';
import 'world_loading.dart';
import 'world_browser_stub.dart'
    if (dart.library.js_interop) 'world_browser_web.dart';
import '../../core/avatar/avatar_view.dart';
import '../lesson/application/lesson_controller.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.api, this.prepareScene = true});
  final bool prepareScene;
  final AuthApi? api;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final shared = LessonController();
  int sceneAttempt = 0;
  bool introRevealed = false;
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
    if (!widget.prepareScene) {
      introRevealed = true;
      shared.ready = true;
      shared.scenePresented = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => hideBootSplash());
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

  Future<void> _enterLesson({bool guest = false}) => _perform(() async {
    if (!shared.scenePresented) return;
    if (guest) user = null;
    await shared.bindAccount(
      id: user?.id ?? '',
      name: user?.nickname,
      saveName: user == null ? null : api.rename,
    );
    if (mounted) {
      setLessonMode(true);
      setState(() => inLesson = true);
    }
  });
  void _retryScene() {
    shared.resetResources();
    setState(() {
      sceneAttempt++;
      introRevealed = false;
    });
  }

  Future<void> _leave() async {
    shared.stop();
    setLessonMode(false);
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
    shared.dispose();
    nickname.dispose();
    phone.dispose();
    code.dispose();
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: shared.resourceTick,
    builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFF073645),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.prepareScene)
            Positioned.fill(
              child: AvatarView(
                key: ValueKey(sceneAttempt),
                controller: shared,
                welcome: !inLesson,
              ),
            ),
          if (shared.scenePresented && inLesson)
            Positioned.fill(
              child: LessonPage(
                key: ValueKey(user?.id ?? 'guest'),
                account: user,
                auth: api,
                onLeave: _leave,
                sharedController: shared,
              ),
            ),
          if (shared.scenePresented && !inLesson)
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  final portrait = box.maxWidth < 600;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: portrait ? 22 : 44,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (box.maxHeight - 40).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: portrait
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _brand(true),
                                SizedBox(
                                  height:
                                      MediaQuery.viewInsetsOf(context).bottom >
                                          0
                                      ? 12
                                      : box.maxHeight * .27,
                                ),
                                _form(),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: (box.maxHeight - 40).clamp(
                                      0,
                                      double.infinity,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: _brand(false),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                SizedBox(
                                  width: (box.maxWidth * .46).clamp(320, 450),
                                  child: _form(),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          if (!introRevealed)
            Positioned.fill(
              child: ExcludeSemantics(
                excluding: shared.scenePresented,
                child: IgnorePointer(
                  ignoring: shared.scenePresented,
                  child: AnimatedOpacity(
                    opacity: shared.scenePresented ? 0 : 1,
                    duration: const Duration(milliseconds: 550),
                    onEnd: () {
                      if (shared.scenePresented && mounted) {
                        setState(() => introRevealed = true);
                      }
                    },
                    child: TickerMode(
                      enabled: !shared.scenePresented,
                      child: WorldLoading(
                        controller: shared,
                        retry: _retryScene,
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
  Widget _brand(bool portrait) => Align(
    alignment: Alignment.topLeft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HELLO, WORLD.',
          style: TextStyle(
            fontFamily: 'NotoSansIPA',
            fontSize: portrait ? 26 : 38,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: const Color(0xFFFFE4A0),
            shadows: const [
              Shadow(color: Color(0xFF07545E), offset: Offset(0, 3)),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '把英语，说进生活',
          style: TextStyle(
            color: const Color(0xFFDCF1E8),
            fontSize: portrait ? 13 : 17,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
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
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
      decoration: BoxDecoration(
        color: const Color(0xF20B3543),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x406CE2CD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40001724),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step > 0 && step < 4) ...[
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB4DED2),
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
                            ? const Color(0xFFB4DED2)
                            : const Color(0xFF255562),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (step == 0) ...[
            _title('你好，新伙伴'),
            _hint('从一个单词开始，\n和我一起，把英语说出来。'),
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
                  foregroundColor: const Color(0xFFB4DED2),
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
                  foregroundColor: const Color(0xFFB4DED2),
                ),
                onPressed: () => _enterLesson(guest: true),
                child: const Text(
                  '先体验课程',
                  style: TextStyle(color: Color(0xFFAAC7C6)),
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
                style: TextStyle(fontSize: 13, color: Color(0xFFAAC7C6)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB4DED2),
                ),
                onPressed: () => _enterLesson(guest: true),
                child: const Text('先体验课程'),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              '手机号用于验证身份和找回账号，不在课堂公开。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xFF96B9BA),
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
                foregroundColor: const Color(0xFFB4DED2),
              ),
              onPressed: busy || cooldown > 0 ? null : _send,
              child: Text(cooldown > 0 ? '${cooldown}s 后重新获取' : '重新获取验证码'),
            ),
          ],
          if (step == 4 && user != null) ...[
            _title('${user!.nickname}，${newlyRegistered ? '很高兴认识你' : '欢迎回来'}'),
            _hint(newlyRegistered ? '准备好了，就从第一声英语开始。' : '准备好了，就从这里继续。'),
            _button('进入课堂', () => _enterLesson()),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB4DED2),
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
                    color: Color(0xFFFFC5A2),
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
        color: Color(0xFFF8F5DF),
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
        color: Color(0xFFB5D2D1),
      ),
    ),
  );
  Widget _button(String text, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFCE69),
        elevation: 4,
        shadowColor: const Color(0xFF031E2A),
        foregroundColor: const Color(0xFF34381F),
        disabledBackgroundColor: const Color(0xFF446369),
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
      color: Color(0xFFF8F5DF),
      letterSpacing: 1,
    ),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFBCD8D5)),
      floatingLabelStyle: const TextStyle(color: Color(0xFFFFDE97)),
      prefixText: prefix,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFF174B58),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFFCE69), width: 1.5),
      ),
    ),
  );
}
