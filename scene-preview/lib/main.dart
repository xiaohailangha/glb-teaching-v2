import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Entry screens support portrait; the native classroom locks landscape on entry.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
  runApp(const SnowSpeaksApp());
}
