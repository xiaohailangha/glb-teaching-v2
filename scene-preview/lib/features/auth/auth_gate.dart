import '../../core/avatar/scene/course_resources.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../lesson/presentation/lesson_page.dart';
import 'auth_api.dart';
import '../lesson/application/learning_sync.dart';
import '../lesson/application/app_session_clock.dart';
import 'entry_design.dart';
import 'world_browser_stub.dart'
    if (dart.library.js_interop) 'world_browser_web.dart';
import '../../core/avatar/avatar_view.dart';
import '../../core/avatar/graphics_recovery_panel.dart';
import '../../core/avatar/scene/browser_graphics.dart';
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
  int lastInputStep = 0;
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
    phoneFocus.addListener(_focusChanged);
    codeFocus.addListener(_focusChanged);
    nameFocus.addListener(_focusChanged);
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
      if (Uri.base.queryParameters['adminPreview'] == '1' &&
          Uri.base.queryParameters['previewToken'] != null) {
        pendingGuest = true;
        waitingForScene = true;
        step = 4;
        unawaited(_prepareContent());
      }
      if (results[1]['user'] is Map) {
        user = LearnerAccount.fromJson(results[1]['user'] as Map);
        AppSessionClock.begin(user!.id);
        unawaited(_prepareContent());
      }
    } catch (_) {
      error = '连接未完成，请重试';
    }
    if (mounted) {
      setState(() => loading = false);
      _sceneChanged();
    }
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _inputChanged() {
    if (mounted) {
      setState(() {
        error = '';
      });
    }
  }

  Future<void> _prepareContent() async {
    if (!widget.prepareScene) return;
    try {
      await CourseResources.instance.initialize(
        previewToken: Uri.base.queryParameters['previewToken'],
      );
    } catch (_) {
      if (mounted) {
        shared.handle({'event': 'error', 'message': '课程资源暂时未能加载，请重试'});
        setState(() {});
      }
    }
  }

  void _go(int value, {bool backwards = false}) {
    if (value == 4) unawaited(_prepareContent());
    if (value == 4 && user != null) AppSessionClock.begin(user!.id);
    final transferFocus =
        value != 4 &&
        (phoneFocus.hasFocus || codeFocus.hasFocus || nameFocus.hasFocus);
    if (value == 4) FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      revealingPhone = step == 0 && value == 2;
      slideDirection = backwards ? -1 : 1;
      step = value;
      if (value != 4) lastInputStep = value;
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
    final preview = Uri.base.queryParameters['adminPreview'] == '1';
    if (guest || preview) user = null;
    if (user != null) await restoreCloudLearning(user!.id);
    await shared.bindAccount(
      id: preview ? 'admin-preview' : user?.id ?? '',
      name: preview ? '老师' : user?.nickname,
      saveName: user == null ? null : api.rename,
    );
    if (preview) {
      final course = Uri.base.queryParameters['course'];
      if (course != null) await shared.selectCourse(course);
      shared.courseCheckpoint = null;
    }
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
      if (!mounted) return;
      if (inLesson) {
        setState(() {});
        return;
      }
      if (step == 0 && authReady && !busy) {
        if (user != null) {
          if (!shared.scenePresented) return;
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
    if (user != null || pendingGuest) unawaited(_prepareContent());
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
    AppSessionClock.end();
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
        Positioned.fill(
          child: _pageSlide(
            incoming: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.prepareScene)
                  TickerMode(
                    enabled: inLesson || step == 0 || step == 4,
                    child: AvatarView(
                      key: ValueKey(sceneAttempt),
                      controller: shared,
                    ),
                  ),
                if (inLesson)
                  LessonPage(
                    key: ValueKey(user?.id ?? 'guest'),
                    account: user,
                    auth: api,
                    onLeave: _leave,
                    sharedController: shared,
                  ),
              ],
            ),
          ),
        ),
        IgnorePointer(
          ignoring: inLesson,
          child: ExcludeSemantics(
            excluding: inLesson,
            child: _pageSlide(
              incoming: false,
              child: TickerMode(
                enabled: !inLesson,
                child: ColoredBox(
                  color: entryPaper,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SafeArea(
                        maintainBottomViewPadding: true,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final guided =
                                step != 0 && (step != 4 || lastInputStep != 0);
                            final h = box.maxHeight;
                            final compact = h < 600;
                            final gap = compact ? 32.0 : 48.0;
                            const identityHeight = 104.0;
                            const formCoreHeight = 24.0 + 12 + 48 + 20 + 48;
                            final panelHeight = formCoreHeight + 48;
                            final groupHeight =
                                identityHeight + gap + formCoreHeight;
                            final groupTop = math.max(
                              8.0,
                              (h - groupHeight) / 2,
                            );
                            final keyboard = MediaQuery.viewInsetsOf(context)
                                .bottom;
                            final keyboardCompact =
                                keyboard > 0 &&
                                box.maxWidth < 500 &&
                                groupTop +
                                        identityHeight +
                                        gap +
                                        formCoreHeight >
                                    h - keyboard;
                            final panelTop = keyboardCompact
                                ? h - keyboard - 56
                                : groupTop + identityHeight + gap;
                            final identityTop = step == 0
                                ? (h - 120) / 2
                                : groupTop;
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
                                    height: step == 0 ? 120 : identityHeight,
                                    child: EntryIdentity(
                                      key: const ValueKey('guide-identity'),
                                      compact: step != 0,
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
                                        opacity: guided ? 1 : 0,
                                        duration: _duration(750),
                                        curve: Curves.easeOutCubic,
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 340,
                                            ),
                                            child: AnimatedSwitcher(
                                              duration: _duration(720),
                                              reverseDuration: _duration(720),
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
                                                        child: Opacity(
                                                          opacity: Curves
                                                              .easeInOut
                                                              .transform(
                                                                animation.value,
                                                              ),
                                                          child: child,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                              child: guided
                                                  ? _form(
                                                      compact,
                                                      keyboardCompact:
                                                          keyboardCompact,
                                                    )
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
        if (shared.graphicsLost)
          GraphicsRecoveryPanel(
            onRecover: () async {
              await shared.persistBeforeRecovery();
              reloadForGraphicsRecovery();
            },
          ),
      ],
    ),
  );

  Widget _pageSlide({required bool incoming, required Widget child}) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: inLesson ? 1 : 0),
        duration: _duration(750),
        curve: Curves.easeInOutCubic,
        child: child,
        builder: (context, progress, child) => FractionalTranslation(
          key: ValueKey(incoming ? 'lesson-page-slide' : 'entry-page-slide'),
          translation: Offset(
            0,
            incoming ? (inLesson ? 1 - progress : 0) : -progress,
          ),
          child: child,
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

  Widget _form(bool compact, {bool keyboardCompact = false}) {
    final displayStep = step == 4 ? lastInputStep : step;
    final isPhone = displayStep == 0 || displayStep == 2,
        isCode = displayStep == 3,
        isName = displayStep == 1;
    final controller = isPhone ? phone : (isCode ? code : nickname);
    final label = isPhone ? '手机号' : (isCode ? '验证码' : '昵称');
    final input = SizedBox(
      height: 48,
      child: Semantics(
        label: label,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TextField(
              key: ValueKey('guide-input-$displayStep'),
              controller: controller,
              focusNode: isPhone
                  ? phoneFocus
                  : (isCode ? codeFocus : nameFocus),
              readOnly: busy,
              maxLength: isPhone ? 11 : (isCode ? (testMode ? 4 : 6) : 12),
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: isName ? TextInputType.name : TextInputType.number,
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
                fontSize: 26,
                letterSpacing: isName ? 1 : 2,
              ),
              cursorColor: entryInk,
              decoration: InputDecoration(
                hintText: null,
                semanticCounterText: label,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                hintStyle: TextStyle(color: entryMuted.withValues(alpha: .35)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
            if (controller.text.isEmpty &&
                !(isPhone ? phoneFocus : (isCode ? codeFocus : nameFocus))
                    .hasFocus)
              const IgnorePointer(child: EntryIdleCaret()),
          ],
        ),
      ),
    );
    if (keyboardCompact) {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            if (!isPhone)
              IconButton(
                key: const ValueKey('guide-back'),
                onPressed: busy ? null : _back,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            Expanded(child: input),
            if (isName && nameValid)
              TextButton(
                key: const ValueKey('guide-explore'),
                onPressed: busy ? null : _nextName,
                child: const Text('开始探索'),
              )
            else if (!isPhone || phoneValid)
              IconButton(
                key: const ValueKey('guide-next'),
                onPressed:
                    busy || !(isPhone ? phoneValid && canSend : codeValid)
                    ? null
                    : () {
                        if (isPhone) {
                          _send();
                        } else {
                          _verify();
                        }
                      },
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
          ],
        ),
      );
    }
    return SizedBox(
      key: ValueKey('guide-step-${isPhone ? 2 : displayStep}'),
      height: 152 + 48,
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                isPhone ? '需要一个手机号' : (isName ? '还需要一个昵称' : '输入验证码'),
                style: TextStyle(
                  color: entryMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          input,
          const SizedBox(height: 20),
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
          SizedBox(
            height: 24,
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
