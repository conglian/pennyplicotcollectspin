import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pc_number_test_assets.dart';

class _FixedRandom implements Random {
  const _FixedRandom(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => (value * max).floor();
  @override
  bool nextBool() => value < .5;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  final numbers = PCNumberHelpers();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await numbers.pc_initNumberModel();
  });

  test('Firebase同名数值覆盖本地，未下发字段保留打包默认值并持久化', () async {
    await numbers.pc_applyRemoteConfig(
      jsonEncode({
        'first_ad_prize': 8,
        'intad_point': [
          {'first_number': 0, 'end_number': 10000, 'point': 70},
        ],
      }),
    );
    expect(numbers.model.firstAdPrize, 8);
    expect(numbers.pc_eqRange, [100, 120, 150, 200]);
    expect(numbers.model.moneyPrize.length, 4);
    expect(
      numbers.pc_checkProbability(balance: 20, random: const _FixedRandom(.69)),
      true,
    );
    expect(
      numbers.pc_checkProbability(balance: 20, random: const _FixedRandom(.70)),
      false,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PCNumberHelpers.configKey), isNotEmpty);
    await numbers.pc_initNumberModel();
    expect(numbers.model.firstAdPrize, 8);
    expect(numbers.model.intadPoint.single.point, 70);
  });

  test('下一版远程未下发的字段回到本地，不继承上一版远程值', () async {
    await numbers.pc_applyRemoteConfig(
      '{"eq_range":[80,160],"first_ad_prize":9}',
    );
    await numbers.pc_applyRemoteConfig('{"quiz_console":7}');
    expect(numbers.pc_eqRange, [100, 120, 150, 200]);
    expect(numbers.model.firstAdPrize, 6);
    expect(numbers.pc_quizConsole, 7);
  });

  test('远程为空、失败或非法JSON时清理旧覆盖并恢复完整本地模型', () async {
    final bundled = numbers.model.toJson();
    final prefs = await SharedPreferences.getInstance();
    for (final unavailable in [null, '', 'bad-json', '[]', '{}', 'null']) {
      await numbers.pc_applyRemoteConfig('{"eq_range":[80,160]}');
      expect(numbers.pc_firstTarget, 80);
      await numbers.pc_applyRemoteConfig(unavailable);
      expect(numbers.model.toJson(), bundled, reason: '$unavailable');
      expect(prefs.containsKey(PCNumberHelpers.configKey), false);
      await numbers.pc_initNumberModel();
      expect(numbers.model.toJson(), bundled);
    }
  });

  test('无效概率字段回退本地，不阻断同一远程JSON其他有效参数', () async {
    final bundled = numbers.model.intadPoint
        .map((row) => row.toJson())
        .toList();
    for (final rows in [
      [],
      [
        {'first_number': 30, 'end_number': 30, 'point': 50},
      ],
      [
        {'first_number': 0, 'end_number': 100, 'point': 101},
      ],
      [
        {'first_number': 0, 'end_number': 100, 'point': -1},
      ],
      [
        {'first_number': 0, 'end_number': 100, 'point': 30},
        {'first_number': 90, 'end_number': 10000, 'point': 80},
      ],
      [
        {'first_number': 0, 'end_number': 100, 'point': 'invalid'},
      ],
    ]) {
      await numbers.pc_applyRemoteConfig(
        jsonEncode({'intad_point': rows, 'quiz_console': 8}),
      );
      expect(numbers.pc_quizConsole, 8);
      expect(
        numbers.model.intadPoint.map((row) => row.toJson()).toList(),
        bundled,
      );
      expect(
        numbers.pc_checkProbability(
          balance: 30,
          random: const _FixedRandom(.29),
        ),
        true,
      );
    }
  });

  test('有效的0和100概率遵守远程配置，区间边界按下一档判断', () async {
    await numbers.pc_applyRemoteConfig(
      jsonEncode({
        'intad_point': [
          {'first_number': 0, 'end_number': 50, 'point': 0},
          {'first_number': 50, 'end_number': 10000, 'point': 100},
        ],
      }),
    );
    expect(
      numbers.pc_checkProbability(
        balance: 49.99,
        random: const _FixedRandom(0),
      ),
      false,
    );
    expect(
      numbers.pc_checkProbability(
        balance: 50,
        random: const _FixedRandom(.999),
      ),
      true,
    );
  });
}
