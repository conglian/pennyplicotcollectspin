import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_shou_icon.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCOtherDialogWidgets.dart';
import 'PCWithdrawalDialogWidgets.dart';

/// 优质用户礼包（You're A Priority User Today，Figma 225:566）。
/// 礼盒先抖动等待3秒，未点击才播放分层开箱；按钮或礼盒随时可点击返回true
/// 进入中奖页，关闭返回false。倒计时及开箱结束均不自动跳页或发放钻石。
class PCWithdrawalPriorityGiftDialog extends StatefulWidget {
  const PCWithdrawalPriorityGiftDialog({
    super.key,
    this.autoOpenDuration = const Duration(seconds: 3),
  });

  /// 开箱前的等待时长，保留原参数名称兼容现有调用。
  final Duration autoOpenDuration;

  @override
  State<PCWithdrawalPriorityGiftDialog> createState() =>
      _PCWithdrawalPriorityGiftDialogState();
}

class _PCWithdrawalPriorityGiftDialogState
    extends State<PCWithdrawalPriorityGiftDialog>
    with TickerProviderStateMixin {
  late final AnimationController _waiting = AnimationController(
    vsync: this,
    duration: widget.autoOpenDuration,
    // 减少动画仅取消抖动，不能缩短开箱前的等待时间。
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_onWaitingChanged);
  late final AnimationController _opening = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _closed = false;
  bool _reduced = false;
  bool _waitingFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closed) _waiting.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced && _opening.isAnimating) _opening.value = 1;
  }

  void _onWaitingChanged() {
    if (_waitingFinished || _waiting.value < 1 || !mounted || _closed) return;
    _waitingFinished = true;
    _waiting.stop();
    if (_reduced) {
      _opening.value = 1;
    } else {
      _opening.forward();
    }
  }

  void _close(bool result) {
    if (!mounted || _closed) return;
    _closed = true;
    _waiting.stop();
    _opening.stop();
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _waiting.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: PCResponsiveDialog(
      designHeight: 640,
      child: AnimatedBuilder(
        animation: Listenable.merge([_waiting, _opening]),
        builder: (context, _) {
          final t = _waiting.value;
          final open = Curves.easeOutCubic.transform(_opening.value);
          final shake = _reduced || _waitingFinished
              ? 0.0
              : math.sin(t * math.pi * 28) * .04;
          final remaining = math.max(
            0,
            widget.autoOpenDuration.inMicroseconds -
                (_waiting.lastElapsedDuration?.inMicroseconds ?? 0),
          );
          final seconds = math.max(
            1,
            (remaining / Duration.microsecondsPerSecond).ceil(),
          );
          return Stack(
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
                left: 80,
                top: 210,
                width: 200,
                height: 200,
                child: ParticleButton(
                  key: const ValueKey('pcWithdrawalGiftTap'),
                  onTap: () => _close(true),
                  child: Transform.rotate(
                    key: const ValueKey('pcWithdrawalGiftArtwork'),
                    angle: shake,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(
                          child: PCImg(name: 'pc_withdraw_gift_base'),
                        ),
                        if (open > 0)
                          Positioned(
                            left: 45,
                            top: 25 - 60 * open,
                            width: 110,
                            height: 110,
                            child: Opacity(
                              opacity: open,
                              child: const PCImg(
                                name: 'pc_withdraw_gift_diamond',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Transform.translate(
                            key: const ValueKey('pcWithdrawalGiftLid'),
                            offset: _reduced
                                ? Offset.zero
                                : Offset(10 * open, -85 * open),
                            child: Transform.rotate(
                              angle: _reduced ? 0 : -.18 * open,
                              child: Opacity(
                                opacity: _reduced && _waitingFinished
                                    ? 0
                                    : 1 - .3 * open,
                                child: const PCImg(
                                  name: 'pc_withdraw_gift_lid',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 46,
                top: 516,
                width: 268,
                height: 64,
                child: PCWithdrawalGreenButton(
                  key: const ValueKey('pcWithdrawalGiftOpen'),
                  text: _waitingFinished
                      ? 'Click To Open'
                      : 'Click To Open(${seconds}s)',
                  onTap: () => _close(true),
                ),
              ),
              Positioned(
                right: 14,
                top: 552,
                width: 60,
                height: 60,
                child: IgnorePointer(
                  child: _reduced
                      ? const PCImg(name: 'pc_shou_icon')
                      : const PCShouIcon(),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: 44,
                height: 44,
                child: IconButton(
                  key: const ValueKey('pcWithdrawalGiftClose'),
                  onPressed: () => _close(false),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
