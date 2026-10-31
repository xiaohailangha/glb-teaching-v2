import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../lesson/presentation/lesson_page.dart';
import 'auth_api.dart';
import '../lesson/application/learning_sync.dart';
import 'entry_design.dart';
import 'world_browser_stub.dart'
    if (dart.library.js_interop) 'world_browser_web.dart';
import '../../core/avatar/avatar_view.dart';
import '../lesson/application/lesson_controller.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.api,
    this.prepareScene = true,
    this.controller,
  });
  final bool prepareScene;
  final LessonController? controller;
  final AuthApi? api;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final shared = widget.controller ?? LessonController();
  int sceneAttempt = 0;
  bool waitingForScene = false;
  bool pendingGuest = false;
  bool testMode = false;
  late final api = widget.api ?? AuthApi();
  final nickname = TextEditingController(),
      phone = TextEditingController(),
      code = TextEditingController();
  final phoneFocus = FocusNode(),
      codeFocus = FocusNode(),
      nameFocus = FocusNode();
  bool loading = true, busy = false, smsReady = false, inLesson = false;
  int step = 0, cooldown = 0;
  double slideDirection = 1;
  bool revealingPhone = false;
  DateTime? resendAt, challengeUntil, proofUntil;
  String sentPhone = '', verifiedCode = '';
  bool authReady = false;
  String error = '', challenge = '', registrationToken = '';
  LearnerAccount? user;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (!widget.prepareScene && widget.controller == null) {
      shared.ready = true;
      shared.scenePresented = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => hideBootSplash());
    shared.resourceTick.addListener(_sceneChanged);
    phone.addListener(_inputChanged);
    code.addListener(_inputChanged);
    nickname.addListener(_inputChanged);
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
      authReady = true;
      if (results[1]['user'] is Map) {
        user = LearnerAccount.fromJson(results[1]['user'] as Map);
      }
    } catch (_) {
      error = '连接未完成，请重试';
    }
    if (mounted) {
      setState(() => loading = false);
      _sceneChanged();
    }
  }

  void _inputChanged() {
    if (mounted) {
      setState(() {
        error = '';
      });
    }
  }

  void _go(int value, {bool backwards = false}) {
    final transferFocus = step != 0 && value != 4;
    if (value == 4) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      revealingPhone = step == 0 && value == 2;
      slideDirection = backwards ? -1 : 1;
      step = value;
      error = '';
    });
    if (transferFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && step == value) {
          (value == 2 ? phoneFocus : (value == 3 ? codeFocus : nameFocus))
              .requestFocus();
        }
      });
    }
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

  Future<void> _send({bool resend = false}) => _perform(() async {
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text.trim())) {
      throw const AuthFailure('请输入正确的手机号');
    }
    if (!resend &&
        sentPhone == phone.text.trim() &&
        challenge.isNotEmpty &&
        challengeUntil != null &&
        DateTime.now().isBefore(challengeUntil!)) {
      _go(3);
      return;
    }
    final result = await api.request(
      'code',
      method: 'POST',
      data: {'phone': phone.text.trim()},
    );
    if (!mounted) return;
    challenge = result['challengeId'] as String;
    sentPhone = phone.text.trim();
    challengeUntil = DateTime.now().add(
      Duration(seconds: (result['expiresIn'] as num?)?.toInt() ?? 300),
    );
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
    if (registrationToken.isNotEmpty &&
        code.text == verifiedCode &&
        proofUntil != null &&
        DateTime.now().isBefore(proofUntil!)) {
      _go(1);
      return;
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
    verifiedCode = code.text;
    proofUntil = DateTime.now().add(const Duration(minutes: 5));
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
    // Resource events notify before the controller updates its fields.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || inLesson) return;
      if (step == 0 && authReady && shared.scenePresented && !busy) {
        if (user != null) {
          _go(4);
          _enterLesson();
        } else {
          _go(2);
        }
      } else if (waitingForScene && shared.scenePresented && !busy) {
        _enterLesson(guest: pendingGuest);
      }
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _retryScene() {
    if (!authReady) {
      setState(() {
        loading = true;
        error = '';
      });
      _restore();
    }
    if (shared.error == null && shared.scenePresented) return;
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
      sentPhone = '';
    });
    _sceneChanged();
  }

  @override
  void dispose() {
    timer?.cancel();
    shared.resourceTick.removeListener(_sceneChanged);
    if (widget.controller == null) shared.dispose();
    phoneFocus.dispose();
    codeFocus.dispose();
    nameFocus.dispose();
    nickname.dispose();
    phone.dispose();
    code.dispose();
    if (widget.api == null) api.dispose();
    super.dispose();
  }

  bool get phoneValid => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone.text.trim());
  bool get codeValid =>
      RegExp(testMode ? r'^\d{4}$' : r'^\d{6}$').hasMatch(code.text);
  bool get nameValid => nickname.text.trim().isNotEmpty;
  bool get canSend =>
      (smsReady || testMode) &&
      (phone.text.trim() != sentPhone || cooldown == 0 || challenge.isNotEmpty);

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
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
          ),
        IgnorePointer(
          ignoring: inLesson,
          child: ExcludeSemantics(
            excluding: inLesson,
            child: AnimatedOpacity(
              opacity: inLesson ? 0 : 1,
              duration: _duration(500),
              child: TickerMode(
                enabled: !inLesson,
                child: ColoredBox(
                  color: entryPaper,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SafeArea(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final guided = step != 0 && step != 4;
                            final h = box.maxHeight;
                            final compact = h < 700;
                            final panelHeight = compact ? 202.0 : 264.0;
                            final panelTop = math.max(
                              0.0,
                              math.min(
                                h * (compact ? .24 : .34),
                                h - panelHeight - 8,
                              ),
                            );
                            final scale = step == 0
                                ? 1.0
                                : (h < 360 ? .44 : (compact ? .58 : .76));
                            final identityTop = step == 0
                                ? (h - 120) / 2
                                : math.max(
                                        2.0,
                                        panelTop -
                                            120 * scale -
                                            (compact ? 6 : 32),
                                      ) -
                                      (120 - 120 * scale) / 2;
                            return ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AnimatedPositioned(
                                    duration: _duration(750),
                                    curve: Curves.easeInOutCubic,
                                    top: identityTop,
                                    left: (box.maxWidth - 240) / 2,
                                    width: 240,
                                    height: 120,
                                    child: AnimatedScale(
                                      scale: scale,
                                      duration: _duration(750),
                                      curve: Curves.easeInOutCubic,
                                      child: const EntryIdentity(
                                        key: ValueKey('guide-identity'),
                                      ),
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: _duration(750),
                                    curve: Curves.easeInOutCubic,
                                    top: step == 0 ? h + 24 : panelTop,
                                    left: 24,
                                    right: 24,
                                    height: panelHeight,
                                    child: IgnorePointer(
                                      ignoring: !guided,
                                      child: AnimatedOpacity(
                                        opacity: 1,
                                        duration: Duration.zero,
                                        curve: Curves.easeOutCubic,
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 340,
                                            ),
                                            child: AnimatedSwitcher(
                                              duration: _duration(600),
                                              reverseDuration: _duration(600),
                                              layoutBuilder:
                                                  (
                                                    current,
                                                    previous,
                                                  ) => ClipRect(
                                                    child: Stack(
                                                      alignment:
                                                          Alignment.topCenter,
                                                      children: [
                                                        for (final child
                                                            in previous)
                                                          IgnorePointer(
                                                            child:
                                                                ExcludeSemantics(
                                                                  child: child,
                                                                ),
                                                          ),
                                                        ?current,
                                                      ],
                                                    ),
                                                  ),
                                              transitionBuilder:
                                                  (
                                                    child,
                                                    animation,
                                                  ) => AnimatedBuilder(
                                                    animation: animation,
                                                    child: child,
                                                    builder: (_, child) {
                                                      if (revealingPhone) {
                                                        return child!;
                                                      }
                                                      final exiting =
                                                          animation.status ==
                                                          AnimationStatus
                                                              .reverse;
                                                      final t = Curves
                                                          .easeInOutCubic
                                                          .transform(
                                                            animation.value,
                                                          );
                                                      return Transform.translate(
                                                        offset: Offset(
                                                          0,
                                                          slideDirection *
                                                              (exiting
                                                                  ? -panelHeight
                                                                  : panelHeight) *
                                                              (1 - t),
                                                        ),
                                                        child: child,
                                                      );
                                                    },
                                                  ),
                                              child: guided
                                                  ? _form(compact)
                                                  : const SizedBox(
                                                      key: ValueKey(
                                                        'empty-guide',
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (step == 0 || step == 4 || busy)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child:
                              (shared.error != null || error.isNotEmpty) &&
                                  (step == 0 || step == 4)
                              ? Semantics(
                                  label: '加载中断，点击重试',
                                  button: true,
                                  child: GestureDetector(
                                    key: const ValueKey('loading-retry'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: busy
                                        ? null
                                        : (step == 4
                                              ? () => _enterLesson()
                                              : _retryScene),
                                    child: const SizedBox(
                                      height: 44,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: SizedBox(
                                          height: 2,
                                          width: double.infinity,
                                          child: ColoredBox(
                                            color: Color(0xFFAD4F38),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : EntryProgress(
                                  value: step == 0 && !loading
                                      ? shared.resourceProgress
                                      : null,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Duration _duration(int ms) => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: ms);
  void _back() {
    if (busy) return;
    if (step == 1) {
      _go(3, backwards: true);
    } else if (step == 3) {
      _go(2, backwards: true);
    }
  }

  Widget _form(bool compact) {
    final isPhone = step == 0 || step == 2,
        isCode = step == 3,
        isName = step == 1;
    final controller = isPhone ? phone : (isCode ? code : nickname);
    final label = isPhone ? '手机号' : (isCode ? '验证码' : '昵称');
    return SizedBox(
      key: ValueKey('guide-step-${isPhone ? 2 : step}'),
      height: compact ? 202 : 264,
      child: Column(
        children: [
          SizedBox(
            height: compact ? 25 : 36,
            child: Center(
              child: Text(
                isPhone ? '需要一个手机号。' : (isName ? '还需要一个昵称。' : '输入验证码。'),
                style: TextStyle(
                  color: entryInk,
                  fontSize: compact ? 15 : 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 16),
          SizedBox(
            height: compact ? 48 : 60,
            child: Semantics(
              label: label,
              child: TextField(
                key: ValueKey('guide-input-$step'),
                controller: controller,
                focusNode: isPhone
                    ? phoneFocus
                    : (isCode ? codeFocus : nameFocus),
                readOnly: busy,
                maxLength: isPhone ? 11 : (isCode ? (testMode ? 4 : 6) : 12),
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: isName
                    ? TextInputType.name
                    : TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: isPhone
                    ? const [AutofillHints.telephoneNumberNational]
                    : (isCode
                          ? const [AutofillHints.oneTimeCode]
                          : const [AutofillHints.nickname]),
                inputFormatters: isName
                    ? null
                    : [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) {
                  if (busy) return;
                  if (isPhone && phoneValid && canSend) {
                    _send();
                  } else if (isCode && codeValid) {
                    _verify();
                  } else if (isName && nameValid) {
                    _nextName();
                  }
                },
                style: TextStyle(
                  color: entryInk,
                  fontSize: compact ? 21 : 25,
                  letterSpacing: isName ? 1 : 3,
                ),
                cursorColor: entryInk,
                decoration: InputDecoration(
                  hintText: isCode && testMode ? '8888' : null,
                  semanticCounterText: label,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 8 : 14,
                  ),
                  hintStyle: TextStyle(
                    color: entryMuted.withValues(alpha: .35),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: compact ? 25 : 32,
            child: isCode
                ? TextButton(
                    onPressed: busy || cooldown > 0
                        ? null
                        : () => _send(resend: true),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: entryMuted,
                    ),
                    child: Text(
                      cooldown > 0 ? '${cooldown}s 后重发' : '重新获取',
                      style: const TextStyle(fontSize: 11),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          GuidedActions(
            showBack: !isPhone,
            showNext: !isPhone || phoneValid,
            canNext: isPhone
                ? (phoneValid && canSend)
                : (isCode ? codeValid : false),
            merged: isName && nameValid,
            busy: busy,
            onBack: _back,
            onNext: () {
              if (isPhone) {
                _send();
              } else if (isCode) {
                _verify();
              }
            },
            onExplore: _nextName,
          ),
          if (error.isNotEmpty)
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFAD4F38),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          if (isPhone && !smsReady && !testMode)
            const Flexible(
              child: Text(
                '短信暂不可用',
                style: TextStyle(color: entryMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
