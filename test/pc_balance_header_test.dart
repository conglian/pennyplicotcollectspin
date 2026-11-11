import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCQuiz.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCWheel.dart';
import 'package:pennypilotcollectspin/PCTool/PCBalanceHeader.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizBank.dart';
import 'package:pennypilotcollectspin/PCTool/PCQuizController.dart';
import 'package:pennypilotcollectspin/PCTool/pc_GradientNumber.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });

  for (final size in const [Size(320, 568), Size(430, 932)]) {
    for (final level in [0, 1, 2]) {
      testWidgets('阶段$level在$size下首页约束/答题/转盘共用本地精确收集量', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'pc_pig_level': level,
          'pc_dollar_number': level == 0 ? 48.25 : 100.0,
          'pc_quiz_diamonds': level == 1
              ? 7.25
              : level == 2
              ? 20.0
              : 0.0,
          'pc_quiz_gold': level == 2 ? 3.15 : 0.0,
          // 转盘次数与收集剩余量无关，不能再错误显示为 Left。
          'pc_wheel_number': 39,
          'pc_new_guide_end': true,
        });
        final provider = PCLocalProvider.instance;
        await provider.init();
        final flow = PCQuizController();
        await flow.load();
        final bank = PCQuizBank.fromQuestions(const [
          PCQuizQuestion(
            question: 'Which fruit is red?',
            a: 'Apple',
            b: 'Grass',
            answer: 'a',
          ),
        ]);

        for (final page in [
          // 与首页LayoutBuilder的328/375宽比、112/650高比保持相同约束。
          if (level > 0)
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 328 * size.width / 375,
                height: 112 * (size.height - 81) / 650,
                child: PCBalanceHeader(provider: provider),
              ),
            ),
          PCQuiz(controller: flow, bank: bank, active: false),
          PCWheel(),
        ]) {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: provider,
              child: ScreenUtilInit(
                designSize: const Size(375, 812),
                minTextAdapt: true,
                splitScreenMode: true,
                builder: (_, child) => MaterialApp(
                  home: Scaffold(
                    body: page,
                    bottomNavigationBar: const SizedBox(height: 81),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          final header = find.byType(PCBalanceHeader);
          expect(header, findsOneWidget);
          if (level == 0) {
            expect(find.text('My Account: '), findsOneWidget);
            expect(find.text('Super Easy Cash Today!'), findsOneWidget);
          } else {
            final numbers = tester
                .widgetList<PCGradientNumberRoller>(
                  find.descendant(
                    of: header,
                    matching: find.byType(PCGradientNumberRoller),
                  ),
                )
                .map((n) => n.value)
                .toList();
            expect(
              numbers,
              containsAll([
                100.0,
                level == 1 ? 7.25 : 3.15,
                level == 1 ? 12.75 : 6.85,
              ]),
            );
            expect(numbers, isNot(contains(39)));
            // 进度条必须显示当前阶段数量/目标，不能再拿美元100作为收集进度。
            expect(numbers.first, level == 1 ? 7.25 : 3.15);
            expect(find.text(level == 1 ? '/20' : '/10'), findsOneWidget);
            final images = tester
                .widgetList<PCImg>(
                  find.descendant(of: header, matching: find.byType(PCImg)),
                )
                .map((n) => n.name);
            expect(
              images,
              contains('pc_stage_pig_${level == 1 ? 'diamond' : 'gold'}'),
            );
            expect(find.text('Super Easy Cash Today!'), findsNothing);
            expectCollectibleGeometry(
              tester,
              header,
              level == 1 ? 'diamond' : 'gold',
            );
          }
          final bounds = tester.getRect(header);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }
        flow.dispose();
      });
    }
  }

  for (final size in const [
    Size(280, 75), // 答题页的小屏实际宽高。
    Size(328, 112),
    Size(376, 124),
  ]) {
    for (final level in [1, 2]) {
      testWidgets('阶段$level在$size下零值/极少量/满档游标与主猪和支付角标分开', (tester) async {
        SharedPreferences.setMockInitialValues({
          'pc_pig_level': level,
          'pc_dollar_number': 100.0,
          'pc_quiz_diamonds': level == 2 ? 20.0 : 0.0,
        });
        final provider = PCLocalProvider.instance;
        await provider.init();
        final target = level == 1 ? 20.0 : 10.0;
        final rewardTarget = GlobalKey();

        for (final collected in [0.0, .01, target]) {
          // 覆盖阶段转换前最后一帧；完整同步到下一阶段由业务测试验证。
          provider.pc_pig_level = level;
          provider.pc_pig_level_index = collected;
          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (_, child) => MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox.fromSize(
                      size: size,
                      child: PCBalanceHeader(
                        provider: provider,
                        rewardTarget: rewardTarget,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final header = find.byType(PCBalanceHeader);
          expectCollectibleGeometry(
            tester,
            header,
            level == 1 ? 'diamond' : 'gold',
          );
          final numbers = tester
              .widgetList<PCGradientNumberRoller>(
                find.descendant(
                  of: header,
                  matching: find.byType(PCGradientNumberRoller),
                ),
              )
              .toList();
          expect(numbers.first.value, collected);
          expect(numbers.first.showDolas, isFalse);
          expect(find.text(level == 1 ? '/20' : '/10'), findsOneWidget);
          final stats = tester.getRect(
            find.byKey(const ValueKey('pc_stage_collection_stats')),
          );
          final rewardDestination = tester.getRect(find.byKey(rewardTarget));
          expect(stats.contains(rewardDestination.center), isTrue);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 200));
      });
    }
  }

  testWidgets('本地阶段缓存更新及重新加载后，顶部保留钻石小数和已升级状态', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pc_dollar_number': 100.0,
      'pc_pig_level': 1,
      'pc_quiz_diamonds': 7.25,
    });
    final provider = PCLocalProvider.instance;
    await provider.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) => MaterialApp(
            home: Scaffold(
              body: Consumer<PCLocalProvider>(
                builder: (_, value, child) => SizedBox(
                  width: 328,
                  height: 112,
                  child: PCBalanceHeader(provider: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pc_quiz_diamonds', 7.75);
    await prefs.setDouble('pc_dollar_number', 25.5);
    await provider.init();
    await tester.pump(const Duration(milliseconds: 200));
    Iterable<num> values() => tester
        .widgetList<PCGradientNumberRoller>(find.byType(PCGradientNumberRoller))
        .map((n) => n.value);
    expect(values(), containsAll([7.75, 12.25]));
    expect(values().first, 7.75);
    expect(values(), isNot(contains(25.5)));
    await provider.init();
    await tester.pump(const Duration(milliseconds: 200));
    expect(provider.pc_pig_level, 1);
    expect(values(), containsAll([7.75, 12.25]));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

/// 断言实际绘制边界，防止只检查数值却漏过主猪/游标重叠或非等比压缩。
void expectCollectibleGeometry(
  WidgetTester tester,
  Finder header,
  String stage,
) {
  Rect image(String name) => tester.getRect(
    find.descendant(
      of: header,
      matching: find.byWidgetPredicate(
        (widget) => widget is PCImg && widget.name == name,
      ),
    ),
  );
  final bounds = tester.getRect(header);
  final pig = image('pc_stage_pig_$stage');
  final marker = image('pc_stage_progress_$stage');
  final track = image('pc_stage_progress_track');
  final payment = tester.getRect(
    find.byKey(const ValueKey('pc_stage_payment_badge')),
  );
  final stats = tester.getRect(
    find.byKey(const ValueKey('pc_stage_collection_stats')),
  );
  final slogan = tester.getRect(
    find.descendant(
      of: header,
      matching: find.text("Money's In-Ready To Withdraw!"),
    ),
  );
  final scale = pig.width / 48;
  expect(pig.width / pig.height, closeTo(48 / 40, .001));
  expect(marker.width, closeTo(marker.height, .001));
  expect(track.left - pig.right, greaterThanOrEqualTo(7.9 * scale));
  expect(marker.left - pig.right, greaterThanOrEqualTo(7.9 * scale));
  expect(payment.left - track.right, greaterThanOrEqualTo(7.9 * scale));
  expect(payment.left - marker.right, greaterThanOrEqualTo(7.9 * scale));
  expect(marker.left, greaterThanOrEqualTo(track.left - .01));
  expect(marker.right, lessThanOrEqualTo(track.right + .01));
  expect(slogan.top, greaterThanOrEqualTo(pig.bottom));
  expect(stats.top - slogan.bottom, greaterThanOrEqualTo(3 * scale));
  for (final rect in [pig, marker, track, payment, stats, slogan]) {
    expect(rect.left, greaterThanOrEqualTo(bounds.left - .01));
    expect(rect.top, greaterThanOrEqualTo(bounds.top - .01));
    expect(rect.right, lessThanOrEqualTo(bounds.right + .01));
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .01));
  }
  final statIcons = find.descendant(
    of: header,
    matching: find.byWidgetPredicate(
      (widget) => widget is PCImg && widget.name == 'pc_stage_collect_$stage',
    ),
  );
  expect(statIcons, findsNWidgets(2));
  for (final icon in statIcons.evaluate()) {
    final iconRect = tester.getRect(find.byWidget(icon.widget));
    expect(iconRect.top, greaterThanOrEqualTo(stats.top));
    expect(iconRect.bottom, lessThanOrEqualTo(stats.bottom));
  }
}
