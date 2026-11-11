import 'dart:async';
import 'dart:math' as math;

import '../PCTool/PCAnalytics.dart';
import '../PCTool/PCAdaptiveLayout.dart';
import '../PCTool/PCAudioUtils.dart';

import 'package:flutter/material.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:provider/provider.dart';
import '../PCDialog/PCAward/PCAwardDialog.dart';
import '../PCDialog/PCOther/PCDialogTool.dart';
import '../PCTool/PCNewUserGuideController.dart';
import '../PCTool/PCQuizController.dart';
import '../PCTool/PCQuizBannerController.dart';
import '../PCTool/PCQuizConfig.dart';
import '../PCTool/PCQuizRewardAnimation.dart';
import '../PCTool/PCPigUpgradeController.dart';
import '../PCTool/PCDialogCoordinator.dart';
import '../PCTool/PCProcessFlowController.dart';
import '../PCTool/PCWithdrawalController.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/PCBalanceHeader.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_shou_icon.dart';
import '../PCBasic/PCTbaBar.dart';
import '../PCTool/PCQuizBank.dart';
import 'PCQuizContentPanel.dart';
import 'PCQuizBanner.dart';

final GlobalKey<PCQuizState> homeKey = GlobalKey<PCQuizState>();

class PCQuiz extends StatefulWidget {
  const PCQuiz({super.key, this.controller, this.bank, this.active});
  final PCQuizController? controller;
  final PCQuizBank? bank;
  final bool? active;

  @override
  State<PCQuiz> createState() => PCQuizState();
}

class PCQuizState extends State<PCQuiz>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  PCQuizBank? _quizBank;
  late final PCQuizController _flow;
  final _bannerFlow = PCQuizBannerController();
  Timer? _correctHintTimer;
  bool _showCorrectHint = false;
  bool _foreground = true;
  bool _handling = false;
  bool _dialogOpen = false;
  bool _wasReadyActive = false;
  bool _analyticsPageActive = false;
  int _rewardVisit = 0;
  bool? _selected;
  bool? _correct;
  PCQuizQuestion? _shownQuestion;
  int _shownIndex = 0;
  PCQuizReward? _effect;
  VoidCallback? _releaseUpgrade;
  VoidCallback? _releaseEffectPresentation;
  VoidCallback? _releaseBannerPresentation;
  int _ownPresentationHolds = 0;
  bool _bannerPresenting = false;
  OverlayEntry? _bannerOverlay;
  bool _bannerOverlayScheduled = false;
  bool _bannerRouteCurrent = true;
  String? _toast;
  final GlobalKey _balanceTarget = GlobalKey(debugLabel: 'pcQuizBalance');
  PCDialogCoordinator get _dialogs => PCDialogCoordinator.instance;
  PCProcessFlowController get _processFlow => PCProcessFlowController.instance;
  bool get _bannerSuppressed =>
      !_active ||
      !_bannerRouteCurrent ||
      _dialogs.isPresenting ||
      _dialogOpen ||
      _effect != null;
  bool get _otherPresentationPending =>
      !_bannerRouteCurrent ||
      _dialogs.isPresenting ||
      _dialogs.pendingCount > 0 ||
      _dialogs.holdCount > _ownPresentationHolds ||
      _processFlow.hasPending ||
      PCWithdrawalController.instance.hasPending ||
      PCPigUpgradeController.instance.pendingLevel != null;

  VoidCallback _holdPresentation() {
    // hold 会同步通知监听器；先记录自己持有，避免被当成其他浮层而自行退出。
    _ownPresentationHolds++;
    final release = _dialogs.holdPresentation();
    var released = false;
    return () {
      if (released) return;
      released = true;
      _ownPresentationHolds--;
      release();
    };
  }

  bool get _pageActive =>
      _foreground &&
      (widget.active ??
          (PigsTabController.currentIndex.value == 1 &&
              PCNewUserGuideController.instance.isComplete));

  bool get _active =>
      _pageActive && !PCPigUpgradeController.instance.isPresenting;

  @override
  void initState() {
    super.initState();
    _flow =
        widget.controller ??
        PCQuizController(onSync: PCLocalProvider.instance.init);
    _flow.addListener(_flowChanged);
    WidgetsBinding.instance.addObserver(this);
    PigsTabController.currentIndex.addListener(_activityChanged);
    PCNewUserGuideController.instance.addListener(_activityChanged);
    PCPigUpgradeController.instance.addListener(_activityChanged);
    _dialogs.addListener(_presentationChanged);
    _processFlow.addListener(_presentationChanged);
    PCWithdrawalController.instance.addListener(_presentationChanged);
    _bannerFlow.addListener(_bannerRequested);
    _load();
  }

  @override
  void didUpdateWidget(covariant PCQuiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _activityChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 根Overlay不能越过收款等新页面；只暂停横幅，不改变领奖恢复的_active。
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (_bannerRouteCurrent == current) return;
    _bannerRouteCurrent = current;
    if (!current && !_dialogOpen && _effect == null) {
      _bannerFlow.cancelPending();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentationChanged();
    });
  }

  Future<void> _load() async {
    try {
      // 页面也可由通知/调试入口直接进入，不能依赖启动页提前加载引导状态。
      if (widget.active == null) await PCNewUserGuideController.instance.load();
      final bank = widget.bank ?? await PCQuizBank.load();
      await _flow.load();
      // 清掉旧版本遗留待奖；答题进度保留，首页/Tab入口不再补弹上次奖励。
      final previous = _flow.pendingReward;
      if (previous != null) {
        await _flow.discardPendingReward(expectedRewardId: previous.id);
      }
      await _bannerFlow.load();
      if (!mounted) return;
      setState(() => _quizBank = bank);
      _resetQuestion();
      _activityChanged();
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(
          context,
          'Questions could not load. Please try again.',
        );
      }
    }
  }

  void _flowChanged() {
    if (mounted) setState(() {});
    _syncBannerActivity();
  }

  void _syncBannerActivity() {
    _bannerFlow.setActive(
      mounted &&
          _active &&
          !_dialogs.isBusy &&
          !_otherPresentationPending &&
          _flow.isLoaded &&
          _quizBank != null &&
          !_flow.isComplete &&
          !_flow.isBusy &&
          !_handling &&
          !_dialogOpen &&
          !_bannerPresenting &&
          _flow.pendingReward == null &&
          _effect == null,
    );
  }

  void _activityChanged() {
    if (!mounted) return;
    if (!_pageActive) _bannerFlow.cancelPending();
    // IndexedStack只统计首次进入/切回Quiz；广告或权限窗口的前后台回切不重复曝光。
    final analyticsActive =
        (widget.active ??
            (PigsTabController.currentIndex.value == 1 &&
                PCNewUserGuideController.instance.isComplete)) &&
        _flow.isLoaded &&
        _quizBank != null;
    if (!analyticsActive) {
      _analyticsPageActive = false;
    } else if (_foreground && !_analyticsPageActive) {
      _analyticsPageActive = true;
      PCAnalytics.event('quiz_page');
    }
    final readyActive = _active && _flow.isLoaded && _quizBank != null;
    if (!readyActive && _wasReadyActive) _rewardVisit++;
    _wasReadyActive = readyActive;
    _syncBannerActivity();
    // IndexedStack 复用同一个页面，切回/回前台不会自动重建按钮。
    // 页面恢复时立即同步 enabled，不再依赖计时器或用户下一次操作。
    setState(() {
      if (!_active) {
        _toast = null;
        _showCorrectHint = false;
      }
    });
    _refreshBannerOverlay();
    if (!_active) {
      _correctHintTimer?.cancel();
      _correctHintTimer = null;
      return;
    }
    _scheduleCorrectHint();
  }

  void _presentationChanged() {
    if (!mounted) return;
    _syncBannerActivity();
    setState(() {
      if (_otherPresentationPending) {
        // 等横幅滑出后再释放展示权，下一弹窗不会压住仍在退场的横幅。
        _toast = null;
        _showCorrectHint = false;
      } else if (_bannerPresenting) {
        _showCorrectHint = false;
      }
    });
    _refreshBannerOverlay();
    if (_otherPresentationPending || _bannerPresenting) {
      _correctHintTimer?.cancel();
      _correctHintTimer = null;
    } else {
      _scheduleCorrectHint();
    }
  }

  void _bannerRequested() {
    final message = _bannerFlow.pendingMessage;
    if (message != null && _showBanner(message)) {
      _bannerFlow.beginPresentation();
    }
  }

  bool _showBanner(String message) {
    if (!mounted ||
        !_active ||
        _bannerPresenting ||
        _otherPresentationPending) {
      return false;
    }
    // 先占用横幅状态，再获取会同步通知的全局hold，防止继续显示答题手势。
    _bannerPresenting = true;
    _releaseBannerPresentation ??= _holdPresentation();
    setState(() {
      _toast = message;
      _showCorrectHint = false;
    });
    _refreshBannerOverlay();
    return true;
  }

  void _refreshBannerOverlay() {
    final entry = _bannerOverlay;
    if (entry != null) {
      entry.markNeedsBuild();
      return;
    }
    final message = _toast;
    if (message == null || _bannerOverlayScheduled || !mounted) return;
    _bannerOverlayScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bannerOverlayScheduled = false;
      if (!mounted) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (_toast == null || _bannerSuppressed || overlay == null) {
        // 尚未创建画面就切页/后台时仍须结束这一轮，避免遗留展示权。
        _bannerDismissed(message);
        return;
      }
      final entry = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: PCQuizBanner(
            message: _toast,
            initialMessage: message,
            withdrawalTarget: _flow.config.withdrawalTarget,
            suppressed: _bannerSuppressed,
            onDismissed: _bannerDismissed,
          ),
        ),
      );
      _bannerOverlay = entry;
      overlay.insert(entry);
      PCAnalytics.event('quiz_toast');
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _removeBannerOverlay() {
    final entry = _bannerOverlay;
    _bannerOverlay = null;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  void _bannerDismissed(String message) {
    if (!mounted) return;
    if (_toast != null && _toast != message) return;
    // 先移除整屏遮罩，再交还展示权给排队弹窗和恢复页面交互。
    _removeBannerOverlay();
    if (mounted) {
      setState(() {
        _toast = null;
        _bannerPresenting = false;
      });
    }
    _releaseBannerPresentation?.call();
    _releaseBannerPresentation = null;
    _bannerFlow.finishPresentation();
    _syncBannerActivity();
    if (mounted && _active && _flow.isComplete) {
      PigsTabController.switchTo(3);
    }
  }

  // 只控制手势的出现时间，不参与按钮 enabled 或答题锁定。
  void _scheduleCorrectHint() {
    if (_showCorrectHint ||
        (_correctHintTimer?.isActive ?? false) ||
        !_active ||
        _bannerPresenting ||
        _otherPresentationPending ||
        _shownQuestion == null ||
        _selected != null ||
        _handling ||
        _dialogOpen ||
        _flow.pendingReward != null ||
        _flow.isComplete) {
      return;
    }
    final questionIndex = _shownIndex;
    _correctHintTimer = Timer(const Duration(seconds: 2), () {
      _correctHintTimer = null;
      if (!mounted ||
          !_active ||
          _bannerPresenting ||
          _otherPresentationPending ||
          _shownIndex != questionIndex ||
          _selected != null ||
          _handling ||
          _dialogOpen ||
          _flow.pendingReward != null) {
        return;
      }
      setState(() => _showCorrectHint = true);
    });
  }

  void _resetQuestion() {
    final bank = _quizBank;
    if (bank == null) return;
    final index = _flow.pendingReward?.questionIndex ?? _flow.questionIndex;
    _correctHintTimer?.cancel();
    _correctHintTimer = null;
    setState(() {
      _showCorrectHint = false;
      _shownIndex = index;
      _shownQuestion = bank.questionAt(index);
      final pending = _flow.pendingReward;
      _selected = pending == null
          ? null
          : _shownQuestion!.answer.toLowerCase() == 'a';
      _correct = pending == null ? null : true;
    });
    _scheduleCorrectHint();
    _syncBannerActivity();
  }

  Future<void> _answer(bool first, int questionIndex) async {
    final question = _shownQuestion;
    if (!_active ||
        _bannerPresenting ||
        _otherPresentationPending ||
        _handling ||
        _dialogOpen ||
        _flow.isBusy ||
        _selected != null ||
        _flow.pendingReward != null ||
        questionIndex != _shownIndex ||
        question == null) {
      return;
    }
    if (_flow.isComplete) {
      PigsTabController.switchTo(3);
      return;
    }
    _handling = true;
    // 每题第一次有效选项点击即播放，不依赖答案是否正确。
    unawaited(PCAudioUtils().playQuizOptionAudio());
    _correctHintTimer?.cancel();
    _correctHintTimer = null;
    final submittedIndex = questionIndex;
    final submittedVisit = _rewardVisit;
    // 从第一次点击开始显示对错1秒，两个选项同步锁定；保存耗时包含在这一秒内。
    final feedbackDone = Future<void>.delayed(const Duration(seconds: 1));
    final correct = first == (question.answer.toLowerCase() == 'a');
    setState(() {
      _toast = null;
      _selected = first;
      _correct = correct;
      _showCorrectHint = false;
    });
    _syncBannerActivity();
    try {
      final answeredReward = await _flow.answer(
        correct: correct,
        expectedQuestionIndex: submittedIndex,
      );
      if (_flow.questionIndex == submittedIndex + 1) {
        PCAnalytics.event(correct ? 'answer_true_c' : 'answer_wrong_c');
        _bannerFlow.recordAnswer(
          questionIndex: submittedIndex,
          correct: correct,
        );
        if (!_pageActive || !_bannerRouteCurrent) _bannerFlow.cancelPending();
      }
      await feedbackDone;
      if (!mounted) return;
      _handling = false;
      if (correct) {
        if (answeredReward == null ||
            _flow.pendingReward?.id != answeredReward.id) {
          // 陈旧题号被控制器拒绝时恢复实际题目，不为旧题重新生成奖励。
          _resetQuestion();
        } else if (_active && submittedVisit == _rewardVisit) {
          await _showReward();
        } else {
          await _flow.discardPendingReward(expectedRewardId: answeredReward.id);
          if (mounted) _resetQuestion();
        }
      } else {
        _resetQuestion();
      }
    } catch (_) {
      if (!mounted) return;
      _handling = false;
      _resetQuestion();
      PCDialogTool.toast(
        context,
        'Could not save your answer. Please try again.',
      );
    }
  }

  Future<void> _showReward() async {
    final reward = _flow.pendingReward;
    if (reward == null || _dialogOpen || _handling || !mounted) return;
    _dialogOpen = true;
    setState(() => _toast = null);
    _refreshBannerOverlay();
    _syncBannerActivity();
    _correctHintTimer?.cancel();
    _correctHintTimer = null;
    _releaseUpgrade ??= PCPigUpgradeController.instance.holdPresentation();
    final provider = PCLocalProvider.instance;
    PCQuizReward? claimed;
    try {
      await context.tipShow2(
        PCAwardDialog(
          award: reward.amount,
          reward: reward,
          balance: provider.pc_dollar_number,
          withdrawalTarget: _flow.config.withdrawalTarget,
          paymentAsset: 'pc_act_${provider.pc_account_seled_index.clamp(0, 3)}',
          remainingCollectible: reward.type == PCQuizRewardType.diamond
              ? math.max(0, PCQuizConfig.diamondTarget - _flow.diamonds)
              : math.max(0, PCQuizConfig.goldTarget - _flow.gold),
          analyticsSource: 'quiz',
          claimAdPlacement: 'nkmdl_quizgetc_rv',
          closeAdPlacement: 'nkmdl_quizgetinfor_int',
          onAbandon: () async {
            await _flow.discardPendingReward(expectedRewardId: reward.id);
          },
          onClaim: () async {
            try {
              claimed = await _flow.claim(expectedRewardId: reward.id);
              if (claimed != null && mounted) {
                // 先保留到账动画的展示权，再由按钮关闭领奖弹窗。
                _releaseEffectPresentation ??= _holdPresentation();
              }
              return claimed != null;
            } catch (_) {
              if (mounted) {
                PCDialogTool.toast(
                  context,
                  'Could not claim reward. Please try again.',
                );
              }
              return false;
            }
          },
        ),
        scaleContent: false,
      );
    } finally {
      // 捕获该次ID兜底清理，外部关闭和迟到广告回调不能复活或误领新题奖励。
      if (claimed == null) {
        await _flow.discardPendingReward(expectedRewardId: reward.id);
      }
      _dialogOpen = false;
      if (mounted) _refreshBannerOverlay();
    }
    if (!mounted) return;
    if (claimed != null) {
      _handling = true;
      setState(() => _effect = claimed);
    } else {
      _handling = false;
      _releaseUpgrade?.call();
      _releaseUpgrade = null;
      _releaseEffectPresentation?.call();
      _releaseEffectPresentation = null;
      _resetQuestion();
      _bannerFlow.rewardFinished();
      _syncBannerActivity();
    }
  }

  void _rewardFinished() {
    if (!mounted) return;
    setState(() => _effect = null);
    _handling = false;
    _resetQuestion();
    _releaseUpgrade?.call();
    _releaseUpgrade = null;
    _bannerFlow.rewardFinished();
    _releaseEffectPresentation?.call();
    _releaseEffectPresentation = null;
    _syncBannerActivity();
    if (_active && _flow.isComplete) PigsTabController.switchTo(3);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _activityChanged();
    if (_foreground && _flow.isLoaded) unawaited(_flow.refreshBalance());
  }

  @override
  void dispose() {
    _removeBannerOverlay();
    _correctHintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PigsTabController.currentIndex.removeListener(_activityChanged);
    PCNewUserGuideController.instance.removeListener(_activityChanged);
    PCPigUpgradeController.instance.removeListener(_activityChanged);
    _dialogs.removeListener(_presentationChanged);
    _processFlow.removeListener(_presentationChanged);
    PCWithdrawalController.instance.removeListener(_presentationChanged);
    _bannerFlow.removeListener(_bannerRequested);
    _bannerFlow.dispose();
    _releaseUpgrade?.call();
    _releaseEffectPresentation?.call();
    _releaseBannerPresentation?.call();
    _flow.removeListener(_flowChanged);
    final abandoned = _flow.pendingReward;
    if (abandoned != null) {
      unawaited(_flow.discardPendingReward(expectedRewardId: abandoned.id));
    }
    if (widget.controller == null) _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final widthScale = PCAdaptiveLayout.widthScale(
                constraints.maxWidth,
                designWidth: 375,
              );
              final headerHeight = provider.pc_pig_level == 0 ? 108.0 : 112.0;
              // 窄小屏把整组等比收紧；大屏按宽度放大文字与题板，空间不足可滚动。
              // 不再把题板横向拉宽、纵向压扁后单独缩小字号。
              final scale = widthScale <= 1
                  ? math.min(
                      widthScale,
                      math.max(
                        .1,
                        constraints.maxHeight / (588 + headerHeight),
                      ),
                    )
                  : widthScale;
              final gap = 12 * scale;
              return Stack(
                fit: StackFit.expand,
                children: [
                  PCImg(
                    name: 'pc_quiz_bg',
                    width: 0.width(context),
                    height: 0.height(context),
                  ),
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 64 * scale),
                        SizedBox(
                          width: 328 * scale,
                          height: headerHeight * scale,
                          child: PCBalanceHeader(
                            provider: provider,
                            rewardTarget: _balanceTarget,
                          ),
                        ),
                        SizedBox(height: gap),
                        SizedBox(
                          width: 328 * scale,
                          height: 48 * scale,
                          child: _QuizProgressTimeline(
                            answeredCount: _flow.correctCount,
                            openedMilestones: _flow.openedMilestones,
                            showHints:
                                !_bannerPresenting &&
                                !_otherPresentationPending &&
                                _active,
                            onMilestoneTap: (index) => _openWheel(index),
                          ),
                        ),
                        SizedBox(height: gap),
                        SizedBox(
                          key: pcQuizContentTargetKey,
                          width: PCQuizContentPanel.designWidth * scale,
                          height: PCQuizContentPanel.designHeight * scale,
                          child: _quizContenWidget(provider),
                        ),
                        SizedBox(height: gap),
                      ],
                    ),
                  ),
                  if (_effect != null)
                    Positioned.fill(
                      child: AbsorbPointer(
                        child: PCQuizRewardAnimation(
                          reward: _effect!,
                          balance: provider.pc_dollar_number,
                          targetKey: _balanceTarget,
                          onFinished: _rewardFinished,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openWheel(int index) async {
    if (!_active ||
        _bannerPresenting ||
        _otherPresentationPending ||
        _handling ||
        _dialogOpen ||
        _flow.isBusy) {
      return;
    }
    PCAnalytics.event('quiz_wheel_c');
    setState(() => _handling = true);
    try {
      if (await _flow.openMilestone(index) && mounted) {
        PigsTabController.switchTo(2);
      }
    } finally {
      _handling = false;
      if (mounted) _activityChanged();
    }
  }

  Widget _quizContenWidget(PCLocalProvider provider) {
    final bank = _quizBank, question = _shownQuestion;
    final questionIndex = _shownIndex;
    if (bank == null || question == null) {
      return const PCQuizContentPanel(question: null);
    }
    return PCQuizContentPanel(
      question: question.question,
      optionA: question.a,
      optionB: question.b,
      category: bank.categoryAt(_shownIndex),
      onAnswer: (first) => _answer(first, questionIndex),
      hintAnswer:
          _showCorrectHint &&
              _active &&
              !_bannerPresenting &&
              !_otherPresentationPending &&
              !_handling &&
              !_dialogOpen &&
              !_flow.isBusy &&
              _selected == null &&
              _flow.pendingReward == null
          ? question.answer.toLowerCase() == 'a'
          : null,
      selectedAnswer: _selected,
      answerCorrect: _correct,
      enabled:
          _active &&
          !_bannerPresenting &&
          !_otherPresentationPending &&
          !_handling &&
          !_dialogOpen &&
          !_flow.isBusy &&
          _selected == null &&
          _flow.pendingReward == null,
      onResumeReward:
          !_active ||
              _bannerPresenting ||
              _dialogs.isPresenting ||
              _dialogs.pendingCount > 0 ||
              _dialogs.holdCount > _ownPresentationHolds ||
              _handling ||
              _dialogOpen ||
              _flow.isBusy
          ? null
          : _flow.pendingReward != null
          ? _showReward
          : _flow.isComplete
          ? () => PigsTabController.switchTo(3)
          : null,
      resumeLabel: _flow.isComplete ? 'Go Withdraw' : 'Claim Reward',
      showResumeHint:
          _active && _flow.pendingReward != null && !_dialogOpen && !_handling,
    );
  }
}

class _QuizProgressTimeline extends StatefulWidget {
  const _QuizProgressTimeline({
    required this.answeredCount,
    required this.onMilestoneTap,
    required this.openedMilestones,
    this.showHints = true,
  });

  final int answeredCount;
  final bool showHints;
  final Set<int> openedMilestones;
  final ValueChanged<int> onMilestoneTap;

  @override
  State<_QuizProgressTimeline> createState() => _QuizProgressTimelineState();
}

class _QuizProgressTimelineState extends State<_QuizProgressTimeline> {
  int get _milestoneCount =>
      math.max(100, PCQuizController.opportunitiesAt(widget.answeredCount) + 8);
  static const double _itemWidth = 96;
  static const double _sidePadding = 64;

  late final ScrollController _scrollController;
  Set<int> get _clickedMilestones => widget.openedMilestones;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToProgress(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant _QuizProgressTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answeredCount != widget.answeredCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToProgress();
      });
    }
  }

  void _scrollToProgress({bool animate = true}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final double itemWidth = _itemWidth;
    final double sidePadding = _sidePadding;
    final double viewportWidth = 328;
    final int currentIndex = ((widget.answeredCount - 2) / 3).floor().clamp(
      0,
      _milestoneCount - 1,
    );
    final double target =
        currentIndex * itemWidth -
        ((viewportWidth - itemWidth) / 2 - sidePadding);
    final double offset = target.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double itemWidth = _itemWidth;
    final double sidePadding = _sidePadding;
    final double contentWidth =
        (sidePadding * 2) + (itemWidth * _milestoneCount);
    final int answered = math.max(0, widget.answeredCount);

    return FittedBox(
      child: SizedBox(
        width: 328,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PCImg(name: 'pc_quiz_pro_bg', width: 328, height: 20),
            ClipRect(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: contentWidth,
                  height: 48,
                  child: Stack(
                    children: [
                      _buildLeadingProgress(answered, sidePadding, itemWidth),
                      ...List.generate(
                        _milestoneCount,
                        (index) => _buildMilestone(
                          index,
                          answered,
                          sidePadding,
                          itemWidth,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingProgress(
    int answered,
    double sidePadding,
    double itemWidth,
  ) {
    final double progress = (answered / 2).clamp(0.0, 1.0).toDouble();
    const double progressHeight = 12;
    const double trackInset = 2;
    return Positioned(
      left: trackInset,
      top: (48 - progressHeight) / 2,
      width: sidePadding + (itemWidth / 2) - trackInset,
      height: progressHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: '#27D31D'.color(),
              borderRadius: BorderRadius.circular(progressHeight / 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestone(
    int index,
    int answered,
    double sidePadding,
    double itemWidth,
  ) {
    final int milestone = 2 + (index * 3);
    final bool unlocked = answered >= milestone;
    final bool showGlow =
        widget.showHints && unlocked && !_clickedMilestones.contains(index);
    final double left = sidePadding + (index * itemWidth);
    final double segmentProgress = ((answered - milestone) / 3)
        .clamp(0.0, 1.0)
        .toDouble();

    return Positioned(
      left: left,
      top: 0,
      width: itemWidth,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (index < _milestoneCount - 1)
            Positioned(
              left: itemWidth / 2,
              top: (48 - 12) / 2,
              width: itemWidth,
              height: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: segmentProgress,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: '#27D31D'.color(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ParticleButton(
              key: ValueKey('pcQuizMilestone$index'),
              size: 48,
              onTap: () {
                if (!unlocked || _clickedMilestones.contains(index)) {
                  return;
                }
                widget.onMilestoneTap(index);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (showGlow)
                    Positioned(
                      left: (itemWidth - 54) / 2,
                      top: -7,
                      width: 54,
                      height: 54,
                      child: const _QuizRotatingGlow(),
                    ),
                  Positioned(
                    left: (itemWidth - 40) / 2,
                    top: 0,
                    width: 40,
                    height: 40,
                    child: PCImg(
                      name: unlocked ? 'pc_quiz_wheel_s' : 'pc_quiz_wheel_n',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  Positioned(
                    left: (itemWidth - 40) / 2,
                    top: 31,
                    width: 40,
                    height: 16,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PCImg(
                          name: 'pc_quiz_wheel_bottom_icon',
                          width: 40,
                          height: 16,
                        ),
                        PCStrokeText(
                          text: '$milestone',
                          size: 9,
                          color: Colors.white,
                          weight: FontWeight.w800,
                          skWidth: 0.8,
                          skColor: '#4A1200'.color(),
                        ),
                      ],
                    ),
                  ),
                  if (showGlow)
                    const Positioned(
                      right: 4,
                      top: 0,
                      child: IgnorePointer(child: PCShouIcon(size: 50)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizRotatingGlow extends StatefulWidget {
  const _QuizRotatingGlow();

  @override
  State<_QuizRotatingGlow> createState() => _QuizRotatingGlowState();
}

class _QuizRotatingGlowState extends State<_QuizRotatingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: PCImg(name: 'pc_quiz_guang_icon', width: 54, height: 54),
    );
  }
}
