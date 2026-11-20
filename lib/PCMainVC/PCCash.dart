import '../PCTool/PCWithdrawMethod.dart';
import '../PCTool/PCProgressMotion.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../PCBasic/PCTbaBar.dart' show PigsTabController;
import '../PCDialog/PCOther/PCProcessAccountDialog.dart';
import '../PCDialog/PCOther/PCDialogTool.dart';
import '../PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import '../PCDialog/PCWithdrawFlow/PCWithdrawalRankToast.dart';
import '../PCTool/PCAdaptiveLayout.dart';
import '../PCTool/PCDialogCoordinator.dart';
import '../PCTool/PCNumberManager.dart';
import '../PCTool/PCQuizConfig.dart';
import '../PCTool/PCWithdrawalController.dart';
import '../PCTool/PCWithdrawalNotifications.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_GradientNumber.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_text.dart';
import 'PCCashWithdrawalContent.dart';
import 'PCWithdrawPage.dart' show PCWithdrawDetails;

final GlobalKey<PCCashState> homeKey = GlobalKey<PCCashState>();

/// 提现列表六态：首档跟随本地提现流程，其余配置档位保留独立提现入口。
/// 导航仅回到本地答题/转盘；提现和广告由统一控制器校验及持久化。
class PCCash extends StatefulWidget {
  /// 仅用于提现页浏览，实际收款渠道仍由已提交的账号信息决定。
  static const viewPaymentKey = 'pc_cash_view_payment_index_v1';

  const PCCash({
    super.key,
    this.controller,
    this.onGoQuiz,
    this.onGoWheel,
    this.isNotificationEnabled,
    this.requestNotifications,
  });
  final PCWithdrawalController? controller;
  final VoidCallback? onGoQuiz, onGoWheel;
  final Future<bool> Function()? isNotificationEnabled, requestNotifications;
  @override
  State<PCCash> createState() => PCCashState();
}

class PCCashState extends State<PCCash> with WidgetsBindingObserver {
  static const _channelColors = {0: Color(0xFF0070BA), 2: Color(0xFF00C244)};
  late PCWithdrawalController _controller;
  final _provider = PCLocalProvider.instance;
  Timer? _clock;
  Timer? _rankFeedbackTimer;
  Completer<void>? _rankFeedbackDone;
  VoidCallback? _releaseQueuePresentation;
  int? _feedbackRank;
  int? _viewPaymentIndex;
  String? _accountSignature;
  bool _notificationEnabled = false, _busy = false, _foreground = true;
  PCWithdrawMethod? get _boundMethod =>
      PCWithdrawMethod.fromStorageIndex(_provider.pc_account_seled_index);
  int get _boundPaymentIndex =>
      (_boundMethod ?? PCWithdrawMethod.paypal).storageIndex;
  String get _boundPaymentName =>
      (_boundMethod ?? PCWithdrawMethod.paypal).label;
  bool get _hasBoundPayment =>
      _boundMethod != null && _provider.pc_account_id.trim().isNotEmpty;
  int get _viewingPaymentIndex => _viewPaymentIndex ?? _boundPaymentIndex;
  bool get _isViewingSavedPayment =>
      _viewPaymentIndex != null &&
      _hasBoundPayment &&
      _viewingPaymentIndex == _boundPaymentIndex;
  PCWithdrawalStage get _displayStage => _isViewingSavedPayment
      ? _controller.stage
      : PCWithdrawalStage.insufficient;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PCWithdrawalController.instance;
    _controller.addListener(_changed);
    _provider.addListener(_providerChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          !_foreground ||
          _displayStage != PCWithdrawalStage.reviewApproved) {
        return;
      }
      setState(() {});
      if (_controller.midnightRemaining == Duration.zero) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didUpdateWidget(covariant PCCash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_changed);
      _controller = widget.controller ?? PCWithdrawalController.instance;
      _controller.addListener(_changed);
      unawaited(_refresh());
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _providerChanged() => unawaited(_refresh());
  Future<void> _refresh() async {
    try {
      await _controller.refresh();
      final enabled =
          await (widget.isNotificationEnabled ??
              PCWithdrawalNotifications.isEnabled)();
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final signature =
          '${_provider.pc_account_seled_index}:${_provider.pc_account_id.trim()}';
      final accountChanged =
          _accountSignature != null && _accountSignature != signature;
      if (accountChanged &&
          !await prefs.setInt(PCCash.viewPaymentKey, _boundPaymentIndex)) {
        throw StateError('Unable to save payment selection');
      }
      if (!mounted) return;
      setState(() {
        if (accountChanged) {
          _viewPaymentIndex = _boundPaymentIndex;
        } else if (_viewPaymentIndex == null) {
          final saved = prefs.getInt(PCCash.viewPaymentKey);
          _viewPaymentIndex =
              PCWithdrawMethod.fromStorageIndex(saved)?.storageIndex ??
              _boundPaymentIndex;
        }
        _accountSignature = signature;
        _notificationEnabled = enabled;
      });
    } catch (_) {
      // 本地状态暂时不可用时保留已显示数据，回前台或再次点击可重试。
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _controller.isBusy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(
          context,
          'Unable to save progress. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prompt([double? amount]) => _run(() async {
    final requested = amount ?? _controller.target;
    if (!_isViewingSavedPayment && requested <= _controller.balance) {
      PCDialogTool.toast(
        context,
        !_hasBoundPayment
            ? 'Add your payment details first.'
            : 'Switch to $_boundPaymentName to continue your withdrawal.',
      );
      return;
    }
    await _controller.requestCurrentPrompt(amount: amount);
  });

  Future<void> _go(bool wheel) => _run(() async {
    if (!_isViewingSavedPayment) return;
    for (final prompt in _controller.pending) {
      if (prompt.kind == PCWithdrawalPromptKind.lastStep ||
          prompt.kind == PCWithdrawalPromptKind.queue ||
          prompt.kind == PCWithdrawalPromptKind.diamondCollect) {
        await _controller.dismiss(prompt);
      }
    }
    if (!mounted) return;
    final callback = wheel ? widget.onGoWheel : widget.onGoQuiz;
    if (callback != null) {
      callback();
    } else {
      PigsTabController.switchTo(wheel ? 2 : 1);
    }
  });

  Future<void> _task() async {
    if (!_isViewingSavedPayment) return;
    if (_controller.currentTask.title == 'video') {
      await _run(() async {
        final result = await _controller.recordVideoWithAdOutcome();
        if (result == PCWithdrawalAdResult.failed && mounted) {
          unawaited(_showAdFailure());
        }
      });
    } else {
      await _go(_controller.currentTask.title == 'spin');
    }
  }

  Future<void> _queueAd() => _run(() async {
    if (!_isViewingSavedPayment) return;
    // 广告回调会立刻推进排名并产生下一任务；先持有展示权，避免任务盖住排名反馈。
    final release = PCDialogCoordinator.instance.holdPresentation();
    _releaseQueuePresentation = release;
    final controller = _controller;
    try {
      final result = await controller.advanceQueueWithAdOutcome();
      if (!mounted || !identical(controller, _controller)) return;
      if (!result.isApplied) {
        // 失败弹窗也需要展示权，必须先交还排名反馈的hold，避免自己等待自己。
        release();
        if (identical(_releaseQueuePresentation, release)) {
          _releaseQueuePresentation = null;
        }
        if (result == PCWithdrawalAdResult.failed) {
          unawaited(_showAdFailure());
        }
        return;
      }
      setState(() => _feedbackRank = controller.queueRank);
      final finished = Completer<void>();
      _rankFeedbackDone = finished;
      _rankFeedbackTimer = Timer(const Duration(seconds: 2), () {
        if (!finished.isCompleted) finished.complete();
      });
      await finished.future;
      if (mounted) {
        setState(() => _feedbackRank = null);
        // 确认浮层已从当前帧移除后再交还队列。
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _rankFeedbackTimer?.cancel();
      _rankFeedbackTimer = null;
      _rankFeedbackDone = null;
      if (identical(_releaseQueuePresentation, release)) {
        _releaseQueuePresentation = null;
      }
      release();
    }
  });

  Future<void> _showAdFailure() async {
    // Try Again仅收起提示；后续由用户再次点击业务入口，复用缓存或等待在途请求。
    await context.tipShow2(
      const PCAdLoadingFailedDialog(),
      scaleContent: false,
    );
  }

  Future<void> _remind() => _run(() async {
    if (!_isViewingSavedPayment) return;
    if (!_notificationEnabled) {
      final enabled =
          await (widget.requestNotifications ??
              PCWithdrawalNotifications.request)();
      if (mounted) setState(() => _notificationEnabled = enabled);
    } else {
      await _controller.requestCurrentPrompt();
    }
  });

  /// 在两个渠道之间切换，只保存浏览项，不改已填写账号所属的渠道。
  Future<void> _cyclePayment() => _run(() async {
    // 渠道缓存索引与界面展示顺序不同，不能直接使用枚举索引入库。
    final next = _viewingPaymentIndex == 0 ? 2 : 0;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(PCCash.viewPaymentKey, next)) {
      throw StateError('Unable to save payment method');
    }
    if (mounted) setState(() => _viewPaymentIndex = next);
  });

  Future<void> _changePayment() => _run(() async {
    final PCWithdrawDetails? details = await context.tipShow2(
      PCProcessAccountDialog(
        initialAccount: _provider.pc_account_id,
        initialPaymentIndex: _provider.pc_account_seled_index,
        hasSavedAccount: _provider.pc_account_id.trim().isNotEmpty,
      ),
    );
    if (details == null) return;
    final index = details.method.storageIndex;
    final account = details.account.trim();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(_provider.pc_account_seled_indexName, index) ||
        !await prefs.setString(_provider.pc_account_idName, account) ||
        !await prefs.setInt(PCCash.viewPaymentKey, index)) {
      throw StateError('Unable to save payment information');
    }
    if (mounted) setState(() => _viewPaymentIndex = index);
    await _provider.init();
    await _controller.refresh();
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refresh());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _rankFeedbackTimer?.cancel();
    final feedbackDone = _rankFeedbackDone;
    if (feedbackDone != null && !feedbackDone.isCompleted) {
      feedbackDone.complete();
    }
    _releaseQueuePresentation?.call();
    _releaseQueuePresentation = null;
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _provider.removeListener(_providerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F8FA),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final scale = PCAdaptiveLayout.widthScale(constraints.maxWidth);
        double s(double value) => value * scale;
        final stage = _displayStage;
        final green =
            stage == PCWithdrawalStage.reviewing ||
            stage == PCWithdrawalStage.reviewApproved;
        final insufficient = stage == PCWithdrawalStage.insufficient;
        final amounts = PCNumberHelpers().pc_eqRange;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                key: const ValueKey('pcCashPageBackground'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.alphaBlend(
                        _channelColors[_viewingPaymentIndex]!.withValues(
                          alpha: .82,
                        ),
                        Colors.white,
                      ),
                      Color.alphaBlend(
                        _channelColors[_viewingPaymentIndex]!.withValues(
                          alpha: .06,
                        ),
                        Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                key: const ValueKey('pcCashScroll'),
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(s(16), s(38), s(16), s(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _paymentHeader(s),
                    SizedBox(height: s(22)),
                    _accountCard(s, green),
                    SizedBox(height: s(20)),
                    PCText(
                      text: 'Choose payout amount',
                      size: s(16),
                      color: Colors.black,
                      weight: FontWeight.w800,
                    ),
                    SizedBox(height: s(12)),
                    if (!insufficient) ...[
                      PCCashWithdrawalContent(
                        controller: _controller,
                        scale: scale,
                        account: _provider.pc_account_id,
                        paymentIndex: _boundPaymentIndex,
                        notificationEnabled: _notificationEnabled,
                        busy: _busy,
                        onCollect: () => unawaited(_go(false)),
                        onReminder: () => unawaited(_remind()),
                        onQueue: () => unawaited(_queueAd()),
                        onTask: () => unawaited(_task()),
                      ),
                      SizedBox(height: s(12)),
                    ],
                    for (final amount
                        in insufficient ? amounts : amounts.skip(1))
                      Padding(
                        padding: EdgeInsets.only(bottom: s(12)),
                        child: _payoutCard(amount, s, green),
                      ),
                  ],
                ),
              ),
            ),
            if (_feedbackRank != null)
              Positioned.fill(
                key: const ValueKey('pcCashRankFeedback'),
                child: IgnorePointer(
                  child: Center(
                    child: PCWithdrawalRankToast(rank: _feedbackRank!),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _paymentHeader(double Function(double) s) {
    final index = _viewingPaymentIndex;
    final method = PCWithdrawMethod.forDisplay(index);
    final brand = _channelColors[index]!;
    return SizedBox(
      height: s(36),
      child: Row(
        children: [
          SizedBox(
            width: s(100),
            height: s(36),
            child: ParticleButton(
              key: const ValueKey('pcCashPayment'),
              enabled: !_busy,
              onTap: () => unawaited(_changePayment()),
              child: DecoratedBox(
                key: const ValueKey('pcCashPaymentBackground'),
                decoration: BoxDecoration(
                  color: brand,
                  border: Border.all(color: brand),
                  borderRadius: BorderRadius.circular(s(8)),
                ),
                child: SizedBox.expand(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: s(6)),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PCImg(name: 'pc_act_$index', size: s(20)),
                          SizedBox(width: s(4)),
                          PCText(
                            text: method.label,
                            size: s(12.5),
                            color: index == 0 ? Colors.white : Colors.black,
                            weight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: s(4)),
          SizedBox(
            width: s(36),
            height: s(36),
            child: ParticleButton(
              key: const ValueKey('pcCashChangePayment'),
              enabled: !_busy,
              onTap: () => unawaited(_cyclePayment()),
              child: const PCImg(name: 'cs_time_icon'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(double Function(double) s, bool green) {
    final insufficient = _displayStage == PCWithdrawalStage.insufficient;
    final balance = _controller.balance;
    final target = _controller.target;
    final index = _viewingPaymentIndex;
    final status = switch (_displayStage) {
      PCWithdrawalStage.insufficient => 'Cash Out',
      PCWithdrawalStage.reviewing => 'Reviewing',
      PCWithdrawalStage.reviewApproved => 'Approved',
      PCWithdrawalStage.releasing => 'Reviewing',
      PCWithdrawalStage.queue => 'In Queue',
      PCWithdrawalStage.lastStep => 'Unlock Payout',
    };
    return SizedBox(
      height: s(insufficient ? 132 : 76),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s(8)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .8),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: s(68),
                      height: s(68),
                      child: Opacity(
                        opacity: index == 0 || index == 2 ? 1 : .15,
                        child: PCImg(
                          name: index == 0
                              ? 'pc_cash_watermark_paypal'
                              : index == 2
                              ? 'pc_cash_watermark_cashapp'
                              : 'pc_act_$index',
                        ),
                      ),
                    ),
                    Positioned(
                      left: s(12),
                      top: s(12),
                      child: PCText(
                        text: insufficient ? 'My Account' : 'Available Amount',
                        size: s(12),
                        color: const Color(0xFF8A8A8A),
                        weight: FontWeight.w500,
                      ),
                    ),
                    Positioned(
                      left: s(12),
                      right: s(132),
                      top: s(32),
                      height: s(32),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PCGradientNumberRoller(
                          key: const ValueKey('pcCashAvailableBalance'),
                          value: balance,
                          currentValue: balance,
                          fontSize: s(32),
                          fontWeight: FontWeight.w800,
                          gradientColors: const [Colors.black, Colors.black],
                          borderWidth: 0,
                          decimalPlaces: 2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: s(12),
                      top: s(20),
                      width: s(112),
                      child: PCCashActionButton(
                        key: const ValueKey('pcCashCurrentPrompt'),
                        text: status,
                        scale: s(1),
                        green: green,
                        enabled: !_busy,
                        onTap: () => unawaited(_prompt()),
                      ),
                    ),
                    if (insufficient) ...[
                      Positioned(
                        left: s(12),
                        right: s(12),
                        top: s(70),
                        child: _dollarProgress(balance, target, s),
                      ),
                      Positioned(
                        left: s(12),
                        right: s(12),
                        top: s(103),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: PCText(
                            text: balance < target
                                ? 'Only \$${PCQuizReward.format(target - balance)} left to withdraw \$${PCQuizReward.format(target)}'
                                : !_hasBoundPayment
                                ? 'Add your payment information to continue.'
                                : 'Your withdrawal is linked to $_boundPaymentName.',
                            size: s(12),
                            color: const Color(0xFF393939),
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (insufficient)
            Positioned(
              right: s(12),
              top: -s(16),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: s(10),
                  vertical: s(4),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDD1D),
                  borderRadius: BorderRadius.circular(s(12)),
                ),
                child: PCText(
                  text: 'Super easy cash today!',
                  size: s(12),
                  color: const Color(0xFFFF4C4C),
                  weight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dollarProgress(
    double balance,
    double target,
    double Function(double) s,
  ) => SizedBox(
    key: const ValueKey('pcCashDollarProgress'),
    height: s(24),
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: s(64),
          top: s(6),
          height: s(16),
          child: Container(
            padding: EdgeInsets.all(s(2)),
            decoration: BoxDecoration(
              color: const Color(0xFFD4DEE4),
              borderRadius: BorderRadius.circular(s(8)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PCProgressMotion(
                value: (balance / target).clamp(0.0, 1.0),
                builder: (_, animatedProgress, _) => FractionallySizedBox(
                  widthFactor: animatedProgress,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(s(6)),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFDF2D), Color(0xFFFF5E01)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          width: s(72),
          height: s(24),
          child: Stack(
            children: [
              const Positioned.fill(child: PCImg(name: 'cs_pp_bg')),
              Positioned(
                left: s(5),
                top: s(2),
                width: s(20),
                height: s(20),
                child: const PCImg(name: 'cs_pp_0_icon'),
              ),
              Positioned(
                left: s(28),
                right: s(4),
                top: s(4),
                height: s(16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PCGradientNumberRoller(
                    value: target,
                    currentValue: target,
                    fontSize: s(12),
                    decimalPlaces: 0,
                    fontWeight: FontWeight.w800,
                    borderWidth: 0,
                    gradientColors: const [
                      Color(0xFFFFDA50),
                      Color(0xFFFFAF00),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _payoutCard(int amount, double Function(double) s, bool green) =>
      Container(
        key: ValueKey('pcCashPayout_$amount'),
        height: s(60),
        padding: EdgeInsets.symmetric(horizontal: s(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(8)),
        ),
        child: Row(
          children: [
            PCText(
              text: '\$$amount',
              size: s(24),
              color: Colors.black,
              weight: FontWeight.w800,
            ),
            const Spacer(),
            SizedBox(
              width: s(92),
              child: PCCashActionButton(
                key: ValueKey('pcCashWithdraw_$amount'),
                text: 'Withdraw',
                height: 32,
                scale: s(1),
                green: green,
                enabled: !_busy,
                onTap: () => unawaited(_prompt(amount.toDouble())),
              ),
            ),
          ],
        ),
      );
}
