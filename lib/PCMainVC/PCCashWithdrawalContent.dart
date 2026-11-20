import '../PCTool/PCProgressMotion.dart';
import '../PCTool/PCWithdrawValidation.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../PCDialog/PCWithdrawFlow/PCWithdrawalDialogWidgets.dart';
import '../PCTool/PCNumberManager.dart';
import '../PCTool/PCQuizConfig.dart';
import '../PCTool/PCWithdrawalController.dart';
import '../PCTool/PCWithdrawalQueueTable.dart';
import '../PCTool/pc_GradientText.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_stroke_text.dart';
import '../PCTool/pc_text.dart';

/// 现金页和排队弹窗共用的稳定本地展示行，不修改真实排队人数与名次。
class PCCashQueueEntry {
  const PCCashQueueEntry(this.userId, this.account, this.amount);
  final String userId, account;
  final double amount;
}

List<PCCashQueueEntry> pcCashQueueEntries({
  required int seed,
  required double target,
  int count = 4,
}) {
  final random = math.Random(seed);
  final amounts = PCNumberHelpers().pc_eqRange;
  return List.generate(
    math.max(0, count),
    (i) => PCCashQueueEntry(
      '${i + 1}'.padLeft(3, '0'),
      'Player ${100 + random.nextInt(900)}',
      amounts[random.nextInt(amounts.length)].toDouble(),
    ),
  );
}

/// 提现页的首档状态卡：未满20收集钻石、达标后午夜倒计时、金砖放款、排队和循环任务。
/// 金额、收集量、排队及任务均读控制器；卡片只呈现数据并转交点击行为。
class PCCashWithdrawalContent extends StatelessWidget {
  const PCCashWithdrawalContent({
    super.key,
    required this.controller,
    required this.scale,
    required this.account,
    required this.paymentIndex,
    required this.notificationEnabled,
    required this.busy,
    required this.onCollect,
    required this.onReminder,
    required this.onQueue,
    required this.onTask,
  });
  final PCWithdrawalController controller;
  final double scale;
  final String account;
  final int paymentIndex;
  final bool notificationEnabled, busy;
  final VoidCallback onCollect, onReminder, onQueue, onTask;
  double s(double value) => value * scale;

  Widget text(
    String value,
    double size, {
    Color color = Colors.black,
    FontWeight weight = FontWeight.w500,
    int lines = 1,
    TextAlign? align,
  }) => PCText(
    text: value,
    size: s(size),
    color: color,
    weight: weight,
    maxLines: lines,
    align: align,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('pcCashStage_${controller.stage.name}'),
    padding: EdgeInsets.all(s(12)),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(s(8)),
    ),
    child: switch (controller.stage) {
      PCWithdrawalStage.reviewing => _reviewing(),
      PCWithdrawalStage.reviewApproved => _approved(),
      PCWithdrawalStage.releasing => _releasing(),
      PCWithdrawalStage.queue => _queue(),
      PCWithdrawalStage.lastStep => _task(),
      PCWithdrawalStage.insufficient => const SizedBox.shrink(),
    },
  );

  Widget _heading(
    String subtitle, {
    bool checked = false,
    bool queue = false,
  }) => Row(
    children: [
      text(
        '\$${PCQuizReward.format(controller.target)}',
        24,
        weight: FontWeight.w800,
      ),
      SizedBox(width: s(8)),
      Expanded(
        child: text(
          subtitle,
          12,
          color: const Color(0xFF8A8A8A),
          weight: FontWeight.w400,
          lines: 2,
        ),
      ),
      if (checked || queue) ...[
        SizedBox(width: s(6)),
        PCImg(
          name: queue ? 'pc_cash_queue_people' : 'pc_process_review_check',
          size: s(queue ? 16 : 24),
        ),
      ],
    ],
  );

  Widget _action(
    String label,
    String key,
    VoidCallback action, {
    bool green = true,
    bool ad = false,
  }) => PCCashActionButton(
    key: ValueKey(key),
    text: label,
    onTap: action,
    scale: scale,
    green: green,
    enabled: !busy && !controller.isBusy,
    ad: ad,
  );

  Widget _reviewing() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Review Task'),
      SizedBox(height: s(10)),
      text('Diamonds', 14),
      SizedBox(height: s(6)),
      PCCashProgress(
        key: const ValueKey('pcCashDiamondProgress'),
        value: controller.diamonds / 20,
        count: '${PCQuizReward.format(controller.diamonds)}/20',
        scale: scale,
        diamond: true,
      ),
      SizedBox(height: s(10)),
      text(
        'Collect 20 Diamonds To Speed Up Your \$${PCQuizReward.format(controller.target)} Approval.',
        12,
        color: const Color(0xFF626262),
        weight: FontWeight.w400,
        lines: 2,
        align: TextAlign.center,
      ),
      SizedBox(height: s(16)),
      _action('Collect Diamonds', 'pcCashCollectDiamonds', onCollect),
    ],
  );

  Widget _approved() {
    final remaining = controller.midnightRemaining;
    String two(int value) => value.toString().padLeft(2, '0');
    final countdown =
        '${two(remaining.inHours)}:${two(remaining.inMinutes.remainder(60))}:${two(remaining.inSeconds.remainder(60))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Review Completed', checked: true),
        SizedBox(height: s(8)),
        text(
          'Come Back Tomorrow To Confirm Release Details.',
          12,
          lines: 2,
          color: const Color(0xFF393939),
        ),
        SizedBox(height: s(12)),
        Container(
          key: const ValueKey('pcCashCountdownPanel'),
          padding: EdgeInsets.symmetric(horizontal: s(8), vertical: s(12)),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(s(4)),
          ),
          child: Column(
            children: [
              text(
                'Release Opens Tomorrow',
                16,
                weight: FontWeight.w700,
                align: TextAlign.center,
              ),
              SizedBox(height: s(8)),
              Semantics(
                label: countdown,
                child: PCGradientStrokeText(
                  key: const ValueKey('pcCashCountdownNumber'),
                  text: countdown,
                  width: s(240),
                  height: s(40),
                  fontSize: s(32).round(),
                  strokeWidth: s(1.5),
                  strokeColor: const Color(0xFF704300),
                  gradientColors: const [Color(0xFFFFE449), Color(0xFFFFAF00)],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: s(16)),
        text(
          'Collect 20 Diamonds To Speed Up Your \$${PCQuizReward.format(controller.target)} Approval.',
          12,
          color: const Color(0xFF626262),
          weight: FontWeight.w400,
          lines: 2,
          align: TextAlign.center,
        ),
        SizedBox(height: s(16)),
        _action(
          notificationEnabled ? 'Open Tomorrow' : 'Remind Me Tomorrow',
          'pcCashRemindTomorrow',
          onReminder,
        ),
      ],
    );
  }

  Widget _releasing() {
    final date = controller.diamondDeadline ?? DateTime.now();
    Widget row(String title, Widget value) => Padding(
      padding: EdgeInsets.symmetric(vertical: s(3)),
      child: Row(
        children: [
          text(
            title,
            14,
            color: const Color(0xFF13395F),
            weight: FontWeight.w600,
          ),
          SizedBox(width: s(12)),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Release details confirmed', checked: true),
        SizedBox(height: s(8)),
        text(
          'Come Back Tomorrow To Confirm Release Details.',
          12,
          color: const Color(0xFF393939),
          lines: 2,
        ),
        SizedBox(height: s(12)),
        Container(
          key: const ValueKey('pcCashReleaseAccount'),
          padding: EdgeInsets.all(s(12)),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(s(4)),
          ),
          child: Column(
            children: [
              row(
                'Method:',
                PCImg(
                  name: paymentIndex == 0
                      ? 'pc_pig_upgrade_paypal'
                      : 'pc_act_$paymentIndex',
                  width: s(paymentIndex == 0 ? 66 : 24),
                  height: s(24),
                  fit: BoxFit.contain,
                ),
              ),
              row(
                'Account:',
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: text(
                    PCWithdrawValidation.displayAccount(
                      account,
                      fallback: 'Not set',
                    ),
                    14,
                  ),
                ),
              ),
              row('Date:', text('${date.month}/${date.day}/${date.year}', 14)),
            ],
          ),
        ),
        SizedBox(height: s(12)),
        Container(
          key: const ValueKey('pcCashGoldCard'),
          padding: EdgeInsets.all(s(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(4)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF6D5), Color(0xFFFFE59A)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PCImg(name: 'pc_zhuan_icons', size: s(36)),
                  SizedBox(width: s(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        text(
                          'Golden Brick Boost',
                          16,
                          color: const Color(0xFF704300),
                          weight: FontWeight.w600,
                        ),
                        SizedBox(height: s(4)),
                        text(
                          'Collect 10 Golden Bricks To Speed Up Release.',
                          11,
                          color: const Color(0xFF9B620C),
                          weight: FontWeight.w400,
                          lines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: s(8)),
              PCCashProgress(
                key: const ValueKey('pcCashGoldProgress'),
                value: controller.gold / 10,
                count: '${PCQuizReward.format(controller.gold)}/10',
                scale: scale,
                gold: true,
              ),
              SizedBox(height: s(12)),
              _action(
                'Collect 10 Golden Brick',
                'pcCashCollectGold',
                onCollect,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _queue() {
    final total = math.max(1, controller.queueTotal);
    final rank = controller.queueRank.clamp(1, total);
    final progress = (1 - (rank - 1) / math.max(1, total - 1)).clamp(0.0, 1.0);
    final rows =
        pcCashQueueEntries(
              seed: controller.queueSeed,
              target: controller.target,
              count: total,
            )
            .map(
              (entry) => PCWithdrawalQueueEntry(
                userId: entry.userId,
                account: entry.account,
                amount: entry.amount,
              ),
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Release successful, currently in queue', queue: true),
        SizedBox(height: s(10)),
        Row(
          children: [
            text('Queue Progress', 12),
            SizedBox(width: s(6)),
            Expanded(
              child: PCCashProgress(
                key: const ValueKey('pcCashQueueProgress'),
                value: progress,
                count: '${(progress * 100).round()}%',
                scale: scale,
              ),
            ),
          ],
        ),
        SizedBox(height: s(16)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: text(
            '$total In Queue, Your Current Rank: $rank',
            14,
            weight: FontWeight.w600,
          ),
        ),
        SizedBox(height: s(8)),
        PCWithdrawalQueueTable(
          key: const ValueKey('pcCashQueueTable'),
          currentRank: rank,
          queueCount: total,
          entries: rows,
          scale: scale,
          currentAccount: account,
          currentAmount: controller.target,
        ),
        SizedBox(height: s(16)),
        _action(
          'Skip Wait',
          'pcCashSkipQueue',
          onQueue,
          green: false,
          ad: true,
        ),
      ],
    );
  }

  Widget _task() {
    final task = controller.currentTask;
    final description = switch (task.title) {
      'spin' =>
        'Spin ${controller.taskProgress}/${controller.taskTarget} Times',
      'video' =>
        'Watch ${controller.taskProgress}/${controller.taskTarget} Videos',
      _ =>
        'Answer ${controller.taskProgress}/${controller.taskTarget} Question Right',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Final Step! Complete the final task to release your cash'),
        SizedBox(height: s(12)),
        Container(
          key: const ValueKey('pcCashTaskPanel'),
          padding: EdgeInsets.all(s(12)),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(s(4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  text('Final Task:', 14),
                  SizedBox(width: s(8)),
                  Expanded(
                    child: PCStrokeText(
                      key: const ValueKey('pcCashTaskDescription'),
                      text: description,
                      size: s(12),
                      color: const Color(0xFFFFDD1D),
                      weight: FontWeight.w700,
                      skWidth: s(1.5),
                      skColor: const Color(0xFF704300),
                      maxLines: 2,
                      align: TextAlign.left,
                    ),
                  ),
                ],
              ),
              SizedBox(height: s(8)),
              PCCashProgress(
                key: const ValueKey('pcCashTaskProgress'),
                value:
                    controller.taskProgress /
                    math.max(1, controller.taskTarget),
                count: '${controller.taskProgress}/${controller.taskTarget}',
                scale: scale,
                highlightCount: true,
              ),
            ],
          ),
        ),
        SizedBox(height: s(16)),
        _action(
          'GO',
          'pcCashTaskGo',
          onTask,
          green: false,
          ad: task.title == 'video',
        ),
      ],
    );
  }
}

/// 提现页复用的蓝/绿渐变按钮，视觉层填满点击框，广告角标独立叠放。
class PCCashActionButton extends StatelessWidget {
  const PCCashActionButton({
    super.key,
    required this.text,
    required this.onTap,
    this.scale = 1,
    this.green = false,
    this.enabled = true,
    this.ad = false,
    this.height = 36,
  });
  final String text;
  final VoidCallback onTap;
  final double scale, height;
  final bool green, enabled, ad;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height * scale,
    child: ParticleButton(
      enabled: enabled,
      onTap: onTap,
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                key: const ValueKey('pcCashActionBackground'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height * scale / 2),
                  gradient: LinearGradient(
                    colors: green
                        ? const [Color(0xFF21BE5B), Color(0xFF019B3A)]
                        : const [Color(0xFF1486F8), Color(0xFF2365EA)],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PCText(
                        text: text,
                        size: 14 * scale,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (ad)
              Positioned(
                right: 0,
                top: -2 * scale,
                child: PCImg(name: 'pc_ad_icon', size: 20 * scale),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 独立进度轨道、填充、钻石游标与数量；零值不绘制填充，游标不会越出轨道。
class PCCashProgress extends StatelessWidget {
  const PCCashProgress({
    super.key,
    required this.value,
    required this.count,
    this.scale = 1,
    this.diamond = false,
    this.gold = false,
    this.highlightCount = false,
  });
  final double value, scale;
  final String count;
  final bool diamond, gold, highlightCount;
  @override
  Widget build(BuildContext context) {
    final target = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: 24 * scale,
      child: Row(
        children: [
          Expanded(
            child: PCProgressMotion(
              value: target,
              builder: (_, progress, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 16 * scale,
                        decoration: BoxDecoration(
                          color: gold
                              ? const Color(0xFFD9C386)
                              : const Color(0xFFE4E4E4),
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                      ),
                      if (progress > 0)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2 * scale),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6 * scale),
                            child: SizedBox(
                              width:
                                  math.max(0, trackWidth - 4 * scale) *
                                  progress,
                              height: 12 * scale,
                              child: diamond
                                  ? const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF2EEFFC),
                                            Color(0xFF1162F9),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const PCImg(name: 'pc_cash_progress_fill'),
                            ),
                          ),
                        ),
                      if (diamond)
                        Positioned(
                          left: (trackWidth * progress - 12 * scale).clamp(
                            0.0,
                            math.max(0.0, trackWidth - 24 * scale),
                          ),
                          child: PCImg(
                            name: 'pc_stage_progress_diamond',
                            size: 24 * scale,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          if (diamond || gold || highlightCount)
            PCStrokeText(
              key: const ValueKey('pcCashProgressCount'),
              text: count,
              size: 12 * scale,
              color: const Color(0xFFFFDD1D),
              weight: FontWeight.w700,
              skWidth: 1.5 * scale,
              skColor: const Color(0xFF704300),
              align: TextAlign.right,
            )
          else
            PCText(
              text: count,
              size: 12 * scale,
              color: const Color(0xFF626262),
              weight: FontWeight.w600,
            ),
        ],
      ),
    );
  }
}
