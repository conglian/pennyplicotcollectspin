import '../../PCTool/PCAnalytics.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../PCOther/PCAdLoadingFailedDialog.dart';
import '../PCOther/PCDialogTool.dart';

import '../../PCTool/PCNoticeMessage.dart';
import '../../PCTool/PCWithdrawalController.dart';
import '../../PCTool/PCWithdrawalQueueTable.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_shou_icon.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCWithdrawalDialogWidgets.dart';
import 'PCWithdrawalRankToast.dart';

/// 提现审核队列（Withdrawal Approval，Figma 235:583/236:779）。
/// Skip Wait等待真实广告回调，仅播放失败显示失败面板；取消保留队列，保存异常单独提示。
/// 成功更新排名并保留弹窗，由用户关闭；排到第一名则在排名反馈结束后自动退出，串行进入提现任务。
/// 请求和反馈期间不可重复看广告，广告结束即可手动关闭，不自行变更队列数据。
class PCWithdrawalApprovalDialog extends StatefulWidget {
  const PCWithdrawalApprovalDialog({
    super.key,
    required this.withdrawalTarget,
    required this.rank,
    required this.queueCount,
    this.onSkipWait,
    this.onSkipWaitOutcome,
    this.entries = const [],
    this.account = '',
    this.showHint = true,
    this.currentRank,
    this.currentQueueCount,
    this.rankDisplayDuration = const Duration(seconds: 2),
  }) : assert(onSkipWait != null || onSkipWaitOutcome != null);
  final double withdrawalTarget;
  final int rank;
  final int queueCount;
  final List<PCWithdrawalQueueEntry> entries;
  final String account;
  final bool showHint;
  final Future<bool> Function()? onSkipWait;
  final Future<PCWithdrawalAdResult> Function()? onSkipWaitOutcome;
  final int Function()? currentRank, currentQueueCount;
  final Duration rankDisplayDuration;

  @override
  State<PCWithdrawalApprovalDialog> createState() =>
      _PCWithdrawalApprovalDialogState();
}

class _PCWithdrawalApprovalDialogState
    extends State<PCWithdrawalApprovalDialog> {
  bool _busy = false;
  bool _showRank = false;
  bool _closed = false;
  bool _adFailed = false;
  Timer? _timer;

  Future<void> _skip() async {
    if (_busy ||
        _showRank ||
        _closed ||
        (widget.currentRank?.call() ?? widget.rank) <= 1) {
      return;
    }
    PCAnalytics.event('cash_queue_po_c');
    setState(() => _busy = true);
    PCWithdrawalAdResult result;
    try {
      final typed = widget.onSkipWaitOutcome;
      result = typed != null
          ? await typed()
          : await widget.onSkipWait!()
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
    if (!result.isApplied) {
      setState(() {
        _busy = false;
        _adFailed = result == PCWithdrawalAdResult.failed;
      });
      return;
    }
    setState(() {
      _busy = false;
      _showRank = true;
    });
    _timer = Timer(widget.rankDisplayDuration, () {
      if (!mounted || _closed) return;
      if ((widget.currentRank?.call() ?? widget.rank) <= 1) {
        _close(true);
      } else {
        setState(() => _showRank = false);
      }
    });
  }

  void _close(bool result) {
    if (!mounted || _closed || (_busy && !result)) return;
    _closed = true;
    _timer?.cancel();
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adFailed) {
      return PCAdLoadingFailedDialog(onClose: () => _close(false));
    }
    final media = MediaQuery.of(context);
    final compact = media.size.height - media.padding.vertical < 640;
    final reduced = media.disableAnimations;
    final rank = widget.currentRank?.call() ?? widget.rank;
    final queueCount = widget.currentQueueCount?.call() ?? widget.queueCount;
    return PopScope(
      canPop: !_busy,
      child: PCWithdrawalWhiteCard(
        height: 512,
        extraHeight: widget.showHint ? (compact ? 64 : 112) : 0,
        title: 'Withdrawal Approval',
        onClose: _busy ? null : () => _close(false),
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
              text:
                  'Congratulations, You Are In The\nWithdrawal Approval Queue.',
              size: 16,
              color: Color(0xFF13395F),
              weight: FontWeight.w600,
              maxLines: 2,
              height: 1.5,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 252,
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _number('$queueCount'),
                  const PCText(
                    text: ' In Queue, Your Current Rank: ',
                    size: 14,
                    color: Colors.black,
                    weight: FontWeight.w600,
                  ),
                  _number('$rank'),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 280,
            height: 140,
            child: PCWithdrawalQueueTable(
              currentRank: rank,
              queueCount: queueCount,
              entries: widget.entries,
              amountColor: const Color(0xFFCB8200),
              currentAccount: widget.account,
              currentAmount: widget.withdrawalTarget,
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            height: 52,
            child: PCWithdrawalBlueButton(
              key: const ValueKey('pcWithdrawalSkipWait'),
              text: 'Skip Wait',
              video: true,
              busy: _busy,
              onTap: _showRank || rank <= 1 ? null : _skip,
            ),
          ),
          if (widget.showHint) ...[
            Positioned(
              right: -18,
              top: 464,
              width: 60,
              height: 60,
              child: IgnorePointer(
                child: reduced
                    ? const PCImg(name: 'pc_shou_icon')
                    : const PCShouIcon(),
              ),
            ),
            Positioned(
              left: 20,
              top: compact ? 520 : 526,
              width: 220,
              height: compact ? 48 : 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FFEF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 4 : 6,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PCText(
                      text:
                          'No need to wait, watch ads and\ncash out ${PCNoticeMessage.money(widget.withdrawalTarget)} faster!',
                      size: 14,
                      color: Colors.black,
                      weight: FontWeight.w400,
                      maxLines: 2,
                      height: 20 / 14,
                    ),
                  ),
                ),
              ),
            ),
            if (!compact)
              const Positioned(
                left: 36,
                top: 590,
                width: 32,
                height: 32,
                child: ClipOval(child: PCImg(name: 'pc_rank_avatar_01')),
              ),
          ],
          if (_showRank)
            Positioned(
              left: 67,
              top: 234,
              width: 170,
              height: 44,
              child: PCWithdrawalRankToast(
                key: const ValueKey('pcWithdrawalRankToast'),
                rank: rank,
              ),
            ),
        ],
      ),
    );
  }

  Widget _number(String text) => PCStrokeText(
    text: text,
    size: 14,
    color: const Color(0xFFFFDF28),
    weight: FontWeight.w600,
    skColor: const Color(0xFF9B5C00),
    skWidth: .5,
  );
}
