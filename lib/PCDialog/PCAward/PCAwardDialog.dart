import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCInterstitialAdService.dart';
import '../../PCTool/PCNumberManager.dart';
import '../../PCTool/PCQuizConfig.dart';
import '../../PCTool/PCRewardedAdService.dart';
import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCAdLoadingFailedDialog.dart';
import '../PCOther/PCDialogTool.dart';
import 'PCCollectibleAwardDialog.dart';
export 'PCAwardOpenDialog.dart';

/// 美元领奖按钮的广告规则；首页普通气泡使用概率插屏。
enum PCAwardClaimAdPolicy { rewarded, probabilityInterstitial }

/// 奖励领取弹窗：美元沿用 Left To Withdraw，钻石与金砖使用独立的转盘设计。
/// 钻石 Collect 领原奖励，Give Up 放弃；金砖激励领双倍，底部 Claim 领原奖励。
/// 美元沿用各入口的广告规则；钻石和金砖主按钮统一播放激励。
/// 关闭按配置概率播放插屏；答题和转盘通过 [onAbandon] 先放弃当前待奖。
/// 激励失败也先清理待奖，再切换同一路由的失败面板。
class PCAwardDialog extends StatefulWidget {
  const PCAwardDialog({
    super.key,
    required this.award,
    this.withdrawalTarget = 100,
    this.reward,
    this.onClaim,
    this.onDoubleClaim,
    this.onClaimAdFailed,
    this.onAbandon,
    this.balance,
    this.paymentAsset = 'pc_act_0',
    this.remainingCollectible,
    this.collectibleCount,
    this.showAdBadge = true,
    this.adsEnabled = true,
    this.claimAdPolicy = PCAwardClaimAdPolicy.rewarded,
    this.claimAdPlacement = 'rv',
    this.claimInterstitialAdPlacement,
    this.closeAdPlacement = 'int',
    this.analyticsSource,
  });

  /// 普通答题/转盘的事件来源；首页及新手不传，避免混入普通激励弹窗。
  final String? analyticsSource;
  final double award;

  /// 当前配置的首档提现门槛；Only文案显示此值减去美元余额后的差额。
  final double withdrawalTarget;
  final PCQuizReward? reward;
  final Future<bool> Function()? onClaim;

  /// 金砖主按钮激励成功后的双倍入账；用原奖励 ID 结算。
  final Future<bool> Function()? onDoubleClaim;

  /// 兼容旧调用的激励失败清理；先完成持久化，再显示原路由失败面板。
  final Future<void> Function()? onClaimAdFailed;

  /// 用户关闭或激励失败时放弃这一笔待奖，调用方须绑定当前 rewardId。
  /// 同一弹窗仅执行一次；关闭插屏开始前、路由退出前均等待持久化完成。
  /// 首页及新用户未传入时保持原有奖励策略，成功领取不会调用此回调。
  final Future<void> Function()? onAbandon;
  final double? balance;
  final String paymentAsset;

  /// [collectibleCount] 为当前数量，包含超目标的真实进度。
  /// 仅在没有完整数量时使用 [remainingCollectible] 推算进度。
  final double? remainingCollectible;
  final double? collectibleCount;

  /// 新用户三题引导设为 false：Claim直接结算，关闭直接退出，均不播放广告。
  final bool adsEnabled;
  final PCAwardClaimAdPolicy claimAdPolicy;
  final String claimAdPlacement;

  /// 仅在普通 Claim 需要独立广告位时传入，默认复用当前来源的插屏标记。
  final String? claimInterstitialAdPlacement;
  final String closeAdPlacement;

  /// 控制原版弹窗的 AD 角标。转盘样式的钻石和金砖主按钮自带角标。
  final bool showAdBadge;

  /// 转盘原稿钻石和金砖画板的遮罩为 80% 黑色，美元使用默认遮罩。
  static Color? backdropFor(PCQuizRewardType type) =>
      type == PCQuizRewardType.cash ? null : const Color(0xCC000000);

  @override
  State<PCAwardDialog> createState() => _PCAwardDialogState();
}

class _PCAwardDialogState extends State<PCAwardDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _claiming = false;
  bool _closing = false;
  bool _adFailed = false;
  Future<void>? _abandonment;
  bool get _busy => _claiming || _closing;
  bool get _usesCollectibleActions =>
      widget.adsEnabled &&
      widget.reward != null &&
      widget.reward!.type != PCQuizRewardType.cash;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _light.stop();
    } else if (!_light.isAnimating) {
      _light.repeat();
    }
  }

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  Future<void> _claim({bool singleGold = false}) async {
    if (_busy || _adFailed) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    final navigator = Navigator.of(context);
    final rewarded =
        widget.adsEnabled &&
        !singleGold &&
        (_usesCollectibleActions ||
            widget.claimAdPolicy == PCAwardClaimAdPolicy.rewarded);
    final doubleGold =
        _usesCollectibleActions &&
        rewarded &&
        widget.reward?.type == PCQuizRewardType.gold;
    _track('double_pop_c', withSource: true);
    setState(() => _claiming = true);
    try {
      final outcome = await _completeClaimAd(
        route,
        rewarded: rewarded,
        singleGold: singleGold,
      );
      if (!outcome.isSuccess) {
        if (rewarded) {
          // 即使用户已切页或路由退出，也清理原奖励，迟到回调不能让待奖复活。
          try {
            await _abandonReward();
            if (outcome == PCAdOutcome.failed) {
              await widget.onClaimAdFailed?.call();
            }
          } catch (error) {
            debugPrint('Reward ad failure cleanup: $error');
          }
        }
        if (!mounted || route?.isCurrent != true) return;
        if (outcome == PCAdOutcome.cancelled) {
          // 正常取消不发奖，退出本次待奖；不再补播关闭插屏或提示播放失败。
          _dismiss(route, navigator, false);
          return;
        }
        setState(() => _adFailed = true);
        return;
      }
      if (!mounted || route?.isCurrent != true) return;
      final settle = doubleGold ? widget.onDoubleClaim : widget.onClaim;
      if (doubleGold && settle == null) {
        throw StateError('Missing double claim handler');
      }
      final claimed = await settle?.call() ?? true;
      if (claimed) _dismiss(route, navigator, true);
    } catch (_) {
      if (mounted && route?.isCurrent == true) {
        PCDialogTool.toast(
          context,
          'Unable to save progress. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<PCAdOutcome> _completeClaimAd(
    Route<dynamic>? route, {
    required bool rewarded,
    required bool singleGold,
  }) async {
    if (!widget.adsEnabled) return PCAdOutcome.success;
    if (rewarded) {
      return PCRewardedAdService.instance.requestOutcome(
        widget.claimAdPlacement,
      );
    }
    try {
      final numbers = PCNumberHelpers();
      await numbers.pc_initNumberModel();
      if (!mounted || route?.isCurrent != true) return PCAdOutcome.cancelled;
      if (numbers.pc_checkProbability()) {
        // 概率插屏失败或未就绪时仍结算单倍奖励。
        // 等待原生广告完整退出，保持领奖和关闭互斥及本地弹窗串行。
        await PCInterstitialAdService.instance.requestOutcome(
          singleGold
              ? widget.closeAdPlacement
              : widget.claimInterstitialAdPlacement ?? widget.closeAdPlacement,
        );
      }
    } catch (error) {
      debugPrint('Reward claim interstitial: $error');
    }
    return PCAdOutcome.success;
  }

  Future<void> _close() async {
    if (_busy) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    final navigator = Navigator.of(context);
    if (!_adFailed) _track('double_pop_close');
    setState(() => _closing = true);
    try {
      // 先落盘放弃；原生插屏期间进程退出也不能恢复已关闭的奖励。
      await _abandonReward();
      if (_adFailed || !widget.adsEnabled) return;
      final numbers = PCNumberHelpers();
      await numbers.pc_initNumberModel();
      if (!mounted || route?.isCurrent != true) return;
      if (numbers.pc_checkProbability()) {
        // 保留当前弹窗的展示权到原生插屏关闭，避免其他本地弹窗抢先覆盖。
        await PCInterstitialAdService.instance.request(widget.closeAdPlacement);
      }
    } catch (error) {
      debugPrint('Reward close ad: $error');
    } finally {
      _dismiss(route, navigator, false);
    }
  }

  Future<void> _abandonReward() =>
      _abandonment ??= Future<void>.sync(() => widget.onAbandon?.call());

  void _dismiss(Route<dynamic>? route, NavigatorState navigator, bool result) {
    if (!mounted ||
        !navigator.mounted ||
        route == null ||
        route.navigator != navigator ||
        !route.isActive) {
      return;
    }
    // 只退出自己的奖励路由，原生广告的迟到回调不能pop后来打开的页面。
    if (route.isCurrent) {
      navigator.pop(result);
    } else {
      navigator.removeRoute(route, result);
    }
  }

  Widget _text(
    String text,
    double size, {
    Color color = Colors.white,
    int lines = 1,
  }) => PCText(
    text: text,
    size: size,
    color: color,
    weight: FontWeight.w700,
    maxLines: lines,
    align: TextAlign.center,
  );

  Widget _withdrawalSummary(double balance) {
    // 美元差额以当前现金和首档门槛计算。
    final remaining = math.max(0.0, widget.withdrawalTarget - balance);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: PCText(
        key: const ValueKey('pcAwardWithdrawalSummary'),
        text: 'Only ',
        size: 20,
        color: Colors.white,
        weight: FontWeight.w700,
        height: 32 / 20,
        align: TextAlign.center,
        spans: [
          TextSpan(
            text: '\$${PCQuizReward.format(remaining)}',
            style: TextStyle(
              foreground: Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [.1875, .796875],
                  colors: [Color(0xFFFFDF28), Color(0xFFFFA11E)],
                ).createShader(const Rect.fromLTWH(0, 0, 1, 32)),
            ),
          ),
          const TextSpan(text: ' Left To Withdraw'),
        ],
      ),
    );
  }

  void _track(String event, {bool withSource = false}) {
    final source = widget.analyticsSource;
    if (source != 'quiz' && source != 'wheel') return;
    PCAnalytics.event(event, withSource ? {'pop_from': source} : const {});
  }

  @override
  Widget build(BuildContext context) {
    final dialog = _buildDialog(context);
    final source = widget.analyticsSource;
    if (source != 'quiz' && source != 'wheel') return dialog;
    return PCAnalyticsExposure(
      event: 'double_pop',
      parameters: {'pop_from': source},
      child: dialog,
    );
  }

  Widget _buildDialog(BuildContext context) {
    final provider = PCLocalProvider.instance;
    final balance = widget.balance ?? provider.pc_dollar_number;
    final type = widget.reward?.type ?? PCQuizRewardType.cash;
    final collectible = type != PCQuizRewardType.cash;
    final amount = PCQuizReward.format(widget.award);
    final remainingCollectible = widget.remainingCollectible;
    final collectibleTarget = type == PCQuizRewardType.diamond
        ? PCQuizConfig.diamondTarget
        : PCQuizConfig.goldTarget;
    final collected =
        widget.collectibleCount ??
        (remainingCollectible != null
            ? math.max(0.0, collectibleTarget - remainingCollectible)
            : provider.pc_pig_level == type.index
            ? provider.pc_pig_level_index
            : 0.0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: _adFailed
          ? PCAdLoadingFailedDialog(onClose: () => unawaited(_close()))
          : _usesCollectibleActions
          ? PCCollectibleAwardDialog(
              type: type,
              amount: widget.award,
              collected: collected,
              withdrawalTarget: widget.withdrawalTarget,
              paymentAsset: widget.paymentAsset,
              lightRotation: _light,
              busy: _busy,
              onRewardedClaim: _claim,
              onSecondaryAction: type == PCQuizRewardType.gold
                  ? () => unawaited(_claim(singleGold: true))
                  : _close,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final padding = MediaQuery.paddingOf(context);
                final top = math.max(
                  padding.top + 8,
                  constraints.maxHeight * 80 / 812,
                );
                final scale = PCAdaptiveLayout.fitScale(
                  width: constraints.maxWidth - 16,
                  height: constraints.maxHeight - top - padding.bottom - 12,
                  designHeight: 602,
                );
                return SizedBox.expand(
                  child: Stack(
                    children: [
                      Positioned(
                        left: (constraints.maxWidth - 360 * scale) / 2,
                        top: top,
                        width: 360 * scale,
                        height: 602 * scale,
                        child: FittedBox(
                          child: SizedBox(
                            width: 360,
                            height: 602,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 20,
                                  top: 110,
                                  width: 320,
                                  height: 492,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Positioned.fill(
                                        child: PCImg(name: 'pc_awards_bg'),
                                      ),
                                      Positioned(
                                        left: 16,
                                        top: 15,
                                        width: 288,
                                        height: 47,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            gradient: const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0xFFFFFDF0),
                                                Color(0xFFFFF09B),
                                              ],
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              PCImg(
                                                name: widget.paymentAsset,
                                                width: 36,
                                                height: 36,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: _text(
                                                    'Payment',
                                                    16,
                                                    color: const Color(
                                                      0xFF0046A0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const PCImg(
                                                name: 'pc_dui_1_icon',
                                                width: 12,
                                                height: 12,
                                              ),
                                              const Spacer(),
                                              _text(
                                                'My Cash: ',
                                                12,
                                                color: const Color(0xFF6F4B1D),
                                              ),
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: _text(
                                                    '\$${PCQuizReward.format(balance)}',
                                                    18,
                                                    color: const Color(
                                                      0xFF00A51A,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        top: 72,
                                        height: 32,
                                        child: _withdrawalSummary(balance),
                                      ),
                                      Positioned(
                                        left: 90,
                                        top: 104,
                                        width: 140,
                                        height: 140,
                                        child: RotationTransition(
                                          turns: _light,
                                          child: const PCImg(
                                            name: 'pc_guang_s',
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: collectible ? 110 : 60,
                                        top: collectible ? 124 : 128,
                                        width: collectible ? 100 : 200,
                                        height: collectible ? 100 : 92,
                                        // 主图使用100逻辑像素对应的300px原生图，不能放大48px顶部图标。
                                        child: PCImg(
                                          key: const ValueKey('pcAwardArtwork'),
                                          name: switch (type) {
                                            PCQuizRewardType.cash =>
                                              'pc_quiz_cash_reward',
                                            PCQuizRewardType.diamond =>
                                              'pc_award_diamond',
                                            PCQuizRewardType.gold =>
                                              'pc_award_gold',
                                          },
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        top: 248,
                                        child: PCStrokeText(
                                          text: collectible
                                              ? '×$amount'
                                              : '+\$$amount',
                                          size: 32,
                                          color: const Color(0xFFFFB800),
                                          weight: FontWeight.w900,
                                          skWidth: 2,
                                          skColor: const Color(0xFF4B4B00),
                                        ),
                                      ),
                                      for (final row in [
                                        (296.0, 'Ensure safety'),
                                        (328.0, 'Arrived within 24 hours'),
                                        (360.0, '1M+ user trusted'),
                                      ])
                                        Positioned(
                                          left: 60,
                                          right: 16,
                                          top: row.$1,
                                          height: 24,
                                          child: Row(
                                            children: [
                                              const PCImg(
                                                name: 'pc_dui_0_icon',
                                                width: 24,
                                                height: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: PCText(
                                                  text: row.$2,
                                                  size: 16,
                                                  color: Colors.white,
                                                  weight: FontWeight.w500,
                                                  height: 1.5,
                                                  align: TextAlign.left,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Positioned(
                                        left: 26,
                                        top: 404,
                                        width: 268,
                                        height: 64,
                                        child: IgnorePointer(
                                          ignoring: _busy,
                                          child: ParticleButton(
                                            key: const ValueKey(
                                              'pcQuizClaimReward',
                                            ),
                                            onTap: _claim,
                                            breathing: !_busy,
                                            child: SizedBox.expand(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: PCImg(
                                                      name: 'pc_btn_bg',
                                                    ),
                                                  ),
                                                  PCStrokeText(
                                                    text: _claiming
                                                        ? 'Claiming...'
                                                        : 'Claim',
                                                    size: 27,
                                                    color: Colors.white,
                                                    weight: FontWeight.w800,
                                                    skWidth: 3,
                                                    skColor: const Color(
                                                      0xFF173600,
                                                    ),
                                                  ),
                                                  if (widget.showAdBadge &&
                                                      widget.claimAdPolicy ==
                                                          PCAwardClaimAdPolicy
                                                              .rewarded)
                                                    const Positioned(
                                                      right: 0,
                                                      top: 0,
                                                      child: PCImg(
                                                        name: 'pc_ad_icon',
                                                        width: 20,
                                                        height: 20,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -5,
                                        top: -6,
                                        child: ParticleButton(
                                          key: const ValueKey(
                                            'pcQuizCloseReward',
                                          ),
                                          enabled: !_busy,
                                          onTap: _close,
                                          child: const PCImg(
                                            name: 'pc_closes_btn',
                                            width: 24,
                                            height: 24,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Positioned(
                                  left: 0,
                                  top: 0,
                                  width: 360,
                                  height: 80,
                                  child: PCImg(name: 'pc_awards_top'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
