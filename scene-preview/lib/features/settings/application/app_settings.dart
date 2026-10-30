import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RenderPreset { high, medium, low }

class AppSettings extends ChangeNotifier {
  RenderPreset preset = RenderPreset.high;
  bool adaptive = true;
  bool _disposed = false;
  int _revision = 0;
  Future<void> _saveQueue = Future.value();
  String? saveError;
  static const _channel = MethodChannel('glb/rendering');

  Map<String, Object?> get command => {
    'type': 'render-settings',
    'quality': preset.name,
    'adaptive': adaptive,
  };

  Future<void> load() async {
    final revision = _revision;
    try {
      final store = await SharedPreferences.getInstance();
      if (_disposed || revision != _revision) return;
      final saved = store.getString('render.quality');
      preset =
          RenderPreset.values.where((p) => p.name == saved).firstOrNull ??
          RenderPreset.high;
      adaptive = store.getBool('render.adaptive') ?? true;
      notifyListeners();
      await _requestPlatformRate();
    } catch (_) {
      // A read failure leaves usable defaults, including in widget tests.
    }
  }

  Future<void> update({RenderPreset? quality, bool? automatic}) async {
    preset = quality ?? preset;
    adaptive = automatic ?? adaptive;
    _revision++;
    saveError = null;
    notifyListeners();
    final qualityName = preset.name, auto = adaptive;
    _saveQueue = _saveQueue.then((_) async {
      try {
        final store = await SharedPreferences.getInstance();
        final saved = await store.setString('render.quality', qualityName);
        final savedAuto = await store.setBool('render.adaptive', auto);
        if (!saved || !savedAuto) throw StateError('save failed');
      } catch (_) {
        if (!_disposed) {
          saveError = '本次设置已生效，但未能保存到设备。';
          notifyListeners();
        }
      }
    });
    await _requestPlatformRate();
    await _saveQueue;
  }

  Future<void> _requestPlatformRate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setProfile', {'quality': preset.name});
    } on MissingPluginException {
      /* Unsupported host: browser cadence still works. */
    } on PlatformException {
      /* System ultimately decides the supported mode. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
