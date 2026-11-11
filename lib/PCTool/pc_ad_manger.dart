import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adjust_sdk/adjust.dart';
import 'package:cloudx_flutter/cloudx.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pennypilotcollectspin/PCTool/pc_init_sdk.dart';
import 'package:thinkup_sdk/at_interstitial.dart';
import 'package:thinkup_sdk/at_interstitial_response.dart';
import 'package:thinkup_sdk/at_listener.dart';
import 'package:thinkup_sdk/at_rewarded.dart';
import 'package:thinkup_sdk/at_rewarded_response.dart';
import '../PCModel/PCAdModel.dart';
import '../PCDialog/PCOther/PCOtherDialog.dart';
import 'PCAdRevenue.dart';
import 'PCAnalytics.dart';
import 'PCAudioUtils.dart';
import 'PCLogger.dart';
import 'PCRewardedAdService.dart';
import 'PCInterstitialAdService.dart';
import 'PCTBAEventTool.dart';
import 'pc_LocalProvider.dart';
import 'pc_extension_help.dart';

Map<String, dynamic> pc_defaultAdConfig = {
  "nkmdl_int": [
    {
      "byfxjhld": "n1hoi31aglpr0a",
      "dmhytwql": "topon",
      "ugebepat": "interstitial",
      "gqqvwedz": 3000,
      "wdzqbsbt": 2,
    },
    {
      "byfxjhld": "ibY48kOdYdGCxD2FqIhOX",
      "dmhytwql": "cloudx",
      "ugebepat": "interstitial",
      "gqqvwedz": 3000,
      "wdzqbsbt": 1,
    },
  ],
  "nkmdl_rv": [
    {
      "byfxjhld": "n1hoi31aglq47q",
      "dmhytwql": "topon",
      "ugebepat": "reward",
      "gqqvwedz": 3000,
      "wdzqbsbt": 2,
    },
    {
      "byfxjhld": "yT9Q-o8dLXJKNqtYmZQ49",
      "dmhytwql": "cloudx",
      "ugebepat": "reward",
      "gqqvwedz": 3000,
      "wdzqbsbt": 1,
    },
  ],
};

class PCCardAuraAdModel {
  String type;
  String source;

  int weight;
  String ad_identifer;
  int status;
  String networkName;
  String sdk;

  PCCardAuraAdModel({
    required this.type,
    required this.source,
    required this.weight,
    required this.ad_identifer,
    required this.status,
    required this.networkName,
    required this.sdk,
  });

  String getTypeToServer() {
    if (type == "reward") {
      return "rv";
    } else {
      return "int";
    }
  }
}

/// TopOn / CloudX各广告位并行预加载，同类型可用缓存按配置权重优先展示。
class PCPigAds {
  static final PCPigAds _instance = PCPigAds._internal();

  factory PCPigAds() {
    return _instance;
  }

  PCPigAds._internal();

  PCAdModel? _PCCardAuraAdModel;

  PCAdModel? pc_PigAdModel = PCAdModel.fromJson(pc_defaultAdConfig);

  bool _pigAdDelegateCreated = false;
  bool _topOnDelegateCreated = false;
  final Set<String> _readySources = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, Stopwatch> _requestWatches = {};
  final Set<PCCardAuraAdModel> _refreshingCachedAds = {};
  final Map<PCCardAuraAdModel, Object> _loadTokens = {};
  final Map<PCCardAuraAdModel, Timer> _loadWatchdogs = {};
  final Map<PCCardAuraAdModel, Object> _recoveringLoads = {};
  final Map<PCCardAuraAdModel, Object> _resettingLoads = {};
  final Map<PCCardAuraAdModel, Timer> _cacheMaintenanceTimers = {};
  final Set<(String, String, String)> _configuredAdKeys = {};
  final Map<String, Timer> _sourceInitializationRetries = {};
  final Map<String, Object> _sourceInitializationsInFlight = {};
  String? _activeAdId;
  bool _rewardEarned = false;
  bool _displaySucceeded = false;
  bool _checkingShow = false;
  Object? _checkingShowToken;
  Object? _showCommandToken;
  int _adSessionVersion = 0;
  DateTime? _lastAdFinishedAt;
  // 兼容旧调用；不再启用A/B或收入比价，展示统一使用配置权重。
  bool compareMode = false;
  static const _cacheCheckTimeout = Duration(seconds: 2);
  static const _loadTimeout = Duration(seconds: 9);
  static const _cacheCheckInterval = Duration(seconds: 9);
  static const _retryDelay = Duration(seconds: 2);
  static const _cloudXChannel = MethodChannel('cloudx_flutter_sdk');

  @visibleForTesting
  Duration? loadTimeoutForTesting;
  @visibleForTesting
  Duration? retryDelayForTesting;
  @visibleForTesting
  Duration? cacheCheckIntervalForTesting;
  @visibleForTesting
  Future<void> Function(String source)? retryAdSourceInitializationForTesting;

  /// 包括检查缓存、等待 SDK 展示和业务关闭回调，前台插屏不能抢占这些阶段。
  bool get isAdBusy =>
      _checkingShow ||
      is_showAd ||
      _activeAdId != null ||
      onAdClosed != null ||
      someAdIsShowing();

  /// 已交给原生SDK展示的广告，不包含缓存检查、加载或尚未完成的业务回调。
  bool get isNativeAdShowing => is_showAd || _activeAdId != null;

  /// 供生命周期区分用户真实返回与原生广告 Activity 的前后台切换。
  int get adSessionVersion => _adSessionVersion;
  DateTime? get lastAdFinishedAt => _lastAdFinishedAt;

  @visibleForTesting
  void Function(String, Map<String, dynamic>) reportEvent = PCAnalytics.event;
  @visibleForTesting
  void Function(Map<String, dynamic>) reportRevenue = pc_ad_fire;

  bool init_suc = false;

  String? quizAdPlaceID;

  Function(bool)? onAdClosed;
  Function(PCAdOutcome)? _onAdOutcome;

  DateTime int_start = DateTime.now();

  DateTime read_start = DateTime.now();

  int _adShowed = 0;
  int _adClicked = 0;
  int adShowedToday = 0;
  double _adRevenues = 0.0;

  List<PCCardAuraAdModel> _ads = [];
  late bool is_showAd = false;
  VoidCallback? _releaseAdBgm;

  /// 是否跳过广告
  final bool skipAd = false;
  @visibleForTesting
  bool? skipAdForTesting;

  /// 先绑定统一入口，不初始化SDK；启动期间未就绪的请求也能记录机会和失败原因。
  void bindServices() {
    PCRewardedAdService.instance.bindOutcomeHandler(requestRewardedOutcome);
    PCInterstitialAdService.instance.bindOutcomeHandler(
      requestInterstitialOutcome,
    );
    PCInterstitialAdService.instance.bindCachedOutcomeHandler(
      requestCachedInterstitialOutcome,
    );
  }

  /// 只补缺失缓存；不自动展示广告，仍在加载或已有缓存的广告不重复load。
  Future<void> retryMissingAds() async {
    asLog.debug(
      '[ad-load] replenish_missing placements=${_configuredAdKeys.length}',
    );
    _requestAd(recheckCached: true);
  }

  Future<void> init({PCAdModel? inputAd, Set<String>? readySources}) async {
    final config = inputAd ?? pc_PigAdModel;
    final firstInitialization = _ads.isEmpty && _configuredAdKeys.isEmpty;
    _readySources.addAll(readySources ?? const {'topon', 'cloudx'});
    bindServices();
    try {
      // 配置增减只调整对应ID，不能清掉其他缓存、在途请求或正在播放的owner。
      _PCCardAuraAdModel = config;
      _reconcileAdConfig(config);
      if (firstInitialization) _getCacheData();
      _createListener();
      _requestAd();
      init_suc = _readySources.isNotEmpty;
    } catch (error) {
      asLog.info("$runtimeType init ad error $error");
    }
  }

  void _reconcileAdConfig(PCAdModel? config) {
    final desired = <String, PCAdModellist>{};
    for (final placement in [...?config?.nkmdl_int, ...?config?.nkmdl_rv]) {
      if (placement.byfxjhld.isNotEmpty) {
        desired.putIfAbsent(placement.byfxjhld, () => placement);
      }
    }
    _configuredAdKeys
      ..clear()
      ..addAll(
        desired.values.map((ad) => (ad.byfxjhld, ad.dmhytwql, ad.ugebepat)),
      );
    final sources = desired.values.map((ad) => ad.dmhytwql).toSet();
    for (final source in {
      ..._sourceInitializationRetries.keys,
      ..._sourceInitializationsInFlight.keys,
    }) {
      if (!sources.contains(source)) {
        _sourceInitializationRetries.remove(source)?.cancel();
        _sourceInitializationsInFlight.remove(source);
      }
    }
    for (final ad in List<PCCardAuraAdModel>.of(_ads)) {
      if (_isConfiguredAd(ad)) {
        ad.weight = desired[ad.ad_identifer]!.wdzqbsbt;
        continue;
      }
      _cancelAdBackground(ad);
      if (_activeAdId == ad.ad_identifer && ad.status == 2) {
        // 已移除的在播ID等真实关闭后才退役，不补量也不销毁其正在展示的实例。
        continue;
      }
      _ads.remove(ad);
    }
    addAds(desired.values.toList());
    asLog.debug('[ad-load] configure placements=${_configuredAdKeys.length}');
  }

  void _retireClosedAd(PCCardAuraAdModel ad) {
    if (_isConfiguredAd(ad)) return;
    _cancelAdBackground(ad);
    _ads.remove(ad);
    final config = _PCCardAuraAdModel;
    addAds([...?config?.nkmdl_int, ...?config?.nkmdl_rv]);
  }

  void _cancelAdBackground(PCCardAuraAdModel ad) {
    _clearLoadTracking(ad);
    _cacheMaintenanceTimers.remove(ad)?.cancel();
    _refreshingCachedAds.remove(ad);
    _retryTimers.remove(ad.ad_identifer)?.cancel();
    _requestWatches.remove(ad.ad_identifer)?.stop();
  }

  void addAds(List<PCAdModellist> list) {
    for (final d in list) {
      if (d.byfxjhld.isEmpty ||
          !_configuredAdKeys.contains((d.byfxjhld, d.dmhytwql, d.ugebepat)) ||
          _ads.any((ad) => ad.ad_identifer == d.byfxjhld)) {
        continue;
      }
      _ads.add(
        PCCardAuraAdModel(
          type: d.ugebepat,
          source: d.dmhytwql,
          weight: d.wdzqbsbt,
          ad_identifer: d.byfxjhld,
          status: 0,
          networkName: "",
          sdk: "",
        ),
      );
    }
  }

  void _getCacheData() {
    _adShowed = PCLocalProvider.instance.pc_ad_show_number;
    _adClicked = 0;
    adShowedToday = 0;
    _adRevenues = 0;
  }

  /// 业务领奖入口，只接受激励类型，真实激励回调后关闭才返回成功。
  Future<bool> requestRewarded(String placement) async =>
      (await requestRewardedOutcome(placement)).isSuccess;

  Future<PCAdOutcome> requestRewardedOutcome(String placement) =>
      _requestAdOutcome(placement, rewarded: true);

  /// 关闭奖励及开屏等插屏入口，未就绪/播放失败直接结束，不叠加失败弹窗。
  Future<bool> requestInterstitial(String placement) async =>
      (await requestInterstitialOutcome(placement)).isSuccess;

  Future<PCAdOutcome> requestInterstitialOutcome(String placement) =>
      _requestAdOutcome(placement, rewarded: false);

  /// 仅缓存插屏入口；未缓存时不改变既有预加载计划。
  Future<bool> requestCachedInterstitial(String placement) async =>
      (await requestCachedInterstitialOutcome(placement)).isSuccess;

  Future<PCAdOutcome> requestCachedInterstitialOutcome(String placement) =>
      _requestAdOutcome(placement, rewarded: false, cachedOnly: true);

  Future<PCAdOutcome> _requestAdOutcome(
    String placement, {
    required bool rewarded,
    bool cachedOnly = false,
  }) {
    if (_adTypeForPlacement(placement, rewarded: rewarded) !=
        (rewarded ? 'rv' : 'int')) {
      return Future<PCAdOutcome>.value(PCAdOutcome.failed);
    }
    final result = Completer<PCAdOutcome>();
    void finish(PCAdOutcome value) {
      if (!result.isCompleted) result.complete(value);
    }

    pc_showAd(
      null,
      placement,
      rewarded: rewarded,
      showDialog: false,
      cachedOnly: cachedOnly,
      onCacheResponse: (ready) {
        if (!ready) finish(PCAdOutcome.failed);
      },
      onOutcome: finish,
      adDidClosed: (_) {},
    );
    return result.future;
  }

  /// 显式场景标识优先；冷/热启动两个无后缀场景均固定插屏。
  String _adTypeForPlacement(String placeID, {bool? rewarded}) {
    final placement = placeID.toLowerCase();
    if (const {'nkmdl_launch', 'nskdh_launch'}.contains(placement) ||
        placement.contains('int')) {
      return 'int';
    }
    if (placement.contains('rv')) return 'rv';
    return rewarded == true ? 'rv' : 'int';
  }

  /// 文档的自定义事件平台枚举；CloudX归other，标准收入仍保留原SDK标识。
  String _eventSource(String source) => switch (source) {
    'admob' || 'max' || 'topon' || 'tradplus' => source,
    _ => 'other',
  };

  String _missingAdReason(String realType) {
    if (_readySources.isEmpty) return 'uninitialized';
    if (_ads.any((ad) => ad.type == realType && ad.status == 3)) {
      return 'notPrepared';
    }
    return 'ad_nocache';
  }

  void setSourceReady(String source) {
    _readySources.add(source);
    _sourceInitializationRetries.remove(source)?.cancel();
    _sourceInitializationsInFlight.remove(source);
    init_suc = true;
    _createListener();
    _requestAd(
      defaultIndex: [
        for (var i = 0; i < _ads.length; i++)
          if (_ads[i].source == source) i,
      ],
    );
  }

  void pc_showAd(
    BuildContext? context,
    String placeID, {
    required Function(bool) onCacheResponse,
    required Function(bool) adDidClosed,
    Function(PCAdOutcome)? onOutcome,
    bool mustShow = false,
    bool showDialog = true,
    bool? rewarded,
    bool cachedOnly = false,
  }) async {
    if (_checkingShow || someAdIsShowing() || onAdClosed != null) {
      asLog.debug(
        '[ad-show] busy placement=$placeID checking=$_checkingShow '
        'native=$isNativeAdShowing owner=${onAdClosed != null}',
      );
      final local = PCLocalProvider.instance;
      if (!isNativeAdShowing &&
          !local.pc_fk_number_status &&
          !local.pc_fk_decvice_status &&
          !local.pc_fk_ip_status) {
        // 原生尚未展示、但上次缓存检查/关闭回调仍在途，也要记录这次入口尝试。
        // 只上报本次placeID，不替换前一请求的owner、锁或SDK请求。
        reportEvent('nkmdl_ad_chance', {
          'ad_pos_id': placeID,
          'ad_format': _adTypeForPlacement(placeID, rewarded: rewarded),
        });
        reportEvent('nkmdl_ad_impression_fail', {
          'ad_pos_id': placeID,
          'reason': 'notPrepared',
        });
      }
      // 另一笔检查/展示正在占用时，本次只是静默取消；先通知typed，
      // 防止legacy缓存false把它抢先折叠成播放失败并排队弹错。
      unawaited(_notifyAdCallback(onOutcome, PCAdOutcome.cancelled));
      onCacheResponse(false);
      return;
    }
    final checkingToken = Object();
    _checkingShowToken = checkingToken;
    _checkingShow = true;
    try {
      final local = PCLocalProvider.instance;
      // 风控
      if (local.pc_fk_number_status ||
          local.pc_fk_decvice_status ||
          local.pc_fk_ip_status) {
        if (context != null && context.mounted) {
          PCDialogTool.toast(
            context,
            'Something went wrong, please try again later.',
          );
        }
        reportEvent('pc_fk_un', {});
        onCacheResponse(false);
        unawaited(_notifyAdCallback(onOutcome, PCAdOutcome.failed));
        return;
      }
      onAdClosed = adDidClosed;
      _onAdOutcome = onOutcome;
      quizAdPlaceID = placeID;
      final adType = _adTypeForPlacement(placeID, rewarded: rewarded);
      reportEvent('nkmdl_ad_chance', {
        'ad_pos_id': placeID,
        'ad_format': adType,
      });
      if (skipAdForTesting ?? skipAd) {
        // 跳过模式模拟激励/插屏成功；只回业务结果，不伪造展示或收入事件。
        _releaseShowCheck(checkingToken);
        await _finishAdCallback(PCAdOutcome.success);
        return;
      }
      await _showAvailableAd(
        adType,
        placeID,
        onCacheResponse,
        context: context,
        showDialog: showDialog,
        cachedOnly: cachedOnly,
      );
    } catch (error) {
      asLog.error('Ad show request failed: $error');
      if (!identical(_checkingShowToken, checkingToken)) {
        // 旧请求已交接/完成，不能因迟到异常清理后来请求的owner和结果。
        return;
      }
      // SDK若已通过失败回调结束本次owner，不再因同一原生调用抛错重复报失败。
      if (onAdClosed != null && quizAdPlaceID == placeID) {
        reportEvent('nkmdl_ad_impression_fail', {
          'ad_pos_id': placeID,
          'reason': 'impfail',
          'error_reason': error.toString(),
        });
      }
      final active = _ads.indexWhere((ad) => ad.ad_identifer == _activeAdId);
      if (_activeAdId != null) _lastAdFinishedAt = DateTime.now();
      if (active >= 0) _ads[active].status = 0;
      is_showAd = false;
      _activeAdId = null;
      _releaseShowCheck(checkingToken);
      final completion = _finishAdCallback(PCAdOutcome.failed);
      onCacheResponse(false);
      await completion;
    } finally {
      _releaseShowCheck(checkingToken);
    }
  }

  void _releaseShowCheck(Object? token) {
    if (token == null || !identical(_checkingShowToken, token)) return;
    _checkingShowToken = null;
    _checkingShow = false;
  }

  Future<void> _showAvailableAd(
    String adType,
    String placeID,
    Function(bool) onCacheResponse, {
    BuildContext? context,
    bool showDialog = true,
    bool cachedOnly = false,
  }) async {
    final realType = adType == 'int' ? 'interstitial' : 'reward';
    final candidates = [
      for (final ad in _ads)
        if (ad.type == realType &&
            _isConfiguredAd(ad) &&
            _readySources.contains(ad.source) &&
            !_resettingLoads.containsKey(ad) &&
            ad.status != 2)
          ad,
    ];
    candidates.sort((a, b) {
      final weightOrder = b.weight.compareTo(a.weight);
      return weightOrder != 0
          ? weightOrder
          : _ads.indexOf(a).compareTo(_ads.indexOf(b));
    });
    // 已收到Loaded的缓存先用：只有一家有缓存时不等待另一家补量或检查。
    // 两家都已缓存时按weight降序尝试；失效/检查异常只淘汰当前候选。
    final knownCached = candidates.where((ad) => ad.status == 1).toList();
    final remaining = candidates.where((ad) => ad.status != 1).toList();
    for (final ad in [...knownCached, ...remaining]) {
      if (!_ads.contains(ad) ||
          _resettingLoads.containsKey(ad) ||
          ad.status == 2) {
        continue;
      }
      bool ready;
      try {
        ready = await _hasCachedAd(ad);
      } catch (error) {
        asLog.error(
          'Ad cache check failed [${ad.source}]: ${error.runtimeType}',
        );
        ready = false;
      }
      if (!_ads.contains(ad) ||
          !_isConfiguredAd(ad) ||
          !_readySources.contains(ad.source) ||
          _resettingLoads.containsKey(ad)) {
        continue;
      }
      if (!ready) {
        // 不能把仍在加载的广告改为空闲，否则会重复load。
        if (ad.status == 1) ad.status = 0;
        continue;
      }
      asLog.debug(
        '$runtimeType show cached ad type=$adType source=${ad.source} '
        'weight=${ad.weight} id=${ad.ad_identifer}',
      );
      // SDK已有缓存但Loaded回调遗漏时，也要解除旧加载看门狗，不能稍后销毁它。
      _markAdCached(ad);
      if (await _tryShowAd(ad, placeID)) return;
    }

    // 所有同类型SDK缓存均不可用，才统一失败一次；不能因一家在补量而提前失败。
    if (context != null && context.mounted && showDialog) {
      pc_showfaildDiolog(context, showDialog);
    }
    reportEvent('nkmdl_ad_impression_fail', {
      'ad_pos_id': placeID,
      'reason': _missingAdReason(realType),
    });
    if (!cachedOnly) {
      // 先启动独立补量，不能依赖失败面板或业务关闭回调才恢复请求。
      unawaited(retryMissingAds());
    }
    _releaseShowCheck(_checkingShowToken);
    final completion = _finishAdCallback(PCAdOutcome.failed);
    onCacheResponse(false);
    await completion;
  }

  Future<bool> _tryShowAd(PCCardAuraAdModel ad, String placeID) async {
    final checkingToken = _checkingShowToken;
    // 先暂停并等待播放器完成，再调用SDK，避免广告已发声后才收到Displayed回调。
    final audio = PCAudioUtils();
    final releaseAudio = audio.holdBGMForAd();
    _releaseAdBgm = releaseAudio;
    // 音频桥接失联时按正常展示失败退出，不能新增一个无限等待，也不能带音乐强行show。
    await audio
        .pauseBGM(requireSuccess: true)
        .timeout(const Duration(seconds: 2));
    if (!identical(_releaseAdBgm, releaseAudio)) {
      // 等待音频期间owner已结束，不能再展示这笔过期广告或清理新的owner。
      return true;
    }
    if (!_ads.contains(ad) || !_isConfiguredAd(ad)) {
      _releaseAdBackgroundMusic();
      return false;
    }
    // 暂停准备期间仍属普通请求；真正交给SDK之前才标记原生展示，不能吞用户session。
    is_showAd = true;
    _adSessionVersion++;
    _activeAdId = ad.ad_identifer;
    _rewardEarned = false;
    _displaySucceeded = false;
    ad.status = 2;
    _cacheMaintenanceTimers.remove(ad)?.cancel();
    final commandToken = Object();
    _showCommandToken = commandToken;
    // 已交给SDK后由原生展示锁接管。TopOn show通道不回复result，不能等待其Future。
    _releaseShowCheck(checkingToken);
    Future<void> command;
    if (ad.source == 'cloudx') {
      // 同一SDK通道保留原监听器，同时接住void封装未转交的原生调用异常。
      command = _cloudXChannel.invokeMethod<void>(
        ad.type == 'reward' ? 'showRewarded' : 'showInterstitial',
        {'adUnitId': ad.ad_identifer, 'placement': placeID},
      );
    } else if (ad.type == 'reward') {
      command = ATRewardedManager.showRewardedVideo(
        placementID: ad.ad_identifer,
      ).then<void>((_) {});
    } else {
      command = ATInterstitialManager.showInterstitialAd(
        placementID: ad.ad_identifer,
      ).then<void>((_) {});
    }
    unawaited(_observeShowCommand(command, ad, commandToken));
    return true;
  }

  Future<void> _observeShowCommand(
    Future<void> command,
    PCCardAuraAdModel ad,
    Object token,
  ) async {
    try {
      await command;
      // 方法调用完成仅代表命令已接收，展示、收益、领奖均仍等待真实SDK回调。
    } catch (error) {
      if (!identical(_showCommandToken, token) ||
          _activeAdId != ad.ad_identifer ||
          !_ads.contains(ad)) {
        asLog.debug('[ad-show] stale_command_error source=${ad.source}');
        return;
      }
      if (_displaySucceeded || _rewardEarned) {
        // 真实SDK回调已经证明命令生效，迟到的通道异常不能覆盖展示/激励结果。
        // 真正的播放失败仍由SDK失败回调处理，激励仍须真实RewardSuccess才发奖。
        asLog.debug(
          '[ad-show] ignored_command_error_after_display source=${ad.source}',
        );
        return;
      }
      asLog.error('[ad-show] command_failed source=${ad.source}: $error');
      await _adDidDisplayedError(ad.ad_identifer, error.toString());
    }
  }

  Future<bool> _hasCachedAd(PCCardAuraAdModel ad) async {
    if (ad.source == 'cloudx') {
      return ad.type == 'reward'
          ? await CloudX.isRewardedReady(
              adUnitId: ad.ad_identifer,
            ).timeout(_cacheCheckTimeout)
          : await CloudX.isInterstitialReady(
              adUnitId: ad.ad_identifer,
            ).timeout(_cacheCheckTimeout);
    } else if (ad.source == 'topon') {
      return ad.type == 'reward'
          ? await ATRewardedManager.rewardedVideoReady(
              placementID: ad.ad_identifer,
            ).timeout(_cacheCheckTimeout)
          : await ATInterstitialManager.hasInterstitialAdReady(
              placementID: ad.ad_identifer,
            ).timeout(_cacheCheckTimeout);
    }
    return false;
  }

  void adImpression(Map extMap, {String? adUnitId}) {
    final event = PCAdRevenue.topOn(
      extMap,
      placement: quizAdPlaceID,
      adUnitId: adUnitId,
    );
    final revenue = PCAdRevenue.amount(extMap['publisher_revenue']) ?? 0;
    final activeIndex = _ads.indexWhere(
      (ad) => ad.ad_identifer == (adUnitId ?? _activeAdId),
    );
    _reportRevenue(
      revenue: revenue,
      network: extMap['network_name']?.toString() ?? 'topon',
      sdk: 'topon_sdk',
      adUnit: (extMap['adunit_id'] ?? adUnitId)?.toString() ?? '',
      format: activeIndex >= 0
          ? _ads[activeIndex].getTypeToServer()
          : (extMap['adunit_format']?.toString().toLowerCase().contains(
                  'reward',
                ) ??
                false)
          ? 'rv'
          : 'int',
    );
    if (event != null) {
      Adjust.trackAdRevenue(event);
      PCFacebookAnalytics.logPurchase(revenue, 'USD');
    }
  }

  void cloudXAdRevenue(CloudXAd ad) {
    final event = PCAdRevenue.cloudX(ad, placement: quizAdPlaceID);
    final revenue = PCAdRevenue.amount(ad.revenue) ?? 0;
    _reportRevenue(
      revenue: revenue,
      network: ad.networkName,
      sdk: 'cloudx',
      adUnit: ad.adUnitId,
      format: ad.adFormat == CloudXAdFormat.rewarded ? 'rv' : 'int',
    );
    if (event != null) {
      Adjust.trackAdRevenue(event);
      PCFacebookAnalytics.logPurchase(revenue, 'USD');
    }
  }

  void _reportRevenue({
    required double revenue,
    required String network,
    required String sdk,
    required String adUnit,
    required String format,
  }) {
    final placement = quizAdPlaceID;
    reportRevenue({
      'dang': revenue * 1000000,
      'noreen': network,
      'dar': sdk,
      'graphic': adUnit,
      'valuate': placement,
      'shadowy': format,
      // 保留既有TBA混淆协议，同时提供表中明文字段；只走pc_ad_fire一条链。
      'ad_pos_id': placement,
      // SDK revenue是单次美元收入；表中eCPM是每千次收入，再转换为微单位。
      // dang沿用原协议的单次收入微美元，不能连同Adjust/FB收入一起放大。
      'ad_pre_ecpm': revenue * 1000 * 1000000,
      'ad_format': format == 'rv' ? 'reward' : 'interstitial',
    });
    adRevenues(revenue);
  }

  pc_showfaildDiolog(BuildContext context, bool isShow) async {
    bool isConnected = await NetworkUtils.isConnected();
    if (isShow && context.mounted) {
      if (isConnected) {
        asLog.debug("有网加载失败");
        context.tipShow(const PCAdLoadingFailedDialog());
      } else {
        asLog.debug("设备无网络连接");
        context.tipShow(const PCNoNetworkDialog());
      }
    }
  }

  void adShowed() async {
    _adShowed += 1;
    asLog.debug("$runtimeType ad show times $_adShowed");
    PCLocalProvider.instance.updateint(
      PCLocalProvider.instance.pc_ad_show_numberName,
      _adShowed,
    );
    PCLocalProvider.instance.updateint(
      PCLocalProvider.instance.pc_ad_all_numberName,
      PCLocalProvider.instance.pc_ad_all_number + 1,
    );
    update();
  }

  void adClicked() async {
    _adClicked += 1;

    update();
  }

  int getAdClickCount() => _adClicked;
  double getAdRevenue() => _adRevenues;

  @visibleForTesting
  void stopForTesting() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _requestWatches.clear();
    _refreshingCachedAds.clear();
    _cancelLoadTracking();
    _readySources.clear();
    compareMode = false;
    _activeAdId = null;
    is_showAd = false;
    _checkingShow = false;
    _checkingShowToken = null;
    _adSessionVersion = 0;
    _lastAdFinishedAt = null;
    _ads.clear();
    _configuredAdKeys.clear();
    resetHandler();
    PCRewardedAdService.instance.handler = null;
    PCInterstitialAdService.instance.handler = null;
    PCInterstitialAdService.instance.cachedHandler = null;
  }

  int getAdShowCount() {
    return _adShowed;
  }

  void adRevenues(double revenue) {
    _adRevenues += revenue;
    update();
  }

  update() async {}
}

extension AdServiceExtension on PCPigAds {
  Future<void> setAdConfigData({PCAdModel? inputAdModel}) async {
    _PCCardAuraAdModel = inputAdModel;
  }

  void _requestAd({
    List<int>? defaultIndex,
    bool recheckCached = false,
    bool retryTimedOut = false,
  }) {
    for (var i = 0; i < _ads.length; i++) {
      if (defaultIndex != null && !defaultIndex.contains(i)) continue;
      final ad = _ads[i];
      if (!_isConfiguredAd(ad)) continue;
      if (!_readySources.contains(ad.source)) {
        _loadLog(ad, 'source_not_ready');
        _waitForAdSource(ad);
        continue;
      }
      if (recheckCached && ad.status == 1) {
        if (_refreshingCachedAds.add(ad)) {
          unawaited(_refreshCachedAd(ad));
        }
        continue;
      }
      if (ad.status == 3) {
        _loadLog(
          ad,
          _resettingLoads.containsKey(ad) ? 'recovering' : 'already_loading',
        );
        // 兼容热重载前遗留的status=3，不能因为缺少原计时器永远跳过。
        final token = _loadTokens.putIfAbsent(ad, Object.new);
        if (!_loadWatchdogs.containsKey(ad) &&
            !_recoveringLoads.containsKey(ad)) {
          _armLoadWatchdog(ad, token);
        }
        continue;
      }
      if (ad.status != 0) {
        _loadLog(ad, ad.status == 1 ? 'cache_available' : 'showing');
        if (ad.status == 1) _armCacheMaintenance(ad);
        continue;
      }
      // 在任何await前占位，缓存检查、初始化重入和失败计时器共用这一个锁。
      ad.status = 3; // 0空闲、1缓存、2展示、3检查缓存/加载中。
      final token = Object();
      _loadTokens[ad] = token;
      _armLoadWatchdog(ad, token);
      _retryTimers.remove(ad.ad_identifer)?.cancel();
      unawaited(_loadIfMissing(ad, token, retryTimedOut: retryTimedOut));
    }
  }

  void _loadLog(PCCardAuraAdModel ad, String state) {
    final elapsed = _requestWatches[ad.ad_identifer]?.elapsedMilliseconds;
    asLog.debug(
      '[ad-load] $state source=${ad.source} type=${ad.type} '
      'id=${ad.ad_identifer} elapsed_ms=${elapsed ?? 0}',
    );
  }

  void _waitForAdSource(PCCardAuraAdModel ad) {
    final id = ad.ad_identifer;
    if (_retryTimers.containsKey(id) || ad.status == 2) return;
    late final Timer timer;
    timer = Timer(loadTimeoutForTesting ?? PCPigAds._loadTimeout, () {
      if (!identical(_retryTimers[id], timer)) return;
      _retryTimers.remove(id);
      final index = _ads.indexOf(ad);
      if (index >= 0 && _isConfiguredAd(ad)) {
        _retryAdSourceInitialization(ad.source);
        _requestAd(defaultIndex: [index]);
      }
    });
    _retryTimers[id] = timer;
  }

  void _retryAdSourceInitialization(String source) {
    if (_readySources.contains(source) ||
        _sourceInitializationRetries.containsKey(source) ||
        _sourceInitializationsInFlight.containsKey(source)) {
      return;
    }
    late final Timer timer;
    timer = Timer(loadTimeoutForTesting ?? PCPigAds._loadTimeout, () {
      if (identical(_sourceInitializationRetries[source], timer)) {
        _sourceInitializationRetries.remove(source);
      }
    });
    _sourceInitializationRetries[source] = timer;
    final token = Object();
    _sourceInitializationsInFlight[source] = token;
    asLog.debug('[ad-load] source_init_retry source=$source');
    final retry =
        retryAdSourceInitializationForTesting ??
        PCSDKHelpers().retryAdSourceInitialization;
    unawaited(
      Future<void>.sync(() => retry(source))
          .catchError((Object error) {
            asLog.error(
              '[ad-load] source_init_retry_failed source=$source '
              'error=${error.runtimeType}',
            );
          })
          .whenComplete(() {
            if (identical(_sourceInitializationsInFlight[source], token)) {
              _sourceInitializationsInFlight.remove(source);
            }
          }),
    );
  }

  bool _isCurrentLoad(PCCardAuraAdModel ad, Object token) =>
      _ads.contains(ad) &&
      _readySources.contains(ad.source) &&
      ad.status == 3 &&
      identical(_loadTokens[ad], token);

  void _clearLoadTracking(PCCardAuraAdModel ad) {
    _loadWatchdogs.remove(ad)?.cancel();
    _loadTokens.remove(ad);
    _recoveringLoads.remove(ad);
    _resettingLoads.remove(ad);
  }

  void _cancelLoadTracking() {
    for (final timer in _loadWatchdogs.values) {
      timer.cancel();
    }
    _loadWatchdogs.clear();
    _loadTokens.clear();
    _recoveringLoads.clear();
    _resettingLoads.clear();
    for (final timer in _cacheMaintenanceTimers.values) {
      timer.cancel();
    }
    _cacheMaintenanceTimers.clear();
    for (final timer in _sourceInitializationRetries.values) {
      timer.cancel();
    }
    _sourceInitializationRetries.clear();
    _sourceInitializationsInFlight.clear();
  }

  bool _isConfiguredAd(PCCardAuraAdModel ad) =>
      _configuredAdKeys.contains((ad.ad_identifer, ad.source, ad.type));

  /// 每个已缓存ID独立巡检。缓存失效也会自动补量，不依赖按钮或其他广告关闭。
  void _armCacheMaintenance(PCCardAuraAdModel ad) {
    if (!_ads.contains(ad) ||
        !_isConfiguredAd(ad) ||
        !_readySources.contains(ad.source) ||
        ad.status != 1 ||
        _cacheMaintenanceTimers.containsKey(ad)) {
      return;
    }
    late final Timer timer;
    timer = Timer(
      cacheCheckIntervalForTesting ?? PCPigAds._cacheCheckInterval,
      () {
        if (!identical(_cacheMaintenanceTimers[ad], timer)) return;
        _cacheMaintenanceTimers.remove(ad);
        if (!_ads.contains(ad) || !_isConfiguredAd(ad) || ad.status != 1) {
          return;
        }
        if (_refreshingCachedAds.add(ad)) {
          unawaited(_refreshCachedAd(ad));
        }
      },
    );
    _cacheMaintenanceTimers[ad] = timer;
  }

  void _armLoadWatchdog(PCCardAuraAdModel ad, Object token) {
    _loadWatchdogs.remove(ad)?.cancel();
    late final Timer timer;
    timer = Timer(loadTimeoutForTesting ?? PCPigAds._loadTimeout, () {
      if (!identical(_loadWatchdogs[ad], timer)) return;
      _loadWatchdogs.remove(ad);
      unawaited(_recoverStalledLoad(ad, token));
    });
    _loadWatchdogs[ad] = timer;
  }

  /// TopOn的load通道不返回完成状态，必须以原生isLoading判断，不能等待Future结束。
  Future<({bool ready, bool? loading})> _nativeLoadState(
    PCCardAuraAdModel ad,
  ) async {
    try {
      if (await _hasCachedAd(ad)) return (ready: true, loading: false);
    } catch (error) {
      _loadLog(ad, 'cache_check_failed:${error.runtimeType}');
    }
    if (ad.source == 'topon') {
      try {
        final status =
            await (ad.type == 'reward'
                    ? ATRewardedManager.checkRewardedVideoLoadStatus(
                        placementID: ad.ad_identifer,
                      )
                    : ATInterstitialManager.checkInterstitialLoadStatus(
                        placementID: ad.ad_identifer,
                      ))
                .timeout(PCPigAds._cacheCheckTimeout);
        return (
          ready: status['isReady'] == true,
          loading: status['isLoading'] is bool
              ? status['isLoading'] as bool
              : null,
        );
      } catch (error) {
        _loadLog(ad, 'native_status_unavailable:${error.runtimeType}');
      }
    }
    return (ready: false, loading: null);
  }

  Future<void> _recoverStalledLoad(PCCardAuraAdModel ad, Object token) async {
    if (!_isCurrentLoad(ad, token) || _recoveringLoads.containsKey(ad)) return;
    _recoveringLoads[ad] = token;
    _loadLog(ad, 'timeout_check');
    try {
      final state = await _nativeLoadState(ad);
      if (!_isCurrentLoad(ad, token)) return;
      if (state.ready) {
        _loadLog(ad, 'recovered_cache');
        _markAdCached(ad);
        return;
      }
      // TopOn没有单ID取消接口。超时后继续派发，由SDK合并仍在途的同ID加载。
      if (ad.source == 'topon') {
        _loadLog(ad, 'timeout_resubmit native_loading=${state.loading}');
      }
      if (ad.source == 'cloudx') {
        // CloudX没有isLoading。超时且无缓存时先终止旧实例，避免叠加SDK请求。
        _loadLog(ad, 'timeout_destroy');
        _resettingLoads[ad] = token;
        await PCPigAds._cloudXChannel
            .invokeMethod<void>(
              ad.type == 'reward' ? 'destroyRewarded' : 'destroyInterstitial',
              {'adUnitId': ad.ad_identifer},
            )
            .timeout(PCPigAds._cacheCheckTimeout);
        if (!_isCurrentLoad(ad, token)) return;
      }
      _loadLog(ad, 'timeout_recover');
      _adDidLoadFailed(
        ad.ad_identifer,
        'load_callback_timeout',
        ad.source,
        expectedToken: token,
        retryTimedOut: true,
      );
    } catch (error) {
      if (_isCurrentLoad(ad, token)) {
        _adDidLoadFailed(
          ad.ad_identifer,
          'load_recovery_failed:${error.runtimeType}',
          ad.source,
          expectedToken: token,
          retryTimedOut: true,
        );
      }
    } finally {
      if (identical(_resettingLoads[ad], token)) {
        _resettingLoads.remove(ad);
      }
      if (identical(_recoveringLoads[ad], token)) {
        _recoveringLoads.remove(ad);
      }
    }
  }

  /// 关闭后同时核对其他已缓存位；仍有缓存不load，失效才交回统一请求锁补量。
  Future<void> _refreshCachedAd(PCCardAuraAdModel ad) async {
    try {
      bool cached;
      try {
        cached = await _hasCachedAd(ad);
      } catch (error) {
        asLog.error(
          'Ad refill cache check failed [${ad.source}]: ${error.runtimeType}',
        );
        cached = false;
      }
      final index = _ads.indexOf(ad);
      if (index == -1 ||
          !_isConfiguredAd(ad) ||
          !_readySources.contains(ad.source) ||
          ad.status != 1 ||
          cached) {
        return;
      }
      ad.status = 0;
      _requestAd(defaultIndex: [index]);
    } finally {
      _refreshingCachedAds.remove(ad);
      _armCacheMaintenance(ad);
    }
  }

  Future<void> _loadIfMissing(
    PCCardAuraAdModel ad,
    Object token, {
    bool retryTimedOut = false,
  }) async {
    final id = ad.ad_identifer;
    try {
      final state = await _nativeLoadState(ad);
      if (!_isCurrentLoad(ad, token)) return;
      if (state.ready) {
        // 热重启或回调延迟时SDK可能已有缓存，直接复用，不再load。
        _loadLog(ad, 'cache_available');
        _markAdCached(ad);
        return;
      }
      if (state.loading == true && !retryTimedOut) {
        _loadLog(ad, 'native_still_loading');
        return;
      }
      _requestWatches[id] = Stopwatch()..start();
      reportEvent('nkmdl_ad_request', {
        'ad_code_id': id,
        'ad_format': ad.getTypeToServer(),
        'ad_source_client': _eventSource(ad.source),
      });
      _loadLog(ad, 'load_start');
      _armLoadWatchdog(ad, token);
      Future<void> load;
      if (ad.source == 'cloudx') {
        // SDK的void封装丢弃Future；沿用同一通道获取原生异常，监听器仍由SDK维护。
        load = PCPigAds._cloudXChannel.invokeMethod<void>(
          ad.type == 'interstitial' ? 'loadInterstitial' : 'loadRewarded',
          {'adUnitId': id},
        );
      } else {
        final request = ad.type == 'interstitial'
            ? ATInterstitialManager.loadInterstitialAd(
                placementID: id,
                extraMap: {},
              )
            : ATRewardedManager.loadRewardedVideo(
                placementID: id,
                extraMap: {},
              );
        load = request.then<void>((_) {});
      }
      unawaited(
        load.catchError((Object error) {
          if (_isCurrentLoad(ad, token)) {
            _adDidLoadFailed(
              id,
              error.toString(),
              ad.source,
              expectedToken: token,
            );
          }
        }),
      );
    } catch (error) {
      if (_isCurrentLoad(ad, token)) {
        _adDidLoadFailed(id, error.toString(), ad.source, expectedToken: token);
      }
    }
  }

  void _createListener() {
    if (_readySources.contains('cloudx') && !_pigAdDelegateCreated) {
      _createCloudXListeners();
      _pigAdDelegateCreated = true;
    }
    if (_readySources.contains('topon') && !_topOnDelegateCreated) {
      _topOnIntListener();
      _topOnRvListener();
      _topOnDelegateCreated = true;
    }
  }

  void _createCloudXListeners() {
    CloudX.setInterstitialListener(
      CloudXInterstitialListener(
        onAdLoaded: (ad) => _adDidFinishLoad(cloudXAd: ad),
        onAdLoadFailed: (id, error) =>
            _adDidLoadFailed(id, error.message, 'cloudx'),
        onAdDisplayed: (ad) {
          if (_adDidDisplayed(adID: ad.adUnitId, ad_network: ad.networkName)) {
            cloudXAdRevenue(ad);
          }
        },
        onAdHidden: (ad) => _adDidHidden(adId: ad.adUnitId),
        onAdDisplayFailed: (ad, error) =>
            _adDidDisplayedError(ad.adUnitId, error.message),
        onAdClicked: (_) => adClicked(),
      ),
    );
    CloudX.setRewardedListener(
      CloudXRewardedListener(
        onAdLoaded: (ad) => _adDidFinishLoad(cloudXAd: ad),
        onAdLoadFailed: (id, error) =>
            _adDidLoadFailed(id, error.message, 'cloudx'),
        onAdDisplayed: (ad) {
          if (_adDidDisplayed(adID: ad.adUnitId, ad_network: ad.networkName)) {
            cloudXAdRevenue(ad);
            _rewardedDisplayed();
          }
        },
        onAdHidden: (ad) => _adDidHidden(adId: ad.adUnitId),
        onAdDisplayFailed: (ad, error) =>
            _adDidDisplayedError(ad.adUnitId, error.message),
        onAdClicked: (_) => adClicked(),
        onAdReceivedReward: (ad, _) {
          if (_activeAdId == ad.adUnitId) _rewardEarned = true;
        },
      ),
    );
  }

  void _rewardedDisplayed() {
    final local = PCLocalProvider.instance;
    local.updateint(local.pc_qunm_ad_indexName, local.pc_qunm_ad_index + 1);
  }

  void _topOnIntListener() {
    ATListenerManager.interstitialEventHandler.listen((value) {
      switch (value.interstatus) {
        case InterstitialStatus.interstitialAdFailToLoadAD:
          _adDidLoadFailed(value.placementID, value.requestMessage, 'topon');
          break;
        case InterstitialStatus.interstitialAdDidFinishLoading:
          _adDidFinishLoad(toponInt: value);
          break;
        case InterstitialStatus.interstitialAdDidStartPlaying:
          break;
        case InterstitialStatus.interstitialAdDidEndPlaying:
          break;
        case InterstitialStatus.interstitialDidFailToPlayVideo:
          _adDidDisplayedError(value.placementID, value.requestMessage);
          break;
        case InterstitialStatus.interstitialDidShowSucceed:
          if (_adDidDisplayed(
            adID: value.placementID,
            ad_network: value.extraMap['network_name']?.toString() ?? 'topon',
          )) {
            adImpression(value.extraMap, adUnitId: value.placementID);
          }
          break;
        case InterstitialStatus.interstitialFailedToShow:
          _adDidDisplayedError(value.placementID, value.requestMessage);
          break;
        case InterstitialStatus.interstitialAdDidClick:
          adClicked();
          break;
        case InterstitialStatus.interstitialAdDidDeepLink:
          break;
        case InterstitialStatus.interstitialAdDidClose:
          _adDidHidden(adId: value.placementID);
          break;

        case InterstitialStatus.interstitialUnknown:
          break;
        case InterstitialStatus.interstitialAdDidMultipleLoaded:
        case InterstitialStatus.interstitialAdDidAdSourceBiddingAttempt:
          break;
        case InterstitialStatus.interstitialAdDidAdSourceBiddingFilled:
          break;
        case InterstitialStatus.interstitialAdDidAdSourceBiddingFail:
          break;
        case InterstitialStatus.interstitialAdDidAdSourceAttempt:
          break;
        case InterstitialStatus.interstitialAdDidAdSourceLoadFilled:
          break;
        case InterstitialStatus.interstitialAdDidAdSourceLoadFail:
          break;
      }
    });
  }

  void _topOnRvListener() {
    ATListenerManager.rewardedVideoEventHandler.listen((value) {
      switch (value.rewardStatus) {
        case RewardedStatus.rewardedVideoDidFailToLoad:
          _adDidLoadFailed(value.placementID, value.requestMessage, 'topon');
          break;
        case RewardedStatus.rewardedVideoDidFinishLoading:
          _adDidFinishLoad(toponReward: value);
          break;
        case RewardedStatus.rewardedVideoDidStartPlaying:
          if (_adDidDisplayed(
            adID: value.placementID,
            ad_network: value.extraMap['network_name']?.toString() ?? 'topon',
          )) {
            adImpression(value.extraMap, adUnitId: value.placementID);
            _rewardedDisplayed();
          }
          break;
        case RewardedStatus.rewardedVideoDidEndPlaying:
          break;
        case RewardedStatus.rewardedVideoDidFailToPlay:
          _adDidDisplayedError(value.placementID, value.requestMessage);
          break;
        case RewardedStatus.rewardedVideoDidRewardSuccess:
          if (_activeAdId == value.placementID) _rewardEarned = true;
          break;
        case RewardedStatus.rewardedVideoDidClick:
          adClicked();
          break;
        case RewardedStatus.rewardedVideoDidDeepLink:
          break;
        case RewardedStatus.rewardedVideoDidClose:
          _adDidHidden(adId: value.placementID);
          break;
        case RewardedStatus.rewardedVideoDidAgainStartPlaying:
          break;
        case RewardedStatus.rewardedVideoDidAgainEndPlaying:
          break;
        case RewardedStatus.rewardedVideoDidAgainFailToPlay:
          break;
        case RewardedStatus.rewardedVideoDidAgainRewardSuccess:
          break;
        case RewardedStatus.rewardedVideoDidAgainClick:
        case RewardedStatus.rewardedVideoUnknown:
          break;
        case RewardedStatus.rewardedVideoDidMultipleLoaded:
          break;
        case RewardedStatus.rewardedVideoDidAdSourceBiddingAttempt:
          break;
        case RewardedStatus.rewardedVideoDidAdSourceBiddingFilled:
          break;
        case RewardedStatus.rewardedVideoDidAdSourceBiddingFail:
          break;
        case RewardedStatus.rewardedVideoDidAdSourceAttempt:
          break;
        case RewardedStatus.rewardedVideoDidAdSourceLoadFilled:
          break;
        case RewardedStatus.rewardedVideoDidAdSourceLoadFail:
          break;
      }
    });
  }

  void _adDidFinishLoad({
    CloudXAd? cloudXAd,
    ATInterstitialResponse? toponInt,
    ATRewardResponse? toponReward,
  }) {
    // Loaded立即标记缓存，不再查询价格明细，避免SDK有缓存却卡在本地加载中。
    String adID = "";
    String networkName = "";
    String sdk = "";
    if (cloudXAd != null) {
      adID = cloudXAd.adUnitId;
      networkName = cloudXAd.networkName;
      sdk = 'cloudx';
    }
    if (toponInt != null) {
      sdk = "topon_sdk";
      adID = toponInt.placementID;
      networkName = "topon";
    }
    if (toponReward != null) {
      sdk = "topon_sdk";
      adID = toponReward.placementID;
      networkName = "topon";
    }

    if (adID.isEmpty) {
      asLog.error("$runtimeType ad did loaded but id is empty id = $adID");
      return;
    }

    int index = _ads.indexWhere((test) => test.ad_identifer == adID);
    if (index == -1) {
      asLog.error(
        "$runtimeType ad did loaded but cant find in ads data from id = $adID",
      );
      return;
    }

    _markAdCached(_ads[index], networkName: networkName, sdk: sdk);
  }

  void _markAdCached(PCCardAuraAdModel ad, {String? networkName, String? sdk}) {
    if (!_ads.contains(ad) || _resettingLoads.containsKey(ad)) return;
    final requestWatch = _requestWatches.remove(ad.ad_identifer);
    requestWatch?.stop();
    final requestMilliseconds = requestWatch?.elapsedMilliseconds;
    _clearLoadTracking(ad);
    _retryTimers.remove(ad.ad_identifer)?.cancel();
    // 已经展示的广告不能被迟到的加载回调重新标记为可展示。
    if (ad.status == 2) return;
    ad.status = 1;
    _armCacheMaintenance(ad);
    if (networkName != null) ad.networkName = networkName;
    if (sdk != null) ad.sdk = sdk;
    asLog.success(
      "$runtimeType ad did load success [${ad.source}] type = ${ad.type} id = ${ad.ad_identifer} weight = ${ad.weight} network = ${ad.networkName}",
    );
    // 只有对应真实load的首次返回发一次；SDK重复Loaded和已有缓存不虚构请求。
    if (requestMilliseconds != null) {
      reportEvent('nkmdl_ad_return', {
        "ad_code_id": ad.ad_identifer,
        "ad_format": ad.getTypeToServer(),
        "ad_source_client": _eventSource(ad.source),
        "nkmdl_ad_request_time": requestMilliseconds,
      });
    }
  }

  void _adDidLoadFailed(
    String adID,
    String reason,
    String type, {
    Object? expectedToken,
    bool retryTimedOut = false,
  }) {
    int index = _ads.indexWhere((test) => test.ad_identifer == adID);
    if (index == -1) {
      asLog.error(
        "$runtimeType ad did load failed but cant find in ads data from id = $adID",
      );
      return;
    }
    final ad = _ads[index];
    // 旧CloudX实例正在销毁时的SDK回调不能抢先释放锁并启动新实例。
    if (expectedToken == null && _resettingLoads.containsKey(ad)) return;
    if (expectedToken != null && !identical(_loadTokens[ad], expectedToken)) {
      return;
    }
    // 只处理当前加载的失败，迟到/重复失败不能清掉缓存或重开计时器。
    if (ad.status != 3) return;
    _clearLoadTracking(ad);
    _requestWatches.remove(adID)?.stop();
    reportEvent('nkmdl_ad_return_fail', {
      "ad_code_id": adID,
      "ad_format": _ads[index].getTypeToServer(),
      "ad_source_client": _eventSource(type),
      "reason": reason,
    });
    ad.status = 0;
    _retryTimers.remove(adID)?.cancel();
    _loadLog(ad, 'retry_scheduled reason=$reason');
    late final Timer timer;
    timer = Timer(
      retryDelayForTesting ??
          (retryTimedOut ? Duration.zero : PCPigAds._retryDelay),
      () {
        if (!identical(_retryTimers[adID], timer)) return;
        _retryTimers.remove(adID);
        final currentIndex = _ads.indexOf(ad);
        if (currentIndex >= 0) {
          _requestAd(
            defaultIndex: [currentIndex],
            retryTimedOut: retryTimedOut,
          );
        }
      },
    );
    _retryTimers[adID] = timer;
  }

  bool _adDidDisplayed({required String adID, required String ad_network}) {
    // 仅当前这次真实展示成功可上报收入；预加载、失败与重复回调均不计收益。
    if (_activeAdId != adID || _displaySucceeded) return false;
    int index = _ads.indexWhere((test) => test.ad_identifer == adID);
    if (index == -1) {
      asLog.success(
        "$runtimeType ad did display but cant find in ads data from id = $adID",
      );
      reportEvent('olstk_ad_show_suc_not_impression', {});
      return false;
    }
    _displaySucceeded = true;
    _ads[index].status = 2;

    PCLocalProvider.instance.updateint(
      PCLocalProvider.instance.pc_ad_show_indexName,
      PCLocalProvider.instance.pc_ad_show_index + 1,
    );

    asLog.success(
      "$runtimeType ad did display success [${_ads[index].source}] type = ${_ads[index].type} id = ${_ads[index].ad_identifer}",
    );

    adShowed();
    unawaited(PCAnalytics.adDisplayed(count: _adShowed));
    return true;
  }

  Future<void> _adDidHidden({required String adId}) async {
    if (_activeAdId != adId) return;
    final index = _ads.indexWhere((ad) => ad.ad_identifer == adId);
    _lastAdFinishedAt = DateTime.now();
    is_showAd = false;
    _activeAdId = null;
    if (index == -1) {
      _releaseAdBackgroundMusic();
      return;
    }
    final ad = _ads[index];
    final outcome = ad.type != 'reward' || _rewardEarned
        ? PCAdOutcome.success
        : PCAdOutcome.cancelled;
    ad.status = 0;
    reportEvent('nkmdl_ad_imp_close', {
      'ad_pos_id': quizAdPlaceID ?? 'none',
      'ad_source_client': _eventSource(ad.source),
      'ad_format': ad.getTypeToServer(),
      'ad_code_id': adId,
    });
    _retireClosedAd(ad);
    _requestAd(recheckCached: true);
    await _finishAdCallback(outcome);
  }

  Future<void> _adDidDisplayedError(String adID, String errorString) async {
    if (_activeAdId != adID) return;
    if (_rewardEarned) {
      // 已收到本次真实激励成功后，重复或迟到的失败不能撤销资格；等待真实关闭。
      asLog.debug('[ad-show] ignored_failure_after_reward id=$adID');
      return;
    }
    _lastAdFinishedAt = DateTime.now();
    is_showAd = false;
    _activeAdId = null;

    int index = _ads.indexWhere((test) => test.ad_identifer == adID);

    if (index == -1) {
      _releaseAdBackgroundMusic();
      asLog.error(
        "$runtimeType ad did display error but cant find in ads data from id = $adID",
      );
      return;
    }
    final ad = _ads[index];
    ad.status = 0;
    asLog.error(
      "$runtimeType ad did display error [${ad.source}] type = ${ad.type} id = ${ad.ad_identifer}",
    );
    reportEvent('nkmdl_ad_impression_fail', {
      "ad_pos_id": quizAdPlaceID ?? "",
      "reason": 'impfail',
      "error_reason": errorString,
    });

    _retireClosedAd(ad);
    _requestAd(recheckCached: true);
    await _finishAdCallback(PCAdOutcome.failed);
  }

  bool findTag(List<PCAdModellist> data, String adID) {
    bool finded = false;
    for (int i = 0; i < data.length; i++) {
      if (data[i].byfxjhld == adID) {
        finded = true;
        break;
      }
    }
    return finded;
  }

  void _releaseAdBackgroundMusic() {
    final release = _releaseAdBgm;
    _releaseAdBgm = null;
    release?.call();
  }

  void resetHandler() {
    _showCommandToken = null;
    _onAdOutcome = null;
    if (onAdClosed != null) {
      onAdClosed = null;
    }
    if (quizAdPlaceID != null) {
      quizAdPlaceID = null;
    }
    _rewardEarned = false;
    _releaseAdBackgroundMusic();
  }

  Future<void> _finishAdCallback(PCAdOutcome outcome) async {
    // 业务回调可能立即请求下一条广告，先释放本次owner，不能再清掉新请求的回调。
    final callback = onAdClosed;
    final outcomeCallback = _onAdOutcome;
    resetHandler();
    await Future.wait([
      _notifyAdCallback(outcomeCallback, outcome),
      _notifyAdCallback(callback, outcome.isSuccess),
    ]);
  }

  Future<void> _notifyAdCallback(Function? callback, Object value) async {
    try {
      final callbackResult = callback?.call(value);
      if (callbackResult is Future) await callbackResult;
    } catch (error) {
      // 业务回调异常不等于广告失败，不能重发失败结果或清掉新广告的owner。
      asLog.error('[ad-show] business_callback_error ${error.runtimeType}');
    }
  }

  bool someAdIsShowing() {
    return _ads.any((e) => e.status == 2);
  }
}

class NetworkUtils {
  static Future<bool> isConnected() async {
    final connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      return true; // 有移动数据或Wi-Fi连接
    }

    return false; // 无网络连接
  }

  static Stream<ConnectivityResult> getNetworkChanges() {
    return Connectivity().onConnectivityChanged;
  }
}
