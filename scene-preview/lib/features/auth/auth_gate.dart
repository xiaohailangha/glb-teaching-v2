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
  bool loading = true, busy = false, smsReady = false, inLesson = false;
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
    if (mounted) {
      setState(() => loading = false);
      if (user != null) _enterLesson();
    }
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
        if (step == 4 &&
            user != null &&
            !inLesson &&
            !waitingForScene &&
            error.isEmpty) {
          _enterLesson();
        }
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
        // Keep the warmed classroom mounted below the entry surface. Only the
        // surface fades away; no second welcome/success route is inserted.
        if (inLesson)
          Positioned.fill(
            child: LessonPage(
              key: ValueKey(user?.id ?? 'guest'),
              account: user,
              auth: api,
              onLeave: _leave,
              sharedController: shared,
            ),
          ),
        IgnorePointer(
          ignoring: inLesson,
          child: ExcludeSemantics(
            excluding: inLesson,
            child: AnimatedOpacity(
              opacity: inLesson ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 450),
              child: ColoredBox(
                color: entryPaper,
                child: waitingForScene
                    ? WorldLoading(
                        controller: shared,
                        retry: _retryScene,
                        cancel: () => setState(() {
                          waitingForScene = false;
                          if (step == 4) step = 0;
                        }),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (step == 0 || step == 4)
                            _landing()
                          else
                            SafeArea(
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final compact = box.maxHeight < 620;
                                  return SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      28,
                                      24,
                                      28,
                                      24,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 340,
                                        ),
                                        child: Column(
                                          children: [
                                            SizedBox(height: compact ? 0 : 36),
                                            EntryIdentity(compact: true),
                                            SizedBox(height: compact ? 26 : 54),
                                            AnimatedSwitcher(
                                              duration:
                                                  MediaQuery.disableAnimationsOf(
                                                    context,
                                                  )
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 220,
                                                    ),
                                              child: _form(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (step > 0 && step < 4)
                            Positioned(
                              top: MediaQuery.paddingOf(context).top + 10,
                              right: 14,
                              child: IconButton(
                                tooltip: '返回',
                                onPressed: busy ? null : _back,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: entryMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          if (loading || busy)
                            const Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: EntryProgress(),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _landing() => Stack(
    fit: StackFit.expand,
    children: [
      Align(
        alignment: MediaQuery.sizeOf(context).height < 520
            ? const Alignment(0, -.35)
            : Alignment.center,
        child: const EntryIdentity(),
      ),
      Positioned(
        left: 28,
        right: 28,
        bottom: MediaQuery.paddingOf(context).bottom + 28,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AnimatedOpacity(
              opacity: loading ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              child: IgnorePointer(
                ignoring: loading,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step == 0) ...[
                      EntryButton(
                        user == null ? '开始学习' : '继续学习',
                        onPressed: () {
                          if (user == null) {
                            _go(2);
                          } else {
                            _enterLesson();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy || loading
                            ? null
                            : () => _enterLesson(guest: true),
                        style: TextButton.styleFrom(
                          foregroundColor: entryMuted,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('先体验课程'),
                      ),
                    ],
                    if (error.isNotEmpty) ...[
                      _error(),
                      const SizedBox(height: 12),
                      if (step == 4)
                        EntryButton(
                          '重试进入课堂',
                          busy: busy,
                          onPressed: () => _enterLesson(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (step == 3 || step == 1) {
      registrationToken = '';
      _go(2);
    } else {
      _go(0);
    }
  }

  Widget _form() => Column(
    key: ValueKey(step),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (step == 2) ...[
        _title('手机号登录 / 注册'),
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
        const SizedBox(height: 22),
        EntryButton(
          cooldown > 0 ? '${cooldown}s 后可重发' : '获取验证码',
          busy: busy,
          onPressed: (!smsReady && !testMode) || cooldown > 0 ? null : _send,
        ),
        const SizedBox(height: 18),
        if (testMode)
          _testNotice()
        else if (!smsReady)
          const Text(
            '短信登录暂未开放，可以先体验课程。',
            textAlign: TextAlign.center,
            style: TextStyle(color: entryMuted, fontSize: 12),
          ),
      ],
      if (step == 3) ...[
        _title('输入验证码'),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            '+86 ${_maskedPhone()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: entryMuted, fontSize: 13),
          ),
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
        const SizedBox(height: 22),
        EntryButton('验证并继续', busy: busy, onPressed: _verify),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy || cooldown > 0 ? null : _send,
          style: TextButton.styleFrom(
            foregroundColor: entryMuted,
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: Text(cooldown > 0 ? '${cooldown}s 后重新获取' : '重新获取验证码'),
        ),
        if (testMode) _testNotice(),
      ],
      if (step == 1) ...[
        _title('怎么称呼你？'),
        _input(
          nickname,
          '你的昵称',
          maxLength: 12,
          action: TextInputAction.done,
          submit: _nextName,
          autofill: const [AutofillHints.nickname],
        ),
        const SizedBox(height: 22),
        EntryButton('完成注册', busy: busy, onPressed: _nextName),
      ],
      if (error.isNotEmpty) _error(),
    ],
  );

  String _maskedPhone() => phone.text.length == 11
      ? '${phone.text.substring(0, 3)} **** ${phone.text.substring(7)}'
      : phone.text;
  Widget _testNotice() => const Text(
    '测试体验 · 验证码 8888',
    textAlign: TextAlign.center,
    style: TextStyle(color: entryMuted, fontSize: 11),
  );
  Widget _error() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Semantics(
      liveRegion: true,
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFAD4F38),
          fontSize: 12,
          height: 1.6,
        ),
      ),
    ),
  );
  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: entryInk,
        fontSize: 20,
        fontWeight: FontWeight.w500,
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
