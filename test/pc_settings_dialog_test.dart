import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCSettingsDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final local = PCLocalProvider.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    local.pc_bg_music = true;
    local.pc_sound_music = true;
  });

  Future<void> open(
    WidgetTester tester, {
    Future<void> Function(bool)? background,
    Future<void> Function(bool)? effects,
    Future<void> Function()? privacy,
    contact,
    terms,
    Size size = const Size(375, 812),
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(size: size, padding: padding),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => context.tipShow2(
                PCSettingsDialog(
                  onBackgroundMusicChanged: background,
                  onSoundEffectsChanged: effects,
                  onPrivacyPolicy: privacy,
                  onContactUs: contact,
                  onTermsOfUse: terms,
                ),
              ),
              child: const Text('open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(PCSettingsDialog), findsOneWidget);
    expect(PCDialogCoordinator.instance.isBusy, isTrue);
  }

  Finder image(String name) => find.byWidgetPredicate(
    (widget) => widget is PCImg && widget.name == name,
  );
  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('pcSettingsClose')));
    await tester.pumpAndSettle();
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('两个开关默认打开，音效保存中防重，关闭不影响背景音乐', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    final prefs = await SharedPreferences.getInstance();
    await open(
      tester,
      effects: (value) async {
        calls++;
        await pending.future;
        await prefs.setBool('pc_sound_music', value);
        local.pc_sound_music = value;
      },
    );
    expect(image('pc_settings_volume_on'), findsOneWidget);
    expect(image('pc_settings_music_on'), findsOneWidget);
    final effects = find.byKey(const ValueKey('pcSettingsEffects'));
    await tester.tap(effects);
    await tester.pumpAndSettle();
    await tester.tap(effects);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.widget<ParticleButton>(effects).enabled, isFalse);
    pending.complete();
    await tester.pumpAndSettle();
    expect(prefs.getBool('pc_sound_music'), isFalse);
    expect(image('pc_settings_volume_off'), findsOneWidget);
    expect(image('pc_settings_music_on'), findsOneWidget);
    expect(local.pc_bg_music, isTrue);
    await close(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('使用真实缓存的关闭状态，保存失败保留图标且允许重试', (tester) async {
    local.pc_bg_music = false;
    var calls = 0;
    await open(
      tester,
      background: (value) async {
        calls++;
        if (calls == 1) throw StateError('disk unavailable');
        local.pc_bg_music = value;
      },
    );
    expect(image('pc_settings_music_off'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcSettingsMusic')));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(image('pc_settings_music_off'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcSettingsMusic')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(image('pc_settings_music_on'), findsOneWidget);
    expect(find.byKey(const ValueKey('pcSettingsMessage')), findsNothing);
    await close(tester);
  });

  testWidgets('隐私及联系地址暂空时仅面板内提示，不覆盖新弹窗', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('pcSettingsPrivacy')));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy is not available yet.'), findsOneWidget);
    expect(find.byType(PCSettingsDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcSettingsContact')));
    await tester.pumpAndSettle();
    expect(find.text('Contact details are not available yet.'), findsOneWidget);
    expect(find.byType(PCSettingsDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcSettingsTerms')));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Use is not available yet.'), findsOneWidget);
    expect(find.byType(PCSettingsDialog), findsOneWidget);
    await close(tester);
  });

  testWidgets('用户条例和隐私分别调用正确入口，空联系保持局部提示且布局不重叠', (tester) async {
    final calls = <String>[];
    await open(
      tester,
      privacy: () async {
        calls.add('privacy');
      },
      terms: () async {
        calls.add('terms');
      },
    );
    await tester.tap(find.byKey(const ValueKey('pcSettingsTerms')));
    await tester.pumpAndSettle();
    expect(calls, ['terms']);
    await tester.tap(find.byKey(const ValueKey('pcSettingsPrivacy')));
    await tester.pumpAndSettle();
    expect(calls, ['terms', 'privacy']);
    await tester.tap(find.byKey(const ValueKey('pcSettingsContact')));
    await tester.pumpAndSettle();
    expect(calls, ['terms', 'privacy']);
    expect(find.text('Contact details are not available yet.'), findsOneWidget);
    final message = tester.getRect(
      find.byKey(const ValueKey('pcSettingsMessage')),
    );
    final effects = tester.getRect(
      find.byKey(const ValueKey('pcSettingsEffects')),
    );
    final contact = tester.getRect(
      find.byKey(const ValueKey('pcSettingsContact')),
    );
    final terms = tester.getRect(find.byKey(const ValueKey('pcSettingsTerms')));
    expect(message.bottom, lessThan(effects.top));
    expect(terms.top, greaterThanOrEqualTo(contact.bottom));
    expect(find.byType(PCSettingsDialog), findsOneWidget);
    await close(tester);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('设置面板${size.width}宽安全区内居中，完整适配且可关闭', (tester) async {
      const padding = EdgeInsets.only(top: 44, bottom: 34);
      await open(tester, size: size, padding: padding);
      final rect = tester.getRect(
        find.byKey(const ValueKey('pcSettingsCanvas')),
      );
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.top, greaterThanOrEqualTo(padding.top));
      expect(rect.bottom, lessThanOrEqualTo(size.height - padding.bottom));
      expect(rect.center.dx, closeTo(size.width / 2, 1));
      expect(rect.center.dy, closeTo((size.height + 44 - 34) / 2, 1));
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }
}
