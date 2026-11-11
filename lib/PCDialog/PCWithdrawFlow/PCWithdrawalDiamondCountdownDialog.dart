import '../../PCTool/PCAnalytics.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../PCTool/PCNoticeMessage.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCOtherDialogWidgets.dart';
import 'PCWithdrawalDialogWidgets.dart';

enum PCWithdrawalCountdownAction { openTomorrow, remindMe, close }

/// 钻石阶段审核通过与跨日倒计时（Figma 230:256）。
/// 使用调用方的本地午夜截止时间；Open Tomorrow只关闭，Remind Me返回权限动作，
/// 已开启通知时不再展示提醒按钮，不自行申请权限、升级或更改奖励。
class PCWithdrawalDiamondCountdownDialog extends StatefulWidget {
  const PCWithdrawalDiamondCountdownDialog({
    super.key,
    required this.withdrawalTarget,
    required this.deadline,
    required this.notificationsEnabled,
    this.now,
  });
  final double withdrawalTarget;
  final DateTime deadline;
  final bool notificationsEnabled;
  final DateTime Function()? now;

  @override
  State<PCWithdrawalDiamondCountdownDialog> createState() =>
      _PCWithdrawalDiamondCountdownDialogState();
}

class _PCWithdrawalDiamondCountdownDialogState
    extends State<PCWithdrawalDiamondCountdownDialog> {
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _close(PCWithdrawalCountdownAction action) {
    if (_closed || !mounted) return;
    _closed = true;
    if (action != PCWithdrawalCountdownAction.close) {
      PCAnalytics.event('release_remind_pop_c');
    }
    Navigator.of(context).pop(action);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remaining {
    final diff = widget.deadline.difference((widget.now ?? DateTime.now)());
    final seconds = diff.inSeconds.clamp(0, 86400 * 365);
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
        '${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: PCResponsiveDialog(
      designHeight: widget.notificationsEnabled ? 528 : 612,
      child: Stack(
        children: [
          const Positioned(
            left: 20,
            top: 124,
            width: 320,
            height: 384,
            child: PCImg(name: 'pc_withdraw_countdown_panel'),
          ),
          const Positioned(
            left: 12,
            top: 68,
            width: 336,
            height: 84,
            child: PCImg(name: 'pc_grow_bonus_title_frame'),
          ),
          const Positioned(
            left: 20,
            top: 76,
            width: 320,
            height: 68,
            child: PCImg(name: 'pc_grow_bonus_title_bg'),
          ),
          const Positioned(
            left: 17.6,
            top: 73.6,
            width: 324.8,
            height: 24.4,
            child: PCImg(name: 'pc_grow_bonus_title_gloss'),
          ),
          const Positioned(
            left: 19,
            top: 0,
            width: 322,
            height: 88,
            child: PCImg(name: 'pc_grow_bonus_bow'),
          ),
          const Positioned(
            left: 28,
            right: 28,
            top: 88,
            height: 48,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCStrokeText(
                text: 'Congratulation!',
                size: 36,
                color: Color(0xFFFFE449),
                weight: FontWeight.w900,
                skColor: Color(0xFF285200),
                skWidth: 1.5,
              ),
            ),
          ),
          const Positioned(
            left: 136,
            top: 160,
            width: 86,
            height: 85,
            child: PCImg(name: 'pc_withdraw_approved_check'),
          ),
          Positioned(
            left: 40,
            right: 40,
            top: 260,
            height: 24,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCText(
                text:
                    '${PCNoticeMessage.money(widget.withdrawalTarget)} Amount Review Approved',
                size: 16,
                color: const Color(0xFFFFEE8A),
                weight: FontWeight.w800,
                align: TextAlign.center,
              ),
            ),
          ),
          const Positioned(
            left: 44,
            right: 44,
            top: 304,
            height: 40,
            child: PCText(
              text:
                  'Payout platform is processing. Come back\ntomorrow to continue release.',
              size: 14,
              color: Colors.white,
              weight: FontWeight.w500,
              maxLines: 2,
              height: 20 / 14,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            top: 364,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF003B13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF002C0B)),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PCText(
                        text: "Tomorrow's Release Ends In ",
                        size: 12,
                        color: Colors.white,
                        weight: FontWeight.w400,
                      ),
                      PCText(
                        key: const ValueKey('pcWithdrawalCountdownTime'),
                        text: _remaining,
                        size: 20,
                        color: const Color(0xFFFF3F3F),
                        weight: FontWeight.w800,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 46,
            top: 420,
            width: 268,
            height: 64,
            child: PCWithdrawalGreenButton(
              key: const ValueKey('pcWithdrawalOpenTomorrow'),
              text: 'Open Tomorrow',
              onTap: () => _close(PCWithdrawalCountdownAction.openTomorrow),
            ),
          ),
          if (!widget.notificationsEnabled)
            Positioned(
              left: 46,
              top: 532,
              width: 268,
              height: 64,
              child: PCWithdrawalGreenButton(
                key: const ValueKey('pcWithdrawalRemindMe'),
                text: 'Remind Me',
                onTap: () => _close(PCWithdrawalCountdownAction.remindMe),
              ),
            ),
          Positioned(
            right: 0,
            top: 0,
            width: 48,
            height: 48,
            child: PCDialogCloseButton(
              key: const ValueKey('pcWithdrawalCountdownClose'),
              onTap: () => _close(PCWithdrawalCountdownAction.close),
            ),
          ),
        ],
      ),
    ),
  );
}
