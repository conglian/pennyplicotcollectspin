import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCWithdrawFlow/PCWithdrawalDialogWidgets.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCCashWithdrawalContent.dart';
import 'package:pennypilotcollectspin/PCModel/PCNumbserModel.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawalQueueTable.dart';
import 'package:pennypilotcollectspin/PCTool/pc_text.dart';

void main() {
  PCAPCConfig? previousConfig;
  setUp(() {
    previousConfig = PCNumberHelpers().intModel;
    PCNumberHelpers().intModel = const PCAPCConfig(
      eqRange: [100, 120, 150, 200],
    );
  });
  tearDown(() => PCNumberHelpers().intModel = previousConfig);

  List<PCWithdrawalQueueEntry> entries([int count = 4]) =>
      pcCashQueueEntries(seed: 17, target: 100, count: count)
          .map(
            (entry) => PCWithdrawalQueueEntry(
              userId: entry.userId,
              account: entry.account,
              amount: entry.amount,
            ),
          )
          .toList();

  Future<void> mount(
    WidgetTester tester, {
    int rank = 99,
    int count = 388,
    double scale = 1,
    bool reduced = true,
    List<PCWithdrawalQueueEntry>? rows,
    String account = 'player@example.com',
    double? target = 100,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 268 * scale,
                child: PCWithdrawalQueueTable(
                  currentRank: rank,
                  queueCount: count,
                  entries: rows ?? entries(count),
                  currentAccount: account,
                  currentAmount: target,
                  scale: scale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder getList() => find.byKey(const ValueKey('pcWithdrawalQueueList'));
  ScrollController scroll(WidgetTester tester) =>
      tester.widget<ListView>(getList()).controller!;

  void expectCurrentVisible(WidgetTester tester, int rank) {
    final row = find.byKey(ValueKey('pcWithdrawalQueueRow_$rank'));
    final viewport = tester.getRect(getList());
    final current = tester.getRect(row);
    expect(current.top, greaterThanOrEqualTo(viewport.top - .01));
    expect(current.bottom, lessThanOrEqualTo(viewport.bottom + .01));
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow')),
      ),
      findsOneWidget,
    );
    expect(find.text('player@example.com'), findsOneWidget);
  }

  testWidgets('初次打开388人队列直接定位第99名，表头固定且当前用户高亮', (tester) async {
    await mount(tester);
    expectCurrentVisible(tester, 99);
    expect(scroll(tester).offset, closeTo(2702, .01));
    final current = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow')),
    );
    expect(
      current.center.dy,
      closeTo(tester.getRect(getList()).center.dy, .01),
    );
    final header = tester.getRect(
      find.byKey(const ValueKey('pcWithdrawalQueueHeader')),
    );
    await tester.drag(getList(), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('pcWithdrawalQueueHeader'))),
      header,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('名次99变94、总人数388变386时平移到新名次，普通重建保留手动位置', (tester) async {
    await mount(tester, reduced: false);
    final initial = scroll(tester).offset;
    await mount(tester, rank: 94, count: 386, reduced: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll(tester).offset, lessThan(initial));
    await tester.pumpAndSettle();
    expectCurrentVisible(tester, 94);
    expect(scroll(tester).offset, closeTo(2562, .01));

    await tester.drag(getList(), const Offset(0, -84));
    await tester.pumpAndSettle();
    final manual = scroll(tester).offset;
    await mount(tester, rank: 94, count: 386, reduced: false);
    await tester.pumpAndSettle();
    expect(scroll(tester).offset, closeTo(manual, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('只有旧版4条数据也能展示当前第99名，并正确使用脱敏账号和实际金额', (tester) async {
    await mount(tester, rows: entries());
    expectCurrentVisible(tester, 99);
    final current = find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow'));
    expect(
      find.descendant(of: current, matching: find.text('099')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: current, matching: find.text('\$100')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('首尾名次、小队列和缩放均定位到有效范围，人数减少后保持当前名次可见', (tester) async {
    await mount(tester, rank: 1, count: 388, scale: .8);
    expectCurrentVisible(tester, 1);
    expect(scroll(tester).offset, 0);
    await mount(tester, rank: 388, count: 388, scale: .8);
    expectCurrentVisible(tester, 388);
    expect(
      scroll(tester).offset,
      closeTo(scroll(tester).position.maxScrollExtent, .01),
    );
    await mount(tester, rank: 2, count: 2, scale: .8);
    expectCurrentVisible(tester, 2);
    expect(scroll(tester).offset, 0);
    expect(tester.takeException(), isNull);
  });

  test('完整榜单复用同一seed稳定生成，前4行保持旧存档展示一致', () {
    final previous = pcCashQueueEntries(seed: 17, target: 100);
    final complete = pcCashQueueEntries(seed: 17, target: 100, count: 388);
    final rebuilt = pcCashQueueEntries(seed: 17, target: 100, count: 386);
    expect(complete, hasLength(388));
    for (var i = 0; i < rebuilt.length; i++) {
      expect(complete[i].userId, '${i + 1}'.padLeft(3, '0'));
      expect(complete[i].account, rebuilt[i].account);
      expect(complete[i].amount, rebuilt[i].amount);
      expect(PCNumberHelpers().pc_eqRange, contains(complete[i].amount));
      expect(RegExp(r'^Player \d{3}$').hasMatch(complete[i].account), isTrue);
      if (i < 4) {
        expect(complete[i].account, previous[i].account);
        expect(complete[i].amount, previous[i].amount);
      }
    }
  });

  test('随机金额仅来自本地eq_range，配置切换后无需改代码或按target倍增', () {
    PCNumberHelpers().intModel = const PCAPCConfig(
      eqRange: [90, 110, 130, 170],
    );
    final rows = pcCashQueueEntries(seed: 17, target: 100, count: 388);
    expect(rows.map((row) => row.amount).toSet(), {90, 110, 130, 170});
    expect(
      rows.every((row) => RegExp(r'^Player \d{3}$').hasMatch(row.account)),
      isTrue,
    );
  });

  testWidgets('当前行真实账号以原文显示，其他行使用示例账号和配置档位', (tester) async {
    PCNumberHelpers().intModel = const PCAPCConfig(
      eqRange: [90, 110, 130, 170],
    );
    const raw = 'customer@example.com';
    await mount(tester, rows: entries(), account: raw, target: null);
    final current = find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow'));
    expect(
      find.descendant(of: current, matching: find.text(raw)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: current, matching: find.text('\$90')),
      findsOneWidget,
    );
    for (final index in [98, 100]) {
      final texts = tester
          .widgetList<PCText>(
            find.descendant(
              of: find.byKey(ValueKey('pcWithdrawalQueueRow_$index')),
              matching: find.byType(PCText),
            ),
          )
          .map((text) => text.text)
          .toList();
      expect(RegExp(r'^Player \d{3}$').hasMatch(texts[1]), isTrue);
      expect([
        90,
        110,
        130,
        170,
      ], contains(double.parse(texts[2].substring(1))));
    }
    await mount(tester, rows: entries(), account: 'c***.com', target: 90);
    expect(
      find.descendant(of: current, matching: find.text('—')),
      findsOneWidget,
    );

    await mount(
      tester,
      rank: 3,
      count: 4,
      account: raw,
      target: 90,
      rows: const [
        PCWithdrawalQueueEntry(
          userId: '001',
          account: 'old@example.com',
          amount: 500,
        ),
        PCWithdrawalQueueEntry(userId: '002', account: '1****258', amount: 700),
        PCWithdrawalQueueEntry(userId: '003', account: '1****777', amount: 200),
        PCWithdrawalQueueEntry(
          userId: '004',
          account: 'old***.com',
          amount: 900,
        ),
      ],
    );
    for (final rank in [1, 2, 4]) {
      final texts = tester
          .widgetList<PCText>(
            find.descendant(
              of: find.byKey(ValueKey('pcWithdrawalQueueRow_$rank')),
              matching: find.byType(PCText),
            ),
          )
          .map((text) => text.text)
          .toList();
      expect(RegExp(r'^Player \d{3}$').hasMatch(texts[1]), isTrue);
      expect([
        90,
        110,
        130,
        170,
      ], contains(double.parse(texts[2].substring(1))));
    }
    expect(find.text('old@example.com'), findsNothing);
  });

  testWidgets('当前账号显示完整电话和邮箱，旧掩码无法恢复时只显示占位', (tester) async {
    for (final (raw, masked) in [
      ('1112345622', '1112345622'),
      ('account*name@example.com', 'account*name@example.com'),
      ('111***22', '—'),
      ('11***22', '—'),
      ('p***@mail.com', '—'),
    ]) {
      await mount(tester, rank: 99, rows: entries(), account: raw);
      final current = find.byKey(const ValueKey('pcWithdrawalQueueCurrentRow'));
      expect(
        find.descendant(of: current, matching: find.text(masked)),
        findsOneWidget,
      );
      if (raw != masked) expect(find.text(raw), findsNothing);
    }
  });
}
