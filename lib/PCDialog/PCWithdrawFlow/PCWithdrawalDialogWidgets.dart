import 'package:flutter/material.dart';

import '../../PCTool/PCNoticeMessage.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCOtherDialogWidgets.dart';

/// 提现流程的响应式白卡；只负责布局，不管理提现状态。
class PCWithdrawalWhiteCard extends StatelessWidget {
  const PCWithdrawalWhiteCard({
    super.key,
    required this.height,
    required this.title,
    required this.children,
    this.onClose,
    this.extraHeight = 0,
  });
  final double height;
  final String title;
  final List<Widget> children;
  final VoidCallback? onClose;
  final double extraHeight;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: PCResponsiveDialog(
      designHeight: height + extraHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          key: const ValueKey('pcWithdrawalWhitePanel'),
          width: 304,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ...children,
                Positioned(
                  top: 16,
                  left: 36,
                  right: 36,
                  height: title.contains('\n') ? 48 : 24,
                  child: PCText(
                    text: title,
                    size: 18,
                    color: Colors.black,
                    weight: FontWeight.w600,
                    maxLines: 2,
                    height: 24 / 18,
                    align: TextAlign.center,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  width: 48,
                  height: 48,
                  child: ParticleButton(
                    key: const ValueKey('pcWithdrawalClose'),
                    onTap: onClose ?? () {},
                    enabled: onClose != null,
                    // 24px图标居中于48px点击区，中心与标题同在顶部28px。
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: onClose == null
                            ? Colors.transparent
                            : const Color(0xFF999999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 审核、排队与任务卡共用的 PayPal 金额卡，金额保持动态。
class PCWithdrawalPaymentCard extends StatelessWidget {
  const PCWithdrawalPaymentCard({
    super.key,
    required this.amount,
    this.insufficient = false,
  });
  final double amount;
  final bool insufficient;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(11.636),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2762CC), Color(0xFF003087)],
        ),
      ),
      child: SizedBox(
        width: 180,
        height: 116,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 48,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF48B0F0), Color(0xFF1B96E1)],
                  ),
                ),
                child: const Center(
                  child: PCImg(
                    name: 'pc_process_account_paypal',
                    width: 116.364,
                    height: 37.818,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 48,
              height: 5,
              child: PCImg(name: 'pc_withdraw_payment_separator'),
            ),
            Positioned(
              top: 54,
              left: 10,
              right: 10,
              height: 52,
              child: insufficient
                  ? const Center(
                      child: PCImg(
                        name: 'pc_withdraw_insufficient_symbol',
                        size: 52,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: PCText(
                        text: PCNoticeMessage.money(amount),
                        size: 36,
                        color: Colors.white,
                        weight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 提现流程的蓝色操作按钮，禁用与加载时不接受重复点击。
class PCWithdrawalBlueButton extends StatelessWidget {
  const PCWithdrawalBlueButton({
    super.key,
    required this.text,
    required this.onTap,
    this.busy = false,
    this.video = false,
  });
  final String text;
  final VoidCallback? onTap;
  final bool busy;
  final bool video;

  @override
  Widget build(BuildContext context) => ParticleButton(
    onTap: onTap ?? () {},
    enabled: !busy && onTap != null,
    child: SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFF1486F8), Color(0xFF2365EA)],
          ),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (video) ...[
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                        ],
                        PCText(
                          text: text,
                          size: 16,
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
}

/// 金色外圈绿色大按钮，保持设计中 268×64 的真实底图尺寸。
class PCWithdrawalGreenButton extends StatelessWidget {
  const PCWithdrawalGreenButton({
    super.key,
    required this.text,
    required this.onTap,
    this.busy = false,
  });
  final String text;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => ParticleButton(
    onTap: onTap ?? () {},
    enabled: !busy && onTap != null,
    child: SizedBox(
      width: 268,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_btn_bg')),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: PCStrokeText(
                  text: text,
                  size: 24,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  skColor: const Color(0xFF173600),
                  skWidth: 2.5,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// 审核和提现任务的横向进度，填充与文字分别绘制。
class PCWithdrawalProgressBar extends StatelessWidget {
  const PCWithdrawalProgressBar({
    super.key,
    required this.progress,
    required this.label,
    this.diamond = false,
  });
  final double progress;
  final String label;
  final bool diamond;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: diamond ? Colors.white24 : const Color(0xFFE7E7E7),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: diamond
                          ? const [Color(0xFF2EEFFC), Color(0xFF1162F9)]
                          : const [Color(0xFFFFDF2D), Color(0xFFFF5E01)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: PCText(
            text: label,
            size: 11,
            color: diamond ? Colors.white : Colors.black,
            weight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// 提现队列的展示行，调用方提供脱敏账号与金额，不保存完整账号。
class PCWithdrawalQueueEntry {
  const PCWithdrawalQueueEntry({
    required this.userId,
    required this.account,
    required this.amount,
  });
  final String userId;
  final String account;
  final double amount;
}

/// 优质用户礼包共用的独立丝带和标题，文案不烘焙进底图。
class PCWithdrawalPriorityHeader extends StatelessWidget {
  const PCWithdrawalPriorityHeader({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    height: 80,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(
          child: PCImg(name: 'pc_withdraw_priority_header'),
        ),
        const Positioned(
          left: 49,
          right: 49,
          top: 27,
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: PCStrokeText(
              text: "🎉 You're A Priority User Today",
              size: 18,
              color: Color(0xFFFFF36B),
              weight: FontWeight.w700,
              skColor: Color(0xFF761C00),
              skWidth: 1.2,
            ),
          ),
        ),
      ],
    ),
  );
}
