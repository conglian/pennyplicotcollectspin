import 'package:flutter/material.dart';

import '../../PCTool/pc_img.dart';

/// 引导3的三行品牌卡片：第一、三行向左，中间一行向右，无缝循环。
class PCGuideBrandMarquee extends StatefulWidget {
  const PCGuideBrandMarquee({super.key});

  @override
  State<PCGuideBrandMarquee> createState() => _PCGuideBrandMarqueeState();
}

class _PCGuideBrandMarqueeState extends State<PCGuideBrandMarquee>
    with SingleTickerProviderStateMixin {
  static const _tileWidth = 72.1797;
  static const _tileHeight = 46.7045;
  static const _gap = 12.7377;
  static const _period = 5 * (_tileWidth + _gap);
  late final AnimationController _controller;
  bool? _animationsEnabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 17),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _row(int row) => Positioned(
    left: 0,
    right: 0,
    top: switch (row) {
      1 => 0.0,
      2 => 59.4421,
      _ => 120.0,
    },
    height: _tileHeight,
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        // 卡片只构建一次，每帧只平移整条，图片继续使用本地缓存。
        child: RepaintBoundary(
          child: Row(
            children: [
              for (var copy = 0; copy < 3; copy++)
                for (var index = 1; index <= 5; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: PCImg(
                      name: 'pc_guide_brand_${row}_$index',
                      width: _tileWidth,
                      height: _tileHeight,
                    ),
                  ),
            ],
          ),
        ),
        builder: (context, child) {
          final distance = _controller.value * _period;
          final start = row == 2 ? -6.0755 : -31.5508;
          var offset = (start + (row == 2 ? distance : -distance)) % _period;
          if (offset > 0) offset -= _period;
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: _period * 3,
            maxWidth: _period * 3,
            minHeight: _tileHeight,
            maxHeight: _tileHeight,
            child: Transform.translate(offset: Offset(offset, 0), child: child),
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: .78,
    child: Stack(children: [_row(1), _row(2), _row(3)]),
  );
}
