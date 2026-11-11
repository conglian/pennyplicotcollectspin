import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCBasic/PCTbaBar.dart';
import '../../PCMainVC/PCWithdrawPage.dart';
import '../../PCTool/PCNewUserGuideController.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCAdOutcome.dart';
import '../../PCTool/PCQuizConfig.dart';
import '../../PCTool/pc_LocalProvider.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_text.dart';
import '../PCAward/PCAwardDialog.dart';
import '../PCCash/PCAccountFeedbackDialog.dart';
import '../PCCash/PCCongsDialog.dart';
import '../PCOther/PCDialogTool.dart';
import 'PCCheckInDialog.dart';
import 'PCGuideDialog.dart';
import 'PCGuideQuizDialog.dart';

/// 说明页之后的引导调度器；页面只负责展示，下一步及奖励全部由 Tool 控制。
/// 全屏遮罩阻止操作底层页面，普通提示的关闭和空白点击都会继续。
class PCNewUserHomeFlow extends StatefulWidget {
  const PCNewUserHomeFlow({super.key, required this.child, this.controller});
  final Widget child;
  final PCNewUserGuideController? controller;

  @override
  State<PCNewUserHomeFlow> createState() => _PCNewUserHomeFlowState();
}

class _PCNewUserHomeFlowState extends State<PCNewUserHomeFlow> {
  late final guide = widget.controller ?? PCNewUserGuideController.instance;
  MaterialPageRoute<PCWithdrawDetails>? _paymentRoute;

  Future<PCWithdrawDetails?> _collectPayment() {
    final submitted = Completer<PCWithdrawDetails>();
    final route = MaterialPageRoute<PCWithdrawDetails>(
      builder: (_) => PCWithdrawPage(
        isGuide: true,
        countryCode: Localizations.localeOf(context).countryCode ?? 'US',
        onSubmitted: (details) {
          if (!submitted.isCompleted) submitted.complete(details);
        },
      ),
    );
    _paymentRoute = route;
    final closed = Navigator.of(context).push(route);
    // 提交后保留表单作为官方通知背景；返回键则仍停留在资料确认步骤。
    return Future.any<PCWithdrawDetails?>([submitted.future, closed]);
  }

  Future<void> _restorePaymentBackground() async {
    if (_paymentRoute?.isActive ?? false) return;
    final route = MaterialPageRoute<PCWithdrawDetails>(
      builder: (_) => PCWithdrawPage(
        isGuide: true,
        trackExposure: false,
        countryCode: Localizations.localeOf(context).countryCode ?? 'US',
      ),
    );
    _paymentRoute = route;
    Navigator.of(context).push(route);
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<dynamic> _dialog(
    Widget child, {
    bool blankContinues = true,
    bool scaleContent = true,
    String? exposure,
    String? blankClickEvent,
    Map<String, dynamic> parameters = const {},
    bool Function()? canPresent,
  }) => context.tipShow2(
    Builder(
      builder: (dialogContext) => SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: blankContinues
              ? () {
                  if (ModalRoute.of(dialogContext)?.isCurrent != true) return;
                  if (blankClickEvent != null) {
                    PCAnalytics.event(blankClickEvent);
                  }
                  Navigator.of(dialogContext).pop();
                }
              : null,
          child: child,
        ),
      ),
    ),
    scaleContent: scaleContent,
    canPresent: canPresent,
    onPresented: exposure == null
        ? null
        : () async => PCAnalytics.event(exposure, parameters),
  );

  Future<bool> _claim(Future<bool> Function() action) async {
    final success = await action();
    if (success) await PCLocalProvider.instance.init();
    if (!success && mounted) {
      PCDialogTool.toast(context, 'Ad is not ready. Please try again.');
    }
    return success;
  }

  Future<PCAdOutcome> _claimNewUserCheckIn() async {
    final outcome = await guide.claimCheckInOutcome();
    if (outcome.isSuccess) await PCLocalProvider.instance.init();
    return outcome;
  }

  Future<void> _run() async {
    try {
      await guide.load();
      await PCLocalProvider.instance.init();
      while (mounted && guide.isIntroComplete && !guide.isComplete) {
        final stage = guide.stage;
        switch (stage) {
          case PCNewUserStage.welcome:
            PigsTabController.switchTo(0);
            await _dialog(
              const PCGuideDialog(),
              blankContinues: false,
              exposure: 'new_home_guide',
            );
          case PCNewUserStage.checkInPrompt:
            PigsTabController.switchTo(0);
            await _dialog(
              const PCGuide0Dialog(),
              exposure: 'new_sign_guide',
              blankClickEvent: 'new_sign_guide_c',
            );
          case PCNewUserStage.checkIn:
            await _dialog(
              PCCheckInDialog(
                rewards: guide.config.checkInRewards,
                day: guide.checkInDay,
                isNewUser: true,
                showAdBadge: true,
                onClaimOutcome: _claimNewUserCheckIn,
              ),
              blankContinues: false,
              exposure: 'new_sign_pop',
            );
          case PCNewUserStage.deposit:
            await _dialog(PCGuide1Dialog(depositAmount: guide.firstCommission));
          case PCNewUserStage.commission:
            await _dialog(
              PCGuide2Dialog(
                depositAmount: guide.firstCommission,
                remainingAmount: math.max(
                  0,
                  guide.config.withdrawalTarget - guide.balance,
                ),
              ),
              exposure: 'new_first_prize_pop',
            );
          case PCNewUserStage.quiz:
            PigsTabController.switchTo(1);
            final quizIndex = guide.quizIndex;
            await PCGuideQuizDialog.prepareForPresentation();
            if (!mounted ||
                guide.stage != stage ||
                guide.quizIndex != quizIndex) {
              return;
            }
            final correct = await _dialog(
              PCGuideQuizDialog(index: quizIndex),
              blankContinues: false,
              scaleContent: false,
              exposure: 'new_quiz_guide',
              canPresent: () =>
                  mounted &&
                  guide.stage == stage &&
                  guide.quizIndex == quizIndex &&
                  PigsTabController.currentIndex.value == 1,
            );
            if (!mounted ||
                guide.stage != stage ||
                guide.quizIndex != quizIndex) {
              return;
            }
            await guide.answerQuiz(correct: correct == true);
          case PCNewUserStage.quizReward:
            PigsTabController.switchTo(1);
            await _dialog(
              PCAwardDialog(
                award: guide.pendingPrize,
                adsEnabled: false,
                showAdBadge: false,
                withdrawalTarget: guide.config.withdrawalTarget,
                reward: guide.quizReward,
                paymentAsset:
                    'pc_act_${PCLocalProvider.instance.pc_account_seled_index.clamp(0, 3)}',
                remainingCollectible:
                    guide.quizReward.type == PCQuizRewardType.diamond
                    ? 20 - guide.diamonds
                    : 10 - guide.gold,
                onClaim: () {
                  PCAnalytics.event('new_quiz_correct_pop_c');
                  return _claim(guide.claimQuizReward);
                },
              ),
              blankContinues: false,
              exposure: 'new_quiz_correct_pop',
            );
          case PCNewUserStage.withdrawalEligibility:
            PigsTabController.switchTo(1);
            await _dialog(
              const PCCongsDialog(),
              exposure: 'new_confirm_account_pop',
            );
          case PCNewUserStage.payment:
            if (!mounted) return;
            final details = await _collectPayment();
            if (!mounted) return;
            if (details == null) continue;
            _displayConfirmedUser = details.account;
            await guide.confirmPayment(
              details.maskedAccount,
              paymentIndex: switch (details.method) {
                PCWithdrawMethod.paypal => 0,
                PCWithdrawMethod.pix => 1,
                PCWithdrawMethod.cashApp => 2,
                PCWithdrawMethod.pagBank => 3,
              },
            );
            await PCLocalProvider.instance.init();
          case PCNewUserStage.officialNotice:
            await _restorePaymentBackground();
            if (!mounted) return;
            await _dialog(
              PCAccountFeedbackDialog(
                onContinue: () => PCAnalytics.event('account_suc_pop_c'),
                maskedUserId: _displayConfirmedUser.isEmpty
                    ? guide.confirmedUser
                    : _displayConfirmedUser,
                remainingAmount: math.max(
                  0,
                  guide.config.withdrawalTarget - guide.balance,
                ),
              ),
              exposure: 'account_suc_pop',
            );
            if (!mounted) return;
            final route = _paymentRoute;
            if (route != null && route.isActive) {
              Navigator.of(context).removeRoute(route);
            }
            _paymentRoute = null;
            PigsTabController.switchTo(0);
          case PCNewUserStage.growBonus:
            PigsTabController.switchTo(0);
            await _dialog(
              PCGuide3Dialog(
                savedAmount: guide.balance,
                growPercent: guide.config.growPercent,
              ),
              exposure: 'grow_bonus_pop',
              parameters: const {'pop_from': 'new'},
            );
          case PCNewUserStage.wheelPrompt:
            await _dialog(const PCWheelGuideDialog());
          case PCNewUserStage.complete:
            break;
        }
        if (!mounted) return;
        await guide.advance(stage);
        if (guide.isComplete) {
          await PCLocalProvider.instance.init();
          PigsTabController.switchTo(2);
        }
      }
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(
          context,
          'Unable to save progress. Tap to try again.',
        );
        setState(() => _failed = true);
      }
    }
  }

  bool _failed = false;
  String _displayConfirmedUser = '';

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_failed)
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _run();
                },
                child: const PCText(
                  text: 'Tap to try again',
                  size: 18,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
