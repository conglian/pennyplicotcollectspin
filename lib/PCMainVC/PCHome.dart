import '../PCTool/PCProgressMotion.dart';
import '../PCTool/PCWithdrawMethod.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../PCDialog/PCGuide/PCCheckInDialog.dart';
import '../PCDialog/PCAward/PCAwardDialog.dart';
import '../PCDialog/PCOther/PCDialogTool.dart';
import '../PCDialog/PCOther/PCAdLoadingFailedDialog.dart';
import '../PCDialog/PCOther/PCHomeDebugDialog.dart';
import '../PCDialog/PCOther/PCSettingsDialog.dart';
import '../PCTool/PCFKManger.dart';
import '../PCTool/PCHomeDebugController.dart';
import '../PCTool/PCSettingsLinks.dart';
import '../PCTool/pc_WebKitView.dart';
import '../PCTool/PCHomeRewardController.dart';
import '../PCTool/PCHomeRewardBubble.dart';
import '../PCTool/PCHomeBonusTip.dart';
import '../PCTool/PCQuizConfig.dart';
import '../PCTool/PCQuizRewardAnimation.dart';
import '../PCTool/PCPigMotion.dart';
import '../PCTool/PCRewardedAdService.dart';
import '../PCTool/PCInterstitialAdService.dart';
import '../PCTool/PCPigUpgradeController.dart';
import '../PCTool/PCDialogCoordinator.dart';
import '../PCTool/PCNewUserGuideController.dart';
import '../PCTool/PCNumberManager.dart';
import '../PCBasic/PCTbaBar.dart' show PigsTabController;
import '../PCDialog/PCOther/PCPigShowDialog.dart';
import '../PCTool/PCRankData.dart';
import '../PCTool/PCCheckInBubble.dart';
import '../PCTool/PCBalanceHeader.dart';
import '../PCTool/PCAnalytics.dart';
import '../PCTool/pc_GradientNumber.dart';
import '../PCTool/pc_GradientText.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_stroke_text.dart';
import '../PCTool/pc_text.dart';

final GlobalKey<PChomeState> homeKey = GlobalKey<PChomeState>();
final GlobalKey pcHomeCheckInTargetKey = GlobalKey(
  debugLabel: 'pcHomeCheckInTarget',
);
final GlobalKey pcHomePigTargetKey = GlobalKey(debugLabel: 'pcHomePigTarget');

class PChome extends StatefulWidget {
  const PChome({super.key, this.rewardController});
  final PCHomeRewardController? rewardController;

  @override
  State<PChome> createState() => PChomeState();
}

class PChomeState extends State<PChome> with WidgetsBindingObserver {
  List<PCUserData> _rankData = [];
  Timer? _rankingRefreshTimer;
  static const _rewardSlots = {1: 0, 2: 1, 5: 2};
  static const _rewardBubbleRewardedPlacement = 'nkmdl_moneybub_getpop_rv';
  late final PCHomeRewardController _rewards;
  final _bonusTip = PCHomeBonusTipController();
  bool _bonusTipPending = false, _bonusTipCheckScheduled = false;
  bool _homeExposurePending = false;
  final _rewardTarget = GlobalKey();
  bool _openingReward = false;
  bool _openingDebug = false;
  bool _openingSettings = false;
  int _rewardVisit = 0;
  PCQuizReward? _rewardEffect;
  Completer<void>? _rewardEffectFinished;
  VoidCallback? _releaseRewardUpgrade;
  VoidCallback? _releaseRewardPresentation;

  final List<String> _bubbleItems = [
    'pc_home_quiz_bubble',
    'pc_doaller_icon',
    'pc_doaller_icon',
    'pc_checkin_bubble',
    'pc_home_wheel_bubble',
    'pc_doaller_icon',
    'pc_home_apple_bubble',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PCFKManger().initFK();
    PigsTabController.currentIndex.addListener(_homeTabChanged);
    PCNewUserGuideController.instance.addListener(_scheduleBonusTipCheck);
    PCDialogCoordinator.instance.addListener(_scheduleBonusTipCheck);
    _homeTabChanged();
    _rewards =
        widget.rewardController ??
        PCHomeRewardController(onSync: PCLocalProvider.instance.init);
    _rewards.addListener(_rewardChanged);
    PCLocalProvider.instance.addListener(_localRewardChanged);
    unawaited(_refreshHomeRewards());
    _loadRanking();
    _scheduleRankingRefresh();
  }

  void _homeTabChanged() {
    if (PigsTabController.currentIndex.value != 0) {
      _rewardVisit++;
      _bonusTipPending = false;
      _bonusTip.deactivate();
      if (_rewardEffect != null) _homeRewardFinished();
      return;
    }
    _bonusTipPending = true;
    _homeExposurePending = true;
    _scheduleBonusTipCheck();
  }

  void _scheduleBonusTipCheck() {
    if (!mounted || _bonusTipCheckScheduled) return;
    _bonusTipCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bonusTipCheckScheduled = false;
      if (!mounted) return;
      if (PCDialogCoordinator.instance.isBusy) {
        if (_bonusTip.visible) _bonusTipPending = true;
        _bonusTip.deactivate();
        return;
      }
      if (_homeExposurePending &&
          PigsTabController.currentIndex.value == 0 &&
          ModalRoute.of(context)?.isCurrent == true) {
        _homeExposurePending = false;
        PCAnalytics.event('home_page');
      }
      if (_bonusTipPending &&
          PigsTabController.currentIndex.value == 0 &&
          PCNewUserGuideController.instance.isComplete) {
        _bonusTipPending = false;
        _bonusTip.activate();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _rewardChanged() {
    if (mounted) setState(() {});
  }

  void _localRewardChanged() {
    if (!_openingReward) unawaited(_refreshHomeRewards());
  }

  Future<void> _refreshHomeRewards() async {
    try {
      await _rewards.refresh();
    } catch (_) {
      /* 暂时读取失败时保留已展示的奖励，下一次余额刷新时重试。 */
    }
  }

  Future<void> _loadRanking() async {
    try {
      final data = await PCUserDataManager.getPCUserData();
      if (!mounted) {
        return;
      }
      setState(() {
        _rankData = data;
      });
    } catch (_) {
      // 读取失败时保留当前榜单，下一次回前台时重试。
    }
  }

  void _scheduleRankingRefresh() {
    _rankingRefreshTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime nextMidnight = PCUserDataManager.nextRefreshAt(now);
    final Duration delay = nextMidnight.difference(now);
    _rankingRefreshTimer = Timer(delay, () async {
      await _loadRanking();
      if (mounted) {
        _scheduleRankingRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _bonusTip.deactivate();
    if (state == AppLifecycleState.resumed) {
      // 回前台重新核对缓存日期，补齐后台挂起期间错过的零点刷新。
      _loadRanking();
      _scheduleRankingRefresh();
      _localRewardChanged();
    }
  }

  @override
  void dispose() {
    _rankingRefreshTimer?.cancel();
    PigsTabController.currentIndex.removeListener(_homeTabChanged);
    PCNewUserGuideController.instance.removeListener(_scheduleBonusTipCheck);
    PCDialogCoordinator.instance.removeListener(_scheduleBonusTipCheck);
    _bonusTip.dispose();
    PCLocalProvider.instance.removeListener(_localRewardChanged);
    _rewards.removeListener(_rewardChanged);
    if (widget.rewardController == null) _rewards.dispose();
    _releaseRewardUpgrade?.call();
    _releaseRewardPresentation?.call();
    final effectFinished = _rewardEffectFinished;
    _rewardEffectFinished = null;
    if (effectFinished != null && !effectFinished.isCompleted) {
      effectFinished.complete();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _openingCheckIn = false;
  Future<void> _onBubbleTap(int index) async {
    if (!mounted || PigsTabController.currentIndex.value != 0) return;
    HapticFeedback.selectionClick();
    final slot = _rewardSlots[index];
    if (slot != null) {
      if (_openingReward || _rewardEffect != null) return;
      final free = _rewards.isFreeSlot(slot);
      if (free && _rewards.freeCooldownRemaining > Duration.zero) return;
      PCAnalytics.event('home_float_c');
      await _openReward(slot, requiresEntryAd: !free, grantOnEntry: !free);
      return;
    }
    if (index == 6) {
      if (_openingReward || _rewardEffect != null) return;
      PCAnalytics.event('home_float_apple');
      // 金苹果入口插屏成功先静默入账，再按新配置开获得框，复用两笔奖励防重。
      await _openReward(2, isApple: true, grantOnEntry: true);
      return;
    }
    if (index == 0) {
      PCAnalytics.event('home_float_quiz');
      PigsTabController.switchTo(1);
      return;
    }
    if (index == 4) {
      PCAnalytics.event('home_float_wheel');
      PigsTabController.switchTo(2);
      return;
    }
    if (index != 3 || _openingCheckIn) return;
    setState(() => _openingCheckIn = true);
    try {
      final guide = PCNewUserGuideController.instance;
      await guide.load();
      if (!mounted) return;
      final claim = await context.tipShow2(
        PCCheckInDialog(
          rewards: guide.config.checkInRewards,
          day: guide.checkInDay,
          canClaim: guide.canCheckIn,
          showAdBadge: true,
          onClaimOutcome: () async {
            final outcome = await guide.claimCheckInOutcome();
            if (outcome.isSuccess) await PCLocalProvider.instance.init();
            return outcome;
          },
        ),
      );
      if (claim != true || !mounted) return;
      await _refreshHomeRewards();
    } finally {
      // 完整退场后同步签到入口的防重状态，后续点击可重新发起请求。
      if (mounted) {
        setState(() => _openingCheckIn = false);
      } else {
        _openingCheckIn = false;
      }
    }
  }

  Future<void> _openReward(
    int slot, {
    bool requiresEntryAd = true,
    bool grantOnEntry = false,
    bool isApple = false,
  }) async {
    if (_openingReward || _rewardEffect != null) return;
    final visit = _rewardVisit;
    setState(() => _openingReward = true);
    _releaseRewardUpgrade ??= PCPigUpgradeController.instance
        .holdPresentation();
    PCQuizReward? claimed;
    try {
      await _rewards.refresh();
      if (!_homeRewardActive(visit)) return;
      final initialReward = requiresEntryAd
          ? _rewards.rewardAt(slot)
          : await _rewards.reserveFreeReward();
      if (initialReward == null) {
        return;
      }
      var reward = initialReward;
      if (requiresEntryAd) {
        final releaseAd = PCDialogCoordinator.instance.holdPresentation();
        late final PCAdOutcome outcome;
        try {
          // 金苹果先完整播放插屏再开框；两个AD气泡入口仍是真实激励。
          outcome = isApple
              ? await PCInterstitialAdService.instance.requestOutcome(
                  'nkmdl_applebub_int',
                )
              : await PCRewardedAdService.instance.requestOutcome(
                  _rewardBubbleRewardedPlacement,
                );
          if (outcome.isSuccess && grantOnEntry && _homeRewardActive(visit)) {
            _releaseRewardPresentation ??= PCDialogCoordinator.instance
                .holdPresentation();
          }
        } finally {
          releaseAd();
        }
        if (!mounted || !_homeRewardActive(visit)) return;
        if (!outcome.isSuccess) {
          if (outcome == PCAdOutcome.failed) {
            await context.tipShow2(const PCAdLoadingFailedDialog());
          }
          return;
        }
      }
      if (!_homeRewardActive(visit)) return;
      if (grantOnEntry) {
        // 入口激励成功只结算第一笔，不播放到账弹窗；原rewardId只可结算一次。
        final entryReward = await _rewards.claim(reward);
        if (entryReward == null) {
          if (mounted) {
            PCDialogTool.toast(context, 'Reward updated. Tap a bubble again.');
          }
          return;
        }
        if (!_homeRewardActive(visit)) return;
        // 第一笔已刷新三气泡，第二笔按最新余额/阶段取配置，不能重复领旧快照。
        await _rewards.refresh();
        final nextReward = _rewards.rewardAt(slot);
        if (nextReward == null) return;
        reward = nextReward;
      }
      if (!mounted || !_homeRewardActive(visit)) return;
      final provider = PCLocalProvider.instance;
      // 入账期间的展示权交给获得弹窗队列，不能持有自己的锁等待弹窗出现。
      _releaseRewardPresentation?.call();
      _releaseRewardPresentation = null;
      Future<bool> settleClaim({bool doubleGold = false}) async {
        try {
          claimed = await _rewards.claim(reward, doubleGold: doubleGold);
        } catch (_) {
          if (mounted) {
            PCDialogTool.toast(
              context,
              'Could not save the reward. Please try again.',
            );
          }
          return false;
        }
        if (claimed == null && mounted) {
          PCDialogTool.toast(
            context,
            'Reward updated. Close this dialog and tap a bubble again.',
          );
        }
        if (claimed != null && mounted) {
          _releaseRewardPresentation ??= PCDialogCoordinator.instance
              .holdPresentation();
        }
        return claimed != null;
      }

      final interstitialPlacement = isApple
          ? 'nkmdl_applebub_getpop_int'
          : 'nkmdl_moneybub_getpop_int';
      await context.tipShow2(
        PCAwardDialog(
          award: reward.amount,
          reward: reward,
          balance: provider.pc_dollar_number,
          withdrawalTarget:
              PCNewUserGuideController.instance.config.withdrawalTarget,
          paymentAsset: PCWithdrawMethod.forDisplay(
            provider.pc_account_seled_index,
          ).paymentAsset,
          collectibleCount: reward.type == PCQuizRewardType.diamond
              ? _rewards.diamonds
              : _rewards.gold,
          showAdBadge: isApple,
          claimAdPolicy: isApple
              ? PCAwardClaimAdPolicy.rewarded
              : PCAwardClaimAdPolicy.probabilityInterstitial,
          claimAdPlacement: isApple ? 'asd_rv' : _rewardBubbleRewardedPlacement,
          closeAdPlacement: interstitialPlacement,
          onClaim: settleClaim,
          onDoubleClaim: () => settleClaim(doubleGold: true),
        ),
        bc: PCAwardDialog.backdropFor(reward.type),
        scaleContent: false,
        canPresent: () => _homeRewardActive(visit),
      );
      if (_homeRewardActive(visit) && claimed != null) {
        await _playHomeReward(claimed!);
      }
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(
          context,
          'Could not save the reward. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingReward = false);
      _releaseRewardUpgrade?.call();
      _releaseRewardUpgrade = null;
      _releaseRewardPresentation?.call();
      _releaseRewardPresentation = null;
      if (mounted) await _refreshHomeRewards();
    }
  }

  bool _homeRewardActive(int visit) =>
      mounted &&
      PigsTabController.currentIndex.value == 0 &&
      visit == _rewardVisit;

  Future<void> _playHomeReward(PCQuizReward reward) async {
    if (!mounted || PigsTabController.currentIndex.value != 0) return;
    _releaseRewardPresentation ??= PCDialogCoordinator.instance
        .holdPresentation();
    final finished = Completer<void>();
    _rewardEffectFinished = finished;
    setState(() => _rewardEffect = reward);
    try {
      await finished.future;
    } finally {
      if (identical(_rewardEffectFinished, finished)) {
        _rewardEffectFinished = null;
      }
      _releaseRewardPresentation?.call();
      _releaseRewardPresentation = null;
    }
  }

  void _homeRewardFinished() {
    if (!mounted || _rewardEffect == null) return;
    final finished = _rewardEffectFinished;
    setState(() => _rewardEffect = null);
    // 等到账层与遮罩真正从本帧移除，才允许后续获得弹窗进入队列。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (finished != null && !finished.isCompleted) finished.complete();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    setState(() => _openingSettings = true);
    try {
      await context.tipShow2(
        PCSettingsDialog(
          onPrivacyPolicy: () => _openSettingsPage(
            PCSettingsLinks.privacyPolicy,
            'Privacy Policy',
          ),
          onTermsOfUse: () =>
              _openSettingsPage(PCSettingsLinks.termsOfUse, 'Terms of Use'),
        ),
        canPresent: () => mounted && PigsTabController.currentIndex.value == 0,
      );
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  Future<void> _openSettingsPage(String url, String title) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PCWebkitview(url: url, title: title),
      ),
    );
  }

  Future<void> _openDebug() async {
    if (!kDebugMode || _openingDebug) return;
    setState(() => _openingDebug = true);
    try {
      final controller = PCHomeDebugController(
        onSync: PCLocalProvider.instance.init,
      );
      final data = await controller.read();
      if (!mounted || PigsTabController.currentIndex.value != 0) return;
      await context.tipShow2(
        PCHomeDebugDialog(
          cash: data.cash,
          diamonds: data.diamonds,
          gold: data.gold,
          queueRank: data.queueRank,
          queueTotal: data.queueTotal,
          pigLevel: data.pigLevel,
          wheelChances: data.wheelChances,
          onSubmit: ({cash, diamonds, gold, queueRank, wheelChances}) async {
            await controller.apply(
              cash: cash,
              diamonds: diamonds,
              gold: gold,
              queueRank: queueRank,
              wheelChances: wheelChances,
            );
            await _refreshHomeRewards();
          },
        ),
        canPresent: () => mounted && PigsTabController.currentIndex.value == 0,
      );
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(
          context,
          'Could not read debug data. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingDebug = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: kDebugMode
          ? Tooltip(
              message: 'Debug data',
              child: ParticleButton(
                key: const ValueKey('pcHomeDebugButton'),
                enabled: !_openingDebug,
                onTap: _openDebug,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF173600),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFDA50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bug_report,
                        size: 18,
                        color: Color(0xFFFFDA50),
                      ),
                      SizedBox(width: 4),
                      PCText(
                        text: 'Debug',
                        size: 13,
                        color: Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final double safeTop = MediaQuery.of(context).padding.top;
              final Size screenSize = MediaQuery.sizeOf(context);
              final double layoutWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : screenSize.width;
              final double layoutHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : screenSize.height;
              // 新版顶部设置行留出点击范围；短屏收紧整组，给排行榜留下滚动空间。
              final double scale = math.min(
                layoutWidth / 360,
                math.max(0.0, layoutHeight - safeTop - 140 - 44) /
                    (provider.pc_pig_level == 0 ? 380 : 400),
              );
              double s(double value) => value * scale;
              final left = (layoutWidth - s(360)) / 2;
              // Figma earn 1:5：齿轮32×32、y32；余额卡y76，两者相隔12。
              final settingsTop = safeTop + s(8);
              final settingsSize = s(32);
              final settingsHitSize = math.max(44.0, s(48));
              final settingsHitTop = math.max(
                safeTop,
                settingsTop - (settingsHitSize - settingsSize) / 2,
              );
              final headerTop = math.max(
                safeTop + s(52),
                settingsHitTop + settingsHitSize + s(4),
              );
              final headerHeight = s(provider.pc_pig_level == 0 ? 92 : 112);
              final heroTop = headerTop + headerHeight + s(4);
              final rankTop = heroTop + s(272);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: PCImg(
                      name: 'pc_home_bg',
                      width: layoutWidth,
                      height: layoutHeight,
                    ),
                  ),
                  Positioned(
                    top: headerTop,
                    left: left + s(16),
                    height: headerHeight,
                    width: s(328),
                    child: _buildHomeTopCard(provider, s, s, s),
                  ),
                  Positioned(
                    top: heroTop + s(160),
                    left: left + s(40),
                    width: s(280),
                    height: s(100),
                    child: const PCImg(name: 'pc_pig_bottom'),
                  ),
                  Positioned(
                    top: heroTop + s(64),
                    left: left + s(96),
                    width: s(168),
                    height: s(140),
                    child: PCPigMotion.hero(
                      key: pcHomePigTargetKey,
                      child: PCImg(
                        name: switch (provider.pc_pig_level) {
                          1 => 'pc_quiz_pig_diamond',
                          2 => 'pc_quiz_pig_gold',
                          _ => 'pc_big_icon_0',
                        },
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  Positioned(
                    top: heroTop + s(184),
                    left: left + s(120),
                    width: s(120),
                    height: s(40),
                    child: _buildBalanceCard(provider, s, s),
                  ),
                  Positioned(
                    top: heroTop + s(232),
                    left: left + s(8),
                    right: left + s(8),
                    height: s(32),
                    child: _HomeBroadcastTicker(
                      fontSize: s(12),
                      iconSize: s(20),
                    ),
                  ),
                  Positioned(
                    top: rankTop,
                    left: left + s(8),
                    right: left + s(8),
                    bottom: 0,
                    child: const PCImg(name: 'pc_home_bottom_bg'),
                  ),
                  Positioned(
                    top: rankTop + s(8),
                    left: left + s(20),
                    right: left + s(20),
                    height: s(28),
                    child: Row(
                      children: [
                        PCImg(
                          name: 'pc_guang_icon',
                          width: s(20),
                          height: s(20),
                        ),
                        PCGradientStrokeText(
                          text: 'Top Earning Pigs',
                          gradientColors: [
                            '#FFDA50'.color(),
                            '#FFAF00'.color(),
                          ],
                          width: s(132),
                          height: s(24),
                          fontSize: s(16).round(),
                          strokeWidth: s(1),
                          strokeColor: '#032C00'.color(),
                        ),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: PCText(
                              text: '(Refresh at 0:00 every day)',
                              size: s(12),
                              color: '#B6D599'.color(),
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: rankTop + s(32),
                    left: left + s(12),
                    right: left + s(12),
                    bottom: 0,
                    child: PCHomeRankingSection(data: _rankData, scale: scale),
                  ),
                  // 七个气泡仍沿用依次出现和呼吸动画，位置与新版设计的三行对应。
                  for (final entry in const <int, Offset>{
                    0: Offset(44, 10),
                    4: Offset(148, 0),
                    6: Offset(252, 12),
                    1: Offset(8, 93),
                    3: Offset(288, 93),
                    2: Offset(20, 166),
                    5: Offset(276, 166),
                  }.entries)
                    Positioned(
                      top: heroTop + s(entry.value.dy),
                      left: left + s(entry.value.dx),
                      width: s(64),
                      height: s(64),
                      child: _buildBubble(entry.key, s(64)),
                    ),
                  // 短提示位于最上层，2秒后退场，不拦截气泡或余额按钮。
                  Positioned(
                    top: heroTop + s(32),
                    left: left + s(80),
                    width: s(200),
                    height: s(48),
                    child: PCHomeBonusTip(
                      key: const ValueKey('pcHomeBonusTip'),
                      controller: _bonusTip,
                      width: s(200),
                      height: s(48),
                      background: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: s(40),
                            child: const PCImg(name: 'pc_home_bonus_tip_bg'),
                          ),
                          Positioned(
                            left: s(140),
                            top: s(40),
                            width: s(12),
                            height: s(8),
                            child: const PCImg(name: 'pc_home_bonus_tip_tail'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: left + s(312) - (settingsHitSize - settingsSize) / 2,
                    top: settingsHitTop,
                    width: settingsHitSize,
                    height: settingsHitSize,
                    child: Semantics(
                      button: true,
                      label: 'Settings',
                      child: ParticleButton(
                        key: const ValueKey('pcHomeSettingsButton'),
                        enabled: !_openingSettings,
                        onTap: _openSettings,
                        child: Stack(
                          children: [
                            Positioned(
                              left: (settingsHitSize - settingsSize) / 2,
                              top: settingsTop - settingsHitTop,
                              width: settingsSize,
                              height: settingsSize,
                              child: const PCImg(
                                name: 'pc_settings_gear',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_rewardEffect != null) ...[
                    const Positioned.fill(
                      child: ModalBarrier(
                        dismissible: false,
                        color: Colors.transparent,
                      ),
                    ),
                    Positioned.fill(
                      child: PCQuizRewardAnimation(
                        key: ValueKey(_rewardEffect!.id),
                        reward: _rewardEffect!,
                        balance: provider.pc_dollar_number,
                        targetKey: _rewardTarget,
                        onFinished: _homeRewardFinished,
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

  Widget _buildHomeTopCard(
    PCLocalProvider provider,
    double Function(double) s,
    double Function(double) w,
    double Function(double) h,
  ) {
    if (provider.pc_pig_level > 0) {
      return PCBalanceHeader(provider: provider, rewardTarget: _rewardTarget);
    }
    final double withdrawTarget =
        PCNewUserGuideController.instance.config.withdrawalTarget;
    final double balance = provider.pc_dollar_number;
    final double progress = (balance / withdrawTarget).clamp(0.0, 1.0);
    final double remaining = math.max(0, withdrawTarget - balance);

    return Container(
      width: w(328),
      height: h(92),
      decoration: BoxDecoration(image: PCDImg('pc_home_top_bg')),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: w(12),
            top: h(12),
            width: w(52),
            height: h(52),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(s(6)),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PCImg(
                    name: 'pc_home_payment_paypal',
                    width: w(52),
                    height: h(52),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: w(72),
            right: w(100),
            top: h(12),
            height: h(24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PCText(
                    text: 'Growing Balance: ',
                    size: s(11),
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                  PCGradientNumberRoller(
                    key: _rewardTarget,
                    value: balance,
                    fontSize: s(16),
                    fontWeight: FontWeight.w900,
                    gradientColors: ['#FFD21C'.color(), '#FFAF00'.color()],
                    borderWidth: 0,
                    decimalPlaces: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: w(12),
            top: h(12),
            width: w(80),
            height: h(24),
            child: ParticleButton(
              onTap: () {
                if (PigsTabController.currentIndex.value != 0) return;
                PCAnalytics.event('home_page_withdraw');
                PigsTabController.switchTo(3);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(s(14)),
                ),
                alignment: Alignment.center,
                child: PCText(
                  text: 'Withdraw',
                  size: s(11),
                  color: '#07529B'.color(),
                  weight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            left: w(72),
            top: h(52),
            width: w(184),
            height: h(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(s(6)),
              child: ColoredBox(
                color: '#002B73'.color(),
                child: Padding(
                  padding: EdgeInsets.all(s(2)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PCProgressMotion(
                      value: progress,
                      builder: (_, animatedProgress, _) => FractionallySizedBox(
                        widthFactor: animatedProgress,
                        heightFactor: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(s(4)),
                          child: ColoredBox(color: '#FFDD1E'.color()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: w(260),
            right: w(12),
            top: h(52),
            height: h(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PCGradientNumberRoller(
                    value: balance,
                    fontSize: s(10),
                    fontWeight: FontWeight.w600,
                    gradientColors: const [Colors.white, Colors.white],
                    borderWidth: 0,
                  ),
                  PCText(
                    text: ' / \$${withdrawTarget.toStringAsFixed(0)}',
                    size: s(10),
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: h(72),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: s(9),
                  fontWeight: FontWeight.w500,
                  color: '#AFE4FF'.color(),
                  height: 1.15,
                  fontFamily: 'CarlsbergSansBlack',
                ),
                children: [
                  const TextSpan(text: 'Only \$'),
                  TextSpan(
                    text: remaining.toStringAsFixed(1),
                    style: TextStyle(color: '#FFDD1D'.color()),
                  ),
                  TextSpan(
                    text:
                        ' Left To Withdraw \$${withdrawTarget.toStringAsFixed(0)}',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    PCLocalProvider provider,
    double Function(double) s,
    double Function(double) w,
  ) {
    final level = provider.pc_pig_level;
    final amount = level == 0
        ? provider.pc_dollar_number
        : provider.pc_pig_level_index;
    return Container(
      key: const ValueKey('pcHomePigBalance'),
      width: w(120),
      height: s(40),
      decoration: BoxDecoration(image: PCDImg('pc_dollar_bgs')),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s(6)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PCGradientText(
                '${level == 0 ? '\$' : ''}${amount.toStringAsFixed(2)}',
                fontSize: s(20),
                maxLines: 1,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: ['#FFDA50'.color(), '#FFAF00'.color()],
                ),
              ),
              if (level > 0) ...[
                SizedBox(width: s(4)),
                PCImg(
                  name: level == 1
                      ? 'pc_stage_collect_diamond'
                      : 'pc_stage_collect_gold',
                  width: s(22),
                  height: s(22),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(int index, double size) {
    final slot = _rewardSlots[index];
    final provider = PCLocalProvider.instance;
    final ready = _rewards.isLoaded && _rewards.level == provider.pc_pig_level;
    final amount = ready && slot != null ? _rewards.amounts[slot] : null;
    final free = slot != null && _rewards.isFreeSlot(slot);
    // 只有免费气泡的60秒冷却禁用点击；签到/领奖状态不能锁住整组入口。
    // 每种弹窗由自己的请求防重与全局队列管理，模态遮罩负责阻挡穿透。
    final enabled = !free || _rewards.freeCooldownRemaining == Duration.zero;
    Widget? content;
    if (slot != null) {
      content = PCHomeRewardBubble(
        type: PCQuizRewardType.values[provider.pc_pig_level.clamp(0, 2)],
        amount: amount,
        mystery: slot == 1,
        size: size,
        showAdBadge: !free,
        cooldownSeconds: free ? _rewards.freeCooldownSeconds : 0,
      );
    } else if (index == 3) {
      content = PCCheckInBubble(size: size);
    } else if (index == 6) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_home_apple_bubble')),
          Positioned(
            top: 0,
            right: 0,
            width: size * 20 / 64,
            height: size * 20 / 64,
            child: const IgnorePointer(child: PCImg(name: 'pc_ad_icon')),
          ),
        ],
      );
    }
    return _PCHomeBubbleButton(
      key: index == 3
          ? pcHomeCheckInTargetKey
          : slot == null
          ? ValueKey('pcHomeBubble$index')
          : ValueKey('pcHomeRewardBubble$slot'),
      iconName: _bubbleItems[index],
      size: size,
      delay: Duration(milliseconds: 320 * index),
      enabled: enabled,
      onTap: () => _onBubbleTap(index),
      content: content,
    );
  }
}

class _PCHomeBubbleButton extends StatefulWidget {
  const _PCHomeBubbleButton({
    super.key,
    required this.iconName,
    required this.size,
    required this.delay,
    required this.onTap,
    this.enabled = true,
    this.content,
  });

  final bool enabled;
  final Widget? content;
  final String iconName;
  final double size;
  final Duration delay;
  final VoidCallback onTap;

  @override
  State<_PCHomeBubbleButton> createState() => _PCHomeBubbleButtonState();
}

class _PCHomeBubbleButtonState extends State<_PCHomeBubbleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  bool _visible = false;
  Timer? _appearanceTimer;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.94,
      upperBound: 1.06,
    );

    _appearanceTimer = Timer(widget.delay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
      _breathController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _appearanceTimer?.cancel();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return SizedBox.square(dimension: widget.size);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // easeOutBack intentionally overshoots, but Opacity only accepts
        // values in the [0, 1] range.
        final double opacity = value.clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: 0.76 + (0.24 * value), child: child),
        );
      },
      child: ScaleTransition(
        scale: _breathController,
        child: ParticleButton(
          enabled: widget.enabled,
          onTap: widget.onTap,
          child: SizedBox.square(
            dimension: widget.size,
            child:
                widget.content ??
                (widget.iconName == 'pc_checkin_bubble'
                    ? PCCheckInBubble(size: widget.size)
                    : PCImg(
                        name: widget.iconName,
                        width: widget.size,
                        height: widget.size,
                      )),
          ),
        ),
      ),
    );
  }
}

class _HomeBroadcastTicker extends StatefulWidget {
  const _HomeBroadcastTicker({required this.fontSize, required this.iconSize});

  final double fontSize;
  final double iconSize;

  @override
  State<_HomeBroadcastTicker> createState() => _HomeBroadcastTickerState();
}

class _HomeBroadcastTickerState extends State<_HomeBroadcastTicker>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();

  late final AnimationController _controller;
  Timer? _timer;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _message = _randomMessage();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _randomMessage();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _randomMessage() {
    final String userId =
        '${10 + _random.nextInt(90)}***${10 + _random.nextInt(90)}';
    final amounts = PCNumberHelpers().pc_homeBroadcastAmounts;
    final int cash = amounts[_random.nextInt(amounts.length)];
    return 'Congrats! User $userId just cashed out \$$cash!';
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle messageStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w800,
      fontFamily: 'CarlsbergSansBlack',
      color: Colors.white,
      height: 1.15,
      decoration: TextDecoration.none,
    );

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: PCImg(name: 'pc_notice_bg')),
          Positioned(
            left: widget.iconSize * 0.45,
            top: 0,
            bottom: 0,
            child: Center(
              child: PCImg(
                name: 'pc_notice_icon',
                width: widget.iconSize,
                height: widget.iconSize,
              ),
            ),
          ),
          Positioned(
            left: widget.iconSize * 1.45,
            right: widget.iconSize * 0.55,
            top: 0,
            bottom: 0,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final TextPainter painter = TextPainter(
                        text: _messageSpan(messageStyle),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout();

                      final double startX = constraints.maxWidth;
                      final double endX = -painter.width;
                      final double dx =
                          startX + ((endX - startX) * _controller.value);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          child: _buildMessageText(messageStyle),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _messageSpan(TextStyle style) {
    final Match? amountMatch = RegExp(r'\$\d+').firstMatch(_message);
    if (amountMatch == null) {
      return TextSpan(text: _message, style: style);
    }

    final int start = amountMatch.start;
    final int end = amountMatch.end;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: _message.substring(0, start)),
        TextSpan(
          text: _message.substring(start, end),
          style: style.copyWith(color: const Color(0xFFFFDD1D)),
        ),
        TextSpan(text: _message.substring(end)),
      ],
    );
  }

  Widget _buildMessageText(TextStyle style) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = '#0B5C0E'.color();

    return Stack(
      alignment: Alignment.center,
      children: [
        Text.rich(
          _messageSpan(style.copyWith(foreground: strokePaint)),
          maxLines: 1,
          softWrap: false,
        ),
        Text.rich(_messageSpan(style), maxLines: 1, softWrap: false),
      ],
    );
  }
}

class PCHomeRankingSection extends StatelessWidget {
  const PCHomeRankingSection({
    super.key,
    required this.data,
    required this.scale,
  });

  final List<PCUserData> data;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => value * scale;

    final List<PCUserData> rest = data.skip(3).toList();

    return ListView.separated(
      padding: EdgeInsets.only(bottom: s(8)),
      itemCount: rest.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 0 : s(7)),
      itemBuilder: (context, index) {
        if (index == 0) {
          // 前三名和后续排名共用同一份当天数据，并一起滚动。
          return SizedBox(
            height: s(196),
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: s(320),
                height: s(180),
                child: Stack(
                  children: [
                    Positioned(
                      top: s(88),
                      left: 0,
                      child: PCImg(
                        name: 'pc_rank_bg',
                        width: s(320),
                        height: s(88),
                      ),
                    ),
                    Positioned(
                      top: s(28),
                      left: s(8),
                      width: s(88),
                      height: s(88),
                      child: _buildPodiumItem(context, 1, s(88), s(60)),
                    ),
                    Positioned(
                      top: s(40),
                      right: s(8),
                      width: s(88),
                      height: s(88),
                      child: _buildPodiumItem(context, 2, s(88), s(60)),
                    ),
                    Positioned(
                      top: 0,
                      right: (s(320) - s(100)) * 0.5,
                      width: s(100),
                      height: s(100),
                      child: _buildPodiumItem(context, 0, s(100), s(72)),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: s(88),
                      height: s(88),
                      child: Row(
                        children: [
                          for (final index in [1, 0, 2])
                            Expanded(
                              child: index >= data.length
                                  ? const SizedBox()
                                  : ParticleButton(
                                      key: ValueKey(
                                        'pcRankPedestal${index + 1}',
                                      ),
                                      onTap: () => PCPigShowDialog.show(
                                        context,
                                        user: data[index],
                                        users: data,
                                      ),
                                      child: const SizedBox.expand(
                                        child: ColoredBox(
                                          color: Colors.transparent,
                                        ),
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
          );
        }

        final int rowIndex = index - 1;
        return _HomeRankListTile(
          rank: rowIndex + 4,
          data: rest[rowIndex],
          scale: scale,
          onShowPig: () =>
              PCPigShowDialog.show(context, user: rest[rowIndex], users: data),
        );
      },
    );
  }

  Widget _buildPodiumAvatar(int index, double size) {
    if (index >= data.length) return const SizedBox.shrink();
    final user = data[index];
    return Semantics(
      label:
          'Rank ${index + 1}, ${user.username}, Total Earning: '
          '\$${user.totalEarning.toStringAsFixed(2)}, Ads Watched: ${user.adsWatched}',
      child: ClipOval(
        child: PCImg(
          key: ValueKey('pcRankAvatar${index + 1}'),
          name: user.avatarName,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPodiumItem(
    BuildContext context,
    int index,
    double frameSize,
    double avatarSize,
  ) {
    if (index >= data.length) return const SizedBox.shrink();
    return ParticleButton(
      key: ValueKey('pcRankPodium${index + 1}'),
      onTap: () =>
          PCPigShowDialog.show(context, user: data[index], users: data),
      child: Stack(
        children: [
          Center(child: _buildPodiumAvatar(index, avatarSize)),
          Center(
            child: PCImg(
              name: 'pc_${index + 1}_icon',
              width: frameSize,
              height: frameSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRankListTile extends StatelessWidget {
  const _HomeRankListTile({
    required this.rank,
    required this.data,
    required this.scale,
    required this.onShowPig,
  });

  final int rank;
  final PCUserData data;
  final double scale;
  final VoidCallback onShowPig;

  @override
  Widget build(BuildContext context) {
    double s(double value) => value * scale;

    return Container(
      key: ValueKey('pcRankRow$rank'),
      height: s(64),
      margin: EdgeInsets.symmetric(horizontal: s(8)),
      decoration: BoxDecoration(image: PCDImg('pc_rank_list_bg')),
      padding: EdgeInsets.symmetric(horizontal: s(12)),
      child: Row(
        children: [
          SizedBox(
            width: s(30),
            child: Center(
              child: PCStrokeText(
                text: '$rank',
                size: s(14),
                color: Colors.white,
                weight: FontWeight.w900,
                skWidth: 1.1,
                skColor: '#4A1800'.color(),
              ),
            ),
          ),
          SizedBox(
            width: s(44),
            height: s(44),
            child: ClipOval(
              child: PCImg(
                name: data.avatarName,
                fit: BoxFit.cover,
                width: s(44),
                height: s(44),
              ),
            ),
          ),
          SizedBox(width: s(8)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PCText(
                  text: data.username,
                  size: s(11),
                  color: Colors.white,
                  weight: FontWeight.w800,
                  maxLines: 1,
                  align: TextAlign.left,
                ),
                SizedBox(height: s(2)),
                _buildRankStat(
                  label: 'Total Earning:',
                  value: '\$${data.totalEarning.toStringAsFixed(2)}',
                  scale: scale,
                ),
                _buildRankStat(
                  label: 'Ads Watched:',
                  value: '${data.adsWatched}',
                  scale: scale,
                ),
              ],
            ),
          ),
          ParticleButton(
            key: ValueKey('pcRankShowPig$rank'),
            onTap: onShowPig,
            child: SizedBox(
              width: s(78),
              height: s(29),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: PCImg(name: 'pc_show_btn_bg')),
                  PCText(
                    text: 'Show Pig',
                    size: s(11),
                    color: Colors.white,
                    weight: FontWeight.w800,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankStat({
    required String label,
    required String value,
    required double scale,
  }) {
    final TextStyle style = TextStyle(
      fontSize: 9 * scale,
      fontWeight: FontWeight.w500,
      color: '#F9D6A2'.color(),
      height: 1.05,
    );
    final TextStyle valueStyle = style.copyWith(color: '#FFE12D'.color());

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label ', style: style),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
