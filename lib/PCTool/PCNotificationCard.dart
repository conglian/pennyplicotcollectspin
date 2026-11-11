import 'package:flutter/material.dart';

import 'PCNoticeMessage.dart';
import 'pc_extension_help.dart';
import 'pc_img.dart';
import 'pc_stroke_text.dart';
import 'pc_text.dart';

/// 通知内容卡片：文字、金额、按钮与背景分层，支持系统通知样式预览。
/// 站内与系统预览复用账户或目标样式，按钮根据通知跳转 Cash 或 Quiz。
class PCNotificationCard extends StatelessWidget {
  const PCNotificationCard({
    super.key,
    required this.message,
    required this.onAction,
    this.onDismiss,
    this.compact = false,
    this.inApp = false,
    this.onCompactWithdraw,
  });
  final PCNoticeMessage message;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;
  final bool compact;
  final bool inApp;
  final VoidCallback? onCompactWithdraw;

  @override
  Widget build(BuildContext context) {
    final height = compact
        ? 60.0
        : message.kind == PCNoticeKind.account
        ? 116.0
        : 172.0;
    return Semantics(
      container: true,
      label: '${message.title}. ${message.body}',
      child: AspectRatio(
        aspectRatio: 328 / height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: 328,
            height: height,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: compact
                          ? _compact()
                          : message.kind == PCNoticeKind.account
                          ? _account()
                          : _goal(),
                    ),
                  ),
                  if (onDismiss != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Semantics(
                        label: 'Close notification',
                        button: true,
                        child: ParticleButton(
                          key: const ValueKey('pcNoticeClose'),
                          onTap: onDismiss!,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xB3002211),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 17,
                              color: Colors.white,
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
    );
  }

  Widget _text(
    String text,
    double size, {
    Color color = Colors.white,
    int lines = 1,
    FontWeight weight = FontWeight.w600,
  }) => PCText(
    text: text,
    size: size,
    color: color,
    weight: weight,
    align: TextAlign.center,
    maxLines: lines,
    height: 1.18,
  );

  Widget _blueButton({double width = double.infinity, bool compact = false}) =>
      ParticleButton(
        key: const ValueKey('pcNoticeAction'),
        breathing: !compact && message.button == 'Claim',
        onTap: compact ? onCompactWithdraw ?? onAction : onAction,
        child: Container(
          width: width,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF168BFF), Color(0xFF2461EE)],
            ),
          ),
          child: _text(
            compact ? 'Withdraw' : message.button,
            14,
            weight: FontWeight.w800,
          ),
        ),
      );

  Widget _account() => ColoredBox(
    color: Colors.white,
    child: Stack(
      children: [
        const Positioned(
          right: 0,
          bottom: 0,
          width: 68,
          height: 68,
          child: PCImg(name: 'pc_notice_paypal'),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _text('You Pending Withdraw', 10, color: Colors.black),
        ),
        const Positioned(
          left: 12,
          top: 44,
          width: 52,
          height: 52,
          child: PCImg(name: 'pc_guide_intro_app_logo'),
        ),
        Positioned(
          left: 76,
          top: 36,
          width: 235,
          height: 24,
          child: Row(
            children: [
              Flexible(
                child: _text(
                  'My Cash Account=',
                  15,
                  color: Colors.black,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              PCStrokeText(
                text: message.amount,
                weight: FontWeight.w800,
                size: 17,
                color: const Color(0xFFFFC000),
                skColor: const Color(0xFF7E3900),
                skWidth: 1,
              ),
            ],
          ),
        ),
        Positioned(left: 76, top: 68, right: 12, child: _blueButton()),
      ],
    ),
  );

  Widget _goal() => ColoredBox(
    color: Colors.white,
    child: Column(
      children: [
        Container(
          height: 120,
          width: 328,
          decoration: BoxDecoration(image: PCDImg('pc_notice_goal_bg')),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            children: [
              FittedBox(
                child: _text(message.title, 22, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              _text(message.body, 13, lines: 3, weight: FontWeight.w500),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _blueButton(),
        ),
      ],
    ),
  );

  Widget _compact() => ColoredBox(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const PCImg(name: 'pc_guide_intro_app_logo', width: 44, height: 44),
          const SizedBox(width: 8),
          Expanded(
            child: message.kind == PCNoticeKind.account
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _text(
                        message.title,
                        13,
                        color: Colors.black,
                        weight: FontWeight.w800,
                      ),
                      PCStrokeText(
                        text: message.amount,
                        weight: FontWeight.w800,
                        size: 17,
                        color: const Color(0xFFFFC000),
                        skColor: const Color(0xFF7E3900),
                        skWidth: 1,
                      ),
                    ],
                  )
                : _text('Add A Little More To...', 12, color: Colors.black),
          ),
          const SizedBox(width: 8),
          _blueButton(width: 88, compact: true),
        ],
      ),
    ),
  );
}
