import 'package:flutter/material.dart';

import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 收款账户确认反馈弹窗（Official Notice）。
///
/// 以黄色加粗突出脱敏账号 [maskedUserId]，并展示距提现还差的金额 [remainingAmount]；
/// 点击 Continue 后先关闭弹窗，再执行 [onContinue]。
class PCAccountFeedbackDialog extends StatelessWidget {
  final String maskedUserId;
  final double remainingAmount;
  final VoidCallback? onContinue;

  const PCAccountFeedbackDialog({
    super.key,
    this.maskedUserId = '1***2334',
    this.remainingAmount = 4,
    this.onContinue,
  });

  void _close(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _continue(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _close(context);
    onContinue?.call();
  }

  String get _amountText {
    final value = remainingAmount < 0 ? 0.0 : remainingAmount;
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '\$$formatted';
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      minimum: EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = PCAdaptiveLayout.fitScale(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            designWidth: 328,
            designHeight: 560,
          ).clamp(1.0, PCAdaptiveLayout.maxCanvasScale).toDouble();
          double s(double value) => value * scale;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: SizedBox(
                  width: s(304),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(s(16)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(s(20), s(10), s(20), s(20)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: s(44),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Center(
                                    child: PCText(
                                      text: 'Official Notice',
                                      size: s(20),
                                      height: 1.2,
                                      color: Colors.black,
                                      weight: FontWeight.w700,
                                      align: TextAlign.center,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: s(-8),
                                  top: 0,
                                  width: s(44),
                                  height: s(44),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _close(context),
                                    child: Center(
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: s(24),
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: s(10)),
                          PCText(
                            text: 'Dear User ',
                            size: s(16),
                            height: 1.35,
                            color: Colors.black,
                            weight: FontWeight.w600,
                            maxLines: 3,
                            spans: [
                              TextSpan(
                                text: maskedUserId,
                                style: TextStyle(
                                  color: const Color(0xFFFFAF00),
                                  fontSize: s(18),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ':'),
                            ],
                          ),
                          SizedBox(height: s(14)),
                          PCText(
                            text:
                                'Your payment information has been confirmed successfully, You are a new user, it will be super easy to withdraw cash today!',
                            size: s(16),
                            height: 1.4,
                            color: Color(0xFF393939),
                            weight: FontWeight.w400,
                            maxLines: 12,
                          ),
                          SizedBox(height: s(20)),
                          // 金额独立加粗；宽度不足时换行，不把整句连同金额一起缩小。
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: s(4),
                            runSpacing: s(4),
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PCText(
                                    text: 'Only ',
                                    size: s(20),
                                    height: 1.25,
                                    color: Colors.black,
                                    weight: FontWeight.w700,
                                  ),
                                  PCStrokeText(
                                    text: _amountText,
                                    size: s(28),
                                    color: Color(0xFFFFC21D),
                                    weight: FontWeight.w900,
                                    skWidth: s(1.2),
                                    skColor: Color(0xFFB76B00),
                                  ),
                                ],
                              ),
                              PCText(
                                text: 'left to withdraw',
                                size: s(20),
                                height: 1.25,
                                color: Colors.black,
                                weight: FontWeight.w700,
                              ),
                            ],
                          ),
                          SizedBox(height: s(16)),
                          PCText(
                            text:
                                'Want to stack up more cash? Keep earning now!',
                            size: s(14),
                            height: 1.35,
                            color: Color(0xFF8A8A8A),
                            weight: FontWeight.w400,
                            align: TextAlign.center,
                            maxLines: 3,
                          ),
                          SizedBox(height: s(22)),
                          SizedBox(
                            height: s(52),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(s(26)),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF1486F8),
                                    Color(0xFF2365EA),
                                  ],
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(s(26)),
                                  onTap: () => _continue(context),
                                  child: Center(
                                    child: PCText(
                                      text: 'Continue',
                                      size: s(16),
                                      color: Colors.white,
                                      weight: FontWeight.w700,
                                      align: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
