import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5.dart';
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5_platform_interface.dart';
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPenyplicotcollectspinsh5Platform
    with MockPlatformInterfaceMixin
    implements Penyplicotcollectspinsh5Platform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  Future<void> Function() createHandler = () async {};
  int createCalls = 0;
  int pageLoggingStarts = 0;

  @override
  Future<void> create() {
    createCalls++;
    return createHandler();
  }

  @override
  void startPageLogging() {
    pageLoggingStarts++;
  }
}

void main() {
  final Penyplicotcollectspinsh5Platform initialPlatform =
      Penyplicotcollectspinsh5Platform.instance;

  tearDown(() {
    Penyplicotcollectspinsh5Platform.instance = initialPlatform;
  });

  test('$MethodChannelPenyplicotcollectspinsh5 is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelPenyplicotcollectspinsh5>(),
    );
  });

  test('getPlatformVersion', () async {
    Penyplicotcollectspinsh5 penyplicotcollectspinsh5Plugin =
        Penyplicotcollectspinsh5();
    MockPenyplicotcollectspinsh5Platform fakePlatform =
        MockPenyplicotcollectspinsh5Platform();
    Penyplicotcollectspinsh5Platform.instance = fakePlatform;

    expect(await penyplicotcollectspinsh5Plugin.getPlatformVersion(), '42');
  });

  test('create转发到平台并等待原生入口返回', () async {
    final native = Completer<void>();
    final fake = MockPenyplicotcollectspinsh5Platform()
      ..createHandler = () => native.future;
    Penyplicotcollectspinsh5Platform.instance = fake;
    var completed = false;
    final pending = Penyplicotcollectspinsh5().create().then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(fake.createCalls, 1);
    expect(completed, isFalse);
    native.complete();
    await pending;
    expect(completed, isTrue);
  });

  test('create保留原生失败，不将无Activity当成成功', () async {
    final fake = MockPenyplicotcollectspinsh5Platform()
      ..createHandler = () async {
        throw PlatformException(code: 'H5_NO_ACTIVITY');
      };
    Penyplicotcollectspinsh5Platform.instance = fake;
    await expectLater(
      Penyplicotcollectspinsh5().create(),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'H5_NO_ACTIVITY',
        ),
      ),
    );
    expect(fake.createCalls, 1);
  });

  test('日志接收可独立启用，不重复调用原生create', () {
    final fake = MockPenyplicotcollectspinsh5Platform();
    Penyplicotcollectspinsh5Platform.instance = fake;
    Penyplicotcollectspinsh5().startPageLogging();
    expect(fake.pageLoggingStarts, 1);
    expect(fake.createCalls, 0);
  });

  testWidgets('WebView在非Android平台显示占位且不调用原生', (tester) async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final fake = MockPenyplicotcollectspinsh5Platform();
      Penyplicotcollectspinsh5Platform.instance = fake;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Penyplicotcollectspinsh5WebView(
            url: 'https://example.com/game',
          ),
        ),
      );
      expect(find.text('H5 WebView requires Android.'), findsOneWidget);
      expect(find.byType(AndroidView), findsNothing);
      expect(fake.createCalls, 0);
      expect(fake.pageLoggingStarts, 0);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}
