import 'dart:async';
import 'PCNumberManager.dart';
import 'PCWheelController.dart';
import 'package:flutter/material.dart';
import 'package:pennypilotcollectspin/PCTool/pc_LocalProvider.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'dart:math';
import 'package:provider/provider.dart';

class PCPigWheelPage extends StatefulWidget {
  final String? imagePath;

  const PCPigWheelPage({super.key, this.imagePath});

  @override
  PCPigWheelPageState createState() => PCPigWheelPageState();
}

class PCPigWheelPageState extends State<PCPigWheelPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _rotationAngle = 0.0;
  bool _isAnimating = false;
  StreamSubscription<int>? _wheelSubscription;

  // 假设转盘有8个奖项，每个奖项占45度
  final int itemCount = 8;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _rotationAngle = _animation.value;
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });
    _submitWheelIndex();
  }

  void _submitWheelIndex() {
    _wheelSubscription = WheelStartNotificationService.stream.listen((value) {
      startRotation(value);
    });
  }

  @override
  void dispose() {
    _wheelSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 指针正对分区中心；从当前角度继续旋转，完成后才允许页面展示结果。
  Future<void> startRotation(int targetIndex) async {
    if (_isAnimating || !mounted) return;
    if (targetIndex < 0 || targetIndex >= itemCount) return;
    final current = _rotationAngle;
    final targetAngle = (360 - targetIndex * (360 / itemCount)) % 360;
    final delta = (targetAngle - current % 360 + 360) % 360;
    _animation = Tween<double>(
      begin: current,
      end: current + 5 * 360 + delta,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
    setState(() => _isAnimating = true);
    try {
      await _controller.forward(from: 0).orCancel;
    } on TickerCanceled {
      // 页面退出时释放动画，已保存的转盘结果下次继续领取。
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        // 盘面始终占父画布340/360，分区与金额只由内部360设计画布缩放一次。
        child: FractionallySizedBox(
          widthFactor: 340 / 360,
          heightFactor: 340 / 360,
          child: Transform.rotate(
            angle: _rotationAngle * (pi / 180),
            child: Consumer<PCLocalProvider>(
              builder: (context, provider, child) {
                if (widget.imagePath != null &&
                    widget.imagePath != 'pc_wheel_center') {
                  return PCImg(name: widget.imagePath!);
                }
                final range = PCNumberHelpers().pc_wheelRange;
                return FittedBox(
                  child: SizedBox(
                    width: 360,
                    height: 360,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: PCImg(name: 'pc_wheel_face_bg'),
                        ),
                        const Positioned(
                          left: 152,
                          top: 56,
                          width: 56,
                          height: 56,
                          child: PCImg(name: 'pc_wheel_bag_top'),
                        ),
                        const Positioned(
                          left: 208.284,
                          top: 72.52,
                          width: 79.196,
                          height: 79.196,
                          child: PCImg(name: 'pc_wheel_money_diagonal'),
                        ),
                        const Positioned(
                          left: 56,
                          top: 152,
                          width: 56,
                          height: 56,
                          child: PCImg(name: 'pc_wheel_money_left'),
                        ),
                        const Positioned(
                          left: 248,
                          top: 152,
                          width: 56,
                          height: 56,
                          child: PCImg(name: 'pc_wheel_money_right'),
                        ),
                        const Positioned(
                          left: 72.52,
                          top: 72.52,
                          width: 79.196,
                          height: 79.196,
                          child: PCImg(name: 'pc_wheel_bag_top_left'),
                        ),
                        const Positioned(
                          left: 208.284,
                          top: 208.284,
                          width: 79.196,
                          height: 79.196,
                          child: PCImg(name: 'pc_wheel_bag_bottom_right'),
                        ),
                        const Positioned(
                          left: 72.52,
                          top: 208.284,
                          width: 79.196,
                          height: 79.196,
                          child: PCImg(name: 'pc_wheel_bag_bottom_left'),
                        ),
                        const Positioned(
                          left: 151,
                          top: 248,
                          width: 56,
                          height: 56,
                          child: PCImg(name: 'pc_wheel_try_again'),
                        ),
                        for (var i = 0; i < 8; i++)
                          Positioned.fill(
                            child: Transform.rotate(
                              angle: i * pi / 4,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 32),
                                  child: PCStrokeText(
                                    text:
                                        PCWheelController.cashSegments.contains(
                                          i,
                                        )
                                        ? '\$${range.first}-${range.last}'
                                        : i == 4
                                        ? 'Try Again'
                                        : 'Cash Bag',
                                    size: 14,
                                    color: Colors.white,
                                    weight: FontWeight.w900,
                                    skWidth: 2,
                                    skColor: const Color(0xFF003000),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class WheelStartNotificationService {
  static final StreamController<int> _streamController =
      StreamController<int>.broadcast();

  static Stream<int> get stream => _streamController.stream;

  static void sendToStartIndexNotification(int value) {
    _streamController.sink.add(value);
  }

  static void close() {
    _streamController.close();
  }
}
