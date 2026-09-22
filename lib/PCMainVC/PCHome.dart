import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../PCDialog/PCCash/PCCashDialog.dart';
import '../PCDialog/PCGuide/PCGuideDialog.dart';
import '../PCDialog/PCOther/PCOtherDialog.dart';
import '../PCTool/PCLogger.dart';
import '../PCTool/PCRankData.dart';
import '../PCTool/pc_GradientText.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_stroke_text.dart';
import '../PCTool/pc_text.dart';
import 'PCWithdrawPage.dart';

final GlobalKey<PChomeState> homeKey = GlobalKey<PChomeState>();
final GlobalKey pcHomeAppleTargetKey = GlobalKey(
  debugLabel: 'pcHomeAppleTarget',
);
final GlobalKey pcHomePigTargetKey = GlobalKey(debugLabel: 'pcHomePigTarget');

class PChome extends StatefulWidget {
  const PChome({super.key});

  @override
  State<PChome> createState() => PChomeState();
}

class PChomeState extends State<PChome> with WidgetsBindingObserver {
  List<PCUserData> _rankData = [];
  Timer? _rankingRefreshTimer;

  final List<String> _bubbleItems = [
    'pc_quiz_icon',
    'pc_doaller_icon',
    'pc_doaller_icon',
    'pc_apple_icon',
    'pc_wheel_icon',
    'pc_doaller_icon',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRanking();
    _scheduleRankingRefresh();
  }

  Future<void> _loadRanking() async {
    try {
      final data = await PCUserDataManager.getPCUserData();
      if (!mounted) {
        return;
      }
      setState(() {
        _rankData = data.take(50).toList();
      });
    } catch (_) {
      // 本地榜单数据异常时保留已生成的兜底数据。
    }
  }

  void _scheduleRankingRefresh() {
    _rankingRefreshTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final Duration delay = nextMidnight.difference(now);
    _rankingRefreshTimer = Timer(delay, () async {
      await _loadRanking();
      if (mounted) {
        _scheduleRankingRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // getPCUserData compares the persisted date, so this also refreshes
      // when the app was suspended overnight and then opened the next day.
      _loadRanking();
      _scheduleRankingRefresh();
    }
  }

  @override
  void dispose() {
    _rankingRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onBubbleTap(int index) {
    if (!mounted) {
      return;
    }
    HapticFeedback.selectionClick();
    context.tipShow(PCNoNetworkDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final double safeTop = MediaQuery.of(context).padding.top;
              final Size screenSize = MediaQuery.sizeOf(context);
              final double layoutWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : screenSize.width;
              final double layoutHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : screenSize.height;
              final double widthScale = layoutWidth / 375;
              final double heightScale = layoutHeight / 650;
              final double scale = math
                  .min(widthScale, heightScale)
                  .clamp(0.78, 1.22);

              double s(double value) => value * scale;
              double w(double value) => value * widthScale;
              double h(double value) => value * heightScale;

              final double headerHeight = h(112);
              final double bigIconTop = safeTop + h(128);
              final double balanceTop = safeTop + h(240);
              final double minRankTop = math.max(
                safeTop + h(300),
                layoutHeight - h(252),
              );
              final double rankTop = math.min(safeTop + h(430), minRankTop);
              final double broadcastTop = math.max(
                safeTop + h(208),
                rankTop - h(70),
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: PCImg(
                      name: 'pc_home_bg',
                      width: layoutWidth,
                      height: layoutHeight,
                    ),
                  ),

                  Positioned(
                    top: safeTop,
                    left: (0.width(context) - w(328)) * 0.5,
                    height: h(92),
                    width: w(328),
                    child: _buildHomeTopCard(provider, s, w, h),
                  ),
                  Positioned(
                    top: safeTop + 116.h,
                    left: (0.width(context) - 200) * 0.5,
                    height: 48,
                    width: 200,
                    child: Container(
                      decoration: BoxDecoration(image: PCDImg('pc_pig_tips')),
                      height: 48,
                      width: 200,
                    ),
                  ),
                  Positioned(
                    top: balanceTop - 20.h,
                    left: 0,
                    right: 0,
                    height: w(100),
                    child: Center(
                      child: PCImg(
                        name: 'pc_pig_bottom',
                        width: w(280),
                        height: w(100),
                      ),
                    ),
                  ),

                  Positioned(
                    top: bigIconTop,
                    left: 0,
                    right: 0,
                    height: w(169),
                    child: Center(
                      child: PCImg(
                        key: pcHomePigTargetKey,
                        name: 'pc_big_icon_0',
                        width: w(169),
                        height: w(140),
                      ),
                    ),
                  ),

                  Positioned(
                    top: balanceTop,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildBalanceCard(provider, s, w)),
                  ),

                  Positioned(
                    top: safeTop + h(98),
                    left: w(6),
                    child: _buildBubbleColumn(
                      items: _bubbleItems.sublist(0, 3),
                      startIndex: 0,
                      bubbleSize: s(64),
                      columnHeight: h(180),
                    ),
                  ),

                  Positioned(
                    top: safeTop + h(98),
                    right: w(6),
                    child: _buildBubbleColumn(
                      items: _bubbleItems.sublist(3),
                      startIndex: 3,
                      bubbleSize: s(64),
                      columnHeight: h(180),
                    ),
                  ),

                  Positioned(
                    top: broadcastTop,
                    left: w(8),
                    right: w(8),
                    height: h(32),
                    child: _HomeBroadcastTicker(
                      fontSize: s(12),
                      iconSize: s(28),
                    ),
                  ),
                  Positioned(
                    top: rankTop - 32.h,
                    left: w(8),
                    right: w(8),
                    child: PCImg(
                      name: 'pc_home_bottom_bg',
                      width: w(334),
                      height: h(360),
                    ),
                  ),
                  Positioned(
                    top: rankTop - 27.h,
                    width: 0.width(context),
                    child: Row(
                      children: [
                        SizedBox(width: 20.w),
                        PCImg(name: 'pc_guang_icon', width: 20, height: 20),
                        PCGradientStrokeText(
                          text: 'Top Earning Pigs',
                          gradientColors: [
                            '#FFDA50'.color(),
                            '#FFAF00'.color(),
                          ],
                          width: 127.w,
                          height: 24.h,
                          fontSize: 18,
                          strokeWidth: 1,
                          strokeColor: '#032C00'.color(),
                        ),
                        PCText(
                          text: '(Refresh at 0:00 every day)',
                          size: 12,
                          color: '#B6D599'.color(),
                          weight: FontWeight.w500,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: rankTop,
                    left: w(12),
                    right: w(12),
                    bottom: 0,
                    child: _HomeRankingSection(data: _rankData, scale: scale),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHomeTopCard(
    PCLocalProvider provider,
    double Function(double) s,
    double Function(double) w,
    double Function(double) h,
  ) {
    const double withdrawTarget = 100;
    final double balance = provider.pc_dollar_number;
    final double progress = (balance / withdrawTarget).clamp(0.0, 1.0);
    final double remaining = math.max(0, withdrawTarget - balance);

    return Container(
      width: w(328),
      height: h(92),
      decoration: BoxDecoration(image: PCDImg('pc_home_top_bg')),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: w(12),
            top: h(28),
            width: 52,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(s(6)),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [PCImg(name: 'pc_act_0', width: 52, height: 52)],
              ),
            ),
          ),
          Positioned(
            left: w(72),
            top: h(14),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Growing Balance: ',
                    style: TextStyle(
                      fontSize: s(11),
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '\$100',
                    style: TextStyle(
                      fontSize: s(16),
                      color: '#FFD21C'.color(),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
          Positioned(
            right: w(12),
            top: h(14),
            width: w(80),
            height: h(24),
            child: ParticleButton(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(s(14)),
                ),
                alignment: Alignment.center,
                child: PCText(
                  text: 'Withdraw',
                  size: s(11),
                  color: '#07529B'.color(),
                  weight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            left: w(76),
            top: h(51),
            width: w(177),
            height: h(12),
            child: Padding(
              padding: EdgeInsets.all(s(3)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(s(4)),
                child: ColoredBox(
                  color: '#003F91'.color(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1,
                      child: ColoredBox(color: '#FFDD1E'.color()),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: w(258),
            top: h(51),
            child: PCText(
              text: '\$${balance.toStringAsFixed(2)} / \$100',
              size: s(10),
              color: Colors.white,
              weight: FontWeight.w600,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: h(72),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: s(9),
                  fontWeight: FontWeight.w500,
                  color: '#AFE4FF'.color(),
                  height: 1.15,
                  fontFamily: 'CarlsbergSansBlack',
                ),
                children: [
                  const TextSpan(text: 'Only \$'),
                  TextSpan(
                    text: remaining.toStringAsFixed(1),
                    style: TextStyle(color: '#FFDD1D'.color()),
                  ),
                  const TextSpan(text: ' Left To Withdraw \$100'),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    PCLocalProvider provider,
    double Function(double) s,
    double Function(double) w,
  ) {
    return Container(
      width: w(120),
      height: s(40),
      decoration: BoxDecoration(image: PCDImg('pc_dollar_bgs')),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PCGradientText(
            '\$${provider.pc_dollar_number.toStringAsFixed(2)}',
            fontSize: s(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: ['#FFDA50'.color(), '#FFAF00'.color()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleColumn({
    required List<String> items,
    required int startIndex,
    required double bubbleSize,
    required double columnHeight,
  }) {
    // Keep every bubble inside the hit-test area on compact screens. The
    // design height is smaller than three bubble diameters at some scales.
    final double actualHeight = math.max(
      columnHeight,
      bubbleSize * items.length,
    );

    return SizedBox(
      width: bubbleSize,
      height: actualHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (offset) {
          final int index = startIndex + offset;
          return _PCHomeBubbleButton(
            key: index == 3 ? pcHomeAppleTargetKey : null,
            iconName: items[offset],
            size: bubbleSize,
            delay: Duration(milliseconds: 320 * index),
            onTap: () => _onBubbleTap(index),
          );
        }),
      ),
    );
  }
}

class _PCHomeBubbleButton extends StatefulWidget {
  const _PCHomeBubbleButton({
    super.key,
    required this.iconName,
    required this.size,
    required this.delay,
    required this.onTap,
  });

  final String iconName;
  final double size;
  final Duration delay;
  final VoidCallback onTap;

  @override
  State<_PCHomeBubbleButton> createState() => _PCHomeBubbleButtonState();
}

class _PCHomeBubbleButtonState extends State<_PCHomeBubbleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.94,
      upperBound: 1.06,
    );

    Future.delayed(widget.delay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
      _breathController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return SizedBox.square(dimension: widget.size);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // easeOutBack intentionally overshoots, but Opacity only accepts
        // values in the [0, 1] range.
        final double opacity = value.clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: 0.76 + (0.24 * value), child: child),
        );
      },
      child: ScaleTransition(
        scale: _breathController,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox.square(
            dimension: widget.size,
            child: PCImg(
              name: widget.iconName,
              width: widget.size,
              height: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBroadcastTicker extends StatefulWidget {
  const _HomeBroadcastTicker({required this.fontSize, required this.iconSize});

  final double fontSize;
  final double iconSize;

  @override
  State<_HomeBroadcastTicker> createState() => _HomeBroadcastTickerState();
}

class _HomeBroadcastTickerState extends State<_HomeBroadcastTicker>
    with SingleTickerProviderStateMixin {
  static const List<int> _cashOptions = [50, 80, 100];

  late final AnimationController _controller;
  Timer? _timer;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _message = _randomMessage();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _randomMessage();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _randomMessage() {
    final math.Random random = math.Random();
    final String userId =
        '${10 + random.nextInt(90)}****${100 + random.nextInt(900)}';
    final int cash = _cashOptions[random.nextInt(_cashOptions.length)];
    return 'Congrats! User $userId just cashed out \$$cash!';
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle messageStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w800,
      fontFamily: 'CarlsbergSansBlack',
      color: Colors.white,
      height: 1.15,
      decoration: TextDecoration.none,
    );

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: PCImg(name: 'pc_notice_bg')),
          Positioned(
            left: widget.iconSize * 0.45,
            top: 0,
            bottom: 0,
            child: Center(
              child: PCImg(
                name: 'pc_notice_icon',
                width: widget.iconSize,
                height: widget.iconSize,
              ),
            ),
          ),
          Positioned(
            left: widget.iconSize * 1.45,
            right: widget.iconSize * 0.55,
            top: 0,
            bottom: 0,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final TextPainter painter = TextPainter(
                        text: _messageSpan(messageStyle),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout();

                      final double startX = constraints.maxWidth;
                      final double endX = -painter.width;
                      final double dx =
                          startX + ((endX - startX) * _controller.value);

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          child: _buildMessageText(messageStyle),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _messageSpan(TextStyle style) {
    final Match? amountMatch = RegExp(r'\$\d+').firstMatch(_message);
    if (amountMatch == null) {
      return TextSpan(text: _message, style: style);
    }

    final int start = amountMatch.start;
    final int end = amountMatch.end;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: _message.substring(0, start)),
        TextSpan(
          text: _message.substring(start, end),
          style: style.copyWith(color: const Color(0xFFFFDD1D)),
        ),
        TextSpan(text: _message.substring(end)),
      ],
    );
  }

  Widget _buildMessageText(TextStyle style) {
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = '#0B5C0E'.color();

    return Stack(
      alignment: Alignment.center,
      children: [
        Text.rich(
          _messageSpan(style.copyWith(foreground: strokePaint)),
          maxLines: 1,
          softWrap: false,
        ),
        Text.rich(_messageSpan(style), maxLines: 1, softWrap: false),
      ],
    );
  }
}

class _HomeRankingSection extends StatelessWidget {
  const _HomeRankingSection({required this.data, required this.scale});

  final List<PCUserData> data;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => value * scale;

    final List<PCUserData> rest = data.skip(3).take(47).toList();

    return ListView.separated(
      padding: EdgeInsets.only(bottom: s(8)),
      itemCount: rest.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 0 : s(7)),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Keep the podium and the rank rows in one scrollable content flow.
          return SizedBox(
            height: 170.h,
            width: double.infinity,
            child: Center(
              child: SizedBox(
                width: 320.w,
                height: 160.h,
                child: Stack(
                  children: [
                    Positioned(
                      top: 75.h,
                      left: 0,
                      child: PCImg(
                        name: 'pc_rank_bg',
                        width: 320.w,
                        height: 88.h,
                      ),
                    ),
                    Positioned(
                      top: 20.h,
                      left: 8.w,
                      width: 88.w,
                      height: 88.w,
                      child: Stack(
                        children: [
                          Center(
                            child: PCImg(
                              name: 'pc_Ellipse_1',
                              width: 66,
                              height: 66,
                            ),
                          ),
                          Center(
                            child: PCImg(
                              name: 'pc_2_icon',
                              width: 88.w,
                              height: 88.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 30.h,
                      right: 8.w,
                      width: 88.w,
                      height: 88.w,
                      child: Stack(
                        children: [
                          Center(
                            child: PCImg(
                              name: 'pc_Ellipse_2',
                              width: 66,
                              height: 66,
                            ),
                          ),
                          Center(
                            child: PCImg(
                              name: 'pc_3_icon',
                              width: 88.w,
                              height: 88.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: (320.w - 100.w) * 0.5,
                      width: 100.w,
                      height: 100.w,
                      child: Stack(
                        children: [
                          Center(
                            child: PCImg(
                              name: 'pc_Ellipse_0',
                              width: 88,
                              height: 88,
                            ),
                          ),
                          Center(
                            child: PCImg(
                              name: 'pc_1_icon',
                              width: 100.w,
                              height: 100.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final int rowIndex = index - 1;
        return _HomeRankListTile(
          rank: rowIndex + 4,
          data: rest[rowIndex],
          scale: scale,
        );
      },
    );
  }

  Widget _buildTopThree(List<PCUserData> topThree, double Function(double) s) {
    final List<PCUserData> ordered = [topThree[1], topThree[0], topThree[2]];
    final List<int> ranks = [2, 1, 3];
    final List<double> sizes = [s(43), s(54), s(43)];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        return Expanded(
          child: _HomePodiumItem(
            data: ordered[index],
            rank: ranks[index],
            avatarSize: sizes[index],
            scale: scale,
          ),
        );
      }),
    );
  }
}

class _HomePodiumItem extends StatelessWidget {
  const _HomePodiumItem({
    required this.data,
    required this.rank,
    required this.avatarSize,
    required this.scale,
  });

  final PCUserData data;
  final int rank;
  final double avatarSize;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => value * scale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: avatarSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: PCImg(
                  name:
                      'pc_Ellipse_${rank == 1
                          ? 0
                          : rank == 2
                          ? 1
                          : 2}',
                  width: avatarSize,
                  height: avatarSize,
                ),
              ),
              PCStrokeText(
                text: '$rank',
                size: rank == 1 ? s(23) : s(18),
                color: '#FFF48C'.color(),
                weight: FontWeight.w900,
                skWidth: 1.5,
                skColor: '#5C2D00'.color(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        PCText(
          text: data.username,
          size: s(9),
          color: Colors.white,
          weight: FontWeight.w700,
          maxLines: 1,
          align: TextAlign.center,
        ),
        PCGradientText(
          '\$${data.totalEarning.toStringAsFixed(2)}',
          fontSize: s(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, '#FFEB7A'.color()],
          ),
        ),
      ],
    );
  }
}

class _HomeRankListTile extends StatelessWidget {
  const _HomeRankListTile({
    required this.rank,
    required this.data,
    required this.scale,
  });

  final int rank;
  final PCUserData data;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double s(double value) => value * scale;

    return Container(
      height: s(64),
      margin: EdgeInsets.symmetric(horizontal: s(8)),
      decoration: BoxDecoration(image: PCDImg('pc_rank_list_bg')),
      padding: EdgeInsets.symmetric(horizontal: s(12)),
      child: Row(
        children: [
          SizedBox(
            width: s(30),
            child: Center(
              child: PCStrokeText(
                text: '$rank',
                size: s(14),
                color: Colors.white,
                weight: FontWeight.w900,
                skWidth: 1.1,
                skColor: '#4A1800'.color(),
              ),
            ),
          ),
          SizedBox(
            width: s(44),
            height: s(44),
            child: ClipOval(
              child: PCImg(
                name: 'pc_Ellipse_${rank % 3}',
                width: s(44),
                height: s(44),
              ),
            ),
          ),
          SizedBox(width: s(8)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PCText(
                  text: data.username,
                  size: s(11),
                  color: Colors.white,
                  weight: FontWeight.w800,
                  maxLines: 1,
                  align: TextAlign.left,
                ),
                SizedBox(height: s(2)),
                _buildRankStat(
                  label: 'Total Earning:',
                  value: '\$${data.totalEarning.toStringAsFixed(0)}',
                  scale: scale,
                ),
                _buildRankStat(
                  label: 'Ads Watched:',
                  value: '${data.adsWatched}',
                  scale: scale,
                ),
              ],
            ),
          ),
          ParticleButton(
            onTap: () {},
            child: SizedBox(
              width: s(78),
              height: s(29),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: PCImg(name: 'pc_show_btn_bg')),
                  PCText(
                    text: 'Show Pig',
                    size: s(11),
                    color: Colors.white,
                    weight: FontWeight.w800,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankStat({
    required String label,
    required String value,
    required double scale,
  }) {
    final TextStyle style = TextStyle(
      fontSize: 9 * scale,
      fontWeight: FontWeight.w500,
      color: '#F9D6A2'.color(),
      height: 1.05,
    );
    final TextStyle valueStyle = style.copyWith(color: '#FFE12D'.color());

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label ', style: style),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
