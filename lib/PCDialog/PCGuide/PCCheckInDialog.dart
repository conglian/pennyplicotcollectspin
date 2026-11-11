import 'package:flutter/material.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCAdOutcome.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_shou_icon.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideCanvas.dart';
import '../PCOther/PCAdLoadingFailedDialog.dart';
import '../PCOther/PCDialogTool.dart';

/// 每日签到弹窗（Daily Cash Rewards），对应 Figma「签到」390:299。
/// 首次与普通签到均播放激励，真实成功后由控制器到账并继续；
/// 失败在同一路由显示Try Again，点击仅退出，新用户随后续接答题引导。
/// 正常取消直接退出、不发奖且不显示广告错误，保存异常沿用独立Toast提示。
/// 普通签到可关闭，已领取日显示勾选，未来日期保持灰色。
class PCCheckInDialog extends StatefulWidget {
  const PCCheckInDialog({
    super.key,
    required this.rewards,
    this.day = 0,
    this.canClaim = true,
    this.isNewUser = false,
    this.onClaim,
    this.onClaimOutcome,
    this.showAdBadge = true,
  });
  final List<double> rewards;
  final int day;
  final bool canClaim;
  final bool isNewUser;

  final Future<bool> Function()? onClaim;

  /// 广告失败、正常取消与领取成功分别处理；旧bool回调仍兼容测试及既有入口。
  final Future<PCAdOutcome> Function()? onClaimOutcome;
  final bool showAdBadge;
  @override
  State<PCCheckInDialog> createState() => _PCCheckInDialogState();
}

class _PCCheckInDialogState extends State<PCCheckInDialog> {
  bool _claiming = false;
  bool _closing = false;
  bool _adFailed = false;

  void _close(bool claimed) {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop(claimed);
  }

  Future<void> _claim() async {
    if (_claiming || _closing || _adFailed || !widget.canClaim) return;
    if (widget.isNewUser) PCAnalytics.event('new_sign_pop_c');
    setState(() => _claiming = true);
    try {
      final outcome = widget.onClaimOutcome != null
          ? await widget.onClaimOutcome!()
          : widget.onClaim == null
          ? PCAdOutcome.cancelled
          : await widget.onClaim!()
          ? PCAdOutcome.success
          : PCAdOutcome.failed;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (outcome.isSuccess) {
        _close(true);
      } else if (outcome == PCAdOutcome.failed) {
        setState(() => _adFailed = true);
      } else {
        _close(false);
      }
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        PCDialogTool.toast(
          context,
          'Unable to save progress. Please try again.',
        );
      }
    } finally {
      if (mounted && !_closing) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adFailed) {
      return PCAdLoadingFailedDialog(onClose: () => _close(false));
    }
    return PCGuideCanvas(
      height: 520,
      child: Stack(
        children: [
          const Positioned(
            left: 12,
            top: 12,
            width: 76,
            height: 70,
            child: PCImg(name: 'pc_checkin_leaf'),
          ),
          Positioned(
            right: 12,
            top: 12,
            width: 76,
            height: 70,
            child: Transform.flip(
              flipX: true,
              child: const PCImg(name: 'pc_checkin_leaf'),
            ),
          ),
          const Positioned(
            left: 20,
            top: 68,
            width: 320,
            height: 432,
            child: PCImg(name: 'pc_checkin_panel'),
          ),
          const Positioned(
            left: 68,
            top: 0,
            width: 232,
            height: 48,
            child: PCImg(name: 'pc_checkin_title'),
          ),
          const Positioned(
            left: 58,
            top: 40,
            width: 244,
            height: 44,
            child: PCImg(name: 'pc_checkin_ribbon'),
          ),
          const Positioned(
            left: 58,
            top: 56,
            width: 244,
            child: PCStrokeText(
              text: 'Check in 7 days, cash out GUARANTEED!',
              size: 12,
              color: Colors.white,
              weight: FontWeight.w700,
              skWidth: 1,
              skColor: Color(0xFF9D540D),
            ),
          ),
          for (var index = 0; index < 7; index++)
            Positioned(
              left: index == 6 ? 36 : 36 + (index % 3) * 98,
              top: index == 6 ? 296 : 100 + (index ~/ 3) * 98,
              width: index == 6 ? 288 : 92,
              height: 92,
              child: _dayCard(index),
            ),
          Positioned(
            left: 28,
            right: 28,
            top: 400,
            child: PCText(
              text:
                  'Finish all 7 days = \$${widget.rewards.fold<double>(0, (a, b) => a + b).toStringAsFixed(2)} total CASH',
              size: 14,
              color: const Color(0xFF5D1400),
              weight: FontWeight.w500,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 46,
            top: 436,
            width: 268,
            height: 48,
            child: ParticleButton(
              enabled: widget.canClaim && !_claiming && !_closing,
              breathing: widget.canClaim,
              onTap: _claim,
              child: Opacity(
                opacity: widget.canClaim && !_claiming ? 1 : .55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF94C626),
                      width: 2,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFC5EC55), Color(0xFF83C72C)],
                    ),
                  ),
                  child: Center(
                    child: PCText(
                      text: widget.canClaim
                          ? 'CLAIM \$${widget.rewards[widget.day.clamp(0, 6)].toStringAsFixed(2)} NOW'
                          : 'COME BACK TOMORROW',
                      size: 16,
                      color: const Color(0xFF326A02),
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showAdBadge && widget.canClaim)
            const Positioned(
              left: 58,
              top: 452,
              child: IgnorePointer(
                child: PCImg(name: 'pc_ad_icon', width: 20, height: 18),
              ),
            ),
          if (widget.isNewUser && widget.canClaim)
            const Positioned(
              left: 268,
              top: 452,
              child: IgnorePointer(child: PCShouIcon(size: 60)),
            ),
          if (!widget.isNewUser)
            Positioned(
              right: 8,
              top: 0,
              child: ParticleButton(
                enabled: !_claiming && !_closing,
                onTap: () => _close(false),
                child: const PCImg(
                  name: 'pc_closes_btn',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCard(int index) {
    final active = index == widget.day && widget.canClaim;
    final claimed = index < widget.day;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFFEE950D) : const Color(0xFFD9AF60),
          width: active ? 2 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? const [Color(0xFFFFAD27), Color(0xFFE4771E)]
              : const [Color(0xFFFFE7A7), Color(0xFFF2D18B)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: PCText(
              text: 'Day ${index + 1}',
              size: 14,
              color: const Color(0xFF7C4F2D),
              weight: FontWeight.w700,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            top: 32,
            left: 4,
            right: 4,
            bottom: 4,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: index == 6 ? 1 : .35,
                    child: PCImg(
                      name: index == 6 ? 'pc_checkin_day7' : 'pc_checkin_bill',
                      width: index == 6 ? 280 : 48,
                      height: index == 6 ? 56 : 48,
                    ),
                  ),
                  FittedBox(
                    child: PCStrokeText(
                      text: claimed
                          ? '✓'
                          : '\$${widget.rewards[index].toStringAsFixed(2)}',
                      size: 24,
                      color: active ? const Color(0xFFFBE716) : Colors.white,
                      weight: FontWeight.w800,
                      skWidth: 4,
                      skColor: const Color(0xFF8D3F12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index == 6)
            const Positioned(
              right: 0,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF77B621),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: PCText(
                    text: 'Cash Out',
                    weight: FontWeight.w500,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
