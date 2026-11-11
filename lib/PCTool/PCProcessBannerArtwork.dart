import 'package:flutter/material.dart';

import 'PCNoticeMessage.dart';
import 'pc_img.dart';
import 'pc_stroke_text.dart';
import 'pc_text.dart';

/// 3.7 红色倾斜横幅的共用画面（Figma 211:757 / 211:808）。
/// 原生导出的底板、飘带、光晕分层显示；标题、正文及金额保持动态。
/// 仅绘制360×332设计画面，外部负责等比尺寸、平移动画和统一遮罩。
class PCProcessBannerArtwork extends StatelessWidget {
  const PCProcessBannerArtwork.accountConfirmed({
    super.key,
    required this.withdrawalTarget,
  }) : message = null,
       _accountConfirmed = true,
       _channelActivated = false;

  const PCProcessBannerArtwork.quiz({
    super.key,
    required String this.message,
    required this.withdrawalTarget,
  }) : _accountConfirmed = false,
       _channelActivated = false;

  const PCProcessBannerArtwork.channelActivated({super.key})
    : withdrawalTarget = 0,
      message = null,
      _accountConfirmed = false,
      _channelActivated = true;

  final double withdrawalTarget;
  final String? message;
  final bool _accountConfirmed;
  final bool _channelActivated;
  static const aspectRatio = 360 / 332;
  static const _titleShadow = [
    Shadow(offset: Offset(2, 2), blurRadius: 1.2, color: Color(0xB3B2000E)),
  ];
  static const _bodyShadow = [
    Shadow(offset: Offset(2, 1), blurRadius: 1, color: Color(0xB3B2000E)),
  ];

  (String, String) get _quizText {
    final text = message!.trim();
    final bang = text.indexOf('!');
    final dash = text.indexOf(' — ');
    String title;
    String body;
    if (bang >= 0) {
      title = text.substring(0, bang + 1);
      body = text.substring(bang + 1).trim();
    } else if (dash > 0) {
      title = text.substring(0, dash);
      body = text.substring(dash + 3).trim();
    } else {
      title = text;
      body = '';
    }
    final amount = PCNoticeMessage.money(withdrawalTarget);
    if (body.isEmpty) body = 'Today Super Easy Cash Out $amount';
    if (body.startsWith('Today Super Easy Cash Out ') &&
        body.endsWith(amount)) {
      body = 'Today Super Easy Cash Out\n$amount';
    }
    return (title, body);
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _accountConfirmed || _channelActivated ? null : _quizText;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: 360,
        height: 332,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _image('pc_process_account_bottom_glow', 0, 186, 360, 120),
            _image(
              'pc_process_account_red_glow',
              85.624,
              98.578,
              274.376,
              233.422,
            ),
            _image('pc_process_account_top_glow', 0, 0, 360, 275.832),
            _image('pc_process_account_top_strip', 219, 44, 141, 80.277),
            _image('pc_process_account_banner', 28, 66, 332, 195.281),
            _image('pc_process_account_bottom_strip', 105, 228, 255, 63.165),
            _image(
              'pc_process_account_light',
              50.861,
              167.75,
              309.139,
              134.508,
            ),
            _image('pc_process_account_star', 18, 39, 20, 20),
            _image('pc_process_account_star', 309, 274, 11, 11),
            _image('pc_process_account_star', 43, 63, 11, 11),
            _image('pc_process_account_star', 242, 26, 14, 14),
            _image('pc_process_account_star', 59, 300, 14, 14),
            _image('pc_process_account_star', 268, 288, 28, 28),
            if (_accountConfirmed)
              _image('pc_process_account_check', 42, 142.832, 23.636, 28.168),
            if (_channelActivated)
              Positioned(
                left: 46,
                top: 151.879,
                width: 295,
                child: Transform(
                  transform: _slant(),
                  alignment: Alignment.topLeft,
                  child: const PCText(
                    text: 'Withdrawal Boost\nAccess Unlocked',
                    size: 32,
                    color: Colors.white,
                    weight: FontWeight.w600,
                    height: 40 / 32,
                    maxLines: 2,
                    shadows: _titleShadow,
                  ),
                ),
              ),
            if (!_channelActivated)
              Positioned(
                left: _accountConfirmed ? 69 : 46,
                // Figma矩阵的变换前原点；不能使用倾斜后包围盒的顶部坐标。
                top: _accountConfirmed ? 138.879 : 143.879,
                width: _accountConfirmed ? 277 : 251,
                height: 28,
                child: Transform(
                  transform: _slant(),
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PCText(
                      text: _accountConfirmed
                          ? 'Payout Details Confirmed'
                          : quiz!.$1,
                      size: _accountConfirmed ? 24 : 32,
                      color: Colors.white,
                      weight: FontWeight.w600,
                      height: _accountConfirmed ? 28 / 24 : 28 / 32,
                      shadows: _titleShadow,
                    ),
                  ),
                ),
              ),
            if (!_channelActivated)
              Positioned(
                left: _accountConfirmed ? 42 : 46,
                top: _accountConfirmed ? 180.094 : 185.094,
                width: 300,
                child: Transform(
                  transform: _slant(),
                  alignment: Alignment.topLeft,
                  child: _accountConfirmed
                      ? _accountBody()
                      : PCText(
                          text: quiz!.$2,
                          size: 20,
                          color: Colors.white,
                          weight: FontWeight.w600,
                          maxLines: 2,
                          height: 28 / 20,
                          shadows: _bodyShadow,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _accountBody() => RichText(
    text: TextSpan(
      style: TextStyle(
        fontFamily: text_fontName,
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.w600,
        height: 1.4,
        shadows: _bodyShadow,
      ),
      children: [
        const TextSpan(text: 'Quiz To Release Your '),
        TextSpan(
          text: PCNoticeMessage.money(withdrawalTarget),
          style: const TextStyle(
            color: Color(0xFFFFE74D),
            fontSize: 28,
            height: 1,
          ),
        ),
        const TextSpan(text: '\nCash Out.'),
      ],
    ),
  );

  static Matrix4 _slant() => Matrix4.identity()
    ..setEntry(0, 0, .9848077297)
    ..setEntry(1, 0, -.1736481637);

  static Widget _image(
    String name,
    double x,
    double y,
    double width,
    double height,
  ) => Positioned(
    left: x,
    top: y,
    width: width,
    height: height,
    child: PCImg(name: name, fit: BoxFit.fill),
  );
}
