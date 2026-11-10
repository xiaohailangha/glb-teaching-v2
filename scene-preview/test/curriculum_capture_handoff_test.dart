import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/features/lesson/application/curriculum_lesson_controller.dart';

import 'curriculum_page_test.dart' as fixture;

class HeldModel extends fixture.Avatar {
  final started = Completer<void>();
  final ended = Completer<void>();
  @override
  Future<void> playCurriculumAudio(Map<String, dynamic> audio) async {
    if (!started.isCompleted) started.complete();
    await ended.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final pause in [false, true]) {
    test(
      pause
          ? 'paused model cannot reopen capture'
          : 'model ends directly in armed capture on the same teaching step',
      () async {
        final api = fixture.CurriculumApi(fixture.fixture());
        final avatar = HeldModel();
        final c = CurriculumLessonController(
          api: api,
          avatar: avatar,
          id: 'B1.01-L01',
          onSelect: (_) async {},
          readerFactory: (_) => fixture.Reader(),
          feedbackDelay: Duration.zero,
        );
        await c.initialize();
        c.coursePosition = c.beats.indexWhere((b) => b.modelStep != null);
        expect(c.coursePosition, greaterThanOrEqualTo(0));
        c.playCourse();
        await avatar.started.future;
        final position = c.coursePosition,
            step = c.courseStep,
            target = c.reader.key;
        expect(c.challenge, isNotNull);
        expect(c.reader.text, isNotEmpty);
        expect(c.reader.playing, true);
        await c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
        expect(api.submissions, isEmpty);
        if (pause) c.pauseCourse();
        avatar.ended.complete();
        await Future<void>.delayed(Duration.zero);
        expect(c.coursePosition, position);
        expect(c.courseStep, step);
        expect(c.reader.key, target);
        if (pause) {
          expect(c.reader.enabled, false);
          await c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
          expect(api.submissions, isEmpty);
        } else {
          expect(c.playing, false);
          expect(c.reader.playing, false);
          final answer = c.acceptUtterance(Uint8List.fromList([1, 2, 3]));
          expect(api.submissions, hasLength(1));
          c.pauseCourse();
          await answer;
        }
        c.dispose();
        avatar.dispose();
        api.dispose();
      },
    );
  }
}
