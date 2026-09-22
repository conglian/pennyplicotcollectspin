import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PCMainVC/PCHome.dart';
import '../PCTool/PCAudioUtils.dart';
import '../PCTool/PCLogger.dart';
import '../PCTool/PCTBAEventTool.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_stroke_text.dart';
import 'PCTbaBar.dart' hide homeKey;

class PCLaunch extends StatefulWidget {
  PCLaunch({super.key});

  @override
  State<PCLaunch> createState() => PCLaunchState();
}

class PCLaunchState extends State<PCLaunch>
    with SingleTickerProviderStateMixin {
  var _daydateString = '';
  late final bool _shouldShowColdLaunchAd;
  bool _didFinishLaunch = false;

  late AnimationController _logoPulseController;

  late Animation<double> _logoPulseAnimation;

  @override
  void initState() {
    super.initState();
    // 启动瞬间取值，避免首次安装过程中 SDK 写入状态后误展示开屏广告。
    _shouldShowColdLaunchAd = PCLocalProvider.instance.pc_install_status;
    if (PCLocalProvider.instance.pc_bg_music) {
      PCAudioUtils().playBGM();
    }
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.08), weight: 10),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
    ]).animate(_logoPulseController);
    _logoPulseController.repeat();
    _setConfigDateInfoData();
    // PCNoticeHelp().setNoticeStatus();
    Future.delayed(Duration(milliseconds: 1), () {
      pc_getUserCloakConfig();
    });
    // pc_event_fire(ASTrackEvent.launchPage, {'source_from': 'icon'});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // PSNumberHelpers().updateBrazilianPortuguese(context);
    });
  }

  void pc_getUserCloakConfig() async {
    try {
      var responseData = await PCRequestHelpers().getCloak();
      asLog.info('pigwalletspine Config Result: $responseData');
      // pc_event_fire("cloak_req", {});
      // pc_event_fire("cloak_suc", {
      //   "cloak_user": responseData.toString() == "freshen" ? 1 : 0,
      // });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pc_install_status') == null) {
        prefs.setBool('pc_install_status', true);
      }
      PCLocalProvider.instance.updateBool(
        PCLocalProvider.instance.pc_cloak_statusName,
        responseData.toString() == "freshen" ? true : false,
      );
    } catch (e) {
      asLog.error('pigwalletspine Request Error: $e');
      Future.delayed(Duration(seconds: 1), () {
        pc_getUserCloakConfig();
      });
    }
  }

  Future<void> _setConfigDateInfoData() async {
    // text
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _daydateString = prefs.getString('pc_day_date') ?? '';
    DateTime today = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd').format(today);
    prefs.setBool('pc_old_guide', true);
    if (_daydateString == '') {
      prefs.setString('pc_day_date', formattedDate);
      // 首次
      prefs.setBool('pc_first_instll', true);
    } else {
      if (_daydateString != formattedDate) {
        await PCLocalProvider.instance.updateint(
          PCLocalProvider.instance.pc_ad_show_indexName,
          0,
        );
        // 隔天
        prefs.setString('pc_day_date', formattedDate);
        prefs.setBool('pc_old_guide', false);
      }
    }
  }

  @override
  void dispose() {
    _logoPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PCImg(
            name: 'pc_luanch_bg',
            width: 0.width(context),
            height: 0.height(context),
          ),
          Column(
            children: [
              SizedBox(height: 140.h),
              ScaleTransition(
                scale: _logoPulseAnimation,
                child: PCImg(name: 'pc_logo_smail', width: 100, height: 100),
              ),
              SizedBox(height: 24.h),
              PCStrokeText(text: 'PennyPilot:Collect&Spin', size: 20, color: '#FFFFFF'.color(), weight: FontWeight.w700, skWidth: 1, skColor: '#174306'.color()),
              Spacer(),
              SizedBox(height: 12.h),
              PCGradientProgressBar(
                onCompleted: () {
                  _finishLaunch();
                },
              ),
              SizedBox(height: 12.h),
              PCStrokeText(
                text: "Loading...",
                size: 14,
                color: '#FFFFFF'.color(),
                weight: FontWeight.w900,
                skWidth: 1,
                skColor: '#4C0E0E'.color(),
              ),
              SizedBox(height: 120.h),
            ],
          ),
        ],
      ),
    );
  }

  void _finishLaunch() {
      pushToGuide();

    // ASCardAds().pc_showAd(
    //   context,
    //   ASTrackEvent.launchColdInterstitial,
    //   showDialog: false,
    //   onCacheResponse: (_) => pushToGuide(),
    //   adDidClosed: (_) => pushToGuide(),
    // );
  }

  void pushToGuide() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PigsBottomExample(key: homeKey)),
    );
  }
}

class PCGradientProgressBar extends StatefulWidget {
  final VoidCallback? onCompleted; // ✅ 动画完成后的回调

  const PCGradientProgressBar({super.key, this.onCompleted});

  @override
  State<PCGradientProgressBar> createState() => _PCGradientProgressBarState();
}

class _PCGradientProgressBarState extends State<PCGradientProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final double barWidth = 245;
  final double barHeight = 18;
  final double progressHeight = 14;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: kDebugMode ? 3 : 12),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // ✅ 动画完成回调
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.onCompleted != null) {
        widget.onCompleted!();
      }
    });

    // 启动动画
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: barWidth,
      height: barHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 进度条
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final progressWidth = barWidth * _animation.value;
              final progressPercent = (_animation.value * 100)
                  .clamp(0, 100)
                  .toInt();
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Container(
                      width: barWidth,
                      height: progressHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            '#003F00'.color(),
                            '#002700'.color(),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  // 渐变进度条
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Container(
                      width: max(0, progressWidth - 8),
                      height: progressHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            '#FFDF2D'.color(),
                            '#DA5000'.color(),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  // ✅ 居中显示百分比文字
                  Center(
                    child: Text(
                      '$progressPercent%',
                      style: TextStyle(
                        fontFamily: text_fontName,
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color: Colors.black.withOpacity(0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
