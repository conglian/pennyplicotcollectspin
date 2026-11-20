import '../../PCTool/PCAnalytics.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCOtherDialogWidgets.dart';
import '../PCOther/PCProcessDialogWidgets.dart';
import 'PCWithdrawalDialogWidgets.dart';

/// 礼盒中奖页（Collect Now，Figma 230:214）。
/// 显示已缓存的配置钻石奖励；Collect异步[onClaim]成功才关闭返回true，失败保留同一笔奖励。
class PCWithdrawalGiftRewardDialog extends StatefulWidget {
  const PCWithdrawalGiftRewardDialog({
    super.key,
    required this.diamondAmount,
    this.collected = 0,
    this.target = 20,
    required this.onClaim,
  });
  final double diamondAmount;
  final double collected;
  final double target;
  final Future<bool> Function() onClaim;

  @override
  State<PCWithdrawalGiftRewardDialog> createState() =>
      _PCWithdrawalGiftRewardDialogState();
}

class _PCWithdrawalGiftRewardDialogState
    extends State<PCWithdrawalGiftRewardDialog> {
  bool _busy = false;
  bool _closed = false;

  Future<void> _claim() async {
    if (_busy || _closed) return;
    PCAnalytics.event('priority_user_pop_c');
    setState(() => _busy = true);
    var success = false;
    try {
      success = await widget.onClaim();
    } catch (_) {
      // 业务保存失败时保留领奖框，不能将失败视为领取成功。
      success = false;
    }
    if (!mounted) return;
    if (success) {
      _closed = true;
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target > 0 ? widget.target : 20.0;
    final afterClaim = (widget.collected + widget.diamondAmount).clamp(
      0.0,
      double.infinity,
    );
    return PopScope(
      canPop: !_busy,
      child: Material(
        type: MaterialType.transparency,
        child: PCResponsiveDialog(
          designHeight: 600,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                top: 0,
                width: 360,
                height: 80,
                child: PCWithdrawalPriorityHeader(),
              ),
              const Positioned(
                left: 32,
                right: 32,
                top: 100,
                height: 48,
                child: PCText(
                  text:
                      'Our advertisers have activated a Lucky\nValue bonus for you.',
                  size: 16,
                  color: Colors.white,
                  weight: FontWeight.w400,
                  maxLines: 2,
                  height: 1.5,
                  align: TextAlign.center,
                ),
              ),
              Positioned(
                left: 120,
                top: 206,
                width: 120,
                height: 120,
                child: PCBouncyImage(
                  imagePath: 'pc_withdraw_gift_diamond',
                  width: 120,
                  height: 120,
                  enableAnimation: !MediaQuery.disableAnimationsOf(context),
                ),
              ),
              Positioned(
                left: 80,
                right: 80,
                top: 334,
                height: 40,
                child: Center(
                  child: PCStrokeText(
                    text: '×${pcProcessAmount(widget.diamondAmount)}',
                    size: 32,
                    color: const Color(0xFFFFDF28),
                    weight: FontWeight.w900,
                    skColor: const Color(0xFF5D3B00),
                    skWidth: 1,
                  ),
                ),
              ),
              Positioned(
                left: 80,
                top: 424,
                width: 200,
                height: 16,
                child: PCWithdrawalProgressBar(
                  key: const ValueKey('pcWithdrawalGiftProgress'),
                  progress: afterClaim / target,
                  initialProgress: widget.collected / target,
                  duration: const Duration(milliseconds: 1350),
                  labelAt: (progress) =>
                      '${pcProcessAmount(progress * target)}/${pcProcessAmount(target)}',
                  label:
                      '${pcProcessAmount(afterClaim)}/${pcProcessAmount(target)}',
                  diamond: true,
                ),
              ),
              const Positioned(
                left: 68,
                top: 420,
                width: 24,
                height: 24,
                child: PCImg(name: 'pc_stage_progress_diamond'),
              ),
              Positioned(
                left: 32,
                right: 32,
                top: 456,
                height: 32,
                child: RichText(
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: text_fontName,
                      fontSize: 12,
                      color: Colors.white,
                      height: 16 / 12,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(text: 'Keep Earning to '),
                      TextSpan(
                        text: 'collect ${pcProcessAmount(target)} Diamonds',
                        style: const TextStyle(color: Color(0xFFFFDD1D)),
                      ),
                      const TextSpan(text: ' and activate\npayout access'),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 46,
                top: 516,
                width: 268,
                height: 64,
                child: PCWithdrawalGreenButton(
                  key: const ValueKey('pcWithdrawalGiftClaim'),
                  text: 'Collect Now',
                  busy: _busy,
                  onTap: _claim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
