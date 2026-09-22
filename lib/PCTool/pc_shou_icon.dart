import 'package:flutter/material.dart';

import 'pc_img.dart';

/// Reusable breathing hand gesture guide.
class PCShouIcon extends StatefulWidget {
  const PCShouIcon({super.key, this.size = 60});

  final double size;

  @override
  State<PCShouIcon> createState() => _PCShouIconState();
}

class _PCShouIconState extends State<PCShouIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.94,
      upperBound: 1.06,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: ScaleTransition(
        scale: _controller,
        child: PCImg(
          name: 'pc_shou_icon',
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}
