import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'PCNumberManager.dart';
import 'PCRankData.dart';
import 'pc_img.dart';
import 'pc_text.dart';

/// 展示存钱罐时的三条随机弹幕；金额从配置提现四档抽取，三行独立匀速向左循环。
class PCPigBarrage extends StatefulWidget {
  const PCPigBarrage({super.key, required this.users, this.scale = 1})
    : assert(users.length > 0);

  final List<PCUserData> users;
  final double scale;

  @override
  State<PCPigBarrage> createState() => _PCPigBarrageState();
}

class _PCPigBarrageState extends State<PCPigBarrage>
    with TickerProviderStateMixin {
  static const _bubbleWidth = 308.0;
  static const _gap = 24.0;
  static const _messageCount = 4;
  static const _period = (_bubbleWidth + _gap) * _messageCount;
  final _random = math.Random();
  late final List<AnimationController> _controllers;
  late final List<List<_PigMessage>> _rows;
  bool? _animationsEnabled;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (row) => AnimationController(
        vsync: this,
        duration: Duration(seconds: 35 + row * 6),
      ),
    );
    final payoutAmounts = PCNumberHelpers().pc_eqRange.take(4).toList();
    _rows = List.generate(
      3,
      (_) => List.generate(_messageCount, (_) {
        final user = widget.users[_random.nextInt(widget.users.length)];
        final amount = payoutAmounts[_random.nextInt(payoutAmounts.length)];
        final (before, after) = switch (_random.nextInt(3)) {
          0 => ('Just started, already made ', ' by watching ads!'),
          1 => ('Quiz rewards added ', ' to my pig today!'),
          _ => ('My pig has already saved ', ' — keep earning!'),
        };
        return _PigMessage(
          user.avatarName,
          before,
          '\$${amount.toStringAsFixed(2)}',
          after,
        );
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    for (final controller in _controllers) {
      if (enabled) {
        controller.repeat();
      } else {
        controller.stop();
        controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _row(int row) {
    final s = widget.scale;
    return Positioned(
      left: 0,
      right: 0,
      top: row * 48 * s,
      height: 24 * s,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controllers[row],
          child: RepaintBoundary(
            key: ValueKey('pcPigBarrageTrack$row'),
            child: Row(
              children: [
                for (var copy = 0; copy < 2; copy++)
                  for (final message in _rows[row])
                    Padding(
                      padding: EdgeInsets.only(right: _gap * s),
                      child: _bubble(message, s),
                    ),
              ],
            ),
          ),
          builder: (context, child) {
            final start = [23.0, 119.0, -26.0][row];
            var offset = (start - _controllers[row].value * _period) % _period;
            if (offset > 0) offset -= _period;
            return OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: _period * 2 * s,
              maxWidth: _period * 2 * s,
              minHeight: 24 * s,
              maxHeight: 24 * s,
              child: Transform.translate(
                offset: Offset(offset * s, 0),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bubble(_PigMessage message, double s) => Container(
    width: _bubbleWidth * s,
    height: 24 * s,
    padding: EdgeInsets.symmetric(horizontal: 2 * s),
    decoration: BoxDecoration(
      color: const Color(0x6651B217),
      borderRadius: BorderRadius.circular(12 * s),
    ),
    child: Row(
      children: [
        ClipOval(
          child: PCImg(name: message.avatar, width: 20 * s, height: 20 * s),
        ),
        SizedBox(width: 4 * s),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PCText(
                  text: message.before,
                  size: 12 * s,
                  color: Colors.white,
                  weight: FontWeight.w400,
                ),
                PCText(
                  text: message.amount,
                  size: 12 * s,
                  color: const Color(0xFFFFDD1D),
                  weight: FontWeight.w500,
                ),
                PCText(
                  text: message.after,
                  size: 12 * s,
                  color: Colors.white,
                  weight: FontWeight.w400,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(children: [for (var row = 0; row < 3; row++) _row(row)]),
  );
}

class _PigMessage {
  const _PigMessage(this.avatar, this.before, this.amount, this.after);
  final String avatar;
  final String before;
  final String amount;
  final String after;
}
