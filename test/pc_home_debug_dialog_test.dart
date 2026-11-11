import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCOther/PCHomeDebugDialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required PCHomeDebugSubmit submit,
    Size size = const Size(375, 812),
    double keyboardHeight = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PCHomeDebugDialog(
                    cash: 12.34,
                    diamonds: 2.5,
                    gold: 3.25,
                    queueRank: 99,
                    queueTotal: 388,
                    pigLevel: 2,
                    wheelChances: 3,
                    onSubmit: submit,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('五个输入分别支持独立设置，留空字段不提交，0不当成空值', (tester) async {
    final cases = <String, num>{
      'pcDebugCash': 0,
      'pcDebugDiamonds': 1.25,
      'pcDebugGold': 0,
      'pcDebugQueueRank': 1,
      'pcDebugWheelChances': 0,
    };
    for (final entry in cases.entries) {
      Map<String, num?>? result;
      await open(
        tester,
        submit: ({cash, diamonds, gold, queueRank, wheelChances}) async {
          result = {
            'pcDebugCash': cash,
            'pcDebugDiamonds': diamonds,
            'pcDebugGold': gold,
            'pcDebugQueueRank': queueRank,
            'pcDebugWheelChances': wheelChances,
          };
        },
      );
      await tester.enterText(find.byKey(ValueKey(entry.key)), '${entry.value}');
      await tap(tester, 'pcDebugSubmit');
      expect(result?[entry.key], entry.value);
      expect(result?.values.where((value) => value != null), hasLength(1));
      expect(find.byType(PCHomeDebugDialog), findsNothing);
    }
  });

  testWidgets('空提交和非法输入不保存，支持一次提交多项', (tester) async {
    var count = 0;
    Map<String, num?>? result;
    await open(
      tester,
      submit: ({cash, diamonds, gold, queueRank, wheelChances}) async {
        count++;
        result = {
          'cash': cash,
          'diamonds': diamonds,
          'gold': gold,
          'rank': queueRank,
          'wheelChances': wheelChances,
        };
      },
    );
    await tap(tester, 'pcDebugSubmit');
    expect(find.text('Fill in at least one field.'), findsOneWidget);
    for (final value in ['-1', 'NaN', 'Infinity', '1.234', '1000000000']) {
      await tester.enterText(find.byKey(const ValueKey('pcDebugCash')), value);
      await tap(tester, 'pcDebugSubmit');
      expect(count, 0);
    }
    await tester.enterText(find.byKey(const ValueKey('pcDebugCash')), '9.99');
    for (final value in ['0', '-1', '1.5', '1000000001']) {
      await tester.enterText(
        find.byKey(const ValueKey('pcDebugQueueRank')),
        value,
      );
      await tap(tester, 'pcDebugSubmit');
      expect(count, 0);
    }
    for (final value in ['-1', '1.5', '1000000001']) {
      await tester.enterText(
        find.byKey(const ValueKey('pcDebugWheelChances')),
        value,
      );
      await tap(tester, 'pcDebugSubmit');
      expect(count, 0);
    }
    await tester.enterText(
      find.byKey(const ValueKey('pcDebugWheelChances')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pcDebugDiamonds')),
      '2.50',
    );
    await tester.enterText(find.byKey(const ValueKey('pcDebugGold')), '0');
    await tester.enterText(
      find.byKey(const ValueKey('pcDebugQueueRank')),
      '94',
    );
    await tap(tester, 'pcDebugSubmit');
    expect(count, 1);
    expect(result, {
      'cash': 9.99,
      'diamonds': 2.5,
      'gold': 0.0,
      'rank': 94,
      'wheelChances': null,
    });
  });

  testWidgets('保存中防重复提交，失败保留输入并允许重试', (tester) async {
    var count = 0;
    final saved = Completer<void>();
    await open(
      tester,
      submit: ({cash, diamonds, gold, queueRank, wheelChances}) async {
        count++;
        if (count == 1) await saved.future;
      },
    );
    await tester.enterText(find.byKey(const ValueKey('pcDebugGold')), '12.34');
    await tap(tester, 'pcDebugSubmit');
    await tap(tester, 'pcDebugSubmit');
    expect(count, 1);
    expect(find.text('Saving…'), findsOneWidget);
    saved.completeError(StateError('storage failure'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('pcDebugGold')),
    );
    expect(field.controller?.text, '12.34');
    await tap(tester, 'pcDebugSubmit');
    expect(count, 2);
    expect(find.byType(PCHomeDebugDialog), findsNothing);
  });

  testWidgets('小屏键盘弹起可滚动操作，取消不保存', (tester) async {
    var count = 0;
    await open(
      tester,
      size: const Size(320, 568),
      keyboardHeight: 270,
      submit: ({cash, diamonds, gold, queueRank, wheelChances}) async =>
          count++,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('pcDebugQueueRank')));
    await tester.enterText(
      find.byKey(const ValueKey('pcDebugQueueRank')),
      '88',
    );
    await tap(tester, 'pcDebugCancel');
    expect(count, 0);
    expect(find.byType(PCHomeDebugDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
