import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../lesson/presentation/lesson_page.dart';
import 'auth_api.dart';
import '../lesson/application/learning_sync.dart';
import 'world_loading.dart';
import 'entry_design.dart';
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
  bool waitingForScene = false;
  bool pendingGuest = false;
  bool testMode = false;
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
      shared.ready = true;
      shared.scenePresented = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => hideBootSplash());
    shared.resourceTick.addListener(_sceneChanged);
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
      testMode = results[0]['testMode'] == true;
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
      if (mounted) {
        setState(() {
          busy = false;
          if (error.isNotEmpty) waitingForScene = false;
        });
        _sceneChanged();
      }
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
    if (!(testMode ? RegExp(r'^\d{4}$') : RegExp(r'^\d{6}$')).hasMatch(
      code.text,
    )) {
      throw AuthFailure(testMode ? '请输入 4 位测试验证码' : '请输入 6 位验证码');
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
    nickname.clear();
    _go(1);
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
    FocusManager.instance.primaryFocus?.unfocus();
    if (!shared.scenePresented) {
      setState(() {
        waitingForScene = true;
        pendingGuest = guest;
      });
      return;
    }
    if (guest || Uri.base.queryParameters['adminPreview'] == '1') user = null;
    if (user != null) await restoreCloudLearning(user!.id);
    await shared.bindAccount(
      id: user?.id ?? '',
      name: user?.nickname,
      saveName: user == null ? null : api.rename,
    );
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    if (mounted) {
      setLessonMode(true);
      setState(() {
        inLesson = true;
        waitingForScene = false;
      });
    }
  });
  void _sceneChanged() {
    if (waitingForScene && !busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && waitingForScene && shared.scenePresented && !busy) {
          _enterLesson(guest: pendingGuest);
        }
      });
    }
  }

  void _retryScene() {
    shared.resetResources();
    setState(() {
      sceneAttempt++;
    });
  }

  Future<void> _leave() async {
    shared.stop();
    setLessonMode(false);
    if (user != null) await api.logout();
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    if (!mounted) return;
    setState(() {
      user = null;
      newlyRegistered = false;
      inLesson = false;
      waitingForScene = false;
      timer?.cancel();
      cooldown = 0;
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
    shared.resourceTick.removeListener(_sceneChanged);
    shared.dispose();
    nickname.dispose();
    phone.dispose();
    code.dispose();
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: entryPaper,
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
        if (inLesson)
          Positioned.fill(
            child: LessonPage(
              key: ValueKey(user?.id ?? 'guest'),
              account: user,
              auth: api,
              onLeave: _leave,
              sharedController: shared,
            ),
          )
        else if (waitingForScene)
          Positioned.fill(
            child: WorldLoading(
              controller: shared,
              retry: _retryScene,
              cancel: () => setState(() => waitingForScene = false),
            ),
          )
        else
          Positioned.fill(
            child: ColoredBox(
              color: entryPaper,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 760;
                    final keyboard =
                        MediaQuery.viewInsetsOf(context).bottom > 0;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 48 : 26,
                        18,
                        wide ? 48 : 26,
                        20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: mathMax(0, box.maxHeight - 38),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const EntryBrand(),
                                if (step > 0 && step < 4)
                                  IconButton(
                                    tooltip: '返回',
                                    onPressed: busy ? null : _back,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: entryInk,
                                      size: 21,
                                    ),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Text(
                                      'EN / 中文',
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1,
                                        color: entryMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(
                              height: keyboard || box.maxHeight < 650 ? 12 : 30,
                            ),
                            if (step == 0)
                              _welcome(wide, box.maxHeight)
                            else
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 250),
                                    child: _form(
                                      keyboard || box.maxHeight < 500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    ),
  );

  double mathMax(double a, double b) => a > b ? a : b;

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (step == 3 || step == 1) {
      registrationToken = '';
      _go(2);
    } else {
      _go(0);
    }
  }

  Widget _welcome(bool wide, double height) {
    final compact = height < 650;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LESS SCROLLING. MORE SPEAKING.',
          style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: entryMuted),
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          '把英语，\n说进生活。',
          style: TextStyle(
            color: entryInk,
            fontSize: compact ? 34 : (wide ? 52 : 40),
            height: 1.2,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 10 : 15),
        const Text(
          '一个单词，一句表达。\n和你的学习伙伴，从容开口。',
          style: TextStyle(color: entryMuted, fontSize: 14, height: 1.8),
        ),
        SizedBox(height: compact ? 18 : 30),
        EntryButton(
          loading ? '正在连接' : '开始我的学习',
          busy: loading,
          onPressed: () {
            login = false;
            _go(2);
          },
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      login = true;
                      _go(2);
                    },
              child: const Text('已有账号，登录'),
            ),
            TextButton(
              onPressed: busy || loading
                  ? null
                  : () => _enterLesson(guest: true),
              child: const Text('先体验课程'),
            ),
          ],
        ),
        if (error.isNotEmpty) _error(),
      ],
    );
    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: entryMuted,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ),
      child: wide
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 0 : 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: compact ? 240 : 350,
                      child: const HelloComposition(),
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: copy,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: (height * (compact ? .24 : .31)).clamp(120, 290),
                  child: const HelloComposition(),
                ),
                SizedBox(height: compact ? 16 : 28),
                copy,
              ],
            ),
    );
  }

  Widget _form(bool keyboard) => Column(
    key: ValueKey(step),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!keyboard) ...[
        const SizedBox(height: 12),
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: step == 4 ? entryLime : const Color(0xFFE8E8DE),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Icon(
            switch (step) {
              1 => Icons.person_outline_rounded,
              3 => Icons.password_rounded,
              4 => Icons.check_rounded,
              _ => Icons.phone_iphone_rounded,
            },
            color: entryInk,
            size: 27,
          ),
        ),
        const SizedBox(height: 32),
      ],
      Text(
        switch (step) {
          1 => 'MAKE IT YOURS',
          3 => 'ONE MORE STEP',
          4 => 'READY WHEN YOU ARE',
          _ => 'YOUR LEARNING SPACE',
        },
        style: const TextStyle(
          color: entryMuted,
          fontSize: 10,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 12),
      if (step == 2) ...[
        _title(login ? '欢迎回来。' : '从这里开始。'),
        _hint('用手机号登录或注册，\n让每一次进步都有记录。'),
        _input(
          phone,
          '手机号',
          maxLength: 11,
          digits: true,
          prefix: '+86  ',
          action: TextInputAction.done,
          submit: () {
            if ((smsReady || testMode) && cooldown == 0) _send();
          },
          autofill: const [AutofillHints.telephoneNumberNational],
        ),
        const SizedBox(height: 24),
        EntryButton(
          cooldown > 0 ? '${cooldown}s 后可重发' : '获取验证码',
          busy: busy,
          onPressed: (!smsReady && !testMode) || cooldown > 0 ? null : _send,
        ),
        const SizedBox(height: 20),
        if (testMode)
          _testNotice()
        else if (!smsReady)
          _hint('短信登录暂未开放，可以先体验课程。'),
        const SizedBox(height: 12),
        const Text(
          '仅用于登录和保存学习进度，手机号不会公开。',
          style: TextStyle(color: entryMuted, fontSize: 11, height: 1.7),
        ),
      ],
      if (step == 3) ...[
        _title('输入验证码。'),
        _hint(
          testMode
              ? '正在验证 +86 ${_maskedPhone()}\n本次使用测试验证码，无需接收短信。'
              : '验证码已发送至\n+86 ${_maskedPhone()}',
        ),
        _input(
          code,
          testMode ? '4 位测试验证码' : '6 位验证码',
          maxLength: testMode ? 4 : 6,
          digits: true,
          action: TextInputAction.done,
          submit: _verify,
          autofill: const [AutofillHints.oneTimeCode],
        ),
        const SizedBox(height: 24),
        EntryButton('验证并继续', busy: busy, onPressed: _verify),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy || cooldown > 0 ? null : _send,
          style: TextButton.styleFrom(foregroundColor: entryMuted),
          child: Text(cooldown > 0 ? '${cooldown}s 后重新获取' : '重新获取验证码'),
        ),
        if (testMode) _testNotice(),
      ],
      if (step == 1) ...[
        _title('怎么称呼你？'),
        _hint('只差一个名字，\n你的专属课堂就准备好了。'),
        _input(
          nickname,
          '你的昵称',
          maxLength: 12,
          action: TextInputAction.done,
          submit: _nextName,
          autofill: const [AutofillHints.nickname],
        ),
        const SizedBox(height: 24),
        EntryButton('完成注册', busy: busy, onPressed: _nextName),
      ],
      if (step == 4 && user != null) ...[
        _title('${user!.nickname}，\n${newlyRegistered ? '很高兴认识你。' : '欢迎回来。'}'),
        _hint(
          newlyRegistered ? '从一个单词开始，\n慢慢说出自己的世界。' : '你的学习进度已为你保留。\n今天，也向前一点。',
        ),
        const SizedBox(height: 20),
        EntryButton('进入课堂', busy: busy, onPressed: () => _enterLesson()),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy ? null : () => _perform(_leave),
          style: TextButton.styleFrom(foregroundColor: entryMuted),
          child: const Text('换个账号'),
        ),
      ],
      if (error.isNotEmpty) _error(),
    ],
  );

  String _maskedPhone() => phone.text.length == 11
      ? '${phone.text.substring(0, 3)} **** ${phone.text.substring(7)}'
      : phone.text;
  Widget _testNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDDB),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.science_outlined, size: 16, color: entryMuted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '测试体验 · 验证码 8888',
            style: TextStyle(color: entryMuted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
  Widget _error() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Semantics(
      liveRegion: true,
      child: Text(
        error,
        style: const TextStyle(
          color: Color(0xFFAD4F38),
          fontSize: 13,
          height: 1.6,
        ),
      ),
    ),
  );
  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: const TextStyle(
        color: entryInk,
        fontSize: 34,
        height: 1.25,
        letterSpacing: -1,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Text(
      text,
      style: const TextStyle(color: entryMuted, fontSize: 14, height: 1.8),
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
    keyboardType: digits ? TextInputType.number : TextInputType.name,
    textInputAction: action,
    autofillHints: autofill,
    inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
    onSubmitted: (_) => submit(),
    cursorColor: entryInk,
    style: const TextStyle(color: entryInk, fontSize: 23, letterSpacing: 2),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: entryMuted,
        fontSize: 14,
        letterSpacing: 0,
      ),
      floatingLabelStyle: const TextStyle(color: entryMuted),
      prefixText: prefix,
      prefixStyle: const TextStyle(color: entryMuted, fontSize: 17),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFEAEAE2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 23),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF8A9672), width: 1),
      ),
    ),
  );
}
