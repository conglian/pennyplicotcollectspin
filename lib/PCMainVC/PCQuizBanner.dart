import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../PCTool/PCProcessBannerArtwork.dart';

/// 答题后的流程横幅：从右侧屏外进入，完整停留后沿原路退出。
/// 退场完成前保留当前文案，并通过 [onDismissed] 释放弹窗展示权。
class PCQuizBanner extends StatefulWidget {
  const PCQuizBanner({
    super.key,
    required this.message,
    required this.withdrawalTarget,
    required this.onDismissed,
    this.initialMessage,
    this.suppressed = false,
    this.displayDuration = const Duration(seconds: 2),
  });

  final String? message;

  /// Overlay入队时的原始文案；首次绘制前已取消时仍须结束这一轮展示。
  final String? initialMessage;
  final double withdrawalTarget;
  final ValueChanged<String> onDismissed;
  final bool suppressed;
  final Duration displayDuration;

  @override
  State<PCQuizBanner> createState() => _PCQuizBannerState();
}

class _PCQuizBannerState extends State<PCQuizBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;
  String? _displayedMessage;
  String? _nextMessage;
  bool _closing = false;
  bool _initialized = false;
  bool _initialPresentationSettled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_statusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 350);
    if (!_initialized) {
      _initialized = true;
      _show(widget.message);
      _completeUnshownPresentation();
    }
  }

  @override
  void didUpdateWidget(covariant PCQuizBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      if (_displayedMessage == null) {
        _show(widget.message);
      } else {
        _nextMessage = widget.message;
        _dismiss();
      }
    }
    _completeUnshownPresentation();
  }

  void _show(String? message) {
    if (message == null) return;
    _initialPresentationSettled = true;
    _displayedMessage = message;
    _closing = false;
    _controller.forward(from: 0);
  }

  void _completeUnshownPresentation() {
    final message = widget.initialMessage;
    if (_initialPresentationSettled ||
        widget.message != null ||
        message == null) {
      return;
    }
    // Overlay.insert与首次build分属两帧，切页、后台或排队弹窗可先清空
    // message。空横幅没有动画状态回调，必须主动归还父页面的展示权。
    _initialPresentationSettled = true;
    _notifyDismissed(message);
  }

  void _notifyDismissed(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDismissed(message);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _dismiss() {
    if (_displayedMessage == null || _closing) return;
    _closing = true;
    _dismissTimer?.cancel();
    // 同一条曲线反向播放；不切换方向或淡出，避免横幅瞬间跳到另一侧。
    if (_controller.value == 0) {
      _finishDismissal();
    } else {
      _controller.reverse();
    }
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_closing) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(widget.displayDuration, _dismiss);
    } else if (status == AnimationStatus.dismissed && _closing) {
      _finishDismissal();
    }
  }

  void _finishDismissal() {
    final dismissed = _displayedMessage;
    final next = _nextMessage;
    _nextMessage = null;
    setState(() {
      _displayedMessage = null;
      _closing = false;
      if (next != null) _show(next);
    });
    // 状态回调可能发生在父组件更新期间，释放展示权放到本帧之后。
    if (dismissed != null) {
      _notifyDismissed(dismissed);
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _displayedMessage;
    if (message == null) return const SizedBox.shrink();
    return Offstage(
      offstage: widget.suppressed,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 手机竖屏横幅铺满宽度；矮窗口按高度收紧，保持360×332设计比例。
          final width = math.min(
            constraints.maxWidth,
            constraints.maxHeight * 360 / 332,
          );
          final height = width * 332 / 360;
          return Stack(
            fit: StackFit.expand,
            children: [
              ModalBarrier(
                key: const ValueKey('pcQuizProcessBarrier'),
                dismissible: false,
                color: Colors.black.withValues(alpha: .9),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  child: AbsorbPointer(
                    child: SizedBox(
                      key: const ValueKey('pcQuizProcessBanner'),
                      width: width,
                      height: height,
                      child: PCProcessBannerArtwork.quiz(
                        message: message,
                        withdrawalTarget: widget.withdrawalTarget,
                      ),
                    ),
                  ),
                  builder: (_, child) => Transform.translate(
                    // 视觉槽位完全移到屏幕右侧，退场沿同一路线反向播放。
                    offset: Offset(
                      (constraints.maxWidth + width) /
                          2 *
                          (1 -
                              Curves.easeOutCubic.transform(_controller.value)),
                      0,
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
