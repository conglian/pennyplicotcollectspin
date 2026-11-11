import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../PCModel/PCNumbserModel.dart';
import 'PCNumberManager.dart';
import 'PCPigProgress.dart';
import 'PCQuizController.dart';
import 'PCRewardedAdService.dart';

enum PCWithdrawalStage {
  insufficient,
  reviewing,
  reviewApproved,
  releasing,
  queue,
  lastStep,
}

enum PCWithdrawalPromptKind {
  diamondUpgrade,
  reviewPending,
  reviewVerification,
  channelActivated,
  priorityGift,
  giftReward,
  diamondCollect,
  diamondCountdown,
  goldUpgrade,
  queue,
  lastStep,
  insufficient,
}

enum PCWithdrawalEventKind { quiz, spin, video }

/// 单次提现广告动作的结果；业务未受理与用户取消都不是广告播放失败。
enum PCWithdrawalAdResult {
  applied,
  cancelled,
  failed,
  notApplied;

  bool get isApplied => this == applied;
}

/// 提现待展示节点。步骤、任务轮次和点击的提现档位随快照保存，重启可恢复。
class PCWithdrawalPrompt {
  const PCWithdrawalPrompt({
    required this.id,
    required this.kind,
    required this.withdrawalTarget,
    this.reviewProgress = 40,
    this.taskIndex = 0,
    this.taskCycle = 0,
  });
  final String id;
  final PCWithdrawalPromptKind kind;
  final double withdrawalTarget;
  final int reviewProgress, taskIndex, taskCycle;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'withdrawalTarget': withdrawalTarget,
    'reviewProgress': reviewProgress,
    'taskIndex': taskIndex,
    'taskCycle': taskCycle,
  };

  factory PCWithdrawalPrompt.fromJson(Map<String, dynamic> raw) =>
      PCWithdrawalPrompt(
        id: raw['id'] as String,
        kind: PCWithdrawalPromptKind.values.byName(raw['kind'] as String),
        withdrawalTarget: (raw['withdrawalTarget'] as num? ?? 100).toDouble(),
        reviewProgress: (raw['reviewProgress'] as num? ?? 40).toInt(),
        taskIndex: (raw['taskIndex'] as num? ?? 0).toInt(),
        taskCycle: (raw['taskCycle'] as num? ?? 0).toInt(),
      );
}

/// 现金页六态、钻石入场链、午夜升级、排队及循环提现任务的本地状态机。
/// 所有动作串行落盘；礼包先记恢复日志，广告只接受真实激励成功。
class PCWithdrawalController extends ChangeNotifier {
  PCWithdrawalController({
    SharedPreferences? preferences,
    DateTime Function()? now,
    math.Random? random,
    Future<bool> Function(String placement)? requestAd,
    Future<PCAdOutcome> Function(String placement)? requestAdOutcome,
    this.onSync,
    bool scheduleMidnightTimer = true,
  }) : _prefs = preferences,
       _now = now ?? DateTime.now,
       _random = random ?? math.Random(),
       _requestAdOutcome =
           requestAdOutcome ??
           (requestAd == null
               ? PCRewardedAdService.instance.requestOutcome
               : (placement) async => await requestAd(placement)
                     ? PCAdOutcome.success
                     : PCAdOutcome.failed),
       _scheduleTimer = scheduleMidnightTimer;

  static final instance = PCWithdrawalController();
  static const storageKey = 'pc_withdrawal_flow_v1';
  static const giftJournalKey = 'pc_withdrawal_gift_journal_v1';
  static const gameplayEnabledKey = 'pc_withdrawal_tasks_active_v1';
  static const _diamondChain = [
    PCWithdrawalPromptKind.diamondUpgrade,
    PCWithdrawalPromptKind.reviewPending,
    PCWithdrawalPromptKind.reviewVerification,
    PCWithdrawalPromptKind.channelActivated,
    PCWithdrawalPromptKind.priorityGift,
    PCWithdrawalPromptKind.giftReward,
    PCWithdrawalPromptKind.diamondCountdown,
  ];

  SharedPreferences? _prefs;
  final DateTime Function() _now;
  final math.Random _random;
  final Future<PCAdOutcome> Function(String) _requestAdOutcome;
  final Future<void> Function()? onSync;
  final bool _scheduleTimer;
  bool _serialBusy = false;
  final List<Completer<void>> _serialWaiters = [];
  Map<String, dynamic> _data = {};
  final Set<String> _dismissed = {};
  Timer? _midnightTimer;
  bool _loaded = false, _disposed = false, _adInFlight = false;
  bool _coldPromptRequested = false;
  String? _lastSavedRaw;
  String? _lastViewSignature;

  bool get isLoaded => _loaded;
  bool get isBusy => _adInFlight;
  double get target => PCNumberHelpers().pc_firstTarget;
  double get balance => _prefs?.getDouble('pc_dollar_number') ?? 0;
  double get diamonds => _prefs?.getDouble('pc_quiz_diamonds') ?? 0;
  double get gold => _prefs?.getDouble('pc_quiz_gold') ?? 0;
  int get pigLevel => (_prefs?.getInt('pc_pig_level') ?? 0).clamp(0, 2);
  DateTime? get diamondEnteredAt =>
      _prefs == null ? null : PCPigProgress.diamondEnteredAt(_prefs!);
  DateTime? get diamondDeadline =>
      _prefs == null ? null : PCPigProgress.diamondDeadline(_prefs!);
  Duration get midnightRemaining {
    final deadline = diamondDeadline;
    if (deadline == null) return Duration.zero;
    final remaining = deadline.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get queueRank =>
      _int('queueRank', PCNumberHelpers().pc_queueNumber.intCurrent);
  int get queueTotal =>
      _int('queueTotal', PCNumberHelpers().pc_queueNumber.intAll);
  int get queueSeed => _int('queueSeed');
  int get taskIndex => _int('taskIndex');
  int get taskCycle => _int('taskCycle');
  int get taskProgress => _int('taskProgress');
  int get taskTarget => currentTask.data;
  int get reviewBaseline => _int('reviewBaseline', 0);
  bool get giftClaimed => _data['giftClaimed'] == true;

  /// 优质用户礼包首次进入中奖步骤时生成并落盘，预览及领取共用这笔配置奖励。
  double get diamondGiftAmount =>
      (_data['diamondGiftAmount'] as num? ?? 0).toDouble();
  List<PCTixianTask> get tasks => PCNumberHelpers().pc_tixianTasks;
  PCTixianTask get currentTask => tasks[taskIndex % tasks.length];
  PCWithdrawalStage get stage => _stage(_data);
  List<PCWithdrawalPrompt> get pending => List.unmodifiable(_prompts(_data));
  PCWithdrawalPrompt? get next => pending.firstOrNull;
  bool get hasPending => pending.isNotEmpty;
  bool get taskCompletionPending =>
      pending.any((prompt) => prompt.kind == PCWithdrawalPromptKind.lastStep);

  bool isPending(PCWithdrawalPrompt prompt) =>
      pending.any((value) => value.id == prompt.id);

  int _int(String key, [int fallback = 0]) =>
      (_data[key] as num? ?? fallback).toInt();
  Map<String, dynamic> _copy() => Map<String, dynamic>.from(_data);
  PCWithdrawalStage _stage(Map<String, dynamic> data) {
    if (pigLevel == 0) return PCWithdrawalStage.insufficient;
    if (pigLevel == 1) {
      return diamonds >= PCNumberHelpers.diamondTarget
          ? PCWithdrawalStage.reviewApproved
          : PCWithdrawalStage.reviewing;
    }
    if (gold < PCNumberHelpers.goldTarget) return PCWithdrawalStage.releasing;
    return (data['queueRank'] as num? ?? 2) <= 1
        ? PCWithdrawalStage.lastStep
        : PCWithdrawalStage.queue;
  }

  List<PCWithdrawalPrompt> _prompts(Map<String, dynamic> data) =>
      (data['pending'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (raw) =>
                PCWithdrawalPrompt.fromJson(Map<String, dynamic>.from(raw)),
          )
          .toList();

  Future<T> _serial<T>(Future<T> Function() action) async {
    while (_serialBusy) {
      final waiter = Completer<void>();
      _serialWaiters.add(waiter);
      await waiter.future;
    }
    _serialBusy = true;
    try {
      return await action();
    } finally {
      _serialBusy = false;
      if (_serialWaiters.isNotEmpty) _serialWaiters.removeAt(0).complete();
    }
  }

  Future<void> load() => refresh();
  Future<void> refresh() => _serial(_refresh);

  Future<void> _load() async {
    if (_loaded) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.reload();
    await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
    _lastSavedRaw = _prefs!.getString(storageKey);
    final data = _decode(_lastSavedRaw);
    if (data.isEmpty) {
      final level = (_prefs!.getInt('pc_pig_level') ?? 0).clamp(0, 2);
      _data = {
        'version': 1,
        'observedLevel': level,
        'diamondStarted': level == 1,
        'diamondStep': level == 1
            ? (_prefs!.getInt('pc_pig_upgrade_seen_level_v1') ?? 0) >= 1
                  ? 1
                  : 0
            : _diamondChain.length,
        'goldUpgradeAcknowledged':
            (_prefs!.getInt('pc_pig_upgrade_seen_level_v1') ?? 0) >= 2,
        'quizCorrectCursor': _quizCorrectCount,
        'pending': <Map<String, dynamic>>[],
      };
    } else {
      _data = data;
    }
    final journal = _decode(_prefs!.getString(giftJournalKey));
    if (journal['flow'] is Map) await _applyGiftJournal(journal);
    _loaded = true;
  }

  static Map<String, dynamic> _decode(String? raw) {
    try {
      return Map<String, dynamic>.from(jsonDecode(raw ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  // 答题快照先于兼容镜像落盘；从真实答对总数读取，避免中断恢复遗漏或把答错计入。
  int get _quizCorrectCount {
    final quiz = _decode(_prefs!.getString(PCQuizController.storageKey));
    final value = quiz['correctCount'];
    return math.max(
      0,
      value is num ? value.toInt() : _prefs!.getInt('pc_quiz_all_num') ?? 0,
    );
  }

  Future<void> _refresh() async {
    await _load();
    // 同实例上次领奖中断也要先重放，不得基于已加过的缓存再次生成奖励目标。
    final journal = _decode(_prefs!.getString(giftJournalKey));
    if (journal['flow'] is Map) await _applyGiftJournal(journal);
    final before = _lastViewSignature;
    await PCNumberHelpers().pc_initNumberModel(preferences: _prefs);
    final progress = await PCPigProgress.sync(_prefs!, now: _now());
    final next = _copy();
    final observed = (next['observedLevel'] as num? ?? 0).toInt();
    if (observed == 0 && progress.level >= 1) {
      next['diamondStarted'] = true;
      next['diamondStep'] = 0;
    }
    next['observedLevel'] = progress.level;
    final queueJustInitialized =
        progress.level == 2 &&
        progress.gold >= PCNumberHelpers.goldTarget &&
        next['queueInitialized'] != true;
    if (progress.level == 2) {
      next['diamondStep'] = _diamondChain.length;
      next['pending'] = _prompts(next)
          .where(
            (prompt) =>
                !_diamondChain.contains(prompt.kind) &&
                prompt.kind != PCWithdrawalPromptKind.diamondCollect,
          )
          .map((prompt) => prompt.toJson())
          .toList();
    }
    if (queueJustInitialized) _initializeQueue(next);
    final quizCount = _quizCorrectCount;
    // 旧版quizCursor是全部答题次数，首次迁移仅建立当前正确次数基线，不追补旧题。
    final quizCursor = (next['quizCorrectCursor'] as num? ?? quizCount).toInt();
    if (_stage(next) == PCWithdrawalStage.lastStep && quizCount > quizCursor) {
      _count(next, PCWithdrawalEventKind.quiz, quizCount - quizCursor);
    }
    next['quizCorrectCursor'] = quizCount;
    next.remove('quizCursor');
    _syncPrompts(next, cold: !_coldPromptRequested || queueJustInitialized);
    await _save(next);
    _coldPromptRequested = true;
    await _mirror();
    _scheduleMidnight();
    if (_viewSignature() != before) _notify();
  }

  void _initializeQueue(Map<String, dynamic> next) {
    if (next['queueInitialized'] == true) return;
    final config = PCNumberHelpers().pc_queueNumber;
    // 调试时可提前设置名次，进入真实排队阶段后再消费，不提前改变猪阶段。
    final debugRank = kDebugMode ? next.remove('debugQueueRank') as int? : null;
    final debugTotal = kDebugMode
        ? next.remove('debugQueueTotal') as int?
        : null;
    final rank = math.max(1, debugRank ?? config.intCurrent);
    next['queueInitialized'] = true;
    next['queueRank'] = rank;
    next['queueTotal'] = math.max(
      rank,
      math.max(1, debugTotal ?? config.intAll),
    );
    next['queueSeed'] = _random.nextInt(1 << 30);
    next['taskIndex'] = 0;
    next['taskCycle'] = 0;
    next['taskProgress'] = 0;
    next['quizCorrectCursor'] = _quizCorrectCount;
  }

  /// 首页调试专用：设置真实队列名次及兼容镜像，第一名沿用提现任务衔接。
  /// 未进入排队时只保存预设名次；不修改余额、猪阶段和既有任务进度。
  Future<void> debugRefreshProgress({int? queueRank}) {
    if (!kDebugMode) throw UnsupportedError('仅Debug版本允许修改排队名次');
    if (queueRank != null && (queueRank < 1 || queueRank > 1000000000)) {
      throw const FormatException('排队名次须为1到1000000000之间的整数');
    }
    return _serial(() async {
      await _refresh();
      final next = _copy();
      if (queueRank != null) {
        final total = math.max(queueRank, math.max(1, queueTotal));
        next['queueRank'] = queueRank;
        next['queueTotal'] = total;
        if (next['queueInitialized'] != true) {
          next['debugQueueRank'] = queueRank;
          next['debugQueueTotal'] = total;
        }
      }
      final current = _stage(next);
      if ((current == PCWithdrawalStage.queue ||
              current == PCWithdrawalStage.lastStep) &&
          next['goldUpgradeAcknowledged'] == true) {
        // 调低再调回10金砖时，不让冷启恢复用的旧收集页挡住真实队列/任务。
        _remove(next, PCWithdrawalPromptKind.goldUpgrade.name);
      }
      if (current != PCWithdrawalStage.queue) {
        _remove(next, PCWithdrawalPromptKind.queue.name);
      }
      if (current != PCWithdrawalStage.lastStep) {
        next['pending'] = _prompts(next)
            .where((prompt) => prompt.kind != PCWithdrawalPromptKind.lastStep)
            .map((prompt) => prompt.toJson())
            .toList();
      }
      _syncPrompts(next, cold: true);
      if (queueRank != null && current == PCWithdrawalStage.lastStep) {
        _remove(next, PCWithdrawalPromptKind.queue.name);
        next['quizCorrectCursor'] = _quizCorrectCount;
        _add(next, PCWithdrawalPromptKind.lastStep, force: true);
      } else if (queueRank != null && current == PCWithdrawalStage.queue) {
        _add(next, PCWithdrawalPromptKind.queue, force: true);
      }
      await _save(next);
      if (queueRank != null) {
        await _stored(_prefs!.setInt('pc_current_ranking', this.queueRank));
        await _stored(_prefs!.setInt('pc_all_ranking', queueTotal));
      }
      await _mirror();
      _notify();
    });
  }

  void _add(
    Map<String, dynamic> next,
    PCWithdrawalPromptKind kind, {
    bool force = false,
    double? amount,
  }) {
    final index = (next['taskIndex'] as num? ?? 0).toInt();
    final cycle = (next['taskCycle'] as num? ?? 0).toInt();
    final id = switch (kind) {
      PCWithdrawalPromptKind.lastStep => 'task:$cycle:$index',
      PCWithdrawalPromptKind.insufficient => 'insufficient:$amount',
      _ => kind.name,
    };
    if (force) _dismissed.remove(id);
    if (_dismissed.contains(id)) return;
    final prompts = _prompts(next);
    if (prompts.any((prompt) => prompt.id == id)) return;
    prompts.add(
      PCWithdrawalPrompt(
        id: id,
        kind: kind,
        withdrawalTarget: amount ?? target,
        taskIndex: index,
        taskCycle: cycle,
      ),
    );
    next['pending'] = prompts.map((prompt) => prompt.toJson()).toList();
  }

  void _remove(Map<String, dynamic> next, String id) {
    next['pending'] = _prompts(next)
        .where((prompt) => prompt.id != id)
        .map((prompt) => prompt.toJson())
        .toList();
  }

  void _syncPrompts(Map<String, dynamic> next, {bool cold = false}) {
    var step = (next['diamondStep'] as num? ?? _diamondChain.length).toInt();
    final deadline = diamondDeadline;
    if (pigLevel == 1) {
      if (deadline == null) {
        _remove(next, PCWithdrawalPromptKind.diamondCountdown.name);
      } else {
        _remove(next, PCWithdrawalPromptKind.diamondCollect.name);
      }
      if (step == 6 && deadline == null) {
        // 礼包已领取但未集满20时结束入场链，继续正常收集，不展示倒计时。
        next['diamondStep'] = _diamondChain.length;
        step = _diamondChain.length;
      }
    }
    if (next['diamondStarted'] == true && step < _diamondChain.length) {
      if (_diamondChain[math.max(0, step)] ==
          PCWithdrawalPromptKind.giftReward) {
        final amount = next['diamondGiftAmount'];
        if (amount is! num || !amount.isFinite || amount <= 0) {
          next['diamondGiftAmount'] = PCNumberHelpers().pc_prizeForLevel(
            1,
            diamonds,
            random: _random,
          );
        }
      }
      _add(next, _diamondChain[math.max(0, step)]);
      if (_diamondChain[math.max(0, step)] ==
          PCWithdrawalPromptKind.diamondCountdown) {
        next['diamondCountdownPromptedFor'] = deadline!.toIso8601String();
      }
      return;
    }
    if (pigLevel == 2 && next['goldUpgradeAcknowledged'] != true) {
      _add(next, PCWithdrawalPromptKind.goldUpgrade);
      return;
    }
    final current = _stage(next);
    if (current == PCWithdrawalStage.reviewApproved &&
        deadline != null &&
        next['diamondCountdownPromptedFor'] != deadline.toIso8601String()) {
      _add(next, PCWithdrawalPromptKind.diamondCountdown, force: true);
      next['diamondCountdownPromptedFor'] = deadline.toIso8601String();
    }
    if (cold) {
      switch (current) {
        case PCWithdrawalStage.reviewing:
          _add(next, PCWithdrawalPromptKind.diamondCollect);
        case PCWithdrawalStage.reviewApproved:
          _add(next, PCWithdrawalPromptKind.diamondCountdown);
        case PCWithdrawalStage.releasing:
          _add(next, PCWithdrawalPromptKind.goldUpgrade);
        case PCWithdrawalStage.queue:
          _add(next, PCWithdrawalPromptKind.queue);
        case PCWithdrawalStage.lastStep:
          _add(next, PCWithdrawalPromptKind.lastStep);
        case PCWithdrawalStage.insufficient:
          break;
      }
    }
  }

  /// 现金页按钮重开当前流程；余额不足时保留所点击的提现档位。
  Future<void> requestCurrentPrompt({double? amount}) => _serial(() async {
    await _refresh();
    final next = _copy();
    if (amount != null && amount.isFinite && amount > balance) {
      _add(
        next,
        PCWithdrawalPromptKind.insufficient,
        force: true,
        amount: amount,
      );
    } else {
      final step = _int('diamondStep', _diamondChain.length);
      if (_data['diamondStarted'] == true && step < _diamondChain.length) {
        _add(next, _diamondChain[math.max(0, step)], force: true);
      } else if (pigLevel == 2 && next['goldUpgradeAcknowledged'] != true) {
        _add(next, PCWithdrawalPromptKind.goldUpgrade, force: true);
      } else {
        final kind = switch (stage) {
          PCWithdrawalStage.insufficient => PCWithdrawalPromptKind.insufficient,
          PCWithdrawalStage.reviewing => PCWithdrawalPromptKind.diamondCollect,
          PCWithdrawalStage.reviewApproved =>
            PCWithdrawalPromptKind.diamondCountdown,
          PCWithdrawalStage.releasing => PCWithdrawalPromptKind.goldUpgrade,
          PCWithdrawalStage.queue => PCWithdrawalPromptKind.queue,
          PCWithdrawalStage.lastStep => PCWithdrawalPromptKind.lastStep,
        };
        _add(next, kind, force: true, amount: amount ?? target);
      }
    }
    await _save(next);
    _notify();
  });

  /// 完成当前节点后才推进；中奖页只有Collect的真实到账可以消费。
  Future<void> acknowledge(PCWithdrawalPrompt prompt) => _serial(() async {
    await _load();
    if (!isPending(prompt)) return;
    if (prompt.kind == PCWithdrawalPromptKind.giftReward && !giftClaimed) {
      return;
    }
    final next = _copy();
    _remove(next, prompt.id);
    final step = _int('diamondStep', _diamondChain.length);
    if (step < _diamondChain.length && _diamondChain[step] == prompt.kind) {
      next['diamondStep'] = step + 1;
      if (prompt.kind == PCWithdrawalPromptKind.reviewPending) {
        next['reviewBaseline'] = 40;
      }
    } else if (prompt.kind == PCWithdrawalPromptKind.goldUpgrade) {
      next['goldUpgradeAcknowledged'] = true;
      // 收集金砖页也会在下次冷启动恢复；本次确认不能被后续同步立刻重新拉起。
      _dismissed.add(prompt.id);
    } else {
      _dismissed.add(prompt.id);
    }
    _syncPrompts(next, cold: prompt.kind == PCWithdrawalPromptKind.goldUpgrade);
    await _save(next);
    await _mirror();
    _notify();
  });

  /// 关闭只收起本次展示，不消费入场链/待领奖励；冷启动或现金按钮可恢复。
  Future<void> dismiss(PCWithdrawalPrompt prompt) => _serial(() async {
    await _load();
    final next = _copy();
    _remove(next, prompt.id);
    await _save(next);
    _dismissed.add(prompt.id);
    _notify();
  });

  Future<bool> claimDiamondGift() => _serial(() async {
    await _refresh();
    if (giftClaimed || _int('diamondStep') != 5) return false;
    final next = _copy();
    next['giftClaimed'] = true;
    next['diamondStep'] = 6;
    _remove(next, PCWithdrawalPromptKind.giftReward.name);
    final journal = {
      'diamondsAfter': ((diamonds + diamondGiftAmount) * 100).round() / 100,
      'flow': next,
    };
    await _stored(_prefs!.setString(giftJournalKey, jsonEncode(journal)));
    await _applyGiftJournal(journal);
    await onSync?.call();
    _notify();
    return true;
  });

  Future<void> _applyGiftJournal(Map<String, dynamic> journal) async {
    await PCPigProgress.sync(
      _prefs!,
      diamonds: (journal['diamondsAfter'] as num).toDouble(),
      now: _now(),
    );
    final next = Map<String, dynamic>.from(journal['flow'] as Map);
    // 礼包可能刚好补足20；下一节点与真实数量一并提交后才清理恢复日志。
    if (pigLevel == 1) _syncPrompts(next);
    await _save(next);
    await _stored(_prefs!.remove(giftJournalKey));
    await _mirror();
  }

  Future<bool> advanceQueueWithAd() async =>
      (await advanceQueueWithAdOutcome()).isApplied;

  Future<PCWithdrawalAdResult> advanceQueueWithAdOutcome() =>
      _advertised('nkmdl_queue_rv', () async {
        if (stage != PCWithdrawalStage.queue) return false;
        final next = _copy();
        final config = PCNumberHelpers().pc_queueNumber;
        final rank = math.max(1, queueRank - _sample(config.intCurrentDelete));
        final total = math.max(rank, queueTotal - _sample(config.intAllDelete));
        next['queueRank'] = rank;
        next['queueTotal'] = total;
        if (rank == 1) {
          _remove(next, PCWithdrawalPromptKind.queue.name);
          next['quizCorrectCursor'] = _quizCorrectCount;
          _add(next, PCWithdrawalPromptKind.lastStep, force: true);
        }
        await _save(next);
        await _mirror();
        return true;
      }, allowed: () => stage == PCWithdrawalStage.queue);

  /// 只当前video任务可请求；成功后本方法已计一次，调用方不要重复上报video。
  Future<bool> recordVideoWithAd() async =>
      (await recordVideoWithAdOutcome()).isApplied;

  Future<PCWithdrawalAdResult> recordVideoWithAdOutcome() => _advertised(
    'withdrawal_task_video',
    () async {
      final sequence = _int('videoSequence') + 1;
      return _recordEvent(
        PCWithdrawalEventKind.video,
        'video:$sequence',
        videoSequence: sequence,
      );
    },
    allowed: () =>
        stage == PCWithdrawalStage.lastStep && currentTask.title == 'video',
  );

  Future<PCWithdrawalAdResult> _advertised(
    String placement,
    Future<bool> Function() success, {
    required bool Function() allowed,
  }) {
    if (_adInFlight || _disposed) {
      return Future.value(PCWithdrawalAdResult.notApplied);
    }
    _adInFlight = true;
    _notify();
    return _serial(() async {
      await _refresh();
      if (_disposed || !allowed()) return PCWithdrawalAdResult.notApplied;
      PCAdOutcome outcome;
      try {
        outcome = await _requestAdOutcome(placement);
      } catch (_) {
        return PCWithdrawalAdResult.failed;
      }
      if (outcome == PCAdOutcome.failed) return PCWithdrawalAdResult.failed;
      if (outcome == PCAdOutcome.cancelled) {
        return PCWithdrawalAdResult.cancelled;
      }
      if (_disposed || !allowed()) return PCWithdrawalAdResult.notApplied;
      final changed = await success();
      if (changed) await onSync?.call();
      return changed
          ? PCWithdrawalAdResult.applied
          : PCWithdrawalAdResult.notApplied;
    }).whenComplete(() {
      _adInFlight = false;
      _notify();
    });
  }

  int _sample(List<int> range) {
    if (range.isEmpty) return 0;
    final low = math.max(0, math.min(range.first, range.last));
    final high = math.max(low, math.max(range.first, range.last));
    return low + _random.nextInt(high - low + 1);
  }

  /// 转盘使用持久化reward/spin ID；错误任务下的事件也消费ID，防止以后补算旧次数。
  /// 答题仅按持久化correctCount增量处理，外部事件不能再为同一道题额外计数。
  Future<bool> recordEvent(
    PCWithdrawalEventKind kind, {
    required String eventId,
  }) => _serial(() async {
    await _refresh();
    if (kind == PCWithdrawalEventKind.quiz) return false;
    return _recordEvent(kind, eventId);
  });

  Future<bool> _recordEvent(
    PCWithdrawalEventKind kind,
    String eventId, {
    int? videoSequence,
  }) async {
    final id = '${kind.name}:$eventId';
    if (eventId.isEmpty) return false;
    final seen = (_data['events'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    if (seen.contains(id)) return false;
    final next = _copy();
    seen.add(id);
    next['events'] = seen.toList();
    if (videoSequence != null) next['videoSequence'] = videoSequence;
    final counted = _count(next, kind, 1);
    await _save(next);
    _notify();
    return counted;
  }

  bool _count(
    Map<String, dynamic> next,
    PCWithdrawalEventKind kind,
    int count,
  ) {
    if (_stage(next) != PCWithdrawalStage.lastStep || count <= 0) return false;
    final index = (next['taskIndex'] as num? ?? 0).toInt() % tasks.length;
    final task = tasks[index];
    if (task.title != kind.name) return false;
    final progress = (next['taskProgress'] as num? ?? 0).toInt() + count;
    if (progress < task.data) {
      next['taskProgress'] = progress;
      return true;
    }
    final cycle = (next['taskCycle'] as num? ?? 0).toInt();
    _remove(next, 'task:$cycle:$index');
    next['taskIndex'] = (index + 1) % tasks.length;
    next['taskCycle'] = cycle + (index + 1 >= tasks.length ? 1 : 0);
    next['taskProgress'] = 0;
    next['quizCorrectCursor'] = _quizCorrectCount;
    _add(next, PCWithdrawalPromptKind.lastStep, force: true);
    return true;
  }

  Future<void> _save(Map<String, dynamic> next) async {
    final raw = jsonEncode(next);
    if (_lastSavedRaw != raw) {
      await _stored(_prefs!.setString(storageKey, raw));
      _lastSavedRaw = raw;
    }
    _data = next;
  }

  Future<void> _mirror() async {
    final active =
        stage == PCWithdrawalStage.queue || stage == PCWithdrawalStage.lastStep;
    if (_prefs!.getBool(gameplayEnabledKey) != active) {
      await _stored(_prefs!.setBool(gameplayEnabledKey, active));
    }
    if (_data['queueInitialized'] == true) {
      if (_prefs!.getInt('pc_current_ranking') != queueRank) {
        await _stored(_prefs!.setInt('pc_current_ranking', queueRank));
      }
      if (_prefs!.getInt('pc_all_ranking') != queueTotal) {
        await _stored(_prefs!.setInt('pc_all_ranking', queueTotal));
      }
    }
  }

  String _viewSignature() => jsonEncode({
    'data': _data,
    'level': pigLevel,
    'diamonds': diamonds,
    'gold': gold,
    'balance': balance,
    'deadline': diamondDeadline?.toIso8601String(),
  });

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
    if (!_scheduleTimer || _disposed || pigLevel != 1) return;
    final remaining = midnightRemaining;
    if (remaining <= Duration.zero) return;
    _midnightTimer = Timer(remaining, () {
      // 自动回调的异常交由下一次前台refresh重试，保留原快照和待展示节点。
      unawaited(refresh().catchError((Object _) {}));
    });
  }

  static Future<void> _stored(Future<bool> operation) async {
    if (!await operation) {
      throw StateError('Withdrawal progress could not be saved');
    }
  }

  void _notify() {
    if (_disposed) return;
    _lastViewSignature = _viewSignature();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _midnightTimer?.cancel();
    super.dispose();
  }
}
