import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCAward/PCAwardDialog.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';

void main() {
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('Underlying page'));
          },
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
      PCRewardedAdService.instance.handler = null;
      expect(PCDialogCoordinator.instance.isBusy, false);
    });
    return context;
  }

  Future<void> frames(WidgetTester tester, [int milliseconds = 500]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
  }

  Finder backdrop() => find.byWidgetPredicate(
    (widget) => widget is Container && widget.color == pcDialogBackdrop,
  );

  void expectFullScreenBackdrop(WidgetTester tester) {
    expect(backdrop(), findsOneWidget);
    final barrier = tester.getRect(backdrop());
    final page = tester.getRect(find.byType(Scaffold).first);
    expect(barrier, page);
    // 内容层独立保持透明，不能把整块Dialog涂成黑方框。
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      Colors.transparent,
    );
  }

  testWidgets('普通tipShow2默认覆盖全屏深色背景，内容底板保持独立且外部点击不关闭', (tester) async {
    final context = await host(tester);
    final closed = context.tipShow2(
      const SizedBox(
        width: 100,
        height: 100,
        child: ColoredBox(color: Colors.green),
      ),
    );
    await frames(tester);
    expect(pcDialogBackdrop.a, greaterThan(0));
    expectFullScreenBackdrop(tester);
    await tester.tapAt(const Offset(5, 5));
    await frames(tester);
    expect(find.byType(Dialog), findsOneWidget);
    Navigator.of(context).pop(false);
    await frames(tester);
    expect(await closed, false);
    expect(backdrop(), findsNothing);
  });

  testWidgets('领奖激励失败先完成待奖清理，再在同一路由显示失败面板且不叠遮罩', (tester) async {
    final context = await host(tester);
    final discarded = Completer<void>();
    var discards = 0;
    var claims = 0;
    var rewarded = 0;
    PCRewardedAdService.instance.handler = (_) async {
      rewarded++;
      return false;
    };
    final closed = context.tipShow2(
      PCAwardDialog(
        award: .2,
        onClaimAdFailed: () {
          discards++;
          return discarded.future;
        },
        onClaim: () async {
          claims++;
          return true;
        },
      ),
    );
    await frames(tester);
    expectFullScreenBackdrop(tester);
    final originalRoute = ModalRoute.of(
      tester.element(find.byType(PCAwardDialog)),
    );
    await tester.tap(find.byKey(const ValueKey('pcQuizClaimReward')));
    await frames(tester, 100);
    expect(discards, 1);
    expect(find.byType(PCAdLoadingFailedDialog), findsNothing);
    expectFullScreenBackdrop(tester);
    discarded.complete();
    await frames(tester);
    expect(find.byType(PCAdLoadingFailedDialog), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(PCAdLoadingFailedDialog))),
      same(originalRoute),
    );
    expectFullScreenBackdrop(tester);
    expect(PCDialogCoordinator.instance.pendingCount, 0);
    expect(claims, 0);
    await tester.tap(find.text('Try Again').last);
    await frames(tester);
    expect(await closed, false);
    expect(rewarded, 1);
    expect(discards, 1);
    expect(claims, 0);
    expect(backdrop(), findsNothing);
  });
}
