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
  Timer? timer;
  bool visible = true, sending = false, disposed = false, initialized = false;
  int lastTick = 0,
      lastWall = DateTime.now().millisecondsSinceEpoch,
      lastInteraction = 0,
      sequence = 0;
  late final String account = controller.accountId;
  String get key => 'account:$account:learning-upload-v1';
  bool get enabled =>
      account.isNotEmpty && Uri.base.queryParameters['adminPreview'] != '1';
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
      prefs.getString('account:$account:cloud-revisions') ?? '{}',
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
          'course': controller.adultCourse ? controller.courseId : '',
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
          data: {'intervals': batch, 'events': actions},
        );
        final ids = batch.map((r) => r['id']).toSet(),
            eids = actions.map((r) => r['id']).toSet();
        intervals.removeWhere((r) => ids.contains(r['id']));
        events.removeWhere((r) => eids.contains(r['id']));
        await persist();
      }
      if (controller.courseCheckpoint != null) {
        final course = controller.courseId;
        final payload = {
          'checkpoint': controller.courseCheckpoint,
          'vocabulary': controller.vocabulary.toJson(),
          'stageId': controller.courseStep,
        };
        final encoded = jsonEncode(payload);
        if (saved[course] != encoded) {
          final remote = await api.request('learning/state');
          final rows = (remote['rows'] as List).cast<Map>();
          final match = rows.where((r) => r['course'] == course).firstOrNull;
          final revision = (match?['revision'] as num?)?.toInt() ?? 0;
          // Do not overwrite a checkpoint updated by another active device.
          if ((revisions[course] ?? 0) != revision) return;
          revisions[course] = revision;
          final result = await api.request(
            'learning/state',
            method: 'POST',
            data: {'course': course, 'revision': revision, 'payload': payload},
          );
          revisions[course] = (result['revision'] as num).toInt();
          saved[course] = encoded;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'account:$account:cloud-revisions',
            jsonEncode(revisions),
          );
        }
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

Future<void> restoreCloudLearning(String account) async {
  if (account.isEmpty || Uri.base.queryParameters['adminPreview'] == '1') {
    return;
  }
  final api = AuthApi();
  try {
    final data = await api.request('learning/state'),
        prefs = await SharedPreferences.getInstance();
    final rows = (data['rows'] as List).cast<Map>()
      ..sort((a, b) => (a['updated'] as num).compareTo(b['updated'] as num));
    final pending = jsonDecode(
      prefs.getString('account:$account:learning-upload-v1') ?? '{}',
    ) as Map;
    if ((pending['events'] as List? ?? []).isNotEmpty ||
        (pending['intervals'] as List? ?? []).isNotEmpty) {
      return;
    }
    final revisions = <String, int>{};
    final seen = <String>{};
    for (final r in rows) {
      revisions[r['course'] as String] = (r['revision'] as num).toInt();
      final payload = r['payload'] as Map;
      await prefs.setString(
        'account:$account:${r['course']}',
        jsonEncode(payload['checkpoint']),
      );
      await prefs.setString(
        'account:$account:active-course',
        r['course'] as String,
      );
      if (payload['vocabulary'] is Map) {
        final vocabulary = payload['vocabulary'] as Map;
        seen.addAll((vocabulary['seen'] as List? ?? []).whereType<String>());
        await prefs.setString(
          'account:$account:course-new:${r['course']}',
          jsonEncode(vocabulary['new'] ?? []),
        );
      }
    }
    if (rows.isNotEmpty) {
      await prefs.setString(
        'account:$account:vocabulary-exposure-v1',
        jsonEncode({'seen': seen.toList(), 'new': [], 'inCourse': false}),
      );
      await prefs.setString(
        'account:$account:cloud-revisions',
        jsonEncode(revisions),
      );
    }
  } catch (_) {
  } finally {
    api.dispose();
  }
}
