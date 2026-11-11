import 'package:flutter/material.dart';

import 'pc_stroke_text.dart';

/// 带渐变和描边的数字滚动组件，数值变化时从当前显示值继续动画。
class PCGradientNumberRoller extends StatefulWidget {
  // 支持num类型（int和double的父类）
  final num value;
  final int duration; // 动画持续时间(毫秒)
  final double fontSize; // 字体大小
  final FontWeight fontWeight;
  final List<Color> gradientColors; // 渐变颜色列表
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final Color borderColor; // 边线颜色
  final double borderWidth; // 边线宽度
  final int decimalPlaces; // 小数位数，默认2位
  final num currentValue; // 初始值
  final bool showDolas; // 是否显示美元符号

  const PCGradientNumberRoller({
    super.key,
    required this.value,
    this.duration = 1000,
    this.fontSize = 24.0,
    this.fontWeight = FontWeight.bold,
    this.gradientColors = const [Colors.red, Colors.yellow],
    this.gradientBegin = Alignment.centerLeft,
    this.gradientEnd = Alignment.centerRight,
    this.borderColor = Colors.black,
    this.borderWidth = 1.0,
    this.decimalPlaces = 2,
    this.currentValue = 0,
    this.showDolas = true,
  });

  @override
  State<PCGradientNumberRoller> createState() => _PCGradientNumberRollerState();
}

class _PCGradientNumberRollerState extends State<PCGradientNumberRoller>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  num _currentValue = 0;
  num _previousValue = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    );

    _animation =
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        )..addListener(() {
          setState(() {
            // 计算当前值（支持小数平滑过渡）
            final difference = widget.value - _previousValue;
            _currentValue = _previousValue + difference * _animation.value;
          });
        });

    // 初始值设置
    _previousValue = widget.currentValue;
    _currentValue = widget.currentValue;

    // 开始动画
    _startAnimation();
  }

  @override
  void didUpdateWidget(PCGradientNumberRoller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = Duration(milliseconds: widget.duration);
    }
    if (widget.value != oldWidget.value) {
      _previousValue = _currentValue;
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 格式化数字，根据类型和小数位数处理
  String _formatNumber(num number) {
    final prefix = widget.showDolas ? '\$' : '';
    return '$prefix${number.toStringAsFixed(widget.decimalPlaces)}';
  }

  @override
  Widget build(BuildContext context) {
    final String displayNumber = _formatNumber(_currentValue);

    return ShaderMask(
      // 渐变遮罩实现文字颜色渐变
      shaderCallback: (bounds) => LinearGradient(
        begin: widget.gradientBegin,
        end: widget.gradientEnd,
        colors: widget.gradientColors,
      ).createShader(bounds),
      child: Stack(
        children: [
          // 字体边线（通过描边实现）
          if (widget.borderWidth > 0)
            Text(
              displayNumber,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                height: 1.15,
                fontFamily: text_fontName,
                // 描边样式设置
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = widget.borderWidth
                  ..color = widget.borderColor,
              ),
            ),
          // 渐变填充文字
          Text(
            displayNumber,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              height: 1.15,
              fontFamily: text_fontName,
              color: Colors.white, // 颜色会被渐变遮罩覆盖
            ),
          ),
        ],
      ),
    );
  }
}
