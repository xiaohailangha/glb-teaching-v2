import 'dart:convert';

import 'package:flutter/services.dart';

/// Teaching metadata is loaded for the chosen course, independently of the
/// character. Unopened courses and their pictures never gate the first frame.
class LessonResources {
  LessonResources(this.bundle);
  final AssetBundle bundle;
  final timings = <String, dynamic>{};
  Map<String, dynamic> units = {};
  final courses = <String, List<dynamic>>{};
  final _pending = <String, Future<List<dynamic>>>{};
  Future<void>? _common;

  Future<void> loadCommon({bool curriculum = false}) =>
      _common ??= _readCommon(curriculum).catchError((Object error) {
        _common = null;
        throw error;
      });

  Future<void> _readCommon(bool curriculum) async {
    final files = [
      'timings',
      'teaching-prompts',
      'pronunciation-units',
      'course-prompts',
      'fruit-prompts',
      'unit-one-prompts',
      'unit-two-prompts',
      'coach-prompts',
      if (curriculum) 'curriculum-prompts',
      'performance-cues',
    ];
    // A small bounded pool avoids a chain of sequential network round trips.
    var next = 0;
    final documents = <String, Map<String, dynamic>>{};
    Future<void> worker() async {
      while (next < files.length) {
        final file = files[next++];
        documents[file] = jsonDecode(
          await bundle.loadString(
            'assets/avatar/audio/$file.json',
            cache: false,
          ),
        ) as Map<String, dynamic>;
      }
    }

    await Future.wait(List.generate(3, (_) => worker()));
    // Merge in authored order, regardless of network completion order.
    for (final file in files) {
      if (file == 'performance-cues') {
        timings['performance'] = documents[file];
      } else {
        timings.addAll(documents[file]!);
      }
    }
    units = documents['pronunciation-units']!;
  }

  Future<List<dynamic>> loadCourse(String id, String asset) {
    final hit = courses[id];
    if (hit != null) return Future.value(hit);
    return _pending.putIfAbsent(id, () async {
      try {
        final doc = jsonDecode(
          await bundle.loadString(
            'assets/avatar/courses/$asset.json',
            cache: false,
          ),
        ) as Map;
        final stages = doc['stages'] as List<dynamic>;
        if (stages.isEmpty) throw const FormatException('课程步骤为空');
        return courses[id] = stages;
      } finally {
        _pending.remove(id);
      }
    });
  }
}
