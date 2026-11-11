import 'penyplicotcollectspinsh5_platform_interface.dart';

export 'penyplicotcollectspinsh5_webview.dart';

class Penyplicotcollectspinsh5 {
  /// 调用 Android 宿主 Activity 的原生 create 入口。
  /// Future 完成表示入口已返回，不代表 H5 页面已经加载完成。
  Future<void> create() {
    return Penyplicotcollectspinsh5Platform.instance.create();
  }

  Future<String?> getPlatformVersion() {
    return Penyplicotcollectspinsh5Platform.instance.getPlatformVersion();
  }

  /// 开始接收原生网页 URL 日志，不调用原生初始化。
  void startPageLogging() {
    Penyplicotcollectspinsh5Platform.instance.startPageLogging();
  }
}
