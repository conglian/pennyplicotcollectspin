import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNewUserConfig.dart';
import 'PCNumberManager.dart';
import 'PCPigProgress.dart';
import 'PCQuizConfig.dart';
import 'PCRewardedAdService.dart';
import 'PCWithdrawValidation.dart';

/// Figma「引导页1–3」的说明页进度，兼容已经保存的 v1 数据。
enum PCNewUserGuideStep { guide1, guide2, guide3, afterIntro }

/// 飞书 3.1 的首页业务引导，使用语义名称区分旧弹窗文件编号。
enum PCNewUserStage {
  welcome,
  checkInPrompt,
  checkIn,
  deposit,
  commission,
  quiz,
  quizReward,
  withdrawalEligibility,
  payment,
  officialNotice,
  growBonus,
  wheelPrompt,
  complete,
}

/// 新用户完整流程控制器：说明页、签到、答题和收款信息确认，冷启动续接。
/// 奖励与下一步通过可恢复的写入日志一起提交，重复回调不会重复加余额。
class PCNewUserGuideController extends ChangeNotifier {
  PCNewUserGuideController({
    SharedPreferences? preferences,
    this.requestRewardedAd,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferences = preferences,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static final instance = PCNewUserGuideController();
  static const progressKey = 'pc_intro_completed_steps_v1';
  static const flowKey = 'pc_new_user_flow_v2';
  static const journalKey = 'pc_new_user_reward_journal_v2';
  static const balanceKey = 'pc_dollar_number';

  final Future<bool> Function(String placement)? requestRewardedAd;
  SharedPreferences? _preferences;
  final Future<SharedPreferences> Function() _preferencesLoader;
  Future<void>? _loading;
  int _loadGeneration = 0;
  bool _loadingWrites = false, _disposed = false;
  bool _loaded = false;
  bool _saving = false;
  int _completedSteps = 0;
  Map<String, dynamic> _flow = {};
  PCNewUserConfig config = const PCNewUserConfig();
  final Random _random = Random();

  bool get isLoaded => _loaded;
  // 已经开始恢复奖励/写阶段时不能并发重读，避免重复结算未完成日志。
  bool get canRetryLoad => !_loaded && !_loadingWrites;
  bool get isSaving => _saving;
  bool get isIntroComplete => _completedSteps == 3;
  int get completedSteps => _completedSteps;
  PCNewUserGuideStep get currentStep =>
      PCNewUserGuideStep.values[_completedSteps];
  PCNewUserStage get stage => PCNewUserStage.values.firstWhere(
    (value) => value.name == _flow['stage'],
    orElse: () => PCNewUserStage.welcome,
  );
  bool get isComplete => stage == PCNewUserStage.complete;
  int get quizIndex => (_flow['quizIndex'] as int? ?? 0).clamp(0, 2);
  int get correctMask => _flow['correctMask'] as int? ?? 0;
  PCQuizRewardType get rewardType =>
      PCQuizRewardType.values[(_preferences?.getInt('pc_pig_level') ?? 0).clamp(
        0,
        2,
      )];
  double get diamonds => _preferences?.getDouble('pc_quiz_diamonds') ?? 0;
  double get gold => _preferences?.getDouble('pc_quiz_gold') ?? 0;
  PCQuizReward get quizReward => PCQuizReward(
    id: 'guide_quiz:$quizIndex',
    type: PCQuizRewardType.values.byName(
      _flow['pendingRewardType'] as String? ?? rewardType.name,
    ),
    amount: pendingPrize,
    questionIndex: quizIndex,
  );
  double get pendingPrize => (_flow['pendingPrize'] as num?)?.toDouble() ?? 0;
  double get firstCommission =>
      (_flow['firstCommission'] as num?)?.toDouble() ?? config.firstAdPrize;
  String get confirmedUser => _flow['confirmedUser'] as String? ?? '';
  double get balance => _preferences?.getDouble(balanceKey) ?? 0;
  int get checkInDay => (_flow['checkInDay'] as int? ?? 0).clamp(0, 7);
  bool get canCheckIn =>
      checkInDay < 7 && _flow['checkInDate'] != _dateKey(DateTime.now());
  double get checkInPrize => config.checkInRewards[min(checkInDay, 6)];
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  Future<void> load() {
    if (_loaded) return _recoverReward();
    return _loading ?? _startRead();
  }

  /// 重建控制器自己的读取，不重置系统插件、不清存档；旧读迟到不能覆盖新进度。
  /// 若底层SharedPreferences或资源全局Future仍未返回，需要关闭并重新打开应用。
  Future<void> retryLoad() {
    if (_loaded) return load();
    if (_loadingWrites) return _loading ?? Future<void>.value();
    return _startRead();
  }

  Future<void> _startRead() {
    final generation = ++_loadGeneration;
    return _loading = _readProgress(generation);
  }

  bool _isCurrentRead(int generation) =>
      !_disposed && generation == _loadGeneration;

  Future<void> _readProgress(int generation) async {
    try {
      final preferences = _preferences ?? await _preferencesLoader();
      if (!_isCurrentRead(generation)) return;
      _preferences = preferences;
      await PCNumberHelpers().pc_initNumberModel(preferences: preferences);
      if (!_isCurrentRead(generation)) return;
      // 只在依赖读取完成后获取并发布快照；旧轮读取不能回写已推进的步骤。
      final saved = preferences.getInt(progressKey) ?? 0;
      var completedSteps = saved >= 0 && saved <= 3 ? saved : 0;
      final raw = preferences.getString(flowKey);
      var flow = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (raw == null && (preferences.getBool('pc_new_guide_end') ?? false)) {
        completedSteps = 3;
        flow = {'stage': PCNewUserStage.complete.name};
      }
      _loadingWrites = true;
      await PCPigProgress.sync(preferences);
      if (!_isCurrentRead(generation)) return;
      _completedSteps = completedSteps;
      _flow = flow;
      config = PCNewUserConfig.fromModel(PCNumberHelpers().model);
      await _recoverReward();
      if (isComplete) await preferences.setBool('pc_new_guide_end', true);
      if (!_isCurrentRead(generation)) return;
      _loaded = true;
      notifyListeners();
    } finally {
      if (generation == _loadGeneration) {
        _loading = null;
        _loadingWrites = false;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }

  /// 成功保存后才前进；忽略重复点击或已离开页面的迟到回调。
  Future<PCNewUserGuideStep> completeStep(PCNewUserGuideStep step) async {
    await load();
    if (_saving || isIntroComplete || step != currentStep) return currentStep;

    _saving = true;
    notifyListeners();
    try {
      final next = _completedSteps + 1;
      if (!await _preferences!.setInt(progressKey, next)) {
        throw StateError('Unable to save guide progress');
      }
      _completedSteps = next;
      return currentStep;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> _writeFlow(Map<String, dynamic> next) async {
    if (!await _preferences!.setString(flowKey, jsonEncode(next))) {
      throw StateError('Unable to save guide flow');
    }
    _flow = next;
  }

  /// 普通说明步骤只能顺序推进；签到、答题和表单必须走各自校验入口。
  Future<void> advance(PCNewUserStage expected) async {
    await load();
    if (_saving || stage != expected) return;
    const next = {
      PCNewUserStage.welcome: PCNewUserStage.checkInPrompt,
      PCNewUserStage.checkInPrompt: PCNewUserStage.checkIn,
      PCNewUserStage.deposit: PCNewUserStage.commission,
      PCNewUserStage.commission: PCNewUserStage.quiz,
      PCNewUserStage.withdrawalEligibility: PCNewUserStage.payment,
      PCNewUserStage.officialNotice: PCNewUserStage.growBonus,
      PCNewUserStage.growBonus: PCNewUserStage.wheelPrompt,
      PCNewUserStage.wheelPrompt: PCNewUserStage.complete,
    };
    if (!next.containsKey(expected)) return;
    await _save(() async {
      await _writeFlow({..._flow, 'stage': next[expected]!.name});
      if (isComplete &&
          !await _preferences!.setBool('pc_new_guide_end', true)) {
        throw StateError('Unable to save guide completion');
      }
    });
  }

  Future<void> _save(Future<void> Function() action) async {
    _saving = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<PCAdOutcome> _requestCheckInAd() async {
    try {
      final legacyRequest = requestRewardedAd;
      if (legacyRequest != null) {
        return await legacyRequest('nkmdl_signin_rv')
            ? PCAdOutcome.success
            : PCAdOutcome.failed;
      }
      return await PCRewardedAdService.instance.requestOutcome(
        'nkmdl_signin_rv',
      );
    } catch (_) {
      return PCAdOutcome.failed;
    }
  }

  Future<bool> claimCheckIn() async => (await claimCheckInOutcome()).isSuccess;

  /// 签到仅真实激励成功才到账；取消与失败均续接新用户答题，但只有失败提示广告错误。
  /// 保存异常保持抛出，由签到页显示原保存提示，不能误作广告播放失败。
  Future<PCAdOutcome> claimCheckInOutcome() async {
    await load();
    if (_saving ||
        !canCheckIn ||
        (!isComplete && stage != PCNewUserStage.checkIn)) {
      return PCAdOutcome.cancelled;
    }
    final prize = checkInPrize;
    var outcome = PCAdOutcome.cancelled;
    await _save(() async {
      // 首次与普通签到统一真实激励成功才到账，不受旧new_ad_console开关影响。
      outcome = await _requestCheckInAd();
      if (!outcome.isSuccess) {
        if (!isComplete) {
          // 先持久化续接点；取消直接退出，失败等用户关闭原路由面板再继续引导。
          await _writeFlow({
            ..._flow,
            'stage': PCNewUserStage.quiz.name,
            'firstCommission': 0,
          });
        }
        return;
      }
      await _credit('checkIn:$checkInDay:${_dateKey(DateTime.now())}', prize, {
        ..._flow,
        'checkInDay': checkInDay + 1,
        'checkInDate': _dateKey(DateTime.now()),
        if (!isComplete) 'stage': PCNewUserStage.deposit.name,
        if (!isComplete) 'firstCommission': prize,
      });
    });
    return outcome;
  }

  Future<void> answerQuiz({required bool correct}) async {
    await load();
    if (_saving || stage != PCNewUserStage.quiz) return;
    await _save(() async {
      await _writeFlow({
        ..._flow,
        if (correct)
          'pendingPrize': PCNumberHelpers().pc_prizeForLevel(
            rewardType.index,
            rewardType == PCQuizRewardType.cash
                ? balance
                : rewardType == PCQuizRewardType.diamond
                ? diamonds
                : gold,
            random: _random,
            config: config.model,
          ),
        if (correct) 'pendingRewardType': rewardType.name,
        'stage': correct
            ? PCNewUserStage.quizReward.name
            : PCNewUserStage.quiz.name,
        if (!correct) 'quizIndex': _nextQuestion(quizIndex, correctMask),
      });
    });
  }

  int _nextQuestion(int current, int mask) {
    for (var offset = 1; offset <= 3; offset++) {
      final index = (current + offset) % 3;
      if ((mask & (1 << index)) == 0) return index;
    }
    return 0;
  }

  Future<bool> claimQuizReward() async {
    await load();
    if (_saving || stage != PCNewUserStage.quizReward) return false;
    final reward = quizReward;
    final mask = correctMask | (1 << quizIndex);
    var claimed = false;
    await _save(() async {
      await _credit('quiz:$quizIndex', pendingPrize, {
        ..._flow,
        'correctMask': mask,
        'pendingPrize': 0,
        'quizIndex': _nextQuestion(quizIndex, mask),
        'stage':
            (mask == 7
                    ? PCNewUserStage.withdrawalEligibility
                    : PCNewUserStage.quiz)
                .name,
      }, type: reward.type);
      claimed = true;
    });
    return claimed;
  }

  /// 有效提交即保存公共脱敏账号、渠道及引导进度；原始资料不写入本地。
  Future<void> confirmPayment(String maskedUser, {int? paymentIndex}) async {
    await load();
    final user = maskedUser.trim();
    if (_saving || stage != PCNewUserStage.payment || user.isEmpty) return;
    if (paymentIndex != null && (paymentIndex < 0 || paymentIndex > 3)) {
      throw RangeError.range(paymentIndex, 0, 3, 'paymentIndex');
    }
    final account = user.contains('*') ? user : PCWithdrawValidation.mask(user);
    await _save(() async {
      if (paymentIndex != null &&
          !await _preferences!.setInt('pc_account_seled_index', paymentIndex)) {
        throw StateError('Unable to save payment method');
      }
      if (!await _preferences!.setString('pc_account_id', account)) {
        throw StateError('Unable to save payment account');
      }
      await _writeFlow({
        ..._flow,
        'confirmedUser': account,
        'stage': PCNewUserStage.officialNotice.name,
      });
    });
  }

  Future<void> _credit(
    String id,
    double amount,
    Map<String, dynamic> next, {
    PCQuizRewardType type = PCQuizRewardType.cash,
  }) async {
    final claims = List<String>.from(_flow['claims'] as List? ?? []);
    if (claims.contains(id)) return;
    final journal = {
      'balance':
          ((balance + (type == PCQuizRewardType.cash ? amount : 0)) * 100)
              .round() /
          100,
      'diamonds': diamonds + (type == PCQuizRewardType.diamond ? amount : 0),
      'gold': gold + (type == PCQuizRewardType.gold ? amount : 0),
      'flow': {
        ...next,
        'claims': [...claims, id],
      },
    };
    if (!await _preferences!.setString(journalKey, jsonEncode(journal))) {
      throw StateError('Unable to save reward');
    }
    await _recoverReward();
  }

  Future<void> _recoverReward() async {
    final raw = _preferences!.getString(journalKey);
    if (raw == null) return;
    final journal = jsonDecode(raw) as Map<String, dynamic>;
    if (!await _preferences!.setDouble(
      balanceKey,
      (journal['balance'] as num).toDouble(),
    )) {
      throw StateError('Unable to save balance');
    }
    await PCPigProgress.sync(
      _preferences!,
      diamonds: (journal['diamonds'] as num?)?.toDouble(),
      gold: (journal['gold'] as num?)?.toDouble(),
    );
    await _writeFlow(Map<String, dynamic>.from(journal['flow'] as Map));
    if (!await _preferences!.remove(journalKey)) {
      throw StateError('Unable to finish reward');
    }
  }
}
