import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:spine_flutter/spine_flutter.dart';
import 'package:pennypilotcollectspin/PCBasic/PCLaunch.dart';
import 'package:pennyplicotollespinFK/pennyplicotollespinFK.dart';
import 'PCTool/PCFKManger.dart';
import 'PCTool/PCLogger.dart';
import 'PCTool/pc_LocalProvider.dart';
import 'PCTool/PCNoticeHelp.dart';
import 'PCTool/PCAnalytics.dart';
import 'PCTool/PCSessionLifecycleController.dart';
import 'PCTool/pc_ad_manger.dart';
import 'PCTool/PCInAppNotificationHost.dart';
import 'PCTool/pc_extension_help.dart';
import 'PCTool/pc_init_sdk.dart';

Future<void> main() async {
  // 初始化Flutter绑定（确保async操作在runApp前执行）
  WidgetsFlutterBinding.ensureInitialized();
  // 只允许竖屏
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 状态栏背景透明
      statusBarIconBrightness: Brightness.dark, // 安卓图标白色
      statusBarBrightness: Brightness.light, // iOS 用
    ),
  );

  await initializeFirebaseForStartup();
  asLog.info(
    BoomUniqueStringUtil.decrypt(
      '/PfGxvXg6Pv63uv42cfS//Dg9PPz4PD14sbwxuLw+/Pw/OjdhfrSy9PJ4OjS4/L+1uL5gd3L48XXxPie29fX6f7pwfnk6ePn3ILy49jI//2F/ITkgefIgsDymvn+h4We0IDr64P399L6/faHiN7+x+Ta8sT8w4Hy8Mb08PDgjIw=',
      177,
    ),
  );
  await PennyplicotollespinFK.instance.pc_initNumberUnit(
    apiKey: BoomUniqueStringUtil.decrypt(
      '/PfGxvXg6Pv63uv42cfS//Dg9PPz4PD14sbwxuLw+/Pw/OjdhfrSy9PJ4OjS4/L+1uL5gd3L48XXxPie29fX6f7pwfnk6ePn3ILy49jI//2F/ITkgefIgsDymvn+h4We0IDr64P399L6/faHiN7+x+Ta8sT8w4Hy8Mb08PDgjIw=',
      177,
    ),
  );

  await initSpineFlutter(enableMemoryDebugging: false);
  // 1. 创建LocalStorageProvider实例并初始化（加载本地数据）
  final localStorageProvider = PCLocalProvider.instance;
  await localStorageProvider.init();
  // 在启动页写入安装标记之前判定首次安装；复用本地标准TBA安装协议。
  await PCAnalytics.install();
  // await trigger.init();
  await PCFKManger().initFKJson();
  // 模拟排队完成
  // PSLocalProvider.instance.updateint(PSLocalProvider.instance.ps_quiz_all_numName, 0);
  // PSLocalProvider.instance.updatedouble(PSLocalProvider.instance.ps_pig_level_indexName, 0);
  // 2. 注入Provider，包裹MyApp
  runApp(
    ChangeNotifierProvider(
      create: (context) => localStorageProvider, // 传入已初始化的实例
      child: const MyApp(),
    ),
  );
}

/// Firebase配置缺失时继续使用本地配置，避免更换包名后阻断应用启动。
Future<void> initializeFirebaseForStartup() async {
  try {
    await Firebase.initializeApp();
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    // 仅在初始化成功后接管错误，配置缺失时保留Flutter默认错误处理。
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final isFatal =
          error is OutOfMemoryError ||
          error is StackOverflowError ||
          error is FlutterError ||
          error is AssertionError;
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: isFatal);
      return true;
    };
  } catch (error) {
    asLog.error(
      'Firebase initialization unavailable; continuing with local defaults '
      '(${error.runtimeType})',
    );
  }
}

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  PCSessionLifecycleController? _sessionLifecycle;
  PCSessionLifecycleController get _sessions =>
      _sessionLifecycle ??= PCSessionLifecycleController(
        isNativeAdShowing: () => PCPigAds().isNativeAdShowing,
        onSession: (source) {
          asLog.info('[session] trigger=$source');
          unawaited(PCAnalytics.session());
        },
      );
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PCLocalProvider.instance.addListener(_analyticsBalanceChanged);
    _sessions.start();
    _analyticsBalanceChanged();
    unawaited(PCSDKHelpers().initSDK());
    unawaited(PCNoticeHelp.instance.initializeForStartup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PCLocalProvider.instance.removeListener(_analyticsBalanceChanged);
    super.dispose();
  }

  void _analyticsBalanceChanged() => unawaited(PCAnalytics.cashChanged());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _sessions.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _analyticsBalanceChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      // 字体自动适配
      splitScreenMode: true,
      // 支持平板分屏
      builder: (context, child) {
        return MaterialApp(
          navigatorObservers: [routeObserver],
          theme: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory, // 彻底取消水波纹
          ),
          debugShowCheckedModeBanner: false,
          builder: (context, widget) {
            // 防止系统字体缩放影响
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: PCInAppNotificationHost(child: widget!),
            );
          },
          home: child,
        );
      },
      child: PCLaunch(),
    );
  }
}
