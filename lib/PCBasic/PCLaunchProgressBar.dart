import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../PCTool/pc_text.dart';

/// 启动页进度条：百分比位于条下方，沿用原来的加载时长和完成回调。
class PCGradientProgressBar extends StatefulWidget {
  const PCGradientProgressBar({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  State<PCGradientProgressBar> createState() => _PCGradientProgressBarState();
}

class _PCGradientProgressBarState extends State<PCGradientProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: kDebugMode ? 3 : 12),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onCompleted?.call();
        });
    _progress = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) => SizedBox(
      width: 200,
      height: 42,
      child: Column(
        children: [
          Container(
            height: 16,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF002000),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 4),
              ],
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _progress.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFDF2D), Color(0xFFDA5000)],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          PCText(
            text: '${(_progress.value * 100).clamp(0, 100).toInt()}%',
            size: 14,
            height: 20 / 14,
            color: Colors.white,
            weight: FontWeight.w700,
            align: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
