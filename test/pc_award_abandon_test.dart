import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCOtherDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> seed([int probability = 0]) async {
    SharedPreferences.setMockInitialValues({
      'pc_bg_music': false,
      'pc_dollar_number': 56.0,
      PCNumberHelpers.configKey: jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': probability},
        ],
      }),
    });
    await PCLocalProvider.instance.init();
    await PCNumberHelpers().pc_initNumberModel();
  }

  Future<void> frames(WidgetTester tester, [int duration = 600]) async {
    for (var elapsed = 0; elapsed < duration; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('Reward UI frame failed: $error');
    }
  }

  Future<BuildContext> host(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext context;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await frames(tester, 400);
      PCRewardedAdService.instance.handler = null;
      PCInterstitialAdService.instance.handler = null;
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
    });
    return context;
  }

  Finder close() => find.byKey(const ValueKey('pcQuizCloseReward'));
  Finder claim() => find.byKey(const ValueKey('pcQuizClaimReward'));

  testWidgets('关闭先等待持久化放弃，再播放插屏，重复关闭只清理一次', (tester) async {
    await seed(100);
    final persisted = Completer<void>();
    final ad = Completer<bool>();
    var abandoned = 0;
    var interstitials = 0;
    PCInterstitialAdService.instance.handler = (_) {
      interstitials++;
      return ad.future;
    };
    final context = await host(tester);
    final result = context.tipShow2(
      PCAwardDialog(
        award: 1,
        onAbandon: () {
          abandoned++;
          return persisted.future;
        },
      ),
    );
    await frames(tester);
    await tester.tap(close());
    await tester.tap(close(), warnIfMissed: false);
    await frames(tester, 100);
    expect(abandoned, 1);
    expect(interstitials, 0);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    persisted.complete();
    await frames(tester, 100);
    expect(interstitials, 1);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    ad.complete(false);
    await frames(tester);
    expect(await result, false);
    expect(abandoned, 1);
  });

  testWidgets('系统返回同样等待持久化放弃后退出，不缓存旧奖励', (tester) async {
    await seed();
    final persisted = Completer<void>();
    var abandoned = 0;
    final context = await host(tester);
    final result = context.tipShow2(
      PCAwardDialog(
        award: 1,
        onAbandon: () {
          abandoned++;
          return persisted.future;
        },
      ),
    );
    await frames(tester);
    await tester.binding.handlePopRoute();
    await frames(tester, 100);
    expect(abandoned, 1);
    expect(find.byType(PCAwardDialog), findsOneWidget);
    persisted.complete();
    await frames(tester);
    expect(await result, false);
    expect(find.byType(PCAwardDialog), findsNothing);
  });

  for (final exit in ['Try Again', 'X', 'back']) {
    testWidgets('激励失败先清理，失败面板$exit退出不重复清理或播放插屏', (tester) async {
      await seed(100);
      final persisted = Completer<void>();
      var abandoned = 0;
      var interstitials = 0;
      var claims = 0;
      PCRewardedAdService.instance.handler = (_) async => false;
      PCInterstitialAdService.instance.handler = (_) async {
        interstitials++;
        return true;
      };
      final context = await host(tester);
      final result = context.tipShow2(
        PCAwardDialog(
          award: 1,
          onAbandon: () {
            abandoned++;
            return persisted.future;
          },
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      await tester.tap(claim());
      await frames(tester, 100);
      expect(abandoned, 1);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
      expect(find.byType(PCAwardDialog), findsOneWidget);
      persisted.complete();
      await frames(tester);
      expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
      switch (exit) {
        case 'Try Again':
          await tester.tap(find.text('Try Again').last);
        case 'X':
          await tester.tap(find.byType(PCDialogCloseButton));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await frames(tester);
      expect(find.byType(PCAwardDialog), findsNothing);
      expect(await result, false);
      expect(abandoned, 1);
      expect(claims, 0);
      expect(interstitials, 0);
    });
  }

  testWidgets('成功Claim只执行发奖，不执行放弃回调', (tester) async {
    await seed();
    var abandoned = 0;
    var claims = 0;
    PCRewardedAdService.instance.handler = (_) async => true;
    final context = await host(tester);
    final result = context.tipShow2(
      PCAwardDialog(
        award: 1,
        onAbandon: () async => abandoned++,
        onClaim: () async {
          claims++;
          return true;
        },
      ),
    );
    await frames(tester);
    await tester.tap(claim());
    await frames(tester);
    expect(await result, true);
    expect(claims, 1);
    expect(abandoned, 0);
  });

  testWidgets('关闭清理迟到时只处理原路由，不能播放插屏或退出新页面', (tester) async {
    await seed(100);
    final persisted = Completer<void>();
    var abandoned = 0;
    var interstitials = 0;
    PCInterstitialAdService.instance.handler = (_) async {
      interstitials++;
      return true;
    };
    final context = await host(tester);
    final navigator = Navigator.of(context);
    final result = context.tipShow2(
      PCAwardDialog(
        award: 1,
        onAbandon: () {
          abandoned++;
          return persisted.future;
        },
      ),
    );
    await frames(tester);
    await tester.tap(close());
    await frames(tester, 100);
    navigator.pop(false);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New page stays open')),
      ),
    );
    persisted.complete();
    await frames(tester);
    expect(await result, false);
    expect(abandoned, 1);
    expect(interstitials, 0);
    expect(find.text('New page stays open'), findsOneWidget);
  });

  testWidgets('激励失败迟到仍清理原奖励，不触碰后打开的页面', (tester) async {
    await seed();
    final ad = Completer<bool>();
    var abandoned = 0;
    PCRewardedAdService.instance.handler = (_) => ad.future;
    final context = await host(tester);
    final navigator = Navigator.of(context);
    final result = context.tipShow2(
      PCAwardDialog(award: 1, onAbandon: () async => abandoned++),
    );
    await frames(tester);
    await tester.tap(claim());
    await frames(tester, 100);
    navigator.pop(false);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New page stays open')),
      ),
    );
    ad.complete(false);
    await frames(tester);
    expect(await result, false);
    expect(abandoned, 1);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expect(find.text('New page stays open'), findsOneWidget);
  });
}
