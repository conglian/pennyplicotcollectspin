import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCMainVC/PCWheel.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/PCBalanceHeader.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelBonusChest.dart';
import 'package:pennypilotcollectspin/PCTool/PCWheelController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_WebKitView.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// WebView在Chrome回归中使用平台接口替身，生产仍使用已有原生PCWebkitview。
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  Future<void> frames(WidgetTester tester, [int duration = 600]) async {
    for (var elapsed = 0; elapsed < duration; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final error = tester.takeException();
      if (error != null) throw StateError('Wheel chest frame failed: $error');
    }
  }

  for (final (size, level) in [
    (const Size(320, 568), 1),
    (const Size(375, 812), 0),
    (const Size(430, 932), 2),
  ]) {
    testWidgets('转盘宝箱在${size.width}宽阶段$level不盖余额，单次打开Games并保持转盘状态', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        PCNewUserGuideController.progressKey: 3,
        PCNewUserGuideController.flowKey: '{"stage":"complete"}',
        'pc_new_guide_end': true,
        'pc_pig_upgrade_seen_level_v1': level,
        'pc_bg_music': false,
        'pc_pig_level': level,
        'pc_dollar_number': level == 0 ? 10.0 : 100.0,
        'pc_quiz_diamonds': level == 0 ? 0.0 : 3.5,
        'pc_quiz_gold': level == 2 ? 4.0 : 0.0,
      });
      await PCNumberHelpers().pc_initNumberModel();
      await PCLocalProvider.instance.init();
      await PCNewUserGuideController.instance.load();
      final flow = PCWheelController();
      final events = <String>[];
      final web = _FakeWebViewPlatform();
      WebViewPlatform.instance = web;
      PCAnalytics.reporter = (name, _) => events.add(name);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      PigsTabController.currentIndex.value = 2;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await frames(tester, 400);
        flow.dispose();
        PCAnalytics.resetForTesting();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: PCLocalProvider.instance,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) =>
                MaterialApp(home: PCWheel(controller: flow, active: true)),
          ),
        ),
      );
      await frames(tester);
      final chest = find.byKey(const ValueKey('pcWheelBonusChestButton'));
      final chestRect = tester.getRect(chest);
      final headerRect = tester.getRect(find.byType(PCBalanceHeader));
      expect(chestRect.top, greaterThan(headerRect.bottom));
      expect(chestRect.left, greaterThanOrEqualTo(0));
      expect(chestRect.right, lessThanOrEqualTo(size.width));
      expect(chestRect.height, greaterThanOrEqualTo(44));
      expect(chestRect.bottom, lessThan(size.height));
      final beforeSpins = flow.spins;
      final prefs = await SharedPreferences.getInstance();
      final beforeCash = prefs.getDouble('pc_dollar_number');
      final beforeDiamonds = flow.diamonds;
      final beforeGold = flow.gold;
      await tester.tap(chest);
      // 在导航入场前连点，不能再叠加第二个网页或重复点击事件。
      await tester.tap(chest, warnIfMissed: false);
      await frames(tester);
      expect(events.where((name) => name == 'h5_c'), hasLength(1));
      expect(events.where((name) => name == 'h5_page'), hasLength(1));
      expect(find.byType(PCWebkitview), findsOneWidget);
      expect(
        tester
            .widget<PCWebkitview>(find.byType(PCWebkitview))
            .useNativeH5Client,
        isTrue,
      );
      expect(find.text('Games'), findsOneWidget);
      expect(web.requests, [Uri.parse('https://tinyurl.com/dfr3jy4u')]);
      await frames(tester, 500);
      expect(events.where((name) => name == 'h5_page'), hasLength(1));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await frames(tester);
      expect(find.byType(PCWebkitview), findsNothing);
      expect(chest, findsOneWidget);
      expect(flow.spins, beforeSpins);
      expect(prefs.getDouble('pc_dollar_number'), beforeCash);
      expect(flow.diamonds, beforeDiamonds);
      expect(flow.gold, beforeGold);
      expect(flow.pending, isNull);
      // 返回后可再次进入，每次真实网页访问各记一次曝光。
      await tester.tap(chest);
      await frames(tester);
      expect(events.where((name) => name == 'h5_c'), hasLength(2));
      expect(events.where((name) => name == 'h5_page'), hasLength(2));
      expect(web.requests, hasLength(2));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await frames(tester);
    });
  }

  testWidgets('宝箱平缓呼吸，减少动画和离页时保持正常尺寸且停表', (tester) async {
    var active = true;
    var reduceMotion = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: Center(
                child: PCWheelBonusChest(active: active, onTap: () {}),
              ),
            );
          },
        ),
      ),
    );
    double scale() => tester
        .widget<ScaleTransition>(
          find.byKey(const ValueKey('pcWheelBonusChestBreath')),
        )
        .scale
        .value;
    final first = scale();
    await frames(tester, 400);
    expect(scale(), isNot(closeTo(first, .001)));
    expect(scale(), inInclusiveRange(.96, 1.04));
    rebuild(() => reduceMotion = true);
    await tester.pump();
    expect(scale(), closeTo(1, .0001));
    await frames(tester, 1700);
    expect(scale(), closeTo(1, .0001));
    rebuild(() {
      reduceMotion = false;
      active = false;
    });
    await tester.pump();
    await frames(tester, 1700);
    expect(scale(), closeTo(1, .0001));
    expect(tester.binding.hasScheduledFrame, false);
    await tester.pumpWidget(const SizedBox());
  });
}

class _FakeWebViewPlatform extends WebViewPlatform {
  final requests = <Uri>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeWebViewController(params, requests);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWebViewWidget(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params, this.requests) : super.implementation();
  final List<Uri> requests;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    requests.add(params.uri);
  }
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('pcFakeWebViewSurface'));
}
