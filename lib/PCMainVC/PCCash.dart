import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_text.dart';

final GlobalKey<PCCashState> homeKey = GlobalKey<PCCashState>();

class PCCash extends StatefulWidget {
  const PCCash({super.key});

  @override
  State<PCCash> createState() => PCCashState();
}

class PCCashState extends State<PCCash> with SingleTickerProviderStateMixin {
  static const _payoutAmounts = <int>[100, 120, 150, 200];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final scale = (width / 360).clamp(0.82, 1.35).toDouble();
              final safeTop = MediaQuery.paddingOf(context).top;
              // The host scaffold keeps the body below the transparent status
              // bar. Add the reference design's top breathing room once more
              // so the payment controls align with the supplied 360px layout.
              final contentTop = safeTop + 19 * scale;

              double s(double value) => value * scale;

              final contentHeight = math.max(height, s(620));
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    width: width,
                    height: width * (1120 / 720),
                    child: PCImg(
                      name: 'cs_cash_top_bg',
                      width: width,
                      height: width * (1120 / 720),
                    ),
                  ),
                  SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: width,
                      height: contentHeight,
                      child: Stack(
                        children: [
                          _buildPaymentHeader(contentTop, s),
                          _buildAccountCard(
                            provider,
                            width,
                            contentTop + s(58),
                            s,
                          ),
                          _buildPayoutList(width, contentTop + s(212), s),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPaymentHeader(double top, double Function(double) s) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: s(18),
            top: top,
            width: s(100),
            height: s(36),
            child: PCImg(name: 'cs_cash_act_0_s', width: s(100), height: s(36)),
          ),
          Positioned(
            left: s(122),
            top: top,
            width: s(36),
            height: s(36),
            child: ParticleButton(
              onTap: () {},
              child: PCImg(name: 'cs_time_icon', width: s(36), height: s(36)),
            ),
          ),
          Positioned(
            right: s(16),
            top: top,
            width: s(36),
            height: s(36),
            child: ParticleButton(
              onTap: () {},
              child: PCImg(
                name: 'cs_replece_icon',
                width: s(36),
                height: s(36),
              ),
            ),
          ),
          Positioned(
            right: s(28),
            top: top + s(42),
            width: s(147),
            height: s(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFDD1B),
                borderRadius: BorderRadius.circular(s(13)),
              ),
              child: Center(
                child: PCText(
                  text: 'Super easy cash today!',
                  size: s(12),
                  color: const Color(0xFFFF5D1F),
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    PCLocalProvider provider,
    double width,
    double top,
    double Function(double) s,
  ) {
    final cardWidth = width - s(32);
    final balance = provider.pc_dollar_number;
    final balanceLabel = balance > 0
        ? '\$${balance.toStringAsFixed(0)}'
        : '\$1000';

    return Positioned(
      left: s(16),
      top: top,
      width: cardWidth,
      height: s(132),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(s(8)),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: const Color(0xFFF0F9FE))),
            Positioned(
              right: 0,
              bottom: 0,
              width: s(82),
              height: s(64),
              child: ClipPath(
                clipper: _AccountCardCornerClipper(),
                child: const ColoredBox(color: Color(0xFFD5EEF9)),
              ),
            ),
            Positioned(
              left: s(12),
              top: s(13),
              child: PCText(
                text: 'My Account',
                size: s(12),
                color: const Color(0xFF7A858C),
                weight: FontWeight.w500,
              ),
            ),
            Positioned(
              left: s(11),
              top: s(29),
              child: PCText(
                text: balanceLabel,
                size: s(30),
                color: Colors.black,
                weight: FontWeight.w900,
              ),
            ),
            Positioned(
              right: s(12),
              top: s(20),
              width: s(112),
              height: s(36),
              child: ParticleButton(
                onTap: () {},
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2375E9),
                    borderRadius: BorderRadius.circular(s(20)),
                  ),
                  child: Center(
                    child: PCText(
                      text: 'Cash Out',
                      size: s(14),
                      color: Colors.white,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: s(12),
              right: s(12),
              top: s(76),
              height: s(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(s(8)),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFFD4DEE4)),
                    ),
                    Positioned(
                      left: s(2),
                      top: s(2),
                      bottom: s(2),
                      width: s(93),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(s(6)),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFDD23), Color(0xFFFF710A)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: s(12),
              top: s(70),
              width: s(72),
              height: s(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PCImg(name: 'cs_pp_bg', width: s(72), height: s(24)),
                  Positioned(
                    left: s(5),
                    child: PCImg(
                      name: 'cs_pp_0_icon',
                      width: s(20),
                      height: s(20),
                    ),
                  ),
                  Positioned(
                    right: s(7),
                    child: PCText(
                      text: '\$100',
                      size: s(12),
                      color: const Color(0xFFFFAD00),
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: s(103),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: s(12),
                    color: const Color(0xFF3C454C),
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                  children: const [
                    TextSpan(text: 'Only '),
                    TextSpan(
                      text: '\$0.9',
                      style: TextStyle(color: Color(0xFFFF4E48)),
                    ),
                    TextSpan(text: ' left to withdraw \$100'),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutList(double width, double top, double Function(double) s) {
    final cardWidth = width - s(32);
    return Positioned(
      left: s(16),
      right: s(16),
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PCText(
            text: 'Choose payout amount',
            size: s(18),
            color: Colors.black,
            weight: FontWeight.w800,
          ),
          SizedBox(height: s(13)),
          ..._payoutAmounts.map(
            (amount) => Padding(
              padding: EdgeInsets.only(bottom: s(12)),
              child: _buildPayoutCard(cardWidth, amount, s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(double width, int amount, double Function(double) s) {
    return SizedBox(
      width: width,
      height: s(60),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(s(8)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: s(12),
              top: s(13),
              child: PCText(
                text: '\$$amount',
                size: s(26),
                color: Colors.black,
                weight: FontWeight.w900,
              ),
            ),
            Positioned(
              right: s(12),
              top: s(14),
              width: s(92),
              height: s(32),
              child: ParticleButton(
                onTap: () {},
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2375E9),
                    borderRadius: BorderRadius.circular(s(18)),
                  ),
                  child: Center(
                    child: PCText(
                      text: 'Withdraw',
                      size: s(14),
                      color: Colors.white,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCardCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _AccountCardCornerClipper oldClipper) => false;
}
