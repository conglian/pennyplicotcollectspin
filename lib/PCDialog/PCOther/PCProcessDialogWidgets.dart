import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_text.dart';
import 'PCOtherDialogWidgets.dart';

/// 3.7 流程提示共用白卡：标题、关闭热区、蓝色操作按钮独立绘制。
class PCProcessWhiteCard extends StatelessWidget {
  const PCProcessWhiteCard({
    super.key,
    required this.height,
    required this.title,
    required this.buttonText,
    required this.onAction,
    required this.onClose,
    required this.children,
  });

  final double height;
  final String title;
  final String buttonText;
  final VoidCallback onAction;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: PCResponsiveDialog(
      designHeight: height,
      child: Center(
        child: SizedBox(
          width: 304,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                ...children,
                Positioned(
                  left: 28,
                  top: 16,
                  width: 208,
                  height: 24,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PCText(
                      text: title,
                      size: 18,
                      color: Colors.black,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  width: 48,
                  height: 56,
                  child: ParticleButton(
                    key: const ValueKey('pcProcessClose'),
                    onTap: onClose,
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  height: 52,
                  child: ParticleButton(
                    key: const ValueKey('pcProcessContinue'),
                    onTap: onAction,
                    child: SizedBox.expand(
                      child: DecoratedBox(
                        key: const ValueKey('pcProcessButtonBackground'),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1486F8), Color(0xFF2365EA)],
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: PCText(
                                text: buttonText,
                                size: 16,
                                color: Colors.white,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
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
    ),
  );
}

/// 钻石收集图与独立环形进度；图形资源来自审核卡 224:481。
class PCProcessDiamondRing extends StatelessWidget {
  const PCProcessDiamondRing({
    super.key,
    required this.collected,
    required this.progress,
  });
  final double collected;
  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    height: 112,
    child: CustomPaint(
      painter: _DiamondRingPainter(progress.clamp(0, 1)),
      child: Stack(
        children: [
          const Positioned(
            left: 28,
            top: 18,
            width: 56,
            height: 56,
            child: PCImg(name: 'pc_process_review_diamond'),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 76,
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCText(
                text:
                    '${pcProcessAmount(collected.clamp(0, 20).toDouble())}/20',
                size: 14,
                color: Colors.black,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DiamondRingPainter extends CustomPainter {
  const _DiamondRingPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5E5E5);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomRight,
      colors: [Color(0xFF28E8E8), Color(0xFF1DA0FF)],
    ).createShader(rect);
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DiamondRingPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// 审核步骤清单：已完成项显示对号，其余使用本地加载图持续旋转。
class PCProcessReviewChecklist extends StatelessWidget {
  const PCProcessReviewChecklist({
    super.key,
    this.completedSteps = 1,
    this.presentation,
  });

  final int completedSteps;
  final ValueListenable<int>? presentation;

  static const _labels = [
    'Ad Click Matched',
    'Account Health Checked',
    'Payment Method Verified',
  ];
  static const _displayLabels = [
    'Ad Click Matched',
    '.......(Account Health Checked)',
    '........(Payment Method Verified)',
  ];
  @override
  Widget build(BuildContext context) {
    final state = presentation;
    if (state != null) {
      return ValueListenableBuilder<int>(
        valueListenable: state,
        builder: (context, completed, _) => _content(completed),
      );
    }
    return _content(completedSteps);
  }

  Widget _content(int completedSteps) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE9F0F4), width: .5),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PCText(
            text: 'Priority Review Is On',
            size: 14,
            weight: FontWeight.w600,
            color: Colors.black,
            height: 20 / 14,
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < _labels.length; index++) ...[
            Row(
              children: [
                Semantics(
                  label: _labels[index],
                  value: index < completedSteps ? 'Complete' : 'In progress',
                  child: index < completedSteps
                      ? const PCImg(name: 'pc_process_review_check', size: 24)
                      : const _ReviewLoadingIcon(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PCText(
                      text: _displayLabels[index],
                      size: 14,
                      weight: FontWeight.w500,
                      color: const Color(0xFF393939),
                      maxLines: 1,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ],
            ),
            if (index < _labels.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
}

class _ReviewLoadingIcon extends StatefulWidget {
  const _ReviewLoadingIcon();

  @override
  State<_ReviewLoadingIcon> createState() => _ReviewLoadingIconState();
}

class _ReviewLoadingIconState extends State<_ReviewLoadingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else {
      _rotation.stop();
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _rotation,
    child: const PCImg(name: 'pc_process_review_loading', size: 24),
  );
}

String pcProcessAmount(double amount) {
  final safe = amount.isFinite ? math.max(0.0, amount) : 0.0;
  return safe.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
