import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCGrowBonusDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigUpgradeController.dart';
import 'package:pennypilotcollectspin/PCTool/PCReturningUserController.dart';
import 'package:pennypilotcollectspin/PCTool/PCReturningUserHost.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'support/pc_number_test_assets.dart';

// 主猪持续呼吸，不等待整棵树settle；逐帧完成弹窗入退场与本地异步记录。
Future<void> _pumpReturning(WidgetTester tester) async {
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首日只建立基线，跨自然日一次，同日冷启动不重复', () async {
    var now = DateTime(2026, 10, 25, 23, 59);
    final first = PCReturningUserController(now: () => now);
    await first.prepareLaunch(isExistingUser: false);
    expect(first.isPending, isFalse);
    await first.prepareLaunch(isExistingUser: true);
    expect(first.isPending, isFalse);
    now = DateTime(2026, 10, 26, 0, 1);
    final returned = PCReturningUserController(now: () => now);
    await returned.prepareLaunch(isExistingUser: true);
    expect(returned.isPending, isTrue, reason: '按自然日判断，不需要满24小时');
    await returned.markShown();
    await returned.markShown();
    final cold = PCReturningUserController(now: () => now);
    await cold.prepareLaunch(isExistingUser: true);
    expect(cold.isPending, isFalse);
    now = DateTime(2026, 10, 27);
    await cold.prepareLaunch(isExistingUser: true);
    expect(cold.isPending, isTrue);
  });

  test('旧安装从 pc_day_date 迁移，已更新启动日但未展示也可恢复', () async {
    SharedPreferences.setMockInitialValues({'pc_day_date': '2026-10-24'});
    final prefs = await SharedPreferences.getInstance();
    final first = PCReturningUserController(
      preferences: prefs,
      now: () => DateTime(2026, 10, 25),
    );
    await first.prepareLaunch(isExistingUser: true);
    expect(first.isPending, isTrue);
    await prefs.setString('pc_day_date', '2026-10-25');
    final restored = PCReturningUserController(
      preferences: prefs,
      now: () => DateTime(2026, 10, 25, 15),
    );
    await restored.prepareLaunch(isExistingUser: true);
    expect(restored.isPending, isTrue);
    await restored.markShown();
    await restored.prepareLaunch(isExistingUser: true);
    expect(restored.isPending, isFalse);
  });

  test('未完成新手引导跨天不触发，完成当日不插入回访提示', () async {
    SharedPreferences.setMockInitialValues({'pc_day_date': '2026-10-20'});
    var now = DateTime(2026, 10, 25);
    final flow = PCReturningUserController(now: () => now);
    await flow.prepareLaunch(isExistingUser: false);
    expect(flow.isPending, isFalse);
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isFalse);
    now = DateTime(2026, 10, 26);
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isTrue);
  });

  test('多日未打开只提示一次，展示不会增加任何阶段余额', () async {
    SharedPreferences.setMockInitialValues({
      'pc_day_date': '2026-09-10',
      'pc_dollar_number': 56.2,
      'pc_quiz_diamonds': 7.25,
      'pc_quiz_gold': 3.15,
    });
    final flow = PCReturningUserController(now: () => DateTime(2026, 10, 25));
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isTrue);
    await flow.markShown();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('pc_dollar_number'), 56.2);
    expect(prefs.getDouble('pc_quiz_diamonds'), 7.25);
    expect(prefs.getDouble('pc_quiz_gold'), 3.15);
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isFalse);
  });

  test('日期回拨不重复展示，恢复到原来的日期也不误判跨天', () async {
    SharedPreferences.setMockInitialValues({'pc_day_date': '2026-10-24'});
    var now = DateTime(2026, 10, 25);
    final flow = PCReturningUserController(now: () => now);
    await flow.prepareLaunch(isExistingUser: true);
    await flow.markShown();
    now = DateTime(2026, 10, 23);
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isFalse);
    now = DateTime(2026, 10, 25);
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isFalse);
    now = DateTime(2026, 10, 26);
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isTrue);
  });

  test('异常记录回退历史日期，异常历史日期只重建基线', () async {
    SharedPreferences.setMockInitialValues({
      PCReturningUserController.storageKey: 'broken',
      'pc_day_date': '2026-10-24',
    });
    final flow = PCReturningUserController(now: () => DateTime(2026, 10, 25));
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCReturningUserController.storageKey,
      jsonEncode({'lastOpenDay': '2026-02-31', 'pendingDay': 'invalid'}),
    );
    await prefs.setString('pc_day_date', 'not-a-date');
    await flow.prepareLaunch(isExistingUser: true);
    expect(flow.isPending, isFalse);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('回访弹窗在$size显示本地金额，Go Earn仅关闭后切答题', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'pc_day_date': '2026-10-24',
        'pc_dollar_number': 56.2,
      });
      await PCLocalProvider.instance.init();
      final flow = PCReturningUserController(now: () => DateTime(2026, 10, 25));
      await flow.prepareLaunch(isExistingUser: true);
      PigsTabController.switchTo(0);
      await tester.pumpWidget(
        MaterialApp(
          home: PCReturningUserHost(
            controller: flow,
            canPresent: () => true,
            onGoEarn: () => PigsTabController.switchTo(1),
            child: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      await _pumpReturning(tester);
      expect(find.byType(PCGrowBonusDialog), findsOneWidget);
      expect(find.text('\$56.20'), findsWidgets);
      expect(find.text('Reminder Me'), findsNothing);
      final buttonImage = find.byWidgetPredicate(
        (widget) => widget is PCImg && widget.name == 'pc_grow_bonus_button',
      );
      expect(tester.getSize(buttonImage).width, greaterThan(200));
      expect(tester.getSize(buttonImage).height, greaterThan(45));
      expect(flow.isPending, isFalse);
      expect(PCPigUpgradeController.instance.isBlocked, isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('pcGrowBonusAction')));
      await _pumpReturning(tester);
      expect(find.byType(PCGrowBonusDialog), findsNothing);
      expect(PigsTabController.currentIndex.value, 1);
      expect(PCLocalProvider.instance.pc_dollar_number, 56.2);
      expect(PCPigUpgradeController.instance.isBlocked, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('关闭只收起，当天再次进入前台不重复，隔天回前台再显示', (tester) async {
    SharedPreferences.setMockInitialValues({'pc_day_date': '2026-10-24'});
    await PCLocalProvider.instance.init();
    var now = DateTime(2026, 10, 25);
    final flow = PCReturningUserController(now: () => now);
    await flow.prepareLaunch(isExistingUser: true);
    PigsTabController.switchTo(0);
    await tester.pumpWidget(
      MaterialApp(
        home: PCReturningUserHost(
          controller: flow,
          canPresent: () => true,
          onGoEarn: () => PigsTabController.switchTo(1),
          child: const Scaffold(),
        ),
      ),
    );
    await _pumpReturning(tester);
    await tester.tap(find.byKey(const ValueKey('pcGrowBonusClose')));
    await _pumpReturning(tester);
    expect(PigsTabController.currentIndex.value, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpReturning(tester);
    expect(find.byType(PCGrowBonusDialog), findsNothing);
    now = DateTime(2026, 10, 26);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpReturning(tester);
    expect(find.byType(PCGrowBonusDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(PCPigUpgradeController.instance.isBlocked, isFalse);
  });

  testWidgets('新用户流程未完成时不盖住引导，也不消费待提示记录', (tester) async {
    SharedPreferences.setMockInitialValues({'pc_day_date': '2026-10-24'});
    final flow = PCReturningUserController(now: () => DateTime(2026, 10, 25));
    await flow.prepareLaunch(isExistingUser: true);
    await tester.pumpWidget(
      MaterialApp(
        home: PCReturningUserHost(
          controller: flow,
          canPresent: () => false,
          onGoEarn: () => fail('不能跳答题'),
          child: const Scaffold(body: Text('Guide')),
        ),
      ),
    );
    await _pumpReturning(tester);
    expect(find.byType(PCGrowBonusDialog), findsNothing);
    expect(flow.isPending, isTrue);
    expect(PCPigUpgradeController.instance.isBlocked, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
