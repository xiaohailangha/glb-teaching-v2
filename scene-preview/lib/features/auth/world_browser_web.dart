import 'package:web/web.dart' as web;

void hideBootSplash() => web.window.dispatchEvent(web.Event('scene-ui-ready'));
void setLessonMode(bool value) => web.document.documentElement?.setAttribute(
  'data-course',
  value ? 'true' : 'false',
);
