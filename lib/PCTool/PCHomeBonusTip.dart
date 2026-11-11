import 'dart:async';

import 'package:flutter/material.dart';

import 'pc_text.dart';

/// 首页成长提示的显示周期：进入首页显示两秒，切离立即隐藏。
///
/// Tab 状态使用 [setActive]；需要主动重播时调用 [activate]。
class PCHomeBonusTipController extends ChangeNotifier {
  static const displayDuration = Duration(seconds: 2);

  Timer? _timer;
  bool _active = false;
  bool _visible = false;
  bool _disposed = false;
  int _generation = 0;

  bool get active => _active;
  bool get visible => _visible;

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    if (active) {
      activate();
    } else {
      deactivate();
    }
  }

  /// 从冷启动或 Tab 点击进入首页时重新计满两秒。
  void activate() {
    if (_disposed) return;
    _active = true;
    _timer?.cancel();
    final generation = ++_generation;
    _setVisible(true);
    _timer = Timer(displayDuration, () {
      if (_disposed || !_active || generation != _generation) return;
      _timer = null;
      _setVisible(false);
    });
  }

  void deactivate() {
    if (_disposed) return;
    _active = false;
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _setVisible(false);
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// 首页「Activated: +3% bonus tomorrow」短提示，不拦截下方点击。
///
/// [background] 可传入 Figma 导出的独立背板；文字仍独立绘制。
class PCHomeBonusTip extends StatelessWidget {
  const PCHomeBonusTip({
    super.key,
    required this.controller,
    this.width = 200,
    this.height = 48,
    this.background,
    this.child,
  });

  final PCHomeBonusTipController controller;
  final double width;
  final double height;
  final Widget? background;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.visible) return const SizedBox.shrink();
        return IgnorePointer(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                background ?? const CustomPaint(painter: _PCBonusTipPainter()),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    width * 0.055,
                    height * 0.05,
                    width * 0.055,
                    height * 0.22,
                  ),
                  child: Center(
                    child:
                        child ??
                        PCText(
                          text: 'Activated: ',
                          spans: const [
                            TextSpan(
                              text: '+3%',
                              style: TextStyle(color: Color(0xFFFFDD1D)),
                            ),
                            TextSpan(
                              text:
                                  " bonus tomorrow,\ndon't forget to come back!",
                            ),
                          ],
                          size: width / 20,
                          color: Colors.white,
                          weight: FontWeight.w400,
                          align: TextAlign.center,
                          maxLines: 2,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PCBonusTipPainter extends CustomPainter {
  const _PCBonusTipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height * 0.8;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, bodyHeight - 1);
    final radius = Radius.circular(bodyHeight / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, radius))
      ..moveTo(size.width * 0.43, bodyHeight - 1)
      ..lineTo(size.width * 0.5, size.height - 1)
      ..lineTo(size.width * 0.58, bodyHeight - 1)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC74DDD), Color(0xFFA014B5)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..color = const Color(0xFFFF7CF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PCBonusTipPainter oldDelegate) => false;
}
