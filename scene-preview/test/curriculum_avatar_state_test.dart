import 'package:flutter_test/flutter_test.dart';
import 'package:snow_speaks/core/avatar/scene/scene_runtime.dart';
import 'package:snow_speaks/features/lesson/application/lesson_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('curriculum keeps teaching intent while silently listening and clears on pause', () async {
    final controller = LessonController();
    final runtime = SceneRuntime(controller, presentStage: (_) async {});
    for (final phase in ['meaning', 'demonstrate', 'listen', 'success', 'support', 'recall', 'finish']) {
      controller.setCurriculumPhase(phase);
      expect(runtime.mode, 'curriculum');
      expect(runtime.phase, phase);
      expect(runtime.playingAudio, false);
      expect(runtime.director, isNull);
    }
    await runtime.stop();
    expect(runtime.phase, 'idle');
    expect(runtime.mode, 'idle');
    runtime.dispose();
    controller.dispose();
  });
}
