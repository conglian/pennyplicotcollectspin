import 'package:flutter/material.dart';

import '../../PCTool/pc_text.dart';
import 'PCGuidePageLayout.dart';

/// Figma「引导页2」：错误栏从左滑入、正确栏从右滑入，最后出现 Continues。
///
/// 按钮完整出现后可点击，保存当前步骤并进入引导3。
class PCGuide2Page extends StatefulWidget {
  const PCGuide2Page({super.key, required this.onNext, this.isBusy = false});

  final VoidCallback onNext;
  final bool isBusy;

  @override
  State<PCGuide2Page> createState() => _PCGuide2PageState();
}

class _PCGuide2PageState extends State<PCGuide2Page>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wrong;
  late final Animation<double> _correct;
  late final Animation<double> _button;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _wrong = _controller.drive(
      CurveTween(curve: const Interval(0, .34, curve: Curves.easeOutCubic)),
    );
    _correct = _controller.drive(
      CurveTween(curve: const Interval(.34, .70, curve: Curves.easeOutCubic)),
    );
    _button = _controller.drive(
      CurveTween(curve: const Interval(.72, 1, curve: Curves.easeOutCubic)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _reveal(
    Animation<double> animation, {
    required Offset from,
    required Widget child,
    bool isButton = false,
    bool fade = true,
  }) => AnimatedBuilder(
    animation: animation,
    child: RepaintBoundary(child: child),
    builder: (context, child) => IgnorePointer(
      ignoring: isButton && animation.value < 1,
      child: Opacity(
        opacity: fade ? animation.value : 1,
        child: FractionalTranslation(
          translation: from * (1 - animation.value),
          child: child,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PCGuidePageLayout(
    title: 'Where Does The Ad Money Really\nGo?',
    buttonText: 'Continues',
    onNext: widget.onNext,
    isBusy: widget.isBusy,
    buttonTransitionBuilder: (button) => _reveal(
      _button,
      from: const Offset(0, .22),
      child: button,
      isButton: true,
    ),
    illustration: Stack(
      children: [
        Positioned.fill(
          child: _reveal(
            _wrong,
            from: const Offset(-1, 0),
            fade: false,
            child: Stack(
              children: const [
                PCGuideArtwork(
                  name: 'pc_guide_intro_other_panel',
                  left: 0,
                  top: 64,
                  width: 319.6758,
                  height: 124,
                ),
                Positioned(
                  left: 20,
                  top: 72,
                  width: 100,
                  height: 28,
                  child: PCText(
                    text: 'Other App',
                    size: 20,
                    height: 1.4,
                    color: Color(0xFF435543),
                    weight: FontWeight.w700,
                  ),
                ),
                Positioned(
                  left: 130,
                  top: 72,
                  width: 150,
                  height: 28,
                  child: PCText(
                    text: 'Gready Developers',
                    size: 14,
                    height: 2,
                    color: Color(0xFF435543),
                    weight: FontWeight.w400,
                  ),
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_other_inner',
                  left: 12,
                  top: 104,
                  width: 289.9,
                  height: 76,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_paypal_wordmark',
                  left: 16,
                  top: 108,
                  width: 116.3636,
                  height: 37.8182,
                ),
                Positioned(
                  left: 25,
                  top: 146,
                  width: 100,
                  height: 28,
                  child: PCText(
                    text: '\$****',
                    size: 16,
                    height: 1.75,
                    color: Color(0xFF667966),
                    weight: FontWeight.w700,
                  ),
                ),
                Positioned(
                  left: 144,
                  top: 112,
                  width: 145,
                  height: 60,
                  child: PCText(
                    text: '‘Sorry, out of stock’\n‘Watch 100 ads to\ncash out’',
                    size: 14,
                    height: 20 / 14,
                    maxLines: 3,
                    color: Color(0xFF667966),
                    weight: FontWeight.w500,
                  ),
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_reject',
                  left: 292,
                  top: 48,
                  width: 48,
                  height: 48,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: _reveal(
            _correct,
            from: const Offset(1, 0),
            fade: false,
            child: Stack(
              children: const [
                PCGuideArtwork(
                  name: 'pc_guide_intro_our_panel',
                  left: 39.7852,
                  top: 220,
                  width: 320.2148,
                  height: 140,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_rays',
                  left: 157,
                  top: 172,
                  width: 203,
                  height: 236,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_app_logo',
                  left: 92,
                  top: 288,
                  width: 60,
                  height: 60,
                ),
                Positioned(
                  left: 75,
                  top: 232,
                  width: 115,
                  height: 32,
                  child: PCText(
                    text: 'Our App',
                    size: 24,
                    height: 32 / 24,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                Positioned(
                  left: 72,
                  top: 264,
                  width: 115,
                  height: 16,
                  child: PCText(
                    text: 'We Share Profit!',
                    size: 14,
                    height: 16 / 14,
                    color: Colors.white,
                    weight: FontWeight.w400,
                  ),
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_payment',
                  left: 193,
                  top: 236,
                  width: 167,
                  height: 110,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_bill_1',
                  left: 85,
                  top: 201,
                  width: 47.2612,
                  height: 43.577,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_bill_2',
                  left: 23,
                  top: 265,
                  width: 53,
                  height: 53,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_bill_3',
                  left: 137,
                  top: 257,
                  width: 74.4688,
                  height: 60.0582,
                ),
                PCGuideArtwork(
                  name: 'pc_guide_intro_accept',
                  left: 20,
                  top: 204,
                  width: 48,
                  height: 48,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
