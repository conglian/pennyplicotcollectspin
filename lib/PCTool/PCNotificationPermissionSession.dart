/// 通知权限召回的单次启动状态；暖重建共用，下一次冷启动重新建立。
class PCNotificationPermissionSession {
  PCNotificationPermissionSession();

  static final current = PCNotificationPermissionSession();

  bool _handled = false;
  bool get handled => _handled;

  /// 已授权或权限引导真实展示后，本次启动不再新增权限引导。
  void markHandled() => _handled = true;
}
