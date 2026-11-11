import 'package:flutter/material.dart';

import 'pc_extension_help.dart';
import 'pc_img.dart';

/// 转盘左上方的 H5 宝箱入口（Figma 772:286）。
///
/// 只为独立宝箱气泡添加缓慢呼吸；页面不活跃或系统减少动画时静止显示。
class PCWheelBonusChest extends StatefulWidget {
  const PCWheelBonusChest({
    super.key,
    required this.onTap,
    this.size = 64,
    this.active = true,
  });

  final VoidCallback onTap;
  final double size;
  final bool active;

  @override
  State<PCWheelBonusChest> createState() => _PCWheelBonusChestState();
}

class _PCWheelBonusChestState extends State<PCWheelBonusChest>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
    value: .5,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: .96,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOutSine));
  bool? _animating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant PCWheelBonusChest oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final enabled =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (_animating == enabled) return;
    _animating = enabled;
    if (enabled) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = .5;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Bonus chest',
    button: true,
    enabled: widget.active,
    child: ParticleButton(
      key: const ValueKey('pcWheelBonusChestButton'),
      enabled: widget.active,
      onTap: widget.onTap,
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: ScaleTransition(
            key: const ValueKey('pcWheelBonusChestBreath'),
            scale: _animating == true
                ? _scale
                : const AlwaysStoppedAnimation(1),
            child: const PCImg(name: 'pc_wheel_bonus_chest'),
          ),
        ),
      ),
    ),
  );
}
