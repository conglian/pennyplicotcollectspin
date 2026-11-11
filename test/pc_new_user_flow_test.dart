import 'support/pc_number_test_assets.dart';
import 'package:pennypilotcollectspin/PCTool/PCNumberManager.dart';
import 'dart:convert';
import 'dart:async';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserConfig.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';
import 'package:pennypilotcollectspin/PCTool/PCWithdrawValidation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// SharedPreferences提供的存储测试替身，用于注入真实写入失败而非广告失败。
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Future<PCNewUserGuideController> resume() async {
  final controller = PCNewUserGuideController();
  await controller.load();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerPCNumberTestAssets();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PCNumberHelpers().pc_initNumberModel();
  });
  setUp(() {
    PCRewardedAdService.instance.handler = (_) async => true;
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 3,
      PCNewUserConfig.remoteKey: jsonEncode({
        'new_ad_console': 0,
        'first_ad_prize': 6,
      }),
    });
  });
  tearDown(() => PCRewardedAdService.instance.handler = null);

  test('签到与三题奖励只入账一次，冷启动从下一步恢复', () async {
    var guide = await resume();
    await guide.advance(PCNewUserStage.welcome);
    await guide.advance(PCNewUserStage.checkInPrompt);
    await Future.wait([guide.claimCheckIn(), guide.claimCheckIn()]);
    expect(guide.balance, 6);
    expect(guide.checkInDay, 1);
    expect(guide.stage, PCNewUserStage.deposit);
    guide.dispose();
    guide = await resume();
    expect(guide.stage, PCNewUserStage.deposit);
    await guide.claimCheckIn();
    expect(guide.balance, 6);
    await guide.advance(PCNewUserStage.deposit);
    await guide.advance(PCNewUserStage.commission);
    for (var i = 0; i < 3; i++) {
      expect(guide.quizIndex, i);
      await guide.answerQuiz(correct: true);
      expect(guide.stage, PCNewUserStage.quizReward);
      final expectedBalance = guide.balance + guide.pendingPrize;
      await Future.wait([guide.claimQuizReward(), guide.claimQuizReward()]);
      expect(guide.balance, closeTo(expectedBalance, .001));
    }
    expect(guide.correctMask, 7);
    expect(guide.stage, PCNewUserStage.withdrawalEligibility);
    final earned = guide.balance;
    await guide.claimQuizReward();
    expect(guide.balance, earned);
    await guide.advance(PCNewUserStage.withdrawalEligibility);
    await guide.confirmPayment('t***.com');
    guide.dispose();
    guide = await resume();
    expect(guide.stage, PCNewUserStage.officialNotice);
    expect(guide.confirmedUser, 't***.com');
    await guide.advance(PCNewUserStage.officialNotice);
    await guide.advance(PCNewUserStage.growBonus);
    await guide.advance(PCNewUserStage.wheelPrompt);
    expect(guide.isComplete, true);
    expect(
      (await SharedPreferences.getInstance()).getBool('pc_new_guide_end'),
      true,
    );
    guide.dispose();
  });

  for (final throwsAd in [false, true]) {
    test('首次签到广告${throwsAd ? '异常' : '失败'}不发奖且跳过到账保存quiz，冷启动不再签到', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PCNewUserConfig.remoteKey, '{"new_ad_console":0}');
      await prefs.setDouble(PCNewUserGuideController.balanceKey, 22.25);
      await prefs.setString(
        PCNewUserGuideController.flowKey,
        '{"stage":"checkIn"}',
      );
      var requests = 0;
      var guide = PCNewUserGuideController(
        requestRewardedAd: (placement) async {
          expect(placement, 'nkmdl_signin_rv');
          requests++;
          if (throwsAd) throw StateError('SDK not ready');
          return false;
        },
      );
      await guide.load();
      final results = await Future.wait([
        guide.claimCheckIn(),
        guide.claimCheckIn(),
      ]);
      expect(results, [false, false]);
      expect(guide.balance, 22.25);
      expect(guide.checkInDay, 0);
      expect(guide.firstCommission, 0);
      expect(guide.stage, PCNewUserStage.quiz);
      expect(requests, 1);
      guide.dispose();
      guide = await resume();
      expect(await guide.claimCheckIn(), false);
      expect(guide.balance, 22.25);
      expect(guide.checkInDay, 0);
      expect(guide.stage, PCNewUserStage.quiz);
      guide.dispose();
    });
  }

  test('签到激励在途拒绝连点，真实成功才记签到与到账', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      '{"stage":"checkIn"}',
    );
    final entered = Completer<void>();
    final ad = Completer<bool>();
    var requests = 0;
    final guide = PCNewUserGuideController(
      requestRewardedAd: (placement) {
        expect(placement, 'nkmdl_signin_rv');
        requests++;
        entered.complete();
        return ad.future;
      },
    );
    await guide.load();
    final first = guide.claimCheckIn();
    await entered.future;
    expect(await guide.claimCheckIn(), false);
    expect(guide.balance, 0);
    expect(guide.checkInDay, 0);
    ad.complete(true);
    expect(await first, true);
    expect(guide.balance, 6);
    expect(guide.checkInDay, 1);
    expect(requests, 1);
    expect(await guide.claimCheckIn(), false);
    guide.dispose();
  });

  for (final throwsWrite in [false, true]) {
    test('签到到账后的流程写入${throwsWrite ? '异常' : '返回false'}仍可恢复且不重复到账', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PCNewUserConfig.remoteKey, '{"new_ad_console":1}');
      await prefs.setString(
        PCNewUserGuideController.flowKey,
        '{"stage":"checkIn"}',
      );
      final guide = PCNewUserGuideController(
        requestRewardedAd: (_) async => true,
      );
      await guide.load();
      final original = SharedPreferencesStorePlatform.instance;
      final store = _FailFlowStore({
        for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
      }, throwsWrite: throwsWrite);
      SharedPreferencesStorePlatform.instance = store;
      try {
        await expectLater(guide.claimCheckIn(), throwsA(isA<StateError>()));
        expect(guide.stage, PCNewUserStage.checkIn);
        expect(guide.balance, 6);
        expect(guide.checkInDay, 0);
        expect(guide.isSaving, false);
        expect(prefs.containsKey(PCNewUserGuideController.journalKey), true);
      } finally {
        SharedPreferencesStorePlatform.instance = original;
        await guide.load();
        expect(guide.balance, 6);
        expect(guide.checkInDay, 1);
        expect(guide.stage, PCNewUserStage.deposit);
        expect(await guide.claimCheckIn(), false);
        expect(prefs.containsKey(PCNewUserGuideController.journalKey), false);
        guide.dispose();
      }
    });
  }

  for (final showAd in [false, true]) {
    test('首次签到不受new_ad_console=${showAd ? 1 : 0}影响，统一真实激励后领取配置奖励', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PCNewUserConfig.remoteKey,
        jsonEncode({'new_ad_console': showAd ? 1 : 0, 'first_ad_prize': 9}),
      );
      await prefs.setString(
        PCNewUserGuideController.flowKey,
        '{"stage":"checkIn"}',
      );
      var requests = 0;
      final guide = PCNewUserGuideController(
        requestRewardedAd: (_) async {
          requests++;
          return true;
        },
      );
      await guide.load();
      expect(await guide.claimCheckIn(), true);
      expect(requests, 1);
      expect(guide.stage, PCNewUserStage.deposit);
      expect(guide.balance, 9);
      expect(guide.checkInDay, 1);
      expect(guide.firstCommission, 9);
      expect(await guide.claimCheckIn(), false);
      expect(guide.balance, 9);
      guide.dispose();
    });
  }

  test('普通完成态签到也需激励，失败保留可签到、再次真实成功只发一次', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PCNewUserConfig.remoteKey, '{"new_ad_console":1}');
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      '{"stage":"complete","checkInDay":1}',
    );
    var requests = 0;
    final guide = PCNewUserGuideController(
      requestRewardedAd: (_) async {
        requests++;
        return requests > 1;
      },
    );
    await guide.load();
    expect(await guide.claimCheckIn(), false);
    expect(guide.balance, 0);
    expect(guide.checkInDay, 1);
    expect(guide.stage, PCNewUserStage.complete);
    expect(guide.canCheckIn, true);
    expect(await guide.claimCheckIn(), true);
    expect(requests, 2);
    expect(guide.balance, .15);
    expect(guide.checkInDay, 2);
    expect(guide.stage, PCNewUserStage.complete);
    expect(await guide.claimCheckIn(), false);
    expect(guide.balance, .15);
    guide.dispose();
  });

  test('答错三题不解锁，答对未领奖也不解锁，重试只补未完成的题', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PCNewUserGuideController.flowKey,
      jsonEncode({'stage': 'quiz'}),
    );
    var guide = await resume();
    for (var i = 0; i < 3; i++) {
      await guide.answerQuiz(correct: false);
    }
    expect(guide.quizIndex, 0);
    expect(guide.balance, 0);
    expect(guide.stage, PCNewUserStage.quiz);
    await guide.answerQuiz(correct: true);
    final prize = guide.pendingPrize;
    guide.dispose();
    guide = await resume();
    expect(guide.stage, PCNewUserStage.quizReward);
    expect(guide.pendingPrize, prize);
    await guide.advance(PCNewUserStage.quizReward);
    expect(guide.stage, PCNewUserStage.quizReward);
    await guide.claimQuizReward();
    await guide.answerQuiz(correct: false);
    await guide.answerQuiz(correct: false);
    expect(guide.quizIndex, 1);
    expect(guide.correctMask, 1);
    guide.dispose();
  });

  test('进程在余额写入后退出，重启恢复领奖日志且不重复加钱', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(PCNewUserGuideController.balanceKey, 26);
    await prefs.setString(
      PCNewUserGuideController.journalKey,
      jsonEncode({
        'balance': 26,
        'flow': {
          'stage': 'quiz',
          'quizIndex': 1,
          'correctMask': 1,
          'claims': ['quiz:0'],
        },
      }),
    );
    final guide = await resume();
    expect(guide.balance, 26);
    expect(guide.stage, PCNewUserStage.quiz);
    expect(guide.quizIndex, 1);
    expect(prefs.containsKey(PCNewUserGuideController.journalKey), false);
    await guide.load();
    expect(guide.balance, 26);
    guide.dispose();
  });

  test('旧完成标记直接迁移，未完成的前三页保留 v1 进度', () async {
    SharedPreferences.setMockInitialValues({'pc_new_guide_end': true});
    var guide = await resume();
    expect(guide.isComplete, true);
    expect(guide.isIntroComplete, true);
    guide.dispose();
    SharedPreferences.setMockInitialValues({
      PCNewUserGuideController.progressKey: 2,
    });
    guide = await resume();
    expect(guide.currentStep, PCNewUserGuideStep.guide3);
    expect(guide.isComplete, false);
    guide.dispose();
  });

  test('顺序校验阻止陈旧关闭回调跳步，表单空值不前进', () async {
    final guide = await resume();
    await guide.advance(PCNewUserStage.deposit);
    expect(guide.stage, PCNewUserStage.welcome);
    await Future.wait([
      guide.advance(PCNewUserStage.welcome),
      guide.advance(PCNewUserStage.welcome),
    ]);
    expect(guide.stage, PCNewUserStage.checkInPrompt);
    await guide.confirmPayment('');
    expect(guide.stage, PCNewUserStage.checkInPrompt);
    guide.dispose();
  });

  for (final index in [0, 1, 2, 3]) {
    test('新用户资料提交立即持久化脱敏公共账号和渠道$index，冷启动保留', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PCNewUserGuideController.flowKey,
        '{"stage":"payment"}',
      );
      final guide = await resume();
      await guide.confirmPayment('player@example.com', paymentIndex: index);
      final account = PCWithdrawValidation.mask('player@example.com');
      expect(prefs.getString('pc_account_id'), account);
      expect(prefs.getInt('pc_account_seled_index'), index);
      expect(guide.confirmedUser, account);
      expect(guide.stage, PCNewUserStage.officialNotice);
      expect(
        prefs.getString(PCNewUserGuideController.flowKey),
        isNot(contains('player@example.com')),
      );
      guide.dispose();
      final cold = await resume();
      expect(cold.confirmedUser, account);
      expect(cold.stage, PCNewUserStage.officialNotice);
      expect(prefs.getString('pc_account_id'), account);
      expect(prefs.getInt('pc_account_seled_index'), index);
      cold.dispose();
    });
  }

  test('远程奖励及开关生效，格式异常退回文档默认值', () {
    final config = PCNewUserConfig.fromRaw(
      '{"eq_range":[120],"new_ad_console":0,"first_ad_prize":9,"grow_point":[5,10]}',
    );
    expect(config.withdrawalTarget, 120);
    expect(config.firstAdPrize, 9);
    expect(config.showFirstAd, true);
    expect(config.growPercent, 5);
    expect(PCNewUserConfig.fromRaw('broken').firstAdPrize, 6);
  });

  test('提现邮箱、美国电话及 PIX 四类字段按文档校验', () {
    expect(PCWithdrawValidation.email('test@example.com'), true);
    expect(PCWithdrawValidation.email('bad@'), false);
    expect(PCWithdrawValidation.cashPhone('1234567890'), true);
    expect(PCWithdrawValidation.cashPhone('123456789'), false);
    expect(PCWithdrawValidation.cpf('12345678901'), true);
    expect(PCWithdrawValidation.name('name@example.com'), false);
    expect(PCWithdrawValidation.pixPhone('+5511999999999'), true);
    expect(PCWithdrawValidation.pixPhone('5511999999999'), false);
    expect(
      PCWithdrawValidation.evp('12345678-1234-1234-1234-123456789012'),
      true,
    );
    expect(PCWithdrawValidation.evp('1234'), false);
  });
}

class _FailFlowStore extends InMemorySharedPreferencesStore {
  _FailFlowStore(super.data, {required this.throwsWrite}) : super.withData();
  final bool throwsWrite;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${PCNewUserGuideController.flowKey}') {
      if (throwsWrite) throw StateError('Unable to write preferences');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
