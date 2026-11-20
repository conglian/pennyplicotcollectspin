import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PCMainVC/PCHome.dart';
import '../PCDialog/PCGuide/PCNewUserGuideFlow.dart';
import '../PCDialog/PCGuide/PCNewUserHomeFlow.dart';
import '../PCTool/PCNewUserGuideController.dart';
import '../PCTool/PCReturningUserController.dart';
import '../PCTool/PCReturningUserHost.dart';
import '../PCTool/PCAudioUtils.dart';
import '../PCTool/PCLogger.dart';
import '../PCTool/PCAnalytics.dart';
import '../PCTool/PCNoticeHelp.dart';
import '../PCTool/PCTBAEventTool.dart';
import '../PCTool/PCInterstitialAdService.dart';
import '../PCTool/PCDialogCoordinator.dart';
import '../PCTool/PCLaunchAdController.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_ad_manger.dart';
import 'PCTbaBar.dart' hide homeKey;
import 'PCLaunchProgressBar.dart';
import 'PCLaunchView.dart';

export 'PCLaunchProgressBar.dart';

class PCLaunch extends StatefulWidget {
  PCLaunch({super.key});

  @override
  State<PCLaunch> createState() => PCLaunchState();
}

class PCLaunchState extends State<PCLaunch> {
  final _returningUser = PCReturningUserController();
  var _daydateString = '';
  late final PCLaunchAdController _launchAds;
  bool _didFinishLaunch = false;

  @override
  void initState() {
    super.initState();
    _launchAds = PCLaunchAdController(
      loadGuideComplete: () async {
        final guide = PCNewUserGuideController.instance;
        await guide.load();
        return guide.isIntroComplete && guide.isComplete;
      },
      requestInterstitial: PCInterstitialAdService.instance.request,
      continueToApp: pushToGuide,
      canContinue: () => mounted,
      waitForStartupPermission: PCNoticeHelp.instance.waitForStartupPermission,
      prepareApp: _prepareLaunchMetadata,
      holdPresentation: PCDialogCoordinator.instance.holdPresentation,
      isNativeAdShowing: () => PCPigAds().isNativeAdShowing,
      canRequestInterstitial: () {
        if (PCNoticeHelp.instance.isStartupPermissionRequestPending)
          return false;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        return lifecycle == null || lifecycle == AppLifecycleState.resumed;
      },
      onWaitTimeout: (phase) =>
          asLog.error('[launch] wait timed out: $phase; continue safely'),
    );
    unawaited(
      PCAudioUtils().initializeForStartup(
        isNativeAdShowing: () => PCPigAds().isNativeAdShowing,
      ),
    );
    // PCNoticeHelp().setNoticeStatus();
    Future.delayed(Duration(milliseconds: 1), () {
      pc_getUserCloakConfig();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reportLaunchExposure());
    });
  }

  Future<void> _reportLaunchExposure() async {
    final source = await PCNoticeHelp.instance.launchSource();
    PCAnalytics.event('launch_page', {'source_from': source});
  }

  Future<void> pc_getUserCloakConfig() async {
    try {
      PCAnalytics.event('cloak_req');
      var responseData = await PCRequestHelpers().getCloak();
      asLog.info('pigpennyp Config Result: $responseData');
      PCLocalProvider.instance.updateBool(
        PCLocalProvider.instance.pc_cloak_statusName,
        responseData.toString() == 'ashland',
      );
      // getCloak失败时返回null；失败和空结果不能误记为黑名单成功返回。
      if (responseData != null && responseData.toString().isNotEmpty) {
        PCAnalytics.event('cloak_suc', {
          'cloak_user': responseData.toString() == 'ashland' ? 1 : 0,
        });
        await PCAnalytics.install();
      }
    } catch (e) {
      asLog.error('pigpennyp Request Error: $e');
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
    await prefs.setBool('pc_old_guide', true);
    if (_daydateString == '') {
      await prefs.setString('pc_day_date', formattedDate);
      // 首次
      await prefs.setBool('pc_first_instll', true);
    } else {
      if (_daydateString != formattedDate) {
        await PCLocalProvider.instance.updateint(
          PCLocalProvider.instance.pc_ad_show_indexName,
          0,
        );
        // 隔天
        await prefs.setString('pc_day_date', formattedDate);
        await prefs.setBool('pc_old_guide', false);
      }
    }
  }

  @override
  void dispose() {
    _launchAds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PCLaunchView(progress: PCGradientProgressBar(onCompleted: _finishLaunch));

  Future<void> _finishLaunch() => _launchAds.finish();

  Future<void> _prepareLaunchMetadata() async {
    final guide = PCNewUserGuideController.instance;
    if (!guide.isLoaded) return;
    // 先读取历史日期，再更新旧启动日期；其失败/超时由启动门禁降级，不能卡在100%。
    await _returningUser.prepareLaunch(isExistingUser: guide.isComplete);
    await _setConfigDateInfoData();
  }

  Future<void> pushToGuide() async {
    if (_didFinishLaunch || !mounted) return;
    _didFinishLaunch = true;
    final guideController = PCNewUserGuideController.instance;
    // 引导已在构造时读取；不能在所有兜底之后又等待同一个永不结束的load。
    // 未知状态交给可重试的引导入口，既离开启动页，也不误跳过新用户流程。
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (routeContext) {
          if (guideController.isLoaded && guideController.isIntroComplete) {
            return _buildHome();
          }
          return PCNewUserGuideFlow(
            controller: guideController,
            onCompleted: () => Navigator.of(
              routeContext,
            ).pushReplacement(MaterialPageRoute(builder: (_) => _buildHome())),
          );
        },
      ),
    );
  }

  Widget _buildHome() => PCReturningUserHost(
    controller: _returningUser,
    onGoEarn: () => PigsTabController.switchTo(1),
    child: PCNewUserHomeFlow(child: PigsBottomExample(key: homeKey)),
  );
}
