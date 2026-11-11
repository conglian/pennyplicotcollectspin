import 'package:flutter/material.dart';

/// 引导专用画布，装饰与文字分别布局，等比适配小屏和安全区域。
class PCGuideCanvas extends StatelessWidget {
  const PCGuideCanvas({super.key, required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: 360, height: height, child: child),
        ),
      ),
    ),
  );
}
