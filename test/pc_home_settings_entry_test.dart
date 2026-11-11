import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCSettingsDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCAudioUtils.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCSettingsLinks.dart';
import 'package:pennypilotcollectspin/PCTool/pc_WebKitView.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/pc_fake_audio.dart';
import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();

  testWidgets('首页齿轮扩大点击范围且不挡提现，大小屏真实开关保存后重开恢复', (tester) async {
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserGuideController.flowKey: '{"stage":"complete"}',
      'pc_new_guide_end': true,
      'pc_dollar_number': 20.0,
      'pc_pig_level': 0,
      'pc_pig_upgrade_seen_level_v1': 2,
    });
    final prefs = await SharedPreferences.getInstance();
    PigsTabController.currentIndex.value = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await PCNumberHelpers().pc_initNumberModel();
    await PCNewUserGuideController.instance.load();
    await PCLocalProvider.instance.init();
    final fake = PCFakeAudio();
    PCAudioUtils.overrideForTesting(fake.audio);
    await fake.audio.initializeForStartup();
    addTearDown(() => PCAudioUtils.overrideForTesting(null));
    final web = _SettingsWebPlatform();
    WebViewPlatform.instance = web;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    Future<void> frames() async {
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
    }

    for (final size in const [Size(375, 812), Size(320, 568), Size(430, 932)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: PCLocalProvider.instance,
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (_, _) => MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(top: 24)),
                child: child!,
              ),
              home: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: size.height - 88,
                  child: const PChome(),
                ),
              ),
            ),
          ),
        ),
      );
      await frames();
      final button = find.byKey(const ValueKey('pcHomeSettingsButton'));
      final icon = find.descendant(of: button, matching: find.byType(PCImg));
      final hitRect = tester.getRect(button);
      final iconRect = tester.getRect(icon);
      expect(hitRect.width, greaterThanOrEqualTo(44));
      expect(hitRect.height, greaterThanOrEqualTo(44));
      expect(iconRect.width, lessThan(hitRect.width));
      final withdraw = find.ancestor(
        of: find.text('Withdraw'),
        matching: find.byType(ParticleButton),
      );
      expect(hitRect.overlaps(tester.getRect(withdraw)), isFalse);
      final enlargedHit = Offset(hitRect.left + 2, hitRect.center.dy);
      expect(iconRect.contains(enlargedHit), isFalse);
      await tester.tapAt(enlargedHit);
      await frames();
      expect(find.byType(PCSettingsDialog), findsOneWidget);
      expect(PCDialogCoordinator.instance.isPresenting, isTrue);
      if (size.width == 375) {
        expect(fake.backgrounds.single.playing, isTrue);
        await tester.tap(find.byKey(const ValueKey('pcSettingsMusic')));
        await frames();
        expect(fake.backgrounds.single.playing, isFalse);
        expect(prefs.getBool('pc_bg_music'), isFalse);
        expect(PCLocalProvider.instance.pc_sound_music, isTrue);
        await tester.tap(find.byKey(const ValueKey('pcSettingsEffects')));
        await frames();
        expect(prefs.getBool('pc_sound_music'), isFalse);
        for (final (key, url, title) in [
          (
            'pcSettingsPrivacy',
            PCSettingsLinks.privacyPolicy,
            'Privacy Policy',
          ),
          ('pcSettingsTerms', PCSettingsLinks.termsOfUse, 'Terms of Use'),
        ]) {
          await tester.tap(find.byKey(ValueKey(key)));
          await frames();
          final page = tester.widget<PCWebkitview>(find.byType(PCWebkitview));
          expect(page.url, url);
          expect(page.title, title);
          expect(page.useNativeH5Client, isFalse);
          expect(web.requests.last.toString(), url);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await frames();
          expect(find.byType(PCSettingsDialog), findsOneWidget);
        }
        expect(web.requests, hasLength(2));
      }
      expect(
        find.byWidgetPredicate(
          (widget) => widget is PCImg && widget.name == 'pc_settings_music_off',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is PCImg && widget.name == 'pc_settings_volume_off',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('pcSettingsClose')));
      await frames();
      expect(PCDialogCoordinator.instance.isBusy, isFalse);
      await tester.pumpWidget(const SizedBox());
      await frames();
    }
    await fake.audio.dispose();
  });
}

class _SettingsWebPlatform extends WebViewPlatform {
  final requests = <Uri>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _SettingsWebController(params, requests);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _SettingsWebDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _SettingsWebSurface(params);
}

class _SettingsWebController extends PlatformWebViewController {
  _SettingsWebController(super.params, this.requests) : super.implementation();
  final List<Uri> requests;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate delegate,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      requests.add(params.uri);
}

class _SettingsWebDelegate extends PlatformNavigationDelegate {
  _SettingsWebDelegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
}

class _SettingsWebSurface extends PlatformWebViewWidget {
  _SettingsWebSurface(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
