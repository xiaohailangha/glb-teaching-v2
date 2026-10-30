import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import '../../features/lesson/application/lesson_controller.dart';

class AvatarView extends StatefulWidget {
  final LessonController controller;
  const AvatarView({super.key, required this.controller});
  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  late final web.HTMLIFrameElement frame;
  late final JSFunction listener;
  late final String viewType;
  @override
  void initState() {
    super.initState();
    viewType = 'snow-avatar-${identityHashCode(this)}';
    final previewParameters = Uri.base.queryParameters.entries.where(
      (entry) => const ['perf', 'quiet', 'demo'].contains(entry.key),
    );
    final previewQuery = Uri(
      queryParameters: {
        'layout': 'full',
        ...Map.fromEntries(previewParameters),
      },
    ).query;
    frame = web.HTMLIFrameElement()
      ..src =
          'assets/assets/avatar/index.html${previewQuery.isEmpty ? '' : '?$previewQuery'}'
      ..title = 'Storm 发音示范人物'
      ..allow = 'autoplay; microphone'
      ..style.border = '0'
      ..style.pointerEvents = Uri.base.queryParameters.containsKey('perf')
          ? 'auto'
          : 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    listener = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin ||
          event.source != frame.contentWindow) {
        return;
      }
      final data = event.data.dartify();
      if (data is! String) return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['source'] == 'snow-avatar') {
          widget.controller.handle(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        /* Ignore unrelated messages. */
      }
    }).toJS;
    web.window.addEventListener('message', listener);
    widget.controller.attach((command) {
      frame.contentWindow?.postMessage(
        jsonEncode({'source': 'snow-flutter', ...command}).toJS,
        web.window.location.origin.toJS,
      );
    });
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => frame);
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: viewType);
  @override
  void dispose() {
    web.window.removeEventListener('message', listener);
    frame.remove();
    super.dispose();
  }
}
