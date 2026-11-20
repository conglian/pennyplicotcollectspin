import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCCash/PCAccountFeedbackDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCGuide3Dialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCNewUserHomeFlow.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCWheelGuideDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCConfirmAccountDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCProcessAccountDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWithdrawPage.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigUpgradeController.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessFlowController.dart';
import 'package:pennypilotcollectspin/PCTool/PCProcessFlowHost.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// SharedPreferences官方内存实现，用于模拟账号落盘尚未完成的实际异步窗口。
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> advance(WidgetTester tester, [int milliseconds = 800]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  Widget app(Widget child) => ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, _) => MaterialApp(home: child),
  );

  void expectNoAccountPages() {
    expect(find.byType(PCWithdrawPage), findsNothing);
    expect(find.byType(PCConfirmAccountDialog), findsNothing);
    expect(find.byType(PCProcessAccountDialog), findsNothing);
  }

  Future<void> showProcessHost(
    WidgetTester tester,
    PCProcessFlowController process,
    PCNewUserGuideController guide,
  ) async {
    await PCLocalProvider.instance.init();
    await PCPigUpgradeController.instance.refresh();
    await tester.pumpWidget(
      app(
        PCProcessFlowHost(
          controller: process,
          canPresent: () => guide.isComplete,
          onGoQuiz: () {},
          child: const Scaffold(body: Text('Ordinary quiz page')),
        ),
      ),
    );
    await advance(tester, 1600);
    expect(find.text('Ordinary quiz page'), findsOneWidget);
    expectNoAccountPages();
    expect(process.hasPending, isFalse);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  }

  // 表单枚举顺序与pc_act_*缓存序号不同，四个真实提交都要校验渠道映射。
  for (final channel in [
    ('PayPal', 0, 'payer@example.com'),
    ('Cash App', 2, '2025550123'),
  ]) {
    testWidgets('新用户${channel.$1}真实提交后，3题和80%及冷启动不再填写账号', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        PCNewUserGuideController.progressKey: 3,
        PCNewUserGuideController.flowKey: '{"stage":"payment"}',
        'pc_dollar_number': 30.0,
        'pc_pig_level': 0,
        'pc_quiz_num_index': 0,
      });
      await PCNumberHelpers().pc_initNumberModel();
      // 普通流程Host会在新引导结束前存在，不能只在首次load时识别确认账号。
      final process = PCProcessFlowController();
      await process.refresh(guideComplete: false);
      final guide = PCNewUserGuideController();
      await guide.load();
      await PCLocalProvider.instance.init();
      await tester.pumpWidget(
        app(
          PCNewUserHomeFlow(
            controller: guide,
            child: const Scaffold(body: Text('Home behind new user flow')),
          ),
        ),
      );
      await advance(tester);
      expect(find.byType(PCWithdrawPage), findsOneWidget);
      await tester.tap(find.text(channel.$1));
      await advance(tester, 200);

      final fields = find.byType(TextField);
      expect(fields, findsOneWidget);
      expect(find.text('Email/Phone Number'), findsOneWidget);
      await tester.enterText(fields, channel.$3);
      // 输入触发setState后先重建，否则上一帧Confirm仍保留禁用回调。
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm'));
      expect(
        tester
            .widget<InkWell>(
              find.ancestor(
                of: find.text('Confirm'),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNotNull,
      );
      await tester.tap(find.text('Confirm'));
      await advance(tester);
      expect(guide.stage, PCNewUserStage.officialNotice);
      expect(find.byType(PCAccountFeedbackDialog), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final account = channel.$3;
      expect(
        tester
            .widget<PCAccountFeedbackDialog>(
              find.byType(PCAccountFeedbackDialog),
            )
            .account,
        account,
      );
      expect(guide.confirmedUser, account);
      // 提交事务就必须写通用缓存；此时尚未再次refresh普通流程控制器。
      expect(prefs.getString('pc_account_id'), account);
      expect(prefs.getInt('pc_account_seled_index'), channel.$2);
      expect(PCLocalProvider.instance.pc_account_id, account);
      expect(PCLocalProvider.instance.pc_account_seled_index, channel.$2);

      await tester.tap(find.text('Continue'));
      await advance(tester);
      expect(find.byType(PCGuide3Dialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pcGrowBonusAction')));
      await advance(tester);
      expect(find.byType(PCWheelGuideDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pcWheelGuideTarget')));
      await advance(tester);
      expect(guide.isComplete, isTrue);
      expect(prefs.getBool('pc_new_guide_end'), isTrue);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);

      await tester.pumpWidget(const SizedBox());
      await advance(tester, 300);
      await prefs.setInt('pc_quiz_num_index', 3);
      await process.refresh(guideComplete: guide.isComplete);
      expect(
        process.pending.where(
          (p) => p.kind == PCProcessPromptKind.confirmAccount,
        ),
        isEmpty,
        reason: '新用户已确认的账号不能作为普通答题3题无账号再次触发',
      );
      await showProcessHost(tester, process, guide);
      expect(prefs.getString('pc_account_id'), account);
      expect(PCLocalProvider.instance.pc_account_id, account);
      expect(PCLocalProvider.instance.pc_account_seled_index, channel.$2);

      await prefs.setDouble('pc_dollar_number', 85.0);
      await PCLocalProvider.instance.init();
      await process.refresh(guideComplete: guide.isComplete);
      await advance(tester, 1600);
      expectNoAccountPages();
      expect(process.hasPending, isFalse, reason: '已确认账号跨过80%仍无需再次确认');
      expect(PCLocalProvider.instance.pc_account_id, account);
      expect(PCLocalProvider.instance.pc_account_seled_index, channel.$2);
      await tester.pumpWidget(const SizedBox());
      await advance(tester, 300);
      process.dispose();
      guide.dispose();

      final coldGuide = PCNewUserGuideController();
      await coldGuide.load();
      expect(coldGuide.isComplete, isTrue);
      expect(coldGuide.confirmedUser, account);
      final coldProcess = PCProcessFlowController();
      await coldProcess.refresh(guideComplete: coldGuide.isComplete);
      await showProcessHost(tester, coldProcess, coldGuide);
      expect(PCLocalProvider.instance.pc_account_id, account);
      expect(PCLocalProvider.instance.pc_account_seled_index, channel.$2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await advance(tester, 300);
      coldProcess.dispose();
      coldGuide.dispose();
    });
  }

  testWidgets('旧账号提示等待迁移写入完成，释放弹窗队列也不能抢先显示填写页', (tester) async {
    final originalStore = SharedPreferencesStorePlatform.instance;
    SharedPreferences.setMockInitialValues({
      'pc_quiz_num_index': 3,
      'pc_dollar_number': 30.0,
      'pc_pig_level': 0,
      'pc_account_seled_index': 2,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = _DelayedAccountStore({
      for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
    });
    SharedPreferencesStorePlatform.instance = store;
    final process = PCProcessFlowController(preferences: prefs);
    final release = PCDialogCoordinator.instance.holdPresentation();
    Future<void>? migration;
    try {
      await PCNumberHelpers().pc_initNumberModel(preferences: prefs);
      await process.refresh();
      expect(process.next?.id, 'account:first');
      await PCLocalProvider.instance.init();
      await PCPigUpgradeController.instance.refresh();
      await tester.pumpWidget(
        app(
          PCProcessFlowHost(
            controller: process,
            canPresent: () => true,
            onGoQuiz: () {},
            child: const Scaffold(body: Text('Quiz during account migration')),
          ),
        ),
      );
      await advance(tester);
      expect(process.next?.id, 'account:first');
      expectNoAccountPages();

      await prefs.setString(
        PCNewUserGuideController.flowKey,
        '{"stage":"complete","confirmedUser":"a***.com"}',
      );
      // Provider的更新通知触发真实Host.refresh，此时它尚未读到迁移账号。
      await PCLocalProvider.instance.init();
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.accountWriteStarted.isCompleted, isTrue);
      migration = process.refresh();
      expect(process.isRefreshing, isTrue);
      expect(process.next?.id, 'account:first');
      expect(PCLocalProvider.instance.pc_account_id, isEmpty);
      expect(
        (await store.getAll()).containsKey('flutter.pc_account_id'),
        isFalse,
      );

      release();
      await advance(tester, 1600);
      expect(process.isRefreshing, isTrue);
      expect(process.next?.id, 'account:first');
      expectNoAccountPages();
      expect(PCDialogCoordinator.instance.isBusy, isFalse);

      store.releaseAccountWrite.complete();
      await migration;
      await advance(tester, 1600);
      expect(process.isRefreshing, isFalse);
      expect(process.hasPending, isFalse);
      expectNoAccountPages();
      expect(prefs.getString('pc_account_id'), 'a***.com');
      expect(PCLocalProvider.instance.pc_account_id, 'a***.com');
      expect(PCLocalProvider.instance.pc_account_seled_index, 2);
      expect(store.accountWrites, 1);
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      if (!store.releaseAccountWrite.isCompleted) {
        store.releaseAccountWrite.complete();
      }
      release();
      try {
        if (migration != null) await migration;
      } finally {
        try {
          await tester.pumpWidget(const SizedBox());
          await advance(tester, 300);
        } finally {
          process.dispose();
          SharedPreferencesStorePlatform.instance = originalStore;
        }
      }
    }
  });
}

class _DelayedAccountStore extends InMemorySharedPreferencesStore {
  _DelayedAccountStore(super.data) : super.withData();
  final accountWriteStarted = Completer<void>();
  final releaseAccountWrite = Completer<void>();
  int accountWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.pc_account_id') {
      accountWrites++;
      if (!accountWriteStarted.isCompleted) accountWriteStarted.complete();
      await releaseAccountWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
}
