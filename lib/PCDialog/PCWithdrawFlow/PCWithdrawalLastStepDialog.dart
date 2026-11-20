import '../../PCTool/PCAnalytics.dart';
import 'package:flutter/material.dart';
import '../PCOther/PCAdLoadingFailedDialog.dart';
import '../PCOther/PCDialogTool.dart';

import '../../PCTool/PCWithdrawalController.dart';
import '../../PCTool/pc_text.dart';
import 'PCWithdrawalDialogWidgets.dart';

/// 提现最后一步任务（One Last Step，Figma 236:878）。
/// 显示当前配置任务与真实完成次数；Cash Out执行调用方动作。
/// 视频任务提供[currentProgress]时逐次刷新进度，达到目标才返回true；
/// 其他成功动作沿用立即返回；取消和未受理保留任务，仅真实广告失败显示失败面板。
class PCWithdrawalLastStepDialog extends StatefulWidget {
  const PCWithdrawalLastStepDialog({
    super.key,
    required this.withdrawalTarget,
    required this.taskTitle,
    required this.progress,
    required this.target,
    this.onAction,
    this.onActionOutcome,
    this.currentProgress,
  }) : assert(onAction != null || onActionOutcome != null);
  final double withdrawalTarget;
  final String taskTitle;
  final int progress;
  final int target;
  final Future<bool> Function()? onAction;
  final Future<PCWithdrawalAdResult> Function()? onActionOutcome;
  final int Function()? currentProgress;

  @override
  State<PCWithdrawalLastStepDialog> createState() =>
      _PCWithdrawalLastStepDialogState();
}

class _PCWithdrawalLastStepDialogState
    extends State<PCWithdrawalLastStepDialog> {
  bool _busy = false;
  bool _closed = false;
  bool _adFailed = false;
  bool get _isVideo => widget.taskTitle.trim().toLowerCase() == 'video';
  int get _progress => (widget.currentProgress?.call() ?? widget.progress)
      .clamp(0, widget.target > 0 ? widget.target : 0);

  Future<void> _action() async {
    if (_busy || _closed) return;
    PCAnalytics.event('one_last_step_pop_c', {
      'type': _isVideo ? 'ad' : widget.taskTitle.trim().toLowerCase(),
    });
    setState(() => _busy = true);
    PCWithdrawalAdResult result;
    try {
      final typed = widget.onActionOutcome;
      result = typed != null
          ? await typed()
          : await widget.onAction!()
          ? PCWithdrawalAdResult.applied
          : PCWithdrawalAdResult.failed;
    } catch (_) {
      if (mounted && !_closed) {
        setState(() => _busy = false);
        PCDialogTool.toast(
          context,
          'Unable to save progress. Please try again.',
        );
      }
      return;
    }
    if (!mounted || _closed) return;
    if (result.isApplied) {
      if (_isVideo &&
          widget.currentProgress != null &&
          _progress < widget.target) {
        setState(() => _busy = false);
        return;
      }
      _closed = true;
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _busy = false;
        _adFailed = _isVideo && result == PCWithdrawalAdResult.failed;
      });
    }
  }

  String get _taskText {
    final progress = _progress;
    switch (widget.taskTitle.trim().toLowerCase()) {
      case 'quiz':
        return 'Answer $progress/${widget.target} Question Right';
      case 'spin':
        return 'Spin $progress/${widget.target} Times';
      case 'video':
        return 'Watch $progress/${widget.target} Videos';
      default:
        return widget.taskTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_adFailed) {
      return const PCAdLoadingFailedDialog();
    }
    return PopScope(
      canPop: !_busy,
      child: PCWithdrawalWhiteCard(
        height: 388,
        title: 'One Last Step',
        onClose: _busy ? null : () => Navigator.of(context).pop(false),
        children: [
          Positioned(
            left: 62,
            top: 64,
            width: 180,
            height: 116,
            child: PCWithdrawalPaymentCard(amount: widget.withdrawalTarget),
          ),
          const Positioned(
            left: 16,
            right: 16,
            top: 192,
            height: 48,
            child: PCText(
              text: 'Only One Step Away From\nSuccessful Withdrawal',
              size: 16,
              color: Color(0xFF13395F),
              weight: FontWeight.w600,
              maxLines: 2,
              height: 1.5,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 252,
            height: 16,
            child: PCText(
              key: const ValueKey('pcWithdrawalTaskDescription'),
              text: _taskText,
              size: 12,
              color: const Color(0xFFFF4C4C),
              weight: FontWeight.w400,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 280,
            height: 16,
            child: PCWithdrawalProgressBar(
              key: const ValueKey('pcWithdrawalTaskProgress'),
              progress: widget.target > 0 ? _progress / widget.target : 0,
              label: '$_progress/${widget.target}',
              labelAt: (value) =>
                  '${(value * widget.target).round()}/${widget.target}',
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            height: 52,
            child: PCWithdrawalBlueButton(
              key: const ValueKey('pcWithdrawalTaskAction'),
              text: 'Cash Out',
              video: _isVideo,
              busy: _busy,
              onTap: _action,
            ),
          ),
        ],
      ),
    );
  }
}
