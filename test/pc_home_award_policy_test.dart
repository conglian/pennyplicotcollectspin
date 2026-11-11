import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> seed(int probability) async {
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

  Future<BuildContext> show(WidgetTester tester) async {
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

  Finder getClaim() => find.byKey(const ValueKey('pcQuizClaimReward'));
  Finder getClose() => find.byKey(const ValueKey('pcQuizCloseReward'));
  Finder getBadge() => find.byWidgetPredicate(
    (widget) => widget is PCImg && widget.name == 'pc_ad_icon',
  );

  testWidgets('首页概率为0时Claim无AD且直接结算，不再播放第二次激励', (tester) async {
    await seed(0);
    var rewarded = 0;
    var interstitials = 0;
    var claims = 0;
    PCRewardedAdService.instance.handler = (_) async {
      rewarded++;
      return false;
    };
    PCInterstitialAdService.instance.handler = (_) async {
      interstitials++;
      return true;
    };
    final context = await show(tester);
    final result = context.tipShow2(
      PCAwardDialog(
        award: .2,
        claimAdPolicy: PCAwardClaimAdPolicy.probabilityInterstitial,
        onClaim: () async {
          claims++;
          return true;
        },
      ),
    );
    await frames(tester);
    expect(getBadge(), findsNothing);
    await tester.tap(getClaim());
    await frames(tester);
    expect(await result, isTrue);
    expect(claims, 1);
    expect(rewarded, 0);
    expect(interstitials, 0);
  });

  for (final adSucceeded in [true, false]) {
    testWidgets('首页Claim概率插屏${adSucceeded ? '成功' : '失败'}均只结算一次，广告期间关闭与连点互斥', (
      tester,
    ) async {
      await seed(100);
      final ad = Completer<bool>();
      final placements = <String>[];
      var rewarded = 0;
      var claims = 0;
      PCRewardedAdService.instance.handler = (_) async {
        rewarded++;
        return false;
      };
      PCInterstitialAdService.instance.handler = (placement) {
        placements.add(placement);
        return ad.future;
      };
      final context = await show(tester);
      final result = context.tipShow2(
        PCAwardDialog(
          award: .2,
          claimAdPolicy: PCAwardClaimAdPolicy.probabilityInterstitial,
          claimInterstitialAdPlacement: 'home_claim_int',
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      expect(getBadge(), findsNothing);
      await tester.tap(getClaim());
      await tester.tap(getClaim(), warnIfMissed: false);
      await tester.tap(getClose(), warnIfMissed: false);
      await frames(tester, 200);
      expect(placements, ['home_claim_int']);
      expect(claims, 0);
      expect(PCDialogCoordinator.instance.isPresenting, isTrue);
      ad.complete(adSucceeded);
      await frames(tester);
      expect(await result, isTrue);
      expect(claims, 1);
      expect(rewarded, 0);
      expect(placements, ['home_claim_int']);
      expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    });
  }

  testWidgets('首页Claim插屏迟到回调不能结算已移除路由或关闭新页面', (tester) async {
    await seed(100);
    final ad = Completer<bool>();
    var claims = 0;
    PCInterstitialAdService.instance.handler = (_) => ad.future;
    final context = await show(tester);
    final navigator = Navigator.of(context);
    final result = context.tipShow2(
      PCAwardDialog(
        award: .2,
        claimAdPolicy: PCAwardClaimAdPolicy.probabilityInterstitial,
        onClaim: () async {
          claims++;
          return true;
        },
      ),
    );
    await frames(tester);
    await tester.tap(getClaim());
    await frames(tester, 100);
    navigator.pop(false);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New page')),
      ),
    );
    ad.complete(true);
    await frames(tester);
    expect(await result, isFalse);
    expect(claims, 0);
    expect(find.text('New page'), findsOneWidget);
  });

  testWidgets('默认答题转盘策略仍显示AD，激励失败保留奖励且不调用概率插屏', (tester) async {
    await seed(100);
    var claims = 0;
    var interstitials = 0;
    final rewardedPlacements = <String>[];
    PCRewardedAdService.instance.handler = (placement) async {
      rewardedPlacements.add(placement);
      return false;
    };
    PCInterstitialAdService.instance.handler = (_) async {
      interstitials++;
      return true;
    };
    final context = await show(tester);
    final result = context.tipShow2(
      PCAwardDialog(
        award: .2,
        onClaim: () async {
          claims++;
          return true;
        },
      ),
    );
    await frames(tester);
    expect(getBadge(), findsOneWidget);
    await tester.tap(getClaim());
    await frames(tester);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(rewardedPlacements, ['rv']);
    expect(interstitials, 0);
    expect(claims, 0);
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(await result, isFalse);
  });

  testWidgets('新用户免广告优先于首页策略，Claim直接领取且关闭不播放广告', (tester) async {
    await seed(100);
    var ads = 0;
    var claims = 0;
    PCRewardedAdService.instance.handler = (_) async {
      ads++;
      return true;
    };
    PCInterstitialAdService.instance.handler = (_) async {
      ads++;
      return true;
    };
    final context = await show(tester);
    for (final claim in [true, false]) {
      final result = context.tipShow2(
        PCAwardDialog(
          award: .2,
          adsEnabled: false,
          claimAdPolicy: PCAwardClaimAdPolicy.probabilityInterstitial,
          onClaim: () async {
            claims++;
            return true;
          },
        ),
      );
      await frames(tester);
      expect(getBadge(), findsNothing);
      await tester.tap(claim ? getClaim() : getClose());
      await frames(tester);
      expect(await result, claim);
    }
    expect(ads, 0);
    expect(claims, 1);
  });
}
