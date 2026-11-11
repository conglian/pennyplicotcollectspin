import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCBasic/PCTbaBar.dart' show PigsTabController;
import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/PCPigBarrage.dart';
import '../../PCTool/PCPigMotion.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCRankData.dart';
import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 排行榜存钱罐弹幕展示页（Go Earn）。
/// 展示所点用户的收益、广告次数；超过 100 美元为金猪，否则为粉猪。
/// 上下各三行弹幕循环平移；关闭按钮仅关闭，Go Earn 关闭后切换答题页。
/// 猪下方紫色底座始终显示所点排行榜用户的美元收益，与顶部和收益弹幕一致。
/// 收益来源每次打开随机选择答题或转盘，图标与文案成对显示且重建不重抽。
class PCPigShowDialog extends StatefulWidget {
  const PCPigShowDialog({
    super.key,
    required this.user,
    this.users = const [],
    this.random,
  });

  final PCUserData user;
  final List<PCUserData> users;
  final math.Random? random;

  bool get isGold => user.totalEarning > 100;

  static Future<dynamic> show(
    BuildContext context, {
    required PCUserData user,
    required List<PCUserData> users,
  }) {
    PCAnalytics.event('home_list_showpig');
    return context.tipShow2(
      PCPigShowDialog(user: user, users: users),
      bc: const Color(0xE6000000),
      scaleContent: false,
      onPresented: () async => PCAnalytics.event('showpig_page'),
    );
  }

  @override
  State<PCPigShowDialog> createState() => _PCPigShowDialogState();
}

class _PCPigShowDialogState extends State<PCPigShowDialog>
    with TickerProviderStateMixin {
  late final bool _quizEarning;
  late final List<AnimationController> _statControllers;
  bool? _animationsEnabled;

  PCUserData get user => widget.user;
  List<PCUserData> get users => widget.users;
  bool get isGold => widget.isGold;

  @override
  void initState() {
    super.initState();
    _quizEarning = (widget.random ?? math.Random()).nextBool();
    _statControllers = [
      for (final seconds in [15, 18, 16])
        AnimationController(
          vsync: this,
          duration: Duration(seconds: seconds),
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (_animationsEnabled == enabled) return;
    _animationsEnabled = enabled;
    for (final controller in _statControllers) {
      if (enabled) {
        controller.repeat();
      } else {
        controller.stop();
        controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _statControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = PCAdaptiveLayout.fitScale(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            designHeight: 540,
          );
          // 固定内容优先保持等比；小屏收紧留白，避免猪、统计与按钮重叠。
          final gap = ((constraints.maxHeight - 508 * s) / 292)
              .clamp(0.0, s)
              .toDouble();
          return Center(
            child: SizedBox(
              width: 360 * s,
              height: 508 * s + 292 * gap,
              child: Column(
                children: [
                  SizedBox(height: 42 * gap),
                  _header(context, s),
                  SizedBox(height: 35 * gap),
                  SizedBox(
                    height: 120 * s,
                    child: PCPigBarrage(
                      users: users.isEmpty ? [user] : users,
                      scale: s,
                    ),
                  ),
                  SizedBox(height: 47 * gap),
                  _pig(s),
                  SizedBox(height: 24 * gap),
                  _stats(s),
                  SizedBox(height: 24 * gap),
                  ParticleButton(
                    key: const ValueKey('pcPigShowGoEarn'),
                    onTap: () {
                      if (ModalRoute.of(context)?.isCurrent != true) return;
                      PCAnalytics.event('showpig_page_c');
                      Navigator.of(context).pop();
                      PigsTabController.switchTo(1);
                    },
                    child: SizedBox(
                      width: 268 * s,
                      height: 64 * s,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned.fill(
                            child: PCImg(name: 'pc_btn_bg'),
                          ),
                          PCStrokeText(
                            text: 'Go Earn',
                            size: 24 * s,
                            color: Colors.white,
                            weight: FontWeight.w700,
                            skWidth: 1.5 * s,
                            skColor: const Color(0xFF003507),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 120 * gap),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _pig(double s) => SizedBox(
    width: 168 * s,
    height: 160 * s,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 140 * s,
          child: PCPigMotion.hero(
            child: PCImg(
              key: const ValueKey('pcPigShowArtwork'),
              name: isGold ? 'pc_rank_pig_gold' : 'pc_big_icon_0',
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: 24 * s,
          top: 120 * s,
          width: 120 * s,
          height: 40 * s,
          child: Container(
            key: const ValueKey('pcPigShowAmountPlate'),
            padding: EdgeInsets.symmetric(horizontal: 6 * s),
            decoration: BoxDecoration(image: PCDImg('pc_dollar_bgs')),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PCGradientText(
                '\$${user.totalEarning.toStringAsFixed(2)}',
                fontSize: 20 * s,
                maxLines: 1,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFDA50), Color(0xFFFFAF00)],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _header(BuildContext context, double s) => SizedBox(
    height: 76 * s,
    child: Stack(
      children: [
        Positioned(
          left: 6 * s,
          top: 16 * s,
          width: 44 * s,
          height: 44 * s,
          child: Semantics(
            label: 'Close',
            button: true,
            child: ParticleButton(
              key: const ValueKey('pcPigShowClose'),
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: PCImg(
                  name: 'pc_close_btn',
                  width: 24 * s,
                  height: 24 * s,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 52 * s,
          right: 16 * s,
          top: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(12 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * s),
              border: Border.all(color: const Color(0x33FFFFFF)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF003087), Color(0xFF0082D2)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52 * s,
                  height: 52 * s,
                  padding: EdgeInsets.all(8 * s),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6 * s),
                  ),
                  child: const PCImg(name: 'pc_paypal_0', fit: BoxFit.contain),
                ),
                SizedBox(width: 8 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PCText(
                              text: 'PayPal sent ',
                              size: 14 * s,
                              color: Colors.white,
                              weight: FontWeight.w500,
                            ),
                            PCGradientText(
                              '\$${user.totalEarning.toStringAsFixed(2)}',
                              fontSize: 16 * s,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFDA50), Color(0xFFFFAF00)],
                              ),
                            ),
                            PCText(
                              text: ' to ${user.username}',
                              size: 14 * s,
                              color: Colors.white,
                              weight: FontWeight.w500,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4 * s),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PCText(
                          text: 'Withdrawal completed!',
                          size: 12 * s,
                          color: const Color(0xFFAFE4FF),
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _stats(double s) => SizedBox(
    height: 88 * s,
    child: IgnorePointer(
      child: Stack(
        children: [
          _statRow(
            row: 0,
            start: 38,
            width: 171,
            scale: s,
            child: _pill(
              _quizEarning ? 'pc_pig_show_quiz' : 'pc_pig_show_wheel',
              _quizEarning ? 'Earning from quiz' : 'Earning from wheel',
              null,
              171,
              s,
            ),
          ),
          _statRow(
            row: 1,
            start: 214,
            width: 129,
            scale: s,
            child: _pill(
              'pc_pig_show_ad',
              'ADs watched: ',
              '${user.adsWatched}',
              129,
              s,
              valueColor: const Color(0xFFFF4128),
            ),
          ),
          _statRow(
            row: 2,
            start: 87,
            width: 160,
            scale: s,
            child: _pill(
              'pc_pig_show_money',
              'Total earning: ',
              '\$${user.totalEarning.toStringAsFixed(2)}',
              160,
              s,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _statRow({
    required int row,
    required double start,
    required double width,
    required double scale,
    required Widget child,
  }) => Positioned(
    left: 0,
    right: 0,
    top: row * 32 * scale,
    height: 24 * scale,
    child: ClipRect(
      child: AnimatedBuilder(
        animation: _statControllers[row],
        child: RepaintBoundary(
          key: ValueKey('pcPigShowStatsTrack$row'),
          child: child,
        ),
        builder: (context, child) {
          // 完全移出左侧后从右边继续进入；只有这一条数据，不重复生成收益或来源。
          final period = 360 + width;
          final offset =
              (start + width - _statControllers[row].value * period) % period -
              width;
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: width * scale,
            maxWidth: width * scale,
            minHeight: 24 * scale,
            maxHeight: 24 * scale,
            child: Transform.translate(
              offset: Offset(offset * scale, 0),
              child: child,
            ),
          );
        },
      ),
    ),
  );

  Widget _pill(
    String icon,
    String label,
    String? value,
    double width,
    double s, {
    Color valueColor = const Color(0xFFFFDD1D),
  }) => Container(
    width: width * s,
    height: 24 * s,
    padding: EdgeInsets.symmetric(horizontal: 2 * s),
    decoration: BoxDecoration(
      color: const Color(0x6651B217),
      borderRadius: BorderRadius.circular(12 * s),
    ),
    child: Row(
      children: [
        PCImg(name: icon, width: 20 * s, height: 20 * s, fit: BoxFit.contain),
        SizedBox(width: 4 * s),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PCText(
                  text: label,
                  size: 12 * s,
                  color: Colors.white,
                  weight: FontWeight.w400,
                ),
                if (value != null)
                  PCText(
                    text: value,
                    size: 12 * s,
                    color: valueColor,
                    weight: FontWeight.w400,
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
