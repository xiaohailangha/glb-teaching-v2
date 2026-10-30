import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../features/lesson/application/lesson_controller.dart';
import 'local_asset_server.dart';

class AvatarView extends StatefulWidget {
  final LessonController controller;
  const AvatarView({super.key, required this.controller});
  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  final assets = LocalAssetServer();
  WebViewController? webView;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return;
    try {
      final uri = await assets.start();
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            )
          : const PlatformWebViewControllerCreationParams();
      late final WebViewController controller;
      controller =
          WebViewController.fromPlatformCreationParams(
              params,
              onPermissionRequest: (request) async {
                final page = Uri.tryParse(await controller.currentUrl() ?? '');
                if (!mounted ||
                    page?.origin != uri.origin ||
                    request.types.length != 1 ||
                    !request.types.contains(
                      WebViewPermissionResourceType.microphone,
                    )) {
                  await request.deny();
                  return;
                }
                try {
                  final granted =
                      !Platform.isAndroid ||
                      await const MethodChannel(
                            'glb/microphone',
                          ).invokeMethod<bool>('requestPermission') ==
                          true;
                  if (granted && mounted) {
                    await request.grant();
                  } else {
                    await request.deny();
                  }
                } catch (_) {
                  await request.deny();
                }
              },
            )
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.transparent)
            ..addJavaScriptChannel(
              'SnowNative',
              onMessageReceived: (message) {
                try {
                  widget.controller.handle(
                    Map<String, dynamic>.from(jsonDecode(message.message)),
                  );
                } catch (_) {
                  /* Only accept structured avatar events. */
                }
              },
            )
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (request) =>
                    Uri.tryParse(request.url)?.host == '127.0.0.1'
                    ? NavigationDecision.navigate
                    : NavigationDecision.prevent,
              ),
            );
      if (controller.platform is AndroidWebViewController) {
        await (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await controller.loadRequest(
        uri.replace(queryParameters: {'layout': 'full'}),
      );
      widget.controller.attach((command) {
        controller.runJavaScript(
          'window.avatarCommand(${jsonEncode(command)})',
        );
      });
      if (mounted) setState(() => webView = controller);
    } catch (e) {
      widget.controller.handle({'event': 'error', 'message': '人物视图启动失败：$e'});
    }
  }

  @override
  Widget build(BuildContext context) => webView == null
      ? const Center(child: Text('正在准备人物…'))
      : WebViewWidget(controller: webView!);
  @override
  void dispose() {
    assets.close();
    super.dispose();
  }
}
