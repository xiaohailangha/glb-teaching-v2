import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'teaching_trial_test.dart' show TrialFixture;
import 'classroom_layout_rules_test.dart' show trialFrame, loadTrialFonts;

void main() {
  testWidgets('capture latest classroom text layouts with actual fonts', (
    tester,
  ) async {
    await loadTrialFonts();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const output =
        '../outputs/classroom-verification';
    Directory(output).createSync(recursive: true);
    for (final entry in {
      'word': 'A02',
      'sentence': 'B08',
      'comparison': 'B07',
      'vocabulary': 'B21',
    }.entries) {
      final f = TrialFixture(
        entry.value.startsWith('A') ? 'N26-U006-L04' : 'N26-U084-L01',
      );
      await f.c.initialize();
      f.c.courseMode = true;
      f.c.coursePosition = f.c.steps.indexWhere((s) => s['id'] == entry.value);
      f.c.prepareStage();
      if (entry.value == 'B21') f.c.reviewPage = 1;
      for (final size in [const Size(844, 390), const Size(1440, 810)]) {
        tester.view.physicalSize = size;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: trialFrame(f, size)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/${entry.key}-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      f.close();
    }
  });
}
