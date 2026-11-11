import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'penyplicotcollectspinsh5_platform_interface.dart';

/// 使用原生 WKSHuhs 监听页面加载的 Android H5 视图。
/// URL 变化会销毁旧视图并创建新的 WebView，初始化日志接收不调用原生 create。
class Penyplicotcollectspinsh5WebView extends StatefulWidget {
  const Penyplicotcollectspinsh5WebView({super.key, required this.url});

  final String url;

  @override
  State<Penyplicotcollectspinsh5WebView> createState() =>
      _Penyplicotcollectspinsh5WebViewState();
}

class _Penyplicotcollectspinsh5WebViewState
    extends State<Penyplicotcollectspinsh5WebView> {
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_isAndroid) {
      Penyplicotcollectspinsh5Platform.instance.startPageLogging();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroid) {
      return const Center(child: Text('H5 WebView requires Android.'));
    }
    return AndroidView(
      key: ValueKey(widget.url),
      viewType: 'penyplicotcollectspinsh5/webview',
      creationParams: <String, Object>{'url': widget.url},
      creationParamsCodec: const StandardMessageCodec(),
      layoutDirection: TextDirection.ltr,
    );
  }
}
