import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../PCDialog/PCWithdrawFlow/PCWithdrawalDialogWidgets.dart';
import 'PCNumberManager.dart';
import 'PCQuizConfig.dart';
import 'PCWithdrawValidation.dart';
import 'pc_text.dart';

/// 提现页和排队弹窗共用的榜单，固定表头并将当前名次定位到可见区域中部。
/// 只在名次、人数或缩放变化时重新定位，普通重建保留用户手动滚动的位置。
class PCWithdrawalQueueTable extends StatefulWidget {
  const PCWithdrawalQueueTable({
    super.key,
    required this.currentRank,
    required this.queueCount,
    required this.entries,
    this.scale = 1,
    this.amountColor = const Color(0xFFCB8200),
    this.currentAccount,
    this.currentAmount,
  });

  final int currentRank, queueCount;
  final List<PCWithdrawalQueueEntry> entries;
  final double scale;
  final Color amountColor;

  /// 当前用户的完整收款账号；旧脱敏存档没有原文时显示占位。
  final String? currentAccount;
  final double? currentAmount;

  @override
  State<PCWithdrawalQueueTable> createState() => _PCWithdrawalQueueTableState();
}

class _PCWithdrawalQueueTableState extends State<PCWithdrawalQueueTable> {
  late final ScrollController _scroll;
  int _positionRevision = 0;

  int get _count => math.max(0, widget.queueCount);
  int get _rank => widget.currentRank.clamp(1, math.max(1, _count));
  double get _rowHeight => 28 * widget.scale;

  double get _targetOffset => ((_rank - 1.0 - 1.5) * _rowHeight).clamp(
    0.0,
    math.max(0.0, (_count - 4) * _rowHeight),
  );

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _targetOffset);
  }

  @override
  void didUpdateWidget(covariant PCWithdrawalQueueTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRank == widget.currentRank &&
        oldWidget.queueCount == widget.queueCount &&
        oldWidget.scale == widget.scale) {
      return;
    }
    final revision = ++_positionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _positionRevision || !_scroll.hasClients) {
        return;
      }
      final target = _targetOffset.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _positionRevision++;
    _scroll.dispose();
    super.dispose();
  }

  PCWithdrawalQueueEntry _entry(int index) {
    final rank = index + 1;
    final amounts = PCNumberHelpers().pc_eqRange;
    final fallbackAccount = 'Player ${100 + (rank * 137 % 900)}';
    final fallbackAmount = amounts[(rank * 7) % amounts.length].toDouble();
    final original = index < widget.entries.length
        ? widget.entries[index]
        : PCWithdrawalQueueEntry(
            userId: '$rank'.padLeft(3, '0'),
            account: fallbackAccount,
            amount: fallbackAmount,
          );
    if (rank != _rank) {
      return PCWithdrawalQueueEntry(
        userId: original.userId,
        account: RegExp(r'^Player \d{3}$').hasMatch(original.account)
            ? original.account
            : fallbackAccount,
        amount: amounts.contains(original.amount)
            ? original.amount
            : fallbackAmount,
      );
    }
    return PCWithdrawalQueueEntry(
      userId: '$rank'.padLeft(3, '0'),
      account: PCWithdrawValidation.displayAccount(widget.currentAccount ?? ''),
      amount: widget.currentAmount ?? PCNumberHelpers().pc_firstTarget,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 140 * widget.scale,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12 * widget.scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9F0F4), width: .5),
        ),
        child: Column(
          children: [
            _row(
              const ['User ID', 'Account', 'Amount'],
              header: true,
              key: const ValueKey('pcWithdrawalQueueHeader'),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('pcWithdrawalQueueList'),
                controller: _scroll,
                primary: false,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemExtent: _rowHeight,
                itemCount: _count,
                itemBuilder: (context, index) {
                  final entry = _entry(index);
                  final current = index + 1 == _rank;
                  return KeyedSubtree(
                    key: ValueKey('pcWithdrawalQueueRow_${index + 1}'),
                    child: _row(
                      [
                        entry.userId,
                        entry.account,
                        '\$${PCQuizReward.format(entry.amount)}',
                      ],
                      shaded: index.isEven,
                      current: current,
                      key: current
                          ? const ValueKey('pcWithdrawalQueueCurrentRow')
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _row(
    List<String> cells, {
    Key? key,
    bool header = false,
    bool shaded = false,
    bool current = false,
  }) => Container(
    key: key,
    height: _rowHeight,
    color: current
        ? const Color(0xFFFFF3CD)
        : shaded
        ? const Color(0xFFE9F0F4)
        : Colors.white,
    child: Row(
      children: [
        for (var column = 0; column < 3; column++)
          Expanded(
            flex: column == 1 ? 2 : 1,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4 * widget.scale),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PCText(
                    text: cells[column],
                    size: 12 * widget.scale,
                    color: !header && column == 2
                        ? widget.amountColor
                        : const Color(0xFF393939),
                    weight: current
                        ? FontWeight.w700
                        : header || column == 2
                        ? FontWeight.w500
                        : FontWeight.w400,
                    align: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
