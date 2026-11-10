import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_api.dart';
import 'lesson_controller.dart';
import 'app_session_clock.dart';

/// Account-bound, local-first queue. Guest and management preview are excluded.
class LearningSync with WidgetsBindingObserver {
  LearningSync(this.controller, {AuthApi? api}) : api = api ?? AuthApi();
  final LessonController controller;
  final AuthApi api;
  final String session =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  final stopwatch = Stopwatch()..start();
  final intervals = <Map<String, dynamic>>[];
  final events = <Map<String, dynamic>>[];
  final revisions = <String, int>{};
  final saved = <String, String>{};
  bool curriculumOverlay = false;
  String curriculumCourse = '';
  Timer? timer;
  bool visible = true, sending = false, disposed = false, initialized = false;
  int lastTick = 0,
      lastWall = DateTime.now().millisecondsSinceEpoch,
      lastInteraction = 0,
      sequence = 0;
  late final String account = controller.accountId;
  String get key => 'account:$account:formal-learning-upload-v2';
  bool get enabled => account.isNotEmpty;
  Future<void> start() async {
    if (!enabled) return;
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(key) ?? '{}') as Map;
      intervals.addAll(
        (raw['intervals'] as List? ?? []).map(
          (r) => Map<String, dynamic>.from(r as Map),
        ),
      );
      events.addAll(
        (raw['events'] as List? ?? []).map(
          (r) => Map<String, dynamic>.from(r as Map),
        ),
      );
    } catch (_) {}
    if (disposed) return;
    final storedRevisions = jsonDecode(
      prefs.getString('account:$account:formal-cloud-revisions') ?? '{}',
    ) as Map;
    for (final entry in storedRevisions.entries) {
      if (entry.value is int) {
        revisions[entry.key.toString()] = entry.value as int;
      }
    }
    controller.onLearningEvent = event;
    lastTick = stopwatch.elapsedMilliseconds;
    lastWall =
        (AppSessionClock.account == account
            ? AppSessionClock.startedAt?.millisecondsSinceEpoch
            : null) ??
        DateTime.now().millisecondsSinceEpoch;
    initialized = true;
    tick();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      tick();
      unawaited(flush());
    });
    unawaited(flush());
  }

  void interact() {
    lastInteraction = stopwatch.elapsedMilliseconds;
  }

  void event(String type, [Map<String, dynamic> detail = const {}]) {
    if (!enabled || disposed) return;
    if (['start', 'help', 'skip', 'pass', 'correct'].contains(type)) interact();
    events.add({
      'id': '$session-e${sequence++}',
      'at': DateTime.now().millisecondsSinceEpoch,
      'course': controller.courseId,
      'stage': controller.courseStep,
      'type': type,
      'detail': detail,
    });
    unawaited(persist());
  }

  void tick() {
    final now = DateTime.now().millisecondsSinceEpoch,
        elapsed = stopwatch.elapsedMilliseconds,
        delta = elapsed - lastTick;
    // Every logged-in app page counts. Persist short slices for idempotent upload.
    // Independent device/session slices are summed by the account on the server.
    if (initialized && !disposed && delta >= 0 && now > lastWall) {
      var start = lastWall;
      while (start < now) {
        final end = min(start + 20000, now);
        intervals.add({
          'id': '$session-i${sequence++}',
          'session': session,
          'start': start,
          'end': end,
          'active': true,
          'course': curriculumOverlay
              ? curriculumCourse
              : (controller.adultCourse ? controller.courseId : ''),
        });
        start = end;
      }
    }
    lastTick = elapsed;
    lastWall = now;
    unawaited(persist());
  }

  Future<void> persist() async {
    if (!initialized) return;
    final prefs = await SharedPreferences.getInstance();
    // Bound local storage while retaining roughly 30 days of ordinary use.
    if (intervals.length > 30000) {
      intervals.removeRange(0, intervals.length - 30000);
    }
    if (events.length > 10000) events.removeRange(0, events.length - 10000);
    await prefs.setString(
      key,
      jsonEncode({'intervals': intervals, 'events': events}),
    );
  }

  Future<void> flush() async {
    if (sending ||
        !enabled ||
        !initialized ||
        controller.accountId != account) {
      return;
    }
    sending = true;
    try {
      final me = await api.me();
      if (me?.id != account) return;
      if (intervals.isNotEmpty || events.isNotEmpty) {
        final batch = intervals.take(500).toList(),
            actions = events.take(100).toList();
        await api.request(
          'learning/batch',
          method: 'POST',
          data: {
            'epoch': 'formal555-reset-v2',
            'intervals': batch,
            'events': actions,
          },
        );
        final ids = batch.map((r) => r['id']).toSet(),
            eids = actions.map((r) => r['id']).toSet();
        intervals.removeWhere((r) => ids.contains(r['id']));
        events.removeWhere((r) => eids.contains(r['id']));
        await persist();
      }
    } catch (_) {
      /* Retry only while authenticated as the queue owner. */
    } finally {
      sending = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    tick();
    visible = state == AppLifecycleState.resumed;
    lastTick = stopwatch.elapsedMilliseconds;
    lastWall = DateTime.now().millisecondsSinceEpoch;
    unawaited(flush());
  }

  void dispose() {
    if (!enabled) return;
    tick();
    timer?.cancel();
    controller.onLearningEvent = null;
    WidgetsBinding.instance.removeObserver(this);
    disposed = true;
    unawaited(flush());
  }
}
