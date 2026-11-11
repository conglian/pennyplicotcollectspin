import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'PCLogger.dart';

class PCWebkitview extends StatefulWidget {
  final String url;
  final String title;
  final bool useNativeH5Client;

  const PCWebkitview({
    super.key,
    required this.url,
    required this.title,
    this.useNativeH5Client = false,
  });

  @override
  State<PCWebkitview> createState() => _PCWebkitviewState();
}

class _PCWebkitviewState extends State<PCWebkitview> {
  late final WebViewController _controller;
  late final bool _nativeH5 =
      widget.useNativeH5Client && !kIsWeb && Platform.isAndroid;
  final String TAG = "PCWebkitview";

  @override
  void initState() {
    super.initState();
    if (_nativeH5) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            asLog.debug("$TAG intercept: $url");
            // if (navRedirect(url)) {
            //   urlJump(url);
            //   return NavigationDecision.prevent; // 拦截特殊 scheme，不加载
            // }

            return NavigationDecision.navigate; // 正常加载
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  urlJump(String url) async {
    asLog.debug("$TAG==_jumpNext=canJump:$url=");
    if (url.startsWith("intent://")) {
      try {
        // StepWinUtils().parse_android_intent(data: u);
        // Gs152webkit().openBrowser(url.toString());
      } catch (e) {
        //
      }
    } else {
      try {
        String u_go = url;
        if (u_go.startsWith("market://details?id=")) {
          u_go = u_go.replaceAll(
            "market://details",
            "https://play.google.com/store/apps/details",
          );
        }
        launchUrl(Uri.parse(u_go), mode: LaunchMode.externalApplication);
      } catch (e) {
        //
      }
    }
  }

  bool navRedirect(String uuuu) {
    if (uuuu.startsWith("market:") ||
        uuuu.startsWith("http://play.google.com/store/") ||
        uuuu.contains("lz_open_browser=1") ||
        uuuu.startsWith("https://play.google.com/store/") ||
        (uuuu.startsWith("intent://") && Platform.isAndroid) ||
        uuuu.endsWith(".apk")) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: _nativeH5
            ? Penyplicotcollectspinsh5WebView(url: widget.url)
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
