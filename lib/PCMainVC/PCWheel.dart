import '../PCTool/PCAnalytics.dart';
import '../PCTool/PCAdaptiveLayout.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pennypilotcollectspin/PCBasic/PCTbaBar.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:provider/provider.dart';
import '../PCTool/PCPigWheelPage.dart';
import '../PCTool/PCWheelController.dart';
import '../PCTool/PCWheelBonusChest.dart';
import '../PCTool/PCWithdrawalController.dart';
import '../PCTool/PCQuizConfig.dart';
import '../PCTool/PCQuizRewardAnimation.dart';
import '../PCTool/PCPigUpgradeController.dart';
import '../PCTool/PCDialogCoordinator.dart';
import '../PCTool/PCNewUserGuideController.dart';
import '../PCDialog/PCAward/PCAwardDialog.dart';
import '../PCDialog/PCOther/PCDialogTool.dart';
import '../PCDialog/PCOther/PCWheelNoChanceDialog.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/PCBalanceHeader.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_shou_icon.dart';
import '../PCTool/pc_WebKitView.dart';

final GlobalKey<PCWheelState> homeKey = GlobalKey<PCWheelState>();

class PCWheel extends StatefulWidget {
  const PCWheel({super.key, this.controller, this.active});
  final PCWheelController? controller;
  final bool? active;

  @override
  State<PCWheel> createState() => PCWheelState();
}

class PCWheelState extends State<PCWheel> with WidgetsBindingObserver {
  final _wheelKey = GlobalKey<PCPigWheelPageState>();
  final _rewardTarget = GlobalKey();
  late final PCWheelController _flow;
  bool _ready = false, _handling = false, _dialogOpen = false;
  bool _foreground = true, _wasActive = false;
  bool _openingBonus = false;
  int _rewardVisit = 0;
  PCQuizReward? _effect;
  VoidCallback? _releaseUpgrade;
  VoidCallback? _releaseRewardPresentation;
  Timer? _dailyRefreshTimer;
  bool get _busy => _handling || _dialogOpen || _effect != null;
  bool get _active =>
      _ready &&
      _foreground &&
      !PCPigUpgradeController.instance.isPresenting &&
      (widget.active ??
          (PigsTabController.currentIndex.value == 2 &&
              PCNewUserGuideController.instance.isComplete));

  @override
  void initState() {
    super.initState();
    _flow =
        widget.controller ??
        PCWheelController(
          onSync: PCLocalProvider.instance.init,
          onWithdrawalSpin: (id) async {
            await PCWithdrawalController.instance.recordEvent(
              PCWithdrawalEventKind.spin,
              eventId: id,
            );
          },
        );
    _flow.addListener(_flowChanged);
    WidgetsBinding.instance.addObserver(this);
    PigsTabController.currentIndex.addListener(_activityChanged);
    PCPigUpgradeController.instance.addListener(_activityChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    await PCNewUserGuideController.instance.load();
    await _flow.load();
    // 旧版本留下的待奖不再作为切页/冷启动入口，保留已转动扣次与真实记录。
    final previous = _flow.pending?.reward;
    if (previous != null) {
      await _flow.discardPending(expectedRewardId: previous.id);
    }
    if (!mounted) return;
    setState(() => _ready = true);
    _scheduleDailyRefresh();
    _activityChanged();
  }

  void _scheduleDailyRefresh() {
    _dailyRefreshTimer?.cancel();
    if (!mounted || !_foreground) return;
    final now = _flow.now;
    final next = DateTime(now.year, now.month, now.day + 1);
    final delay = next.difference(now);
    _dailyRefreshTimer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      () => unawaited(_refreshDailyOpportunities()),
    );
  }

  Future<void> _refreshDailyOpportunities() async {
    try {
      await _flow.refreshDailyOpportunities();
    } catch (_) {
      // 保留现有次数与待奖；再次进入、回前台或点击GO时重试本地事务。
    } finally {
      if (mounted) _scheduleDailyRefresh();
    }
  }

  void _flowChanged() {
    if (mounted) setState(() {});
  }

  void _activityChanged() {
    if (!mounted) return;
    final becameActive = _active && !_wasActive;
    if (!_active && _wasActive) _rewardVisit++;
    _wasActive = _active;
    setState(() {});
    if (becameActive) unawaited(_refreshDailyOpportunities());
  }

  @override
  void didUpdateWidget(covariant PCWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activityChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_refreshDailyOpportunities());
    } else {
      _dailyRefreshTimer?.cancel();
    }
    _activityChanged();
  }

  @override
  void dispose() {
    _dailyRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PigsTabController.currentIndex.removeListener(_activityChanged);
    PCPigUpgradeController.instance.removeListener(_activityChanged);
    _flow.removeListener(_flowChanged);
    final abandoned = _flow.pending?.reward;
    if (abandoned != null) {
      unawaited(_flow.discardPending(expectedRewardId: abandoned.id));
    }
    if (widget.controller == null) _flow.dispose();
    _releaseHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final scale = PCAdaptiveLayout.widthScale(
                constraints.maxWidth,
                designWidth: 375,
              );
              double s(double value) => value * scale;
              return Stack(
                fit: StackFit.expand,
                children: [
                  PCImg(
                    name: 'pc_wheel_bg',
                    width: 0.width(context),
                    height: 0.height(context),
                  ),
                  // 小屏允许内容滚动，避免固定高度挤入底部导航栏。
                  SingleChildScrollView(
                    child: Center(
                      child: SizedBox(
                        width: s(375),
                        child: Column(
                          children: [
                            SizedBox(height: s(64)),
                            SizedBox(
                              width: s(328),
                              height: provider.pc_pig_level == 0
                                  ? s(108)
                                  : s(112),
                              child: PCBalanceHeader(
                                provider: provider,
                                rewardTarget: _rewardTarget,
                              ),
                            ),
                            SizedBox(height: s(12)),
                            // 与设计一致将宝箱、Quiz放在顶部栏下的同一行；随内容
                            // 一起滚动，避免短屏或钻石/金猪顶部较高时与顶部余额重叠。
                            SizedBox(
                              width: double.infinity,
                              height: s(64),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: s(16),
                                    child: PCWheelBonusChest(
                                      size: s(64),
                                      active: _active && !_openingBonus,
                                      onTap: () => unawaited(_openBonus()),
                                    ),
                                  ),
                                  Positioned(
                                    right: s(20),
                                    child: ParticleButton(
                                      onTap: () =>
                                          PigsTabController.switchTo(1),
                                      child: PCBouncyImage(
                                        imagePath: 'pc_quiz_icon',
                                        width: s(64),
                                        height: s(64),
                                        enableAnimation:
                                            _active &&
                                            !MediaQuery.disableAnimationsOf(
                                              context,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: s(360),
                              height: s(360) + s(28),
                              child: Stack(
                                children: [
                                  Positioned(
                                    bottom: 0,
                                    child: PCImg(
                                      name: 'pc_bottom_money',
                                      width: s(360),
                                      height: s(112),
                                    ),
                                  ),
                                  ParticleButton(
                                    key: const ValueKey('pcWheelFaceButton'),
                                    enabled: _ready && !_busy,
                                    onTap: () {
                                      tapWheelEvent();
                                    },
                                    child: SizedBox(
                                      width: s(360),
                                      height: s(360),
                                      child: PCPigWheelPage(
                                        key: _wheelKey,
                                        imagePath: 'pc_wheel_center',
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: (s(360) - s(38)) * 0.5,
                                    top: s(12),
                                    child: PCImg(
                                      name: 'pc_rectangle_icon',
                                      width: s(38),
                                      height: s(36),
                                    ),
                                  ),
                                  Positioned(
                                    top: s(130),
                                    left: (s(360) - s(100)) * 0.5,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ParticleButton(
                                          key: const ValueKey(
                                            'pcWheelGoButton',
                                          ),
                                          enabled: _ready && !_busy,
                                          child: PCImg(
                                            name: 'pc_go_btn',
                                            width: s(100),
                                            height: s(100),
                                          ),
                                          onTap: () {
                                            tapWheelEvent();
                                          },
                                        ),
                                        // 手势跟随 GO 按钮常驻，点击时穿透到原按钮。
                                        Positioned(
                                          right: s(-14),
                                          bottom: s(-12),
                                          child: IgnorePointer(
                                            child: PCShouIcon(size: s(60)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    left: (s(360) - s(56)) * 0.6,
                                    top: s(120),
                                    child: SizedBox(
                                      width: s(56),
                                      height: s(36),
                                      child: Stack(
                                        children: [
                                          PCImg(name: 'pc_num_bg'),
                                          Center(
                                            child: PCStrokeText(
                                              text: '×${_flow.spins}',
                                              size: s(16),
                                              color: '#FFDD1D'.color(),
                                              weight: FontWeight.w700,
                                              skWidth: s(1),
                                              skColor: '#5D0D03'.color(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_effect != null) ...[
                    const Positioned.fill(
                      child: ModalBarrier(
                        dismissible: false,
                        color: Colors.transparent,
                      ),
                    ),
                    Positioned.fill(
                      child: PCQuizRewardAnimation(
                        reward: _effect!,
                        balance: provider.pc_dollar_number,
                        targetKey: _rewardTarget,
                        onFinished: _rewardFinished,
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openBonus() async {
    if (!_active ||
        _busy ||
        _openingBonus ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    setState(() => _openingBonus = true);
    PCAnalytics.event('h5_c');
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => const PCAnalyticsExposure(
            event: 'h5_page',
            child: PCWebkitview(
              url: 'https://tinyurl.com/dfr3jy4u',
              title: 'Games',
              useNativeH5Client: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingBonus = false);
    }
  }

  Future<void> tapWheelEvent() async {
    if (!_active || _busy) return;
    setState(() => _handling = true);
    _releaseUpgrade ??= PCPigUpgradeController.instance.holdPresentation();
    final startedVisit = _rewardVisit;
    try {
      final result = await _flow.start();
      if (!mounted) return;
      if (result == PCWheelStartResult.started) {
        await _wheelKey.currentState?.startRotation(_flow.pending!.segment);
      }
      if (!mounted) return;
      setState(() => _handling = false);
      if (!_active || startedVisit != _rewardVisit) {
        final abandoned = _flow.pending?.reward;
        if (abandoned != null) {
          await _flow.discardPending(expectedRewardId: abandoned.id);
        }
        return;
      }
      switch (result) {
        case PCWheelStartResult.started:
        case PCWheelStartResult.pending:
          await _showPending();
        case PCWheelStartResult.noSpins:
          _dialogOpen = true;
          final goQuiz = await context.tipShow2(
            const PCWheelNoChanceDialog(),
            bc: const Color(0xE6000000),
            scaleContent: false,
            onPresented: () async {
              PCAnalytics.event('no_chance_pop');
            },
          );
          if (mounted && goQuiz == true) {
            PigsTabController.switchTo(1);
          }
        case PCWheelStartResult.complete:
          PigsTabController.switchTo(3);
        case PCWheelStartResult.busy:
          break;
      }
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(
          context,
          'Could not save the spin. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _handling = false;
          _dialogOpen = false;
        });
      }
      if (_effect == null) _releaseHold();
    }
  }

  Future<void> _showPending() async {
    final reward = _flow.pending?.reward;
    if (reward == null || !_active || _busy) return;
    // 排队/最后一步仍可转盘领奖；异常旧存档中的零金额只结算，不展示空奖励框。
    if (reward.amount <= 0) {
      await _flow.claim();
      return;
    }
    setState(() => _dialogOpen = true);
    _releaseUpgrade ??= PCPigUpgradeController.instance.holdPresentation();
    PCQuizReward? claimed;
    final provider = PCLocalProvider.instance;
    try {
      await context.tipShow2(
        PCAwardDialog(
          award: reward.amount,
          reward: reward,
          balance: provider.pc_dollar_number,
          withdrawalTarget:
              PCNewUserGuideController.instance.config.withdrawalTarget,
          paymentAsset: 'pc_act_${provider.pc_account_seled_index.clamp(0, 3)}',
          remainingCollectible: reward.type == PCQuizRewardType.diamond
              ? (PCQuizConfig.diamondTarget - _flow.diamonds).clamp(
                  0,
                  PCQuizConfig.diamondTarget,
                )
              : (PCQuizConfig.goldTarget - _flow.gold).clamp(
                  0,
                  PCQuizConfig.goldTarget,
                ),
          analyticsSource: 'wheel',
          claimAdPlacement: 'nkmdl_wheel_rv',
          closeAdPlacement: 'nkmdl_wheel_int',
          onAbandon: () async {
            await _flow.discardPending(expectedRewardId: reward.id);
          },
          onClaim: () async {
            claimed = await _flow.claim(expectedRewardId: reward.id);
            if (claimed != null && mounted) {
              _releaseRewardPresentation ??= PCDialogCoordinator.instance
                  .holdPresentation();
            }
            return claimed != null;
          },
        ),
        bc: pcDialogBackdrop,
        scaleContent: false,
      );
    } finally {
      // 外部pop、路由替换及页面销毁也必须放弃原奖，不能在Tab回来时补弹。
      if (claimed == null) {
        await _flow.discardPending(expectedRewardId: reward.id);
      }
      if (mounted) {
        setState(() {
          _dialogOpen = false;
          _effect = claimed;
        });
      }
      if (claimed == null) _releaseHold();
    }
  }

  void _releaseHold() {
    _releaseUpgrade?.call();
    _releaseUpgrade = null;
    _releaseRewardPresentation?.call();
    _releaseRewardPresentation = null;
  }

  void _rewardFinished() {
    if (!mounted) return;
    setState(() => _effect = null);
    _releaseHold();
  }
}
