import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCSessionLifecycleController.dart';

void main() {
  late PCSessionLifecycleController controller;
  late bool nativeAdShowing;
  late List<String> sessions;

  void lifecycle(AppLifecycleState state) =>
      controller.didChangeAppLifecycleState(state);

  setUp(() {
    nativeAdShowing = false;
    sessions = [];
    controller = PCSessionLifecycleController(
      isNativeAdShowing: () => nativeAdShowing,
      onSession: sessions.add,
    );
    controller.start();
  });

  test('冷启动只记一次，初始和重复resumed不会再记会话', () {
    controller.start();
    lifecycle(AppLifecycleState.resumed);
    controller.start();
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start']);
  });

  test('进入后台立即上报，hidden和paused合并一次且返回前台另记一次', () {
    lifecycle(AppLifecycleState.inactive);
    expect(sessions, ['cold_start']);
    lifecycle(AppLifecycleState.hidden);
    expect(sessions, ['cold_start', 'background_enter']);
    lifecycle(AppLifecycleState.paused);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.inactive);
    expect(sessions, ['cold_start', 'background_enter']);
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start', 'background_enter', 'foreground_return']);
  });

  test('消费后台记录后重复resumed不重复上报', () {
    lifecycle(AppLifecycleState.paused);
    expect(sessions, ['cold_start', 'background_enter']);
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start', 'background_enter', 'foreground_return']);
  });

  test('权限窗口只有inactive和resumed不算热启动', () {
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.inactive);
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start']);
  });

  test('原生广告造成后台切换，广告关闭后返回不记新会话', () {
    nativeAdShowing = true;
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    expect(sessions, ['cold_start']);
    nativeAdShowing = false;
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start']);
  });

  test('重复paused不能覆盖首次记录的原生广告状态', () {
    nativeAdShowing = true;
    lifecycle(AppLifecycleState.paused);
    nativeAdShowing = false;
    lifecycle(AppLifecycleState.paused);
    lifecycle(AppLifecycleState.hidden);
    expect(sessions, ['cold_start']);
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start']);
  });

  test('正常返回时其他observer已开始新广告仍应记本次会话', () {
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.paused);
    nativeAdShowing = true;
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start', 'background_enter', 'foreground_return']);
  });

  test('首次后台无广告，后续paused不能改为广告回切吞掉会话', () {
    lifecycle(AppLifecycleState.hidden);
    expect(sessions, ['cold_start', 'background_enter']);
    nativeAdShowing = true;
    lifecycle(AppLifecycleState.paused);
    nativeAdShowing = false;
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, ['cold_start', 'background_enter', 'foreground_return']);
  });

  test('广告回切结束后，下一次正常后台返回继续上报', () {
    nativeAdShowing = true;
    lifecycle(AppLifecycleState.paused);
    nativeAdShowing = false;
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.paused);
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.hidden);
    lifecycle(AppLifecycleState.resumed);

    expect(sessions, [
      'cold_start',
      'background_enter',
      'foreground_return',
      'background_enter',
      'foreground_return',
    ]);
  });

  test('detached保留已上报后台事件，清除记录后恢复不会补记前台', () {
    lifecycle(AppLifecycleState.paused);
    expect(sessions, ['cold_start', 'background_enter']);
    lifecycle(AppLifecycleState.detached);
    lifecycle(AppLifecycleState.resumed);
    expect(sessions, ['cold_start', 'background_enter']);

    lifecycle(AppLifecycleState.paused);
    expect(sessions, ['cold_start', 'background_enter', 'background_enter']);
    lifecycle(AppLifecycleState.resumed);
    expect(sessions, [
      'cold_start',
      'background_enter',
      'background_enter',
      'foreground_return',
    ]);
  });
}
