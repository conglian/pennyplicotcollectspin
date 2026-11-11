import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'penyplicotcollectspinsh5_platform_interface.dart';

/// An implementation of [Penyplicotcollectspinsh5Platform] that uses method channels.
class MethodChannelPenyplicotcollectspinsh5
    extends Penyplicotcollectspinsh5Platform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('penyplicotcollectspinsh5');

  @override
  Future<void> create() {
    // 先接收回调，避免原生 create 尚未返回时漏掉首次网页地址。
    startPageLogging();
    return methodChannel.invokeMethod<void>('create');
  }

  @override
  void startPageLogging() {
    methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onPageLog' || call.arguments is! Map) return;
    final arguments = call.arguments as Map;
    final event = arguments['event'];
    final url = arguments['url'];
    if ((event != 'onPageStarted' && event != 'onPageFinished') ||
        url is! String ||
        url.trim().isEmpty) {
      return;
    }
    debugPrint('[H5] $event url=$url');
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
