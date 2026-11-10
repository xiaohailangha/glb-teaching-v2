import 'dart:typed_data';
import 'package:scene/scene.dart';

Future<SceneDocument> readFscenebBrowser(Uint8List bytes) async =>
    readFsceneb(bytes);
