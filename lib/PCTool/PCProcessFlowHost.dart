import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../PCMainVC/PCWithdrawPage.dart' show PCWithdrawDetails;
import '../PCDialog/PCOther/PCConfirmAccountDialog.dart';
import '../PCDialog/PCOther/PCProcessAccountDialog.dart';
import '../PCDialog/PCOther/PCProcessAccountConfirmedDialog.dart';
import '../PCDialog/PCOther/PCQuizRankingDialog.dart';
import '../PCDialog/PCOther/PCReviewProgressDialog.dart';
import '../PCDialog/PCOther/PCDiamondReminderDialog.dart';
import '../PCDialog/PCOther/PCOfficialCollectNoticeDialog.dart';
import 'PCAnalytics.dart';
import 'PCReviewPresentationController.dart';
import 'PCDialogCoordinator.dart';
import 'PCNewUserGuideController.dart';
import 'PCNumberManager.dart';
import 'PCPigUpgradeController.dart';
import 'PCProcessFlowController.dart';
import 'PCWithdrawalController.dart';
import 'pc_LocalProvider.dart';
import 'pc_extension_help.dart';

/// 3.7 流程调度：奖励及到账动画优先，随后审核、收集提醒和排行逐个展示。
/// 关闭任一提示不改奖励；完整账号先保存到本机，确认横幅退场后继续答题。
class PCProcessFlowHost extends StatefulWidget {
  const PCProcessFlowHost({
    super.key,
    required this.child,
    required this.onGoQuiz,
    this.controller,
    this.canPresent,
  });
  final Widget child;
  final VoidCallback onGoQuiz;
  final PCProcessFlowController? controller;
  final bool Function()? canPresent;
  @override
  State<PCProcessFlowHost> createState() => _PCProcessFlowHostState();
}

class _PCProcessFlowHostState extends State<PCProcessFlowHost>
    with WidgetsBindingObserver {
  late final _controller =
      widget.controller ?? PCProcessFlowController.instance;
  final _dialogs = PCDialogCoordinator.instance;
  final _upgrades = PCPigUpgradeController.instance;
  Timer? _retry;
  VoidCallback? _releaseUpgrade;
  bool _running = false, _scheduled = false, _foreground = true;
  bool _syncingAccount = false;
  int? _lastQuestion;
  DateTime? _notBefore;
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
    _controller.addListener(_schedule);
    _dialogs.addListener(_schedule);
    PCWithdrawalController.instance.addListener(_refresh);
    _upgrades.addListener(_schedule);
    PCLocalProvider.instance.addListener(_refresh);
    PCNewUserGuideController.instance.addListener(_refresh);
    _refresh();
  }

  void _refresh() {
    final question = PCLocalProvider.instance.pc_quiz_num_index;
    if (_lastQuestion != null && question > _lastQuestion!) {
      _notBefore = DateTime.now().add(const Duration(milliseconds: 1100));
    }
    _lastQuestion = question;
    unawaited(
      _controller
          .refresh(guideComplete: _canPresent)
          .then((_) async {
            if (!mounted) return;
            final account = _controller.savedAccount;
            final provider = PCLocalProvider.instance;
            // 引导旧档迁移只写一次公共账号；差异消失后不再init，避免通知循环。
            if (!_syncingAccount &&
                account.isNotEmpty &&
                provider.pc_account_id != account) {
              _syncingAccount = true;
              try {
                await provider.init();
              } finally {
                _syncingAccount = false;
              }
            }
            if (mounted) _schedule();
          })
          .catchError((Object _) {
            // 存储临时不可用时保留当前页面，下一次本地状态变化继续重试。
          }),
    );
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

  Future<void> _showNext() async {
    _retry?.cancel();
    if (_running ||
        !_foreground ||
        !_canPresent ||
        _controller.next == null ||
        (_controller.isRefreshing &&
            _controller.next?.kind == PCProcessPromptKind.confirmAccount) ||
        _dialogs.isBusy ||
        PCWithdrawalController.instance.hasPending ||
        _controller.hasPendingQuizReward ||
        _upgrades.isBlocked ||
        _upgrades.isPresenting ||
        _upgrades.pendingLevel != null) {
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
    final prompt = _controller.next!;
    _releaseUpgrade = _upgrades.holdPresentation();
    try {
      if (!mounted) return;
      switch (prompt.kind) {
        case PCProcessPromptKind.confirmAccount:
          await _confirmAccount(prompt);
        case PCProcessPromptKind.reviewProgress:
          final reviewPresentation = PCReviewPresentationController();
          try {
            await _present(
              PCReviewProgressDialog(
                collected: prompt.collected,
                fromProgress: prompt.fromProgress,
                toProgress: prompt.toProgress,
                reviewPresentation: reviewPresentation,
              ),
              bc: Colors.black.withValues(alpha: .9),
              prompt: prompt,
            );
          } finally {
            reviewPresentation.dispose();
          }
        case PCProcessPromptKind.diamondReminder:
          final reviewPresentation = PCReviewPresentationController();
          dynamic proceed;
          try {
            proceed = await _present(
              PCDiamondReminderDialog(
                remaining: prompt.remaining,
                reviewPresentation: reviewPresentation,
              ),
              bc: Colors.black.withValues(alpha: .9),
              prompt: prompt,
            );
          } finally {
            reviewPresentation.dispose();
          }
          if (mounted && proceed == true) widget.onGoQuiz();
        case PCProcessPromptKind.officialNotice:
          await _present(
            PCOfficialCollectNoticeDialog(remaining: prompt.remaining),
            bc: Colors.black.withValues(alpha: .9),
            prompt: prompt,
          );
        case PCProcessPromptKind.quizRanking:
          final proceed = await _present(
            PCQuizRankingDialog(
              answerCount: prompt.answerCount,
              account: PCLocalProvider.instance.pc_account_id,
              seed: prompt.seed,
            ),
            bc: Colors.black.withValues(alpha: .9),
            prompt: prompt,
          );
          if (mounted && proceed == true) widget.onGoQuiz();
      }
    } catch (_) {
      _notBefore = DateTime.now().add(const Duration(seconds: 2));
      _retry = Timer(const Duration(seconds: 2), _schedule);
    } finally {
      _running = false;
      _releaseUpgrade?.call();
      _releaseUpgrade = null;
      _controller.finish();
      if (mounted) _schedule();
    }
  }

  Future<dynamic> _present(
    Widget content, {
    PCProcessPrompt? prompt,
    Color? bc,
  }) => context.tipShow2(
    content,
    bc: bc ?? Colors.black.withValues(alpha: .9),
    scaleContent: false,
    canPresent: () =>
        mounted &&
        _foreground &&
        _canPresent &&
        (prompt?.kind != PCProcessPromptKind.confirmAccount ||
            !_controller.isRefreshing) &&
        (prompt == null || _controller.isPending(prompt)),
    onPresented: () async {
      if (content is PCReviewProgressDialog) {
        await content.reviewPresentation?.recordPresentation();
      } else if (content is PCDiamondReminderDialog) {
        await content.reviewPresentation?.recordPresentation();
      }
      if (prompt != null) await _controller.begin(prompt);
      final event = switch (content) {
        PCConfirmAccountDialog() => 'process_confirm_account_pop',
        PCReviewProgressDialog() => 'diamond_review_process_pop',
        PCDiamondReminderDialog() => 'diamond_near_pop',
        PCOfficialCollectNoticeDialog() => 'diamond_remind_pop',
        PCQuizRankingDialog() => 'process_rank_pop',
        _ => null,
      };
      if (event != null) PCAnalytics.event(event);
    },
  );

  Future<void> _confirmAccount(PCProcessPrompt prompt) async {
    final target = PCNumberHelpers().pc_firstTarget;
    final proceed = prompt.accountSaved
        ? true
        : await _present(
            PCConfirmAccountDialog(withdrawalTarget: target),
            prompt: prompt,
          );
    if (!mounted || proceed != true) return;
    final provider = PCLocalProvider.instance;
    final PCWithdrawDetails? details = await _present(
      PCProcessAccountDialog(
        initialAccount: provider.pc_account_id,
        initialPaymentIndex: provider.pc_account_seled_index,
        hasSavedAccount: provider.pc_account_id.trim().isNotEmpty,
      ),
      prompt: prompt.accountSaved ? prompt : null,
    );
    if (!mounted || details == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(
          provider.pc_account_seled_indexName,
          details.method.storageIndex,
        ) ||
        !await prefs.setString(
          provider.pc_account_idName,
          details.account.trim(),
        )) {
      throw StateError('Unable to save payment information');
    }
    await provider.init();
    await _controller.accountConfirmed();
    if (!mounted) return;
    await _present(PCProcessAccountConfirmedDialog(withdrawalTarget: target));
    if (mounted) widget.onGoQuiz();
  }

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
    _controller.removeListener(_schedule);
    _dialogs.removeListener(_schedule);
    PCWithdrawalController.instance.removeListener(_refresh);
    _upgrades.removeListener(_schedule);
    PCLocalProvider.instance.removeListener(_refresh);
    PCNewUserGuideController.instance.removeListener(_refresh);
    _releaseUpgrade?.call();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
