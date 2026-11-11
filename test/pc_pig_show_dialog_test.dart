import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart'
    show PigsTabController;
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCPigShowDialog.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigBarrage.dart';
import 'package:pennypilotcollectspin/PCTool/PCPigMotion.dart';
import 'package:pennypilotcollectspin/PCTool/PCRankData.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';

final users = List.generate(
  56,
  (i) => PCUserData(
    id: 1000 + i,
    username: 'User ****${1000 + i} (Brazil)',
    totalEarning: i < 3 ? 150 - i * 20 : 80 - i.toDouble(),
    adsWatched: 151 - i,
    avatarIndex: i % 54,
  ),
);

Widget app(Widget home) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  splitScreenMode: true,
  builder: (_, child) => MaterialApp(home: Scaffold(body: home)),
);

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _EarningRandom implements math.Random {
  _EarningRandom(this.quiz);
  final bool quiz;
  int calls = 0;

  @override
  bool nextBool() {
    calls++;
    return quiz;
  }

  @override
  double nextDouble() => throw UnsupportedError('Not used');

  @override
  int nextInt(int max) => throw UnsupportedError('Not used');
}

void main() {
  setUp(() => PigsTabController.switchTo(0));
  tearDown(() => PigsTabController.switchTo(0));

  for (final quiz in [true, false]) {
    testWidgets('来源随机为${quiz ? '答题' : '转盘'}时只显示匹配图文，重建不重抽', (tester) async {
      viewport(tester, const Size(360, 780));
      final random = _EarningRandom(quiz);
      Widget dialog(math.Random source) =>
          app(PCPigShowDialog(user: users[0], users: users, random: source));
      await tester.pumpWidget(dialog(random));
      await tester.pump();
      final expectedText = quiz ? 'Earning from quiz' : 'Earning from wheel';
      final expectedIcon = quiz ? 'pc_pig_show_quiz' : 'pc_pig_show_wheel';
      final otherIcon = quiz ? 'pc_pig_show_wheel' : 'pc_pig_show_quiz';
      Finder icon(String name) => find.byWidgetPredicate(
        (widget) => widget is PCImg && widget.name == name,
      );
      expect(find.text(expectedText), findsOneWidget);
      expect(icon(expectedIcon), findsOneWidget);
      expect(icon(otherIcon), findsNothing);
      expect(random.calls, 1);

      final changedRandom = _EarningRandom(!quiz);
      await tester.pumpWidget(dialog(changedRandom));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(expectedText), findsOneWidget);
      expect(icon(expectedIcon), findsOneWidget);
      expect(icon(otherIcon), findsNothing);
      expect(random.calls, 1);
      expect(changedRandom.calls, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(dialog(changedRandom));
      await tester.pump();
      expect(changedRandom.calls, 1);
      expect(
        find.text(quiz ? 'Earning from wheel' : 'Earning from quiz'),
        findsOneWidget,
      );
      expect(icon(otherIcon), findsOneWidget);
      expect(icon(expectedIcon), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('前三名各自打开金猪弹幕，Show Pig 打开对应列表用户的粉猪', (tester) async {
    viewport(tester, const Size(360, 780));
    await tester.pumpWidget(app(PCHomeRankingSection(data: users, scale: 1)));
    await tester.pump();
    for (var rank = 1; rank <= 3; rank++) {
      await tester.tap(find.byKey(ValueKey('pcRankPodium$rank')));
      await tester.pump(const Duration(milliseconds: 400));
      final dialog = tester.widget<PCPigShowDialog>(
        find.byType(PCPigShowDialog),
      );
      expect(dialog.user, same(users[rank - 1]));
      expect(
        tester
            .widget<PCImg>(find.byKey(const ValueKey('pcPigShowArtwork')))
            .name,
        'pc_rank_pig_gold',
      );
      expect(find.text('${users[rank - 1].adsWatched}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pcPigShowClose')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PCPigShowDialog), findsNothing);
      expect(PigsTabController.currentIndex.value, 0);
    }
    await tester.tap(find.byKey(const ValueKey('pcRankPedestal2')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<PCPigShowDialog>(find.byType(PCPigShowDialog)).user,
      same(users[1]),
    );
    await tester.tap(find.byKey(const ValueKey('pcPigShowClose')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('pcRankShowPig4')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<PCPigShowDialog>(find.byType(PCPigShowDialog)).user,
      same(users[3]),
    );
    expect(
      tester.widget<PCImg>(find.byKey(const ValueKey('pcPigShowArtwork'))).name,
      'pc_big_icon_0',
    );
    expect(
      find.text('\$${users[3].totalEarning.toStringAsFixed(2)}'),
      findsNWidgets(3),
    );
    await tester.tap(find.byKey(const ValueKey('pcPigShowGoEarn')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PCPigShowDialog), findsNothing);
    expect(PigsTabController.currentIndex.value, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(768, 1024),
  ]) {
    testWidgets('弹幕展示在 $size 中不重叠，100 整为粉猪，超过 100 才为金猪', (tester) async {
      viewport(tester, size);
      for (final earning in [99.99, 100.0, 100.01]) {
        final user = PCUserData(
          id: 1,
          username: 'User ****1234 (Brazil)',
          totalEarning: earning,
          adsWatched: 109,
        );
        await tester.pumpWidget(app(PCPigShowDialog(user: user)));
        await tester.pump();
        final artwork = find.byKey(const ValueKey('pcPigShowArtwork'));
        expect(
          tester.widget<PCImg>(artwork).name,
          earning > 100 ? 'pc_rank_pig_gold' : 'pc_big_icon_0',
        );
        final pig = tester.getRect(artwork);
        final button = tester.getRect(
          find.byKey(const ValueKey('pcPigShowGoEarn')),
        );
        final barrage = tester.getRect(find.byType(PCPigBarrage));
        final plate = tester.getRect(
          find.byKey(const ValueKey('pcPigShowAmountPlate')),
        );
        expect(barrage.bottom, lessThan(pig.top));
        expect(pig.bottom, lessThan(button.top));
        expect(plate.bottom, lessThan(button.top));
        expect(plate.center.dx, closeTo(size.width / 2, .01));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('pcPigShowAmountPlate')),
            matching: find.text('\$${earning.toStringAsFixed(2)}'),
          ),
          findsOneWidget,
        );
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(button.left, greaterThanOrEqualTo(0));
        expect(button.right, lessThanOrEqualTo(size.width));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('上下六条弹幕向左移动，内容保持稳定，关闭后释放动画', (tester) async {
    viewport(tester, const Size(360, 780));
    await tester.pumpWidget(app(PCPigShowDialog(user: users[0], users: users)));
    await tester.pump();
    final before = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.byKey(ValueKey('pcPigBarrageTrack$i'))),
    ];
    final statsBefore = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.byKey(ValueKey('pcPigShowStatsTrack$i'))),
    ];
    final pigMotion = tester.widget<PCPigMotion>(find.byType(PCPigMotion));
    expect(pigMotion.jumpHeight, 6);
    expect(pigMotion.showShadow, isFalse);
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 3; i++) {
      final after = tester.getTopLeft(
        find.byKey(ValueKey('pcPigBarrageTrack$i')),
      );
      expect(after.dx, lessThan(before[i].dx));
      expect(after.dy, before[i].dy);
      final statsAfter = tester.getTopLeft(
        find.byKey(ValueKey('pcPigShowStatsTrack$i')),
      );
      expect(statsAfter.dx, lessThan(statsBefore[i].dx));
      expect(statsAfter.dy, statsBefore[i].dy);
    }
    // 一轮以上仍在移动，统计值不因动画重抽或重复生成。
    final amount = '\$${users[0].totalEarning.toStringAsFixed(2)}';
    await tester.pump(const Duration(seconds: 20));
    final continued = tester.getTopLeft(
      find.byKey(const ValueKey('pcPigShowStatsTrack0')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('pcPigShowStatsTrack0'))).dx,
      lessThan(continued.dx),
    );
    for (final key in ['pcPigShowAmountPlate', 'pcPigShowStatsTrack2']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.text(amount),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('${users[0].adsWatched}'), findsOneWidget);
    final avatars = tester.widgetList<PCImg>(
      find.descendant(
        of: find.byType(PCPigBarrage),
        matching: find.byType(PCImg),
      ),
    );
    expect(avatars, hasLength(24));
    expect(
      avatars.every((image) => image.name.startsWith('pc_rank_avatar_')),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动画时保留上下六条弹幕且位置不移动', (tester) async {
    viewport(tester, const Size(360, 780));
    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 780),
            disableAnimations: true,
          ),
          child: PCPigShowDialog(user: users[0], users: users),
        ),
      ),
    );
    await tester.pump();
    final before = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.byKey(ValueKey('pcPigBarrageTrack$i'))),
    ];
    final statsBefore = [
      for (var i = 0; i < 3; i++)
        tester.getTopLeft(find.byKey(ValueKey('pcPigShowStatsTrack$i'))),
    ];
    final pigBefore = tester.getRect(
      find.byKey(const ValueKey('pcPigShowArtwork')),
    );
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 3; i++) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('pcPigBarrageTrack$i'))),
        before[i],
      );
      expect(
        tester.getTopLeft(find.byKey(ValueKey('pcPigShowStatsTrack$i'))),
        statsBefore[i],
      );
    }
    expect(
      tester.getRect(find.byKey(const ValueKey('pcPigShowArtwork'))),
      pigBefore,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
