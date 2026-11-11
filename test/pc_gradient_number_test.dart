import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/pc_GradientNumber.dart';

Widget _number({
  required num value,
  num initial = 0,
  bool dollars = true,
  int decimals = 2,
  int duration = 1000,
}) {
  return MaterialApp(
    home: Center(
      child: PCGradientNumberRoller(
        value: value,
        currentValue: initial,
        showDolas: dollars,
        decimalPlaces: decimals,
        duration: duration,
        borderWidth: 0,
      ),
    ),
  );
}

void main() {
  testWidgets('美元余额从指定初始值滚动到目标并保留两位小数', (tester) async {
    await tester.pumpWidget(_number(value: 12.34, initial: 5));
    expect(find.text(r'$5.00'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text(r'$12.34'), findsOneWidget);
  });

  testWidgets('纯数字和整数余额使用各自的格式', (tester) async {
    await tester.pumpWidget(_number(value: 42, dollars: false, decimals: 0));
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);

    await tester.pumpWidget(_number(value: 19.75, decimals: 0));
    await tester.pumpAndSettle();
    expect(find.text(r'$20'), findsOneWidget);
  });

  testWidgets('余额连续更新时从当前显示值衔接，支持金额减少和时长变化', (tester) async {
    await tester.pumpWidget(_number(value: 100));
    await tester.pump(const Duration(milliseconds: 250));
    final displayed = tester.widget<Text>(find.byType(Text)).data!;
    expect(displayed, isNot(r'$100.00'));
    expect(displayed, isNot(r'$0.00'));

    await tester.pumpWidget(_number(value: 200));
    expect(find.text(displayed), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text(r'$200.00'), findsOneWidget);

    await tester.pumpWidget(_number(value: 50, duration: 200));
    expect(find.text(r'$200.00'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(r'$50.00'), findsOneWidget);
  });
}
