import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'penyplicotcollectspinsh5_method_channel.dart';

abstract class Penyplicotcollectspinsh5Platform extends PlatformInterface {
  /// Constructs a Penyplicotcollectspinsh5Platform.
  Penyplicotcollectspinsh5Platform() : super(token: _token);

  static final Object _token = Object();

  static Penyplicotcollectspinsh5Platform _instance =
      MethodChannelPenyplicotcollectspinsh5();

  /// The default instance of [Penyplicotcollectspinsh5Platform] to use.
  ///
  /// Defaults to [MethodChannelPenyplicotcollectspinsh5].
  static Penyplicotcollectspinsh5Platform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [Penyplicotcollectspinsh5Platform] when
  /// they register themselves.
  static set instance(Penyplicotcollectspinsh5Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> create() {
    throw UnimplementedError('create() has not been implemented.');
  }

  /// 仅启用网页日志接收，不触发原生 create 或打开页面。
  void startPageLogging() {}
}
