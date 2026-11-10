import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data' show Float32List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/fscene.dart';
// Validate the maintained renderer patches, including their resource lifetime.
// ignore: implementation_imports
import 'package:flutter_scene/src/fscene/fsceneb_yielding.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/render/frame_image_releaser.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/texture/texture_mip_budget.dart';
import 'package:snow_speaks/core/avatar/scene/lesson_resources.dart';
import 'package:snow_speaks/core/avatar/scene/render_budget.dart';
import 'package:snow_speaks/core/avatar/graphics_recovery_panel.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Documents extends CachingAssetBundle {
  final requested = <String>[];
  final failing = <String>{};
  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    if (failing.contains(key)) throw StateError('offline');
    final value = key.contains('/courses/')
        ? {
            'stages': [
              {'id': key},
            ],
          }
        : {'name': key};
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(jsonEncode(value))),
    );
  }
}

void main() {
  test(
    'recovery persists the active account checkpoint before allowing a reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = LessonController(accountId: 'alice');
      final id = controller.courseId;
      controller.courseCheckpoint = {'version': 1, 'courseId': id, 'index': 7};
      controller.handle({'event': 'graphics-lost'});
      expect(controller.graphicsLost, true);
      expect(controller.ready, false);
      await controller.persistBeforeRecovery();
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('account:alice:$id')!)['index'], 7);
      expect(prefs.getString('account:alice:active-course'), id);
      expect(prefs.getString('account:bob:$id'), isNull);
      controller.dispose();
    },
  );
  test('phone textures use existing 1024 mips while desktop and base-only assets retain their source', () {
    expect(textureBaseMip(2048, 2048, 12, maxSide: 1024), 1);
    expect(textureBaseMip(4096, 2048, 13, maxSide: 1024), 2);
    expect(textureBaseMip(1024, 1024, 11, maxSide: 1024), 0);
    expect(textureBaseMip(2048, 2048, 1, maxSide: 1024), 0);
    expect(textureBaseMip(2048, 2048, 12), 0);
  });
  test('only the requested course is loaded; parallel taps share one load and failure can retry', () async {
    final bundle = Documents(), resources = LessonResources(Documents());
    final loader = LessonResources(bundle);
    final first = loader.loadCourse('first', 'first');
    final again = loader.loadCourse('first', 'first');
    expect(await first, await again);
    expect(bundle.requested, ['assets/avatar/courses/first.json']);
    expect(loader.courses.keys, ['first']);
    bundle.failing.add('assets/avatar/courses/next.json');
    await expectLater(loader.loadCourse('next', 'next'), throwsStateError);
    bundle.failing.clear();
    await loader.loadCourse('next', 'next');
    expect(bundle.requested.where((p) => p.contains('/next.')).length, 2);
    expect(bundle.requested.any((p) => p.contains('/images/')), false);
    expect(resources.courses, isEmpty);
  });
  test('mobile rendering never inherits desktop 120 fps or expensive balanced shadows', () {
    for (final quality in ['high', 'medium', 'low']) {
      final b = RenderBudget.resolve(quality, mobileBrowser: true);
      expect(b.fps, lessThanOrEqualTo(30));
    }
    expect(RenderBudget.resolve('medium', mobileBrowser: true).shadows, false);
    expect(
      RenderBudget.resolve('medium', mobileBrowser: true).scale,
      lessThan(1),
    );
    expect(RenderBudget.resolve('high', mobileBrowser: false).fps, 120);
  });
  test('yielding binary reader preserves exact scene payloads and rejects corruption', () async {
    final source = SceneDocument()..generator = 'mobile-reader-test';
    source.createNode(name: 'world', root: true);
    source.addPayload(
      PayloadSpec(
        source.newId(),
        encoding: PayloadEncoding.bytes,
        bytes: Uint8List(50000),
      ),
    );
    final encoded = writeFsceneb(source);
    var inflations = 0;
    final decoded = await readFscenebYielding(
      encoded,
      inflate: (bytes) async {
        inflations++;
        return Uint8List.fromList(gzip.decode(bytes));
      },
    );
    expect(inflations, greaterThan(0));
    expect(writeFsceneb(decoded), writeFsceneb(readFsceneb(encoded)));
    for (final payload in decoded.payloads.values) {
      expect(payload.bytes!.offsetInBytes % 4, 0);
      expect(Float32List.sublistView(payload.bytes!).length, 12500);
    }
    encoded[0] = 0;
    await expectLater(
      readFscenebYielding(encoded, inflate: (b) async => b),
      throwsA(isA<FscenebFormatException>()),
    );
  });
  testWidgets(
    'frame snapshot images are closed after painting and disposal is idempotent',
    (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..drawColor(Colors.blue, BlendMode.src);
      expect(canvas, isNotNull);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(2, 2);
      picture.dispose();
      final pool = FrameImageReleaser()..defer(image);
      expect(pool.heldImages, 1);
      tester.binding.scheduleFrame();
      await tester.pump();
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(pool.heldImages, 0);
      expect(image.debugDisposed, true);
      pool.dispose();
      pool.dispose();
    },
  );
  testWidgets(
    'graphics recovery never runs automatically and waits for the user action',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: GraphicsRecoveryPanel(
            onRecover: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 0);
      await tester.tap(find.text('恢复页面'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('正在保存学习位置…'), findsOneWidget);
      pending.complete();
      await tester.pump();
    },
  );
  testWidgets(
    'failed checkpoint persistence leaves recovery open with a retry action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GraphicsRecoveryPanel(
            onRecover: () async {
              throw StateError('storage unavailable');
            },
          ),
        ),
      );
      await tester.tap(find.text('恢复页面'));
      await tester.pump();
      expect(find.text('学习位置暂未保存，请稍后重试。'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
