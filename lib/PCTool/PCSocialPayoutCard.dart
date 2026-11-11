import 'package:flutter/material.dart';

import 'PCSocialPayoutNotice.dart';
import 'pc_extension_help.dart';
import 'pc_img.dart';
import 'pc_stroke_text.dart';
import 'pc_text.dart';

/// 站内提现播报卡（Figma「站内通知」250:1151）。
/// 动态头像、金额与PayPal水印独立搭建，点击收起后打开提现页。
class PCSocialPayoutCard extends StatelessWidget {
  const PCSocialPayoutCard({
    super.key,
    required this.notice,
    required this.onAction,
  });
  final PCSocialPayoutNotice notice;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final split = notice.bodyTemplate.split('{amount}');
    return Semantics(
      container: true,
      button: true,
      label: '${notice.title}. ${notice.body}',
      child: AspectRatio(
        aspectRatio: 328 / 88,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: 328,
            height: 88,
            child: Material(
              color: Colors.transparent,
              child: ParticleButton(
                key: const ValueKey('pcSocialNoticeAction'),
                onTap: onAction,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
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
                          top: 16,
                          width: 56,
                          height: 56,
                          child: ClipOval(
                            child: PCImg(
                              name: notice.avatarName,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 80,
                          top: 12,
                          width: 236,
                          height: 20,
                          child: PCText(
                            text: notice.title,
                            size: 14,
                            color: Colors.black,
                            weight: FontWeight.w700,
                            height: 20 / 14,
                          ),
                        ),
                        Positioned(
                          left: 80,
                          top: 36,
                          width: 236,
                          height: 40,
                          // 局部富文本用于设计中的红色金额，保持项目字体与两行布局。
                          child: RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: text_fontName,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 20 / 14,
                                color: Color(0xFF393939),
                              ),
                              children: [
                                TextSpan(text: '${notice.name} ${split.first}'),
                                TextSpan(
                                  text: notice.amountText,
                                  style: const TextStyle(
                                    color: Color(0xFFFF4C4C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (split.length > 1)
                                  TextSpan(text: split.last),
                              ],
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
        ),
      ),
    );
  }
}
