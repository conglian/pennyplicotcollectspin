import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../PCMainVC/PCCashWithdrawalContent.dart';
import '../PCDialog/PCCash/PCDiamondPigUpgradeDialog.dart';
import '../PCDialog/PCCash/PCGoldPigUpgradeDialog.dart';
import '../PCDialog/PCWithdrawFlow/PCWithdrawalDialogs.dart';
import '../PCDialog/PCOther/PCDiamondReminderDialog.dart';
import 'PCAnalytics.dart';
import 'PCDialogCoordinator.dart';
import 'PCNewUserGuideController.dart';
import 'PCNumberManager.dart';
import 'PCPigUpgradeController.dart';
import 'PCQuizController.dart';
import 'PCReviewPresentationController.dart';
import 'PCWithdrawalController.dart';
import 'PCWithdrawalNotifications.dart';
import 'pc_LocalProvider.dart';
import 'pc_extension_help.dart';

/// 提现全流程唯一弹窗入口，等待引导、答题反馈、领奖动画和其他弹窗退出。
/// 钻石入场逐步持久化；午夜主动转金猪，各阶段冷启动恢复且同次关闭不循环弹。
class PCWithdrawalFlowHost extends StatefulWidget {
  const PCWithdrawalFlowHost({
    super.key,
    required this.child,
    required this.onGoQuiz,
    required this.onGoWheel,
    this.controller,
    this.canPresent,
    this.notificationsEnabled,
    this.requestNotifications,
  });
  final Widget child;
  final VoidCallback onGoQuiz, onGoWheel;
  final PCWithdrawalController? controller;
  final bool Function()? canPresent;
  final Future<bool> Function()? notificationsEnabled, requestNotifications;
  @override
  State<PCWithdrawalFlowHost> createState() => _PCWithdrawalFlowHostState();
}

class _PCWithdrawalFlowHostState extends State<PCWithdrawalFlowHost>
    with WidgetsBindingObserver {
  late final _flow = widget.controller ?? PCWithdrawalController.instance;
  final _upgrades = PCPigUpgradeController.instance;
  final _dialogs = PCDialogCoordinator.instance;
  Timer? _retry;
  bool _running = false, _scheduled = false, _foreground = true;
  bool _refreshing = false, _refreshAgain = false;
  int? _lastQuestion;
  DateTime? _notBefore;
  Route<dynamic>? _ownedRoute;
  PCWithdrawalPrompt? _showing;
  bool get _canPresent =>
      widget.canPresent?.call() ??
      (PCNewUserGuideController.instance.isLoaded &&
          PCNewUserGuideController.instance.isComplete);

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _flow.addListener(_changed);
    _dialogs.addListener(_schedule);
    _upgrades.addListener(_schedule);
    PCNewUserGuideController.instance.addListener(_refresh);
    PCLocalProvider.instance.addListener(_refresh);
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final question = PCLocalProvider.instance.pc_quiz_num_index;
    if (_lastQuestion != null && question > _lastQuestion!) {
      _notBefore = DateTime.now().add(const Duration(milliseconds: 1100));
    }
    _lastQuestion = question;
    _refreshAgain = true;
    if (_refreshing) return;
    _refreshing = true;
    unawaited(() async {
      try {
        do {
          _refreshAgain = false;
          await _flow.refresh();
          if (!mounted) return;
          await _syncProvider();
        } while (_refreshAgain && mounted);
        _schedule();
      } catch (_) {
        _retry = Timer(const Duration(seconds: 2), _refresh);
      } finally {
        _refreshing = false;
      }
    }());
  }

  Future<void> _syncProvider() async {
    final provider = PCLocalProvider.instance;
    final amount = switch (_flow.pigLevel) {
      0 => _flow.balance,
      1 => _flow.diamonds,
      _ => _flow.gold,
    };
    if (provider.pc_pig_level != _flow.pigLevel ||
        provider.pc_pig_level_index != amount ||
        provider.pc_current_ranking != _flow.queueRank ||
        provider.pc_all_ranking != _flow.queueTotal) {
      await provider.init();
    }
  }

  void _changed() {
    // 午夜只关闭自己仍在显示的钻石入场页，绝不误关队列成功反馈或其他页面。
    final kind = _showing?.kind;
    if (_flow.pigLevel == 2 &&
        kind != null &&
        kind.index <= PCWithdrawalPromptKind.diamondCountdown.index &&
        _ownedRoute?.isCurrent == true) {
      _ownedRoute!.navigator?.pop();
    }
    if (kind == PCWithdrawalPromptKind.diamondCollect &&
        _flow.diamondDeadline != null &&
        _ownedRoute?.isCurrent == true) {
      _ownedRoute!.navigator?.pop();
    }
    if (!_refreshing) unawaited(_syncProvider());
    _schedule();
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_showNext());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<bool> _hasReward() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(
        prefs.getString(PCQuizController.storageKey) ?? '{}',
      );
      return raw is Map && raw['pendingReward'] is Map;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showNext() async {
    _retry?.cancel();
    if (_running ||
        !_foreground ||
        !_canPresent ||
        !_flow.hasPending ||
        _dialogs.isBusy ||
        _upgrades.isBlocked ||
        _upgrades.isPresenting) {
      return;
    }
    final wait = _notBefore?.difference(DateTime.now()) ?? Duration.zero;
    if (wait > Duration.zero) {
      _retry = Timer(wait, _schedule);
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      _retry = Timer(const Duration(milliseconds: 400), _schedule);
      return;
    }
    _running = true;
    var waitingForReward = false;
    try {
      await _flow.refresh();
      waitingForReward = await _hasReward();
      if (waitingForReward || !mounted || !_foreground || !_canPresent) {
        return;
      }
      final prompt = _flow.next;
      if (prompt == null) return;
      _showing = prompt;
      _upgrades.setPresenting(true);
      await _show(prompt);
    } catch (_) {
      _notBefore = DateTime.now().add(const Duration(seconds: 2));
      _retry = Timer(const Duration(seconds: 2), _refresh);
    } finally {
      _ownedRoute = null;
      _showing = null;
      _running = false;
      _upgrades.setPresenting(false);
      if (mounted) {
        if (waitingForReward) {
          _retry = Timer(const Duration(milliseconds: 400), _schedule);
        } else {
          _schedule();
        }
      }
    }
  }

  Future<dynamic> _present(PCWithdrawalPrompt prompt, Widget dialog) async {
    var presented = false;
    final result = await context.tipShow2(
      Builder(
        key: ValueKey('pcWithdrawal:${prompt.id}'),
        builder: (dialogContext) {
          _ownedRoute = ModalRoute.of(dialogContext);
          return dialog;
        },
      ),
      bc: Colors.black.withValues(alpha: .9),
      scaleContent: false,
      canPresent: () =>
          mounted &&
          _foreground &&
          _canPresent &&
          !(_flow.pigLevel == 2 &&
              prompt.kind.index <=
                  PCWithdrawalPromptKind.diamondCountdown.index) &&
          _flow.isPending(prompt),
      onPresented: () async {
        presented = true;
        if (dialog is PCWithdrawalReviewVerificationDialog) {
          await dialog.reviewPresentation?.recordPresentation();
        } else if (dialog is PCDiamondReminderDialog) {
          await dialog.reviewPresentation?.recordPresentation();
        }
        // 只在调度器真正呈现时曝光，排队等待或状态取消均不记展示。
        final event = switch (prompt.kind) {
          PCWithdrawalPromptKind.diamondUpgrade => 'diamond_pig_getpop',
          PCWithdrawalPromptKind.reviewPending => 'ad_review_pop',
          PCWithdrawalPromptKind.reviewVerification =>
            'diamond_review_process_pop',
          PCWithdrawalPromptKind.priorityGift => 'priority_user_pop',
          PCWithdrawalPromptKind.diamondCountdown => 'release_remind_pop',
          PCWithdrawalPromptKind.goldUpgrade => 'gold_pig_getpop',
          PCWithdrawalPromptKind.queue => 'cash_queue_pop',
          PCWithdrawalPromptKind.lastStep => 'one_last_step_pop',
          PCWithdrawalPromptKind.insufficient => 'cash_not_pop',
          // 通道激活和独立中奖页在表中未定义曝光，不借用其他页面的事件。
          PCWithdrawalPromptKind.channelActivated ||
          PCWithdrawalPromptKind.giftReward ||
          PCWithdrawalPromptKind.diamondCollect => null,
        };
        if (event != null) {
          final title = _flow.currentTask.title.trim().toLowerCase();
          PCAnalytics.event(
            event,
            prompt.kind == PCWithdrawalPromptKind.lastStep
                ? {'type': title == 'video' ? 'ad' : title}
                : const {},
          );
        }
        if (prompt.kind == PCWithdrawalPromptKind.diamondUpgrade) {
          // 用户确认Earn Now收集钻石曝光与升级到钻石使用同一弹窗。
          PCAnalytics.event('collect_diamond_pop');
        }
      },
    );
    // 等待中的路由被前后台/午夜状态取消时，不能消费从未出现过的步骤。
    if (!presented) throw StateError('Withdrawal prompt deferred');
    return result;
  }

  Future<void> _show(PCWithdrawalPrompt prompt) async {
    final provider = PCLocalProvider.instance;
    final payment = 'pc_act_${provider.pc_account_seled_index.clamp(0, 3)}';
    switch (prompt.kind) {
      case PCWithdrawalPromptKind.diamondUpgrade:
        await _present(
          prompt,
          PCDiamondPigUpgradeDialog(
            amount: prompt.withdrawalTarget,
            account: provider.pc_account_id,
            paymentAsset: payment,
          ),
        );
        if (!mounted) return;
        await _upgrades.acknowledge(1);
        await _flow.acknowledge(prompt);
      case PCWithdrawalPromptKind.reviewPending:
        await _present(
          prompt,
          PCWithdrawalReviewPendingDialog(
            withdrawalTarget: prompt.withdrawalTarget,
          ),
        );
        if (mounted) await _flow.acknowledge(prompt);
      case PCWithdrawalPromptKind.reviewVerification:
        final reviewPresentation = PCReviewPresentationController();
        try {
          await _present(
            prompt,
            PCWithdrawalReviewVerificationDialog(
              collected: _flow.diamonds,
              reviewProgress: prompt.reviewProgress,
              reviewPresentation: reviewPresentation,
            ),
          );
        } finally {
          reviewPresentation.dispose();
        }
        if (mounted) await _flow.acknowledge(prompt);
      case PCWithdrawalPromptKind.channelActivated:
        await _present(
          prompt,
          PCWithdrawalChannelActivatedDialog(
            withdrawalTarget: prompt.withdrawalTarget,
          ),
        );
        if (mounted) await _flow.acknowledge(prompt);
      case PCWithdrawalPromptKind.priorityGift:
        final result = await _present(
          prompt,
          const PCWithdrawalPriorityGiftDialog(),
        );
        if (!mounted) return;
        if (result == true) {
          await _flow.acknowledge(prompt);
        } else {
          await _flow.dismiss(prompt);
        }
      case PCWithdrawalPromptKind.giftReward:
        await _present(
          prompt,
          PCWithdrawalGiftRewardDialog(
            diamondAmount: _flow.diamondGiftAmount,
            collected: _flow.diamonds,
            onClaim: () async {
              final claimed = await _flow.claimDiamondGift();
              if (claimed) await provider.init();
              return claimed;
            },
          ),
        );
        if (mounted && _flow.isPending(prompt)) await _flow.dismiss(prompt);
      case PCWithdrawalPromptKind.diamondCountdown:
        final enabled =
            await (widget.notificationsEnabled ??
                PCWithdrawalNotifications.isEnabled)();
        if (!mounted || !_flow.isPending(prompt)) return;
        final deadline = _flow.diamondDeadline;
        if (deadline == null) return;
        final action = await _present(
          prompt,
          PCWithdrawalDiamondCountdownDialog(
            withdrawalTarget: prompt.withdrawalTarget,
            deadline: deadline,
            notificationsEnabled: enabled,
          ),
        );
        if (!mounted) return;
        if (action == PCWithdrawalCountdownAction.remindMe) {
          await (widget.requestNotifications ??
              PCWithdrawalNotifications.request)();
        }
        await _flow.acknowledge(prompt);
      case PCWithdrawalPromptKind.diamondCollect:
        final reviewPresentation = PCReviewPresentationController();
        dynamic collect;
        try {
          collect = await _present(
            prompt,
            PCDiamondReminderDialog(
              remaining: (PCNumberHelpers.diamondTarget - _flow.diamonds).clamp(
                0,
                20,
              ),
              reviewPresentation: reviewPresentation,
            ),
          );
        } finally {
          reviewPresentation.dispose();
        }
        if (!mounted) return;
        await _flow.dismiss(prompt);
        if (collect == true) widget.onGoQuiz();
      case PCWithdrawalPromptKind.goldUpgrade:
        final prefs = await SharedPreferences.getInstance();
        if (!mounted || !_flow.isPending(prompt)) return;
        final proceed = await _present(
          prompt,
          PCGoldPigUpgradeDialog(
            amount: prompt.withdrawalTarget,
            account: provider.pc_account_id,
            paymentAsset: payment,
            gold: _flow.gold,
            date:
                DateTime.tryParse(
                  prefs.getString('pc_pig_upgrade_date_2') ?? '',
                ) ??
                DateTime.now(),
          ),
        );
        if (!mounted) return;
        await _upgrades.acknowledge(2);
        await _flow.acknowledge(prompt);
        if (mounted && proceed == true) widget.onGoQuiz();
      case PCWithdrawalPromptKind.queue:
        await _present(
          prompt,
          PCWithdrawalApprovalDialog(
            withdrawalTarget: prompt.withdrawalTarget,
            rank: _flow.queueRank,
            queueCount: _flow.queueTotal,
            entries: _queueEntries(),
            account: provider.pc_account_id,
            currentRank: () => _flow.queueRank,
            currentQueueCount: () => _flow.queueTotal,
            onSkipWaitOutcome: () async {
              final result = await _flow.advanceQueueWithAdOutcome();
              if (result.isApplied) await provider.init();
              return result;
            },
          ),
        );
        if (mounted) await _flow.dismiss(prompt);
      case PCWithdrawalPromptKind.lastStep:
        final task = _flow.currentTask.title;
        final taskTarget = _flow.taskTarget;
        final result = await _present(
          prompt,
          PCWithdrawalLastStepDialog(
            withdrawalTarget: prompt.withdrawalTarget,
            taskTitle: task,
            progress: _flow.taskProgress,
            target: taskTarget,
            currentProgress: () =>
                _flow.isPending(prompt) ? _flow.taskProgress : taskTarget,
            onActionOutcome: () async {
              if (task != 'video') return PCWithdrawalAdResult.applied;
              final result = await _flow.recordVideoWithAdOutcome();
              if (result.isApplied) await provider.init();
              return result;
            },
          ),
        );
        if (!mounted) return;
        await _flow.dismiss(prompt);
        if (result == true) {
          if (task == 'quiz') widget.onGoQuiz();
          if (task == 'spin') widget.onGoWheel();
        }
      case PCWithdrawalPromptKind.insufficient:
        final proceed = await _present(
          prompt,
          PCWithdrawalInsufficientDialog(
            balance: _flow.balance,
            withdrawalTarget: prompt.withdrawalTarget,
          ),
        );
        if (!mounted) return;
        await _flow.dismiss(prompt);
        if (mounted && proceed == true) widget.onGoQuiz();
    }
  }

  List<PCWithdrawalQueueEntry> _queueEntries() =>
      pcCashQueueEntries(
            seed: _flow.queueSeed,
            target: _flow.target,
            count: _flow.queueTotal,
          )
          .map(
            (entry) => PCWithdrawalQueueEntry(
              userId: entry.userId,
              account: entry.account,
              amount: entry.amount,
            ),
          )
          .toList();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _refresh();
    } else {
      _retry?.cancel();
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _flow.removeListener(_changed);
    _dialogs.removeListener(_schedule);
    _upgrades.removeListener(_schedule);
    PCNewUserGuideController.instance.removeListener(_refresh);
    PCLocalProvider.instance.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    if (_showing != null) _upgrades.setPresenting(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
