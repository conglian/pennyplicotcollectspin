import 'dart:async';
import 'dart:convert';

import 'package:thinkup_sdk/at_init.dart';
import 'package:cloudx_flutter/cloudx.dart';
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_attribution.dart';
import 'package:adjust_sdk/adjust_config.dart';
import '../PCModel/PCAdModel.dart';
import '../PCModel/PCFKModel.dart';
import '../PCModel/PCNumbserModel.dart';
import 'PCAdRevenue.dart';
import 'PCAnalytics.dart';
import 'PCFKManger.dart';
import 'pc_ad_manger.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tba_info/flutter_tba_info.dart';

import 'PCLogger.dart';
import 'PCNumberManager.dart';
import 'PCFacebookConfig.dart';

String decsgerew(String st) => utf8.decode(base64Decode(st));

class PCSDKHelpers {
  static final PCSDKHelpers _instance = PCSDKHelpers._internal();

  factory PCSDKHelpers() {
    return _instance;
  }

  PCSDKHelpers._internal()
    : _initializeAdSourceForTesting = null,
      _onAdSourceReadyForTesting = null,
      _adSourceInitializationTimeout = const Duration(seconds: 9);

  /// 隔离测试广告管理器就绪状态、SDK初始化结果与时限，不连接真实平台。
  @visibleForTesting
  PCSDKHelpers.forTesting({
    Future<void>? adManagerReady,
    Future<bool> Function(String source)? initializeAdSource,
    required void Function(String source) onAdSourceReady,
    Duration initializationTimeout = const Duration(seconds: 9),
  }) : _initializeAdSourceForTesting = initializeAdSource,
       _onAdSourceReadyForTesting = onAdSourceReady,
       _adSourceInitializationTimeout = initializationTimeout {
    if (adManagerReady != null) {
      unawaited(
        adManagerReady.then<void>(
          (_) => _adManagerReady = true,
          onError: (Object error, StackTrace stack) {
            asLog.error('[ad-init] manager_not_ready ${error.runtimeType}');
          },
        ),
      );
    }
  }

  final Future<bool> Function(String source)? _initializeAdSourceForTesting;
  final void Function(String source)? _onAdSourceReadyForTesting;
  final Duration _adSourceInitializationTimeout;
  final Map<String, Future<void>> _adSourceInitializations = {};
  final Map<String, Object> _adSourceInitializationTokens = {};
  final Set<String> _initializedAdSources = {};
  bool _adManagerReady = false;
  bool _cloudXInitializationDispatched = false;

  DateTime sj_cloudx_start = DateTime.now();

  DateTime sj_topon_start = DateTime.now();

  int sj_remoteConfigTryCount = 0;

  bool is_ad_suc = false;

  Future<void>? _initialization;
  static const cloudXAppKey = 'livzRGPJw4a0ySKXruUqX';
  static const adjustAppToken = 'b8np4lxyznk0';
  // 保留本地原TopOn App ID和App Key。
  static const topOnAppId = 'h6ae010efa1e01';
  static const topOnAppKey = 'adf85d6c9ca315d2f42105fbb6095b67e';

  Future<void> initSDK() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    // 本次仅接入Android；iOS不拉起尚未配置的聚合源。
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // 先接通展示入口；SDK/远程配置未就绪时也由管理器记录chance和uninitialized。
    PCPigAds().bindServices();
    // H5 与广告/归因独立初始化；沿用原生 create，不因其他 SDK 等待而漏调。
    unawaited(_initH5());
    try {
      await _initAdjustSDk();
    } catch (error) {
      asLog.error('Adjust initialization failed: $error');
    }
    await _initializeFacebookAndAds();
  }

  /// FB配置/初始化和广告初始化并行运行，慢响应或失败不能阻挡另一条链。
  Future<void> _initializeFacebookAndAds({
    Future<void> Function()? initializeFacebook,
    Future<void> Function()? initializeAdManager,
  }) async {
    Future<void> isolated(String name, Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        asLog.error('[sdk-init] failed source=$name ${error.runtimeType}');
      }
    }

    unawaited(isolated('facebook', initializeFacebook ?? _initializeFacebook));
    await isolated('ad_manager', () async {
      await (initializeAdManager != null
          ? initializeAdManager()
          : PCPigAds().init(readySources: <String>{}));
      // 仅等待广告管理器就位；FB远程配置和初始化不参与广告SDK的门控。
      _adManagerReady = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(retryAdSourceInitialization('topon'));
        unawaited(retryAdSourceInitialization('cloudx'));
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  @visibleForTesting
  Future<void> initializeFacebookAndAdsForTesting({
    required Future<void> Function() initializeFacebook,
    required Future<void> Function() initializeAdManager,
  }) => _initializeFacebookAndAds(
    initializeFacebook: initializeFacebook,
    initializeAdManager: initializeAdManager,
  );

  Future<void> _initH5() async {
    try {
      await Penyplicotcollectspinsh5().create();
      // 原生 create 没有成功状态返回，仅记录 Flutter 到原生的调用已完成。
      asLog.info('[H5] create returned');
    } on PlatformException catch (error) {
      asLog.error('[H5] create failed (${error.code})');
    } on MissingPluginException {
      asLog.error('[H5] create failed (plugin unavailable)');
    } catch (error) {
      asLog.error('[H5] create failed (${error.runtimeType})');
    }
  }

  Future<void> _initializeFacebook() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (error) {
      asLog.error(
        'Firebase unavailable; use default Facebook configuration: $error',
      );
    }
    if (Firebase.apps.isNotEmpty) {
      await _asinitloadFireBase();
    } else {
      await PCFacebookAnalytics.initializeFromRemote(null);
      await PCNumberHelpers().pc_applyRemoteConfig(null);
    }
  }

  /// 按广告平台合并初始化请求；失败或超时后允许下一轮后台维护再次尝试。
  Future<void> retryAdSourceInitialization(String source) {
    if (!_adManagerReady ||
        !const {'topon', 'cloudx'}.contains(source) ||
        _initializedAdSources.contains(source)) {
      return Future<void>.value();
    }
    final pending = _adSourceInitializations[source];
    if (pending != null) return pending;
    final token = Object();
    _adSourceInitializationTokens[source] = token;
    late final Future<void> attempt;
    attempt = _initializeAdSourceAttempt(source, token).whenComplete(() {
      if (identical(_adSourceInitializations[source], attempt)) {
        _adSourceInitializations.remove(source);
      }
      if (identical(_adSourceInitializationTokens[source], token)) {
        _adSourceInitializationTokens.remove(source);
      }
    });
    _adSourceInitializations[source] = attempt;
    return attempt;
  }

  Future<void> _initializeAdSourceAttempt(String source, Object token) async {
    final initializationTime = Stopwatch()..start();
    if (source == 'topon') {
      sj_topon_start = DateTime.now();
    } else {
      sj_cloudx_start = DateTime.now();
    }
    asLog.debug('[ad-init] start source=$source');
    try {
      final initialize = _initializeAdSourceForTesting;
      final success =
          await (initialize != null
                  ? initialize(source)
                  : _initializeAdSource(source, token))
              .timeout(_adSourceInitializationTimeout);
      if (!identical(_adSourceInitializationTokens[source], token)) return;
      if (!success) {
        asLog.error('[ad-init] failed source=$source; awaiting next retry');
        return;
      }
      final ready = _onAdSourceReadyForTesting;
      if (ready != null) {
        ready(source);
      } else {
        PCPigAds().setSourceReady(source);
      }
      if (!_initializedAdSources.add(source)) return;
      is_ad_suc = true;
      PCAnalytics.event('nkmdl_ad_initsuc', {
        // 文档自定义平台枚举暂未列CloudX，仍沿用other。
        'ad_source_client': source == 'topon' ? 'topon' : 'other',
        'ad_init_time': initializationTime.elapsedMilliseconds,
      });
      asLog.success('[ad-init] ready source=$source');
    } catch (error) {
      // timeout不会把尚在执行的SDK认作成功；迟到结果也不能发布或清理下一次尝试。
      asLog.error('[ad-init] failed source=$source ${error.runtimeType}');
    } finally {
      initializationTime.stop();
    }
  }

  Future<bool> _initializeAdSource(String source, Object token) async {
    if (source == 'topon') {
      await ATInitManger.setLogEnabled(logEnabled: kDebugMode);
      if (!identical(_adSourceInitializationTokens[source], token))
        return false;
      await ATInitManger.initSDK(
        appidStr: topOnAppId,
        appidkeyStr: topOnAppKey,
      );
      return true;
    }
    // CloudX会合并未完成的initialize。原生已成功但旧通道回执丢失时，
    // 后台用真实状态恢复ready；首次仍必须initialize以安装Flutter回调handler。
    if (_cloudXInitializationDispatched) {
      final initialized = await CloudX.isInitialized();
      if (!identical(_adSourceInitializationTokens[source], token))
        return false;
      if (initialized) return true;
    }
    _cloudXInitializationDispatched = true;
    final result = await CloudX.initialize(appKey: cloudXAppKey);
    if (!identical(_adSourceInitializationTokens[source], token)) return false;
    if (!result.success) {
      asLog.error(
        'CloudX initialization failed: ${result.errorCodeName} ${result.message}',
      );
      return false;
    }
    // 插件缺失时initialize会返回失败，不能先调用void日志API造成未捕获异常。
    CloudX.setMinLogLevel(
      kDebugMode ? CloudXLogLevel.debug : CloudXLogLevel.warn,
    );
    return true;
  }

  Future<void> _initAdjustSDk() async {
    const String appToken1 = adjustAppToken;
    // 用户标识属于可选参数，读取失败不能阻断Adjust初始化和收入上报。
    try {
      final disId = await FlutterTbaInfo.instance.getDistinctId().timeout(
        const Duration(seconds: 2),
      );
      if (disId.isNotEmpty) {
        Adjust.addGlobalCallbackParameter('customer_user_id', disId);
      }
    } catch (error) {
      asLog.error('Adjust customer ID unavailable: $error');
    }
    final config = AdjustConfig(appToken1, AdjustEnvironment.production);
    config.logLevel = kDebugMode ? AdjustLogLevel.verbose : AdjustLogLevel.warn;
    config.attributionCallback = handleAdjustAttribution;
    PCAnalytics.event('adjust_req');
    Adjust.initSdk(config);
  }

  /// 只由Adjust真实归因回调记录成功；trackerName严格等于Organic为A，其余为B。
  @visibleForTesting
  void handleAdjustAttribution(AdjustAttribution attributionChangedData) {
    print('[Adjust]: Attribution changed!');
    if (attributionChangedData.trackerToken != null) {
      print('[Adjust]: Tracker token: ${attributionChangedData.trackerToken}');
    }
    final trackerName = attributionChangedData.trackerName;
    final isPackageB = trackerName != 'Organic';
    PCAnalytics.event('adjust_suc', {'adjust_user': isPackageB ? '1' : '0'});
    if (trackerName != null) {
      print('[Adjust]: Tracker name: $trackerName');
      if (isPackageB) {
        PCAnalytics.event('organic_to_buy', {});
        // _toHome();
      }
    }
    if (attributionChangedData.campaign != null) {
      print('[Adjust]: Campaign: ${attributionChangedData.campaign}');
    }
    if (attributionChangedData.network != null) {
      print('[Adjust]: Network: ${attributionChangedData.network}');
    }
    if (attributionChangedData.creative != null) {
      print('[Adjust]: Creative: ${attributionChangedData.creative}');
    }
    if (attributionChangedData.adgroup != null) {
      print('[Adjust]: Adgroup: ${attributionChangedData.adgroup}');
    }
    if (attributionChangedData.clickLabel != null) {
      print('[Adjust]: Click label: ${attributionChangedData.clickLabel}');
    }
    if (attributionChangedData.fbInstallReferrer != null) {
      print(
        '[Adjust]: facebook install referrer: ${attributionChangedData.fbInstallReferrer}',
      );
    }
    if (attributionChangedData.jsonResponse != null) {
      print('[Adjust]: JSON Response: ${attributionChangedData.jsonResponse}');
    }
  }

  Future<void> _asinitloadFireBase() async {
    var facebookConfigured = false;
    var numberConfigured = false;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      asLog.debug("app firebase init");
      asLog.debug("app firebase loading");
      await remoteConfig.fetchAndActivate();
      final c177pig_android_fb = remoteConfig
          .getValue(PCFacebookConfig.remoteKey)
          .asString();
      if (c177pig_android_fb.trim().isNotEmpty) {
        await PCFacebookAnalytics.initializeFromRemote(c177pig_android_fb);
      } else {
        await PCFacebookAnalytics.initializeFromRemote(null);
      }
      facebookConfigured = true;
      await PCNumberHelpers().pc_applyRemoteConfig(
        remoteConfig.getString(PCNumberHelpers.configKey),
      );
      numberConfigured = true;

      final gp177_pig_number = remoteConfig
          .getValue('gp177_pig_number')
          .asString();
      if (gp177_pig_number != '') {
        try {
          Map<String, dynamic> jsonMap = json.decode(gp177_pig_number);
          var intModel = PCAPCConfig.fromJson(jsonMap);
          PCNumberHelpers().intModel = intModel;
          asLog.success(
            "app firebase remoteconfig gp177_pig_number data $jsonMap",
          );
        } catch (error) {
          asLog.error(
            "app firebase remoteconfig gp177_pig_number error ${error}",
          );
        }
      }

      final nkmdl_ad_config = remoteConfig
          .getValue('nkmdl_ad_config')
          .asString();
      if (nkmdl_ad_config != '') {
        try {
          Map<String, dynamic> jsonMap = json.decode(nkmdl_ad_config);

          PCPigAds().pc_PigAdModel = PCAdModel.fromJson(jsonMap);
          if (PCPigAds().init_suc == true) {
            PCPigAds().init(inputAd: PCPigAds().pc_PigAdModel);
          }
          asLog.success(
            "app firebase remoteconfig nkmdl_ad_config data $jsonMap",
          );
        } catch (error) {
          asLog.error(
            "app firebase remoteconfig nkmdl_ad_config error ${error}",
          );
        }
      }

      final c177_risk_control = remoteConfig
          .getValue('c177_risk_control')
          .asString();
      if (c177_risk_control != '') {
        try {
          Map<String, dynamic> jsonMap = json.decode(c177_risk_control);
          var fkModel = PCFkModel.fromJson(jsonMap);
          PCFKManger().fkModel = fkModel;
          asLog.success(
            "app firebase remoteconfig c177_risk_control data $jsonMap",
          );
        } catch (error) {
          asLog.error(
            "app firebase remoteconfig c177_risk_control error ${error}",
          );
        }
      }
    } catch (e) {
      print("RemoteConfig fetch error: $e");
      // 数值配置解析等后续步骤失败，不能把已生效的远程FB应用切回默认应用。
      if (!facebookConfigured) {
        await PCFacebookAnalytics.initializeFromRemote(null);
      }
      if (!numberConfigured) {
        await PCNumberHelpers().pc_applyRemoteConfig(null);
      }
      sj_remoteConfigTryCount += 1;
      if (sj_remoteConfigTryCount <= 60) {
        Future.delayed(Duration(seconds: 1), () {
          _asinitloadFireBase();
        });
      } else {}
    }
  }

  /// CloudX收入在真实展示成功回调调用；publisher_sdk为Adjust支持的来源。
  void pc_sendAdToSdk(CloudXAd ad, {String? placement}) {
    final event = PCAdRevenue.cloudX(ad, placement: placement);
    if (event != null) Adjust.trackAdRevenue(event);
  }

  void pc_sendintTopOnAdToSdk(Map extraMap, {String? placement}) {
    final event = PCAdRevenue.topOn(extraMap, placement: placement);
    if (event != null) Adjust.trackAdRevenue(event);
  }
}

class PCFacebookAnalytics {
  static final _channel = MethodChannel(
    "com.example.pennyplicotcollectspin/facebook",
  );

  /// 远程三项完整有效时动态初始化；缺失或非法则整组使用默认配置。
  /// 原生拒绝远程初始化时仅再尝试一次默认配置，失败不阻断其他SDK。
  static Future<void> initializeFromRemote(String? raw) async {
    final config = PCFacebookConfig.fromRemote(raw);
    final isRemote = !identical(config, PCFacebookConfig.defaults);
    try {
      await init(
        appId: config.appId,
        clientToken: config.clientToken,
        appName: config.name,
      );
      asLog.success(
        'Facebook initialized (${isRemote ? 'remote' : 'default'}): '
        '${config.appId} / ${config.name}',
      );
    } catch (error) {
      asLog.error('Facebook initialization failed: $error');
      if (!isRemote) return;
      final fallback = PCFacebookConfig.defaults;
      try {
        await init(
          appId: fallback.appId,
          clientToken: fallback.clientToken,
          appName: fallback.name,
        );
      } catch (fallbackError) {
        asLog.error('Facebook default initialization failed: $fallbackError');
      }
    }
  }

  /// 初始化 Facebook SDK（动态传入 appId、clientToken、appName）
  static Future<void> init({
    required String appId,
    required String clientToken,
    required String appName,
  }) async {
    asLog.debug('initFacebook1');
    await _channel.invokeMethod("initFacebook", {
      "app_id": appId,
      "client_token": clientToken,
      "app_name": appName,
    });
    asLog.debug('initFacebook2');
  }

  /// 购买打点（无参数）广告收益
  static Future<void> logPurchase(double amount, String currency) async {
    if (!amount.isFinite || amount < 0) return;
    try {
      await _channel.invokeMethod("logPurchase", {
        "amount": amount,
        "currency": currency,
      });
    } catch (error) {
      asLog.error('Facebook revenue reporting failed: $error');
    }
  }
}
