import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'PCDialogCoordinator.dart';
import 'PCAnalytics.dart';
import 'PCForegroundAdController.dart';
import 'PCInterstitialAdService.dart';
import 'PCNewUserGuideController.dart';
import 'PCNoticeMessage.dart';
import 'PCPigUpgradeController.dart';
import 'PCProcessFlowController.dart';
import 'PCWithdrawalController.dart';
import 'pc_LocalProvider.dart';
import 'pc_ad_manger.dart';

/// 四路循环本地通知各自使用独立ID和通道。
class PCNotificationSchedule {
  const PCNotificationSchedule(
    this.id,
    this.channel,
    this.nameKey,
    this.minutes,
    this.payload, {
    this.media = false,
    this.kind = PCNoticeKind.goal,
  });
  final int id, minutes;
  final String channel, nameKey, payload;
  final bool media;
  final PCNoticeKind kind;
  PCNoticeMessage message(double balance, double target) =>
      PCNoticeMessage(kind: kind, balance: balance, target: target);
}

/// FCM使用两个独立展示槽；可覆盖topic，不在客户端保存服务端密钥。
class PCFcmNotificationSlot {
  const PCFcmNotificationSlot(this.slotKey, this.channel, this.name, this.kind);
  final String slotKey, channel, name;
  final PCNoticeKind kind;
}

/// 通知唯一入口：4路循环本地提醒、场景通知、1条前台服务及2个FCM槽。
/// 保留站内横幅和既有导航API；回前台插屏独立判定，不从通知计时器触发广告。
class PCNoticeHelp with WidgetsBindingObserver {
  PCNoticeHelp._({
    bool testing = false,
    bool Function()? isGuideComplete,
    Future<bool> Function()? permissionEnabled,
    double Function()? balance,
    double Function()? target,
    Map<String, String>? fcmTopics,
    this._startupPermissionTimeout = startupPermissionLimit,
  }) : _testing = testing,
       _guideComplete = isGuideComplete,
       _permission = permissionEnabled,
       _readBalance = balance,
       _readTarget = target,
       _topicOverrides = fcmTopics;
  factory PCNoticeHelp() => instance;
  static final instance = PCNoticeHelp._();
  @visibleForTesting
  PCNoticeHelp.testing({
    required bool Function() isGuideComplete,
    Future<bool> Function()? permissionEnabled,
    double Function()? balance,
    double Function()? target,
    Map<String, String>? fcmTopics,
    Duration startupPermissionTimeout = startupPermissionLimit,
  }) : this._(
         testing: true,
         isGuideComplete: isGuideComplete,
         permissionEnabled: permissionEnabled,
         balance: balance,
         target: target,
         fcmTopics: fcmTopics,
         startupPermissionTimeout: startupPermissionTimeout,
       );

  static const startupPermissionLimit = Duration(seconds: 8);
  static const foregroundServiceId = 1200;
  static const foregroundChannel = 'pigwalletForeground';
  static const defaultFcmTopics = {
    'fcm1': 'c177fcm_piggy',
    'fcm2': 'c177fcm_piggy_two',
  };
  static const schedules = [
    PCNotificationSchedule(5590, '177notice1', 'Piggy Reminder 1', 30, 'local'),
    PCNotificationSchedule(4562, '177notice2', 'Piggy Reminder 2', 39, 'local'),
    PCNotificationSchedule(7552, '177notice3', 'Piggy Reminder 3', 59, 'local'),
    PCNotificationSchedule(9475, '177notice4', 'Piggy Reminder 4', 79, 'local'),
  ];
  static const fcmChannels = [
    PCFcmNotificationSlot(
      'fcm1',
      'pc_fcm_withdraw_v1',
      'Piggy FCM Withdraw',
      PCNoticeKind.goal,
    ),
    PCFcmNotificationSlot(
      'fcm2',
      'pc_fcm_claim_v1',
      'Piggy FCM Claim',
      PCNoticeKind.goal,
    ),
  ];
  static const _topicsKey = 'pc_notification_fcm_topics_v1';
  static const _subscribedKey = 'pc_notification_fcm_subscribed_v1';
  static const _migrationKey = 'pc_notification_channels_migrated_v4';
  static const _sceneNotifications = <(String, String, String?)>[
    ('android.intent.action.USER_PRESENT', 'unlock', null),
    ('android.intent.action.SCREEN_ON', 'screen_on', null),
    ('android.intent.action.SCREEN_OFF', 'screen_off', null),
    ('android.intent.action.ACTION_POWER_CONNECTED', 'power_connected', null),
    (
      'android.intent.action.ACTION_POWER_DISCONNECTED',
      'power_disconnected',
      null,
    ),
    ('android.intent.action.CLOSE_SYSTEM_DIALOGS', 'background', null),
    ('android.intent.action.TIME_SET', 'system_time_changed', null),
    ('android.intent.action.TIMEZONE_CHANGED', 'system_timezone_changed', null),
    ('android.intent.action.DATE_CHANGED', 'system_date_changed', null),
    ('android.intent.action.PACKAGE_ADDED', 'package_added', 'package'),
    ('android.intent.action.PACKAGE_REMOVED', 'package_removed', 'package'),
    ('android.intent.action.PACKAGE_CHANGED', 'package_changed', 'package'),
    ('android.intent.action.PACKAGE_REPLACED', 'package_replaced', 'package'),
  ];
  static const _broadcastIds = [
    2829,
    2830,
    2831,
    2832,
    2833,
    2834,
    2835,
    2836,
    2837,
    2840,
    2841,
    2842,
    2843,
  ];
  static const _notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  final bool _testing;
  final bool Function()? _guideComplete;
  final Future<bool> Function()? _permission;
  final Duration _startupPermissionTimeout;
  final double Function()? _readBalance, _readTarget;
  Map<String, String>? _topicOverrides;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _android = AndroidFlutterLocalNotificationsPlugin();
  final banner = ValueNotifier<PCNoticeMessage?>(null);
  final navigationReady = ValueNotifier<bool>(false);

  /// 系统申请晚于启动等待返回时，通知召回宿主重新查询真实权限。
  final startupPermissionChanges = ValueNotifier<int>(0);
  final _timers = <Timer>[];
  Future<void>? _initializing;
  Future<void>? _startupPermission;
  VoidCallback? _releaseStartupPermission;
  bool _startupPermissionExpired = false;
  bool _startupSystemRequestPending = false;

  /// 真实系统申请尚未回调；有界启动等待结束并不表示原生授权窗口已结束。
  bool get isStartupPermissionRequestPending => _startupSystemRequestPending;
  Future<NotificationAppLaunchDetails?>? _launchDetails;
  bool didNotificationLaunchApp = false;
  bool _ready = false,
      _disposed = false,
      _foreground = true,
      _observing = false;
  bool _refreshing = false, _refreshAgain = false, _channelsCreated = false;
  bool _wasBackgrounded = false;
  bool? _foregroundServiceEnabled;
  String? _foregroundServiceAmount, _broadcastSignature;
  PCNoticeAction? _pendingAction;
  ValueChanged<PCNoticeAction>? _onAction;
  BuildContext? _navigationContext;
  PCForegroundAdController? _foregroundAds;
  bool get _isAndroid =>
      _testing || defaultTargetPlatform == TargetPlatform.android;
  bool get _supported =>
      _testing ||
      (!kIsWeb && (_isAndroid || defaultTargetPlatform == TargetPlatform.iOS));
  bool get _guideReady =>
      _guideComplete?.call() ??
      (PCNewUserGuideController.instance.isLoaded &&
          PCNewUserGuideController.instance.isComplete);
  bool get _canPresent => _foreground && _guideReady && _onAction != null;
  double get _balance =>
      _readBalance?.call() ?? PCLocalProvider.instance.pc_dollar_number;
  double get _target =>
      _readTarget?.call() ??
      PCNewUserGuideController.instance.config.withdrawalTarget;

  Future<NotificationAppLaunchDetails?> _readLaunchDetails() =>
      _launchDetails ??=
          (_isAndroid
                  ? _android.getNotificationAppLaunchDetails()
                  : _plugin.getNotificationAppLaunchDetails())
              .then((details) {
                didNotificationLaunchApp =
                    details?.didNotificationLaunchApp ?? false;
                return details;
              });

  /// 使用原生启动Intent判定来源，不能以延后导航的待处理action推断push。
  Future<String> launchSource() async {
    if (!_supported) return 'icon';
    try {
      await _readLaunchDetails();
    } catch (_) {
      return 'icon';
    }
    return didNotificationLaunchApp ? 'push' : 'icon';
  }

  Future<void> initialize() {
    if (_disposed || _ready) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  /// 每次冷启动读取通知权限；系统权限只在用户点击引导按钮后申请。
  Future<void> initializeForStartup() =>
      _startupPermission ??= _initializeForStartup();

  /// 兼容旧调用方；权限检查不再自动弹出系统授权框。
  Future<void> waitForStartupPermission() =>
      _startupPermission ?? Future<void>.value();

  Future<void> _initializeForStartup() async {
    if (_disposed || !_supported) return;
    final release = PCDialogCoordinator.instance.holdPresentation();
    _releaseStartupPermission = release;
    try {
      await _completeStartupPermission().timeout(
        _startupPermissionTimeout,
        onTimeout: () {
          // 超时仅放行页面，不伪造授权，不重发仍在途的系统请求。
          _startupPermissionExpired = true;
          debugPrint('Notification startup permission: timed out');
        },
      );
    } catch (error) {
      debugPrint('Notification startup permission: $error');
    } finally {
      _releaseStartupPermission = null;
      release();
    }
  }

  Future<void> _completeStartupPermission() async {
    try {
      await initialize();
      if (_disposed || !_ready || _startupPermissionExpired) return;
      await _permissionEnabled();
    } catch (error) {
      // 拒绝、缺少系统界面或插件异常不能阻断启动，后续召回仍可引导设置。
      debugPrint('Notification startup permission: $error');
    } finally {
      if (!_disposed) {
        startupPermissionChanges.value++;
        // 真实申请晚返回后依旧恢复计划；其等待不再持有全局弹窗锁。
        if (_ready) await refreshSchedules();
      }
    }
  }

  Future<void> _initialize() async {
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!_testing && !_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
      PCLocalProvider.instance.addListener(_dataChanged);
      PCNewUserGuideController.instance.addListener(_guideChanged);
      final ads = PCPigAds();
      _foregroundAds = PCForegroundAdController(
        adShowing: () => ads.isNativeAdShowing,
        adSessionVersion: () => ads.adSessionVersion,
        lastAdFinishedAt: () => ads.lastAdFinishedAt,
        requestInterstitial: PCInterstitialAdService.instance.request,
        canPresent: _canShowReturnAd,
        holdPresentation: PCDialogCoordinator.instance.holdPresentation,
      );
    }
    if (_supported) {
      try {
        if (_isAndroid) {
          final initialized = await _android.initialize(
            const AndroidInitializationSettings('pc_notification_small'),
            onDidReceiveNotificationResponse: (response) =>
                handlePayload(response.payload),
          );
          if (!initialized) {
            throw StateError('Android notifications initialization failed');
          }
          final launch = await _readLaunchDetails();
          if (launch?.didNotificationLaunchApp ?? false) {
            handlePayload(launch?.notificationResponse?.payload);
          }
        } else {
          await _plugin.initialize(
            const InitializationSettings(
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
                defaultPresentAlert: false,
                defaultPresentBanner: false,
                defaultPresentList: false,
                defaultPresentSound: false,
                defaultPresentBadge: false,
              ),
            ),
            onDidReceiveNotificationResponse: (response) =>
                handlePayload(response.payload),
          );
          final launch = await _readLaunchDetails();
          if (launch?.didNotificationLaunchApp ?? false) {
            handlePayload(launch?.notificationResponse?.payload);
          }
        }
        _ready = true;
      } catch (error) {
        debugPrint('Notification initialization: $error');
      }
    }
    if (_ready && _isAndroid) {
      unawaited(PCAnalytics.flushNotificationTriggers());
    }
    _resetForegroundTimers();
    if (_ready) await refreshSchedules();
  }

  /// 兼容更新文件入口；初始化本身不申请系统权限。
  Future<void> PC_initNotice(BuildContext context) => initialize();
  Future<void> PC_startForegroundService() => refreshSchedules();
  Future<void> PC_setNoticeStatus() async {
    await initialize();
    if (_isAndroid && _supported) {
      await _android.requestNotificationsPermission();
    }
    await refreshSchedules();
  }

  /// 权限引导按钮的用户手势入口。系统永久拒绝后返回 true 以打开设置页。
  Future<bool> requestPermissionFromGuide() async {
    if (!_supported) return false;
    if (_isAndroid) {
      _startupSystemRequestPending = true;
      bool granted = false;
      try {
        granted = await _android.requestNotificationsPermission() ?? false;
      } finally {
        _startupSystemRequestPending = false;
      }
      if (granted || await _permissionEnabled()) {
        if (!_disposed) await refreshSchedules();
        return false;
      }
      final canAskAgain = await _notificationChannel.invokeMethod<bool>(
        'shouldShowNotificationPermissionRationale',
      );
      return canAskAgain == false;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (!_disposed) await refreshSchedules();
    return false;
  }

  void attachNavigation(
    ValueChanged<PCNoticeAction> callback, {
    BuildContext? context,
  }) {
    _onAction = callback;
    _navigationContext = context;
    navigationReady.value = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _deliverPendingAction(),
    );
    _resetForegroundTimers();
  }

  void detachNavigation(ValueChanged<PCNoticeAction> callback) {
    if (_onAction != callback) return;
    _onAction = null;
    _navigationContext = null;
    navigationReady.value = false;
    dismiss();
    _resetForegroundTimers();
  }

  void handlePayload(String? payload) {
    final action = PCNoticeMessage.parseAction(payload);
    if (action == null) return;
    PCAnalytics.event('inform_c', {
      'type': PCNoticeMessage.analyticsType(payload),
    });
    _pendingAction = action;
    _deliverPendingAction();
  }

  void _deliverPendingAction() {
    if (!_canPresent || _pendingAction == null || _disposed) return;
    final action = _pendingAction!;
    _pendingAction = null;
    _onAction?.call(action);
  }

  void open(PCNoticeMessage message) => openAction(message.action);
  void openAction(PCNoticeAction action) {
    dismiss();
    _pendingAction = action;
    _deliverPendingAction();
  }

  void dismiss() => banner.value = null;
  bool _canShowReturnAd() {
    final context = _navigationContext;
    return _isAndroid &&
        _canPresent &&
        _pendingAction == null &&
        (context == null ||
            (context.mounted && ModalRoute.of(context)?.isCurrent == true)) &&
        !PCDialogCoordinator.instance.isBusy &&
        !PCWithdrawalController.instance.hasPending &&
        !PCProcessFlowController.instance.hasPending &&
        !PCPigUpgradeController.instance.isBlocked &&
        !PCPigUpgradeController.instance.isPresenting;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _wasBackgrounded = false;
    } else if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        !_wasBackgrounded) {
      _wasBackgrounded = true;
      unawaited(_showSceneNotification('background'));
    }
    if (!_foreground) dismiss();
    _resetForegroundTimers();
    // 通知导航尚未消费时先排除回流广告，避免点击通知后同时打开插屏。
    unawaited(
      _foregroundAds?.didChangeAppLifecycleState(state) ??
          Future<bool>.value(false),
    );
    if (_foreground) {
      if (_isAndroid) unawaited(PCAnalytics.flushNotificationTriggers());
      _deliverPendingAction();
      unawaited(refreshSchedules());
    }
  }

  void _guideChanged() {
    _resetForegroundTimers();
    if (!_guideReady) dismiss();
    _deliverPendingAction();
    unawaited(refreshSchedules());
  }

  void _dataChanged() {
    // 余额变化仅同步已有通知和前台服务，不再触发提现就绪横幅。
    final current = banner.value;
    if (current != null) {
      banner.value = PCNoticeMessage(
        kind: current.kind,
        balance: _balance,
        target: _target,
      );
    }
    unawaited(refreshSchedules());
  }

  void _resetForegroundTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    if (_testing || !_canPresent || _disposed) return;
    for (final job in PCNoticeJob.all) {
      _timers.add(
        Timer(Duration(minutes: job.minutes), () {
          if (_canPresent && !_disposed) {
            banner.value = job.message(_balance, _target);
          }
        }),
      );
    }
  }

  Future<bool> _permissionEnabled() async {
    if (_permission != null) return _permission();
    if (_isAndroid) return await _android.areNotificationsEnabled() ?? false;
    final permission = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    return (permission?.isEnabled ?? false) ||
        (permission?.isProvisionalEnabled ?? false);
  }

  BeautyStyleInformation _beauty(PCNoticeMessage message) =>
      BeautyStyleInformation(
        template: message.kind.name,
        title: message.title,
        body: message.body,
        amount: message.amount,
        button: message.button,
        appIcon: 'pc_notice_account_icon',
      );
  AndroidNotificationDetails _details(
    String channel,
    String name,
    PCNoticeMessage message,
  ) => AndroidNotificationDetails(
    channel,
    name,
    icon: 'pc_notification_small',
    importance: Importance.high,
    priority: Priority.high,
    autoCancel: true,
    onlyAlertOnce: true,
    styleInformation: _beauty(message),
  );
  Future<void> _createChannels() async {
    if (_channelsCreated) return;
    for (final schedule in schedules) {
      await _android.createNotificationChannel(
        AndroidNotificationChannel(
          schedule.channel,
          schedule.nameKey,
          importance: Importance.high,
        ),
      );
    }
    await _android.createNotificationChannel(
      const AndroidNotificationChannel(
        foregroundChannel,
        'Piggy Bank Balance',
        importance: Importance.low,
      ),
    );
    for (final slot in fcmChannels) {
      await _android.createNotificationChannel(
        AndroidNotificationChannel(
          slot.channel,
          slot.name,
          importance: Importance.high,
        ),
      );
    }
    _channelsCreated = true;
  }

  List<Map<String, String>> _notificationCopies() => [
    for (var index = 0; index < 4; index++)
      () {
        final message = PCStepMotivationManager.PC_getMotivation(
          index,
          balance: _balance,
        );
        return {'title': message.title, 'body': message.body};
      }(),
  ];

  Future<void> _configureLocalNotificationCopies() async {
    await _notificationChannel.invokeMethod<void>(
      'configureLocalNotificationCopies',
      {'copies': _notificationCopies()},
    );
  }

  Future<void> _migrate(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationKey) == true) return;
    await _android.stopForegroundService();
    for (final id in [
      8852,
      1268,
      6722,
      1195,
      17759,
      4738,
      2788,
      2934,
      1320,
      1029,
    ]) {
      await _android.cancel(id);
    }
    for (final schedule in schedules) {
      await _android.cancel(schedule.id);
    }
    for (final channel in [
      'pc_balance_service_v1',
      'pc_piggy_reminders_v1',
      '177PigWalletSPines',
      '177PigWalletSPinescreen',
    ]) {
      await _android.deleteNotificationChannel(channel);
    }
    await prefs.setBool(_migrationKey, true);
  }

  Future<void> _refreshForegroundService(bool enabled) async {
    if (!enabled) {
      if (_foregroundServiceEnabled != false) {
        await _android.stopForegroundService();
      }
      _foregroundServiceEnabled = false;
      _foregroundServiceAmount = null;
      return;
    }
    if (!_foreground) return;
    final message = PCNoticeMessage(
      kind: PCNoticeKind.account,
      balance: _balance,
      target: _target,
    );
    if (_foregroundServiceEnabled == true &&
        _foregroundServiceAmount == message.amount) {
      return;
    }
    await _android.startForegroundService(
      foregroundServiceId,
      message.title,
      message.body,
      notificationDetails: AndroidNotificationDetails(
        foregroundChannel,
        'Piggy Bank Balance',
        icon: 'pc_notification_small',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.service,
        styleInformation: _beauty(message),
      ),
      payload: 'foreground',
    );
    _foregroundServiceEnabled = true;
    _foregroundServiceAmount = message.amount;
  }

  Map<String, dynamic> _readMap(SharedPreferences prefs, String key) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(prefs.getString(key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  /// 四路本地提醒分别在30/39/59/79分钟后开始循环，余额更新不重置计时。
  Future<void> _scheduleIntervals() async {
    final pending = (await _android.pendingNotificationRequests())
        .map((item) => item.id)
        .toSet();
    for (final schedule in schedules) {
      if (pending.contains(schedule.id)) continue;
      final message = PCNoticeMessage(
        kind: schedule.kind,
        balance: _balance,
        target: _target,
        titleOverride: PCStepMotivationManager.PC_getMotivation(
          0,
          balance: _balance,
        ).title,
        bodyOverride: PCStepMotivationManager.PC_getMotivation(
          0,
          balance: _balance,
        ).body,
      );
      try {
        await _android.periodicallyShowWithDuration(
          schedule.id,
          message.title,
          message.body,
          Duration(minutes: schedule.minutes),
          notificationDetails: _details(
            schedule.channel,
            schedule.nameKey,
            message,
          ),
          payload: schedule.payload,
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (error) {
        debugPrint('Notification ${schedule.id}: $error');
      }
    }
  }

  Future<void> configureFcmTopics({
    String? withdrawTopic,
    String? earnTopic,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final topics = {
      ...defaultFcmTopics,
      ..._readMap(prefs, _topicsKey),
      ...?_topicOverrides,
    };
    if (withdrawTopic != null) topics['fcm1'] = withdrawTopic.trim();
    if (earnTopic != null) topics['fcm2'] = earnTopic.trim();
    _topicOverrides = topics.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    await prefs.setString(_topicsKey, jsonEncode(_topicOverrides));
    await initialize();
    await refreshSchedules();
  }

  Future<void> _refreshFcm(SharedPreferences prefs, bool enabled) async {
    final topics = {
      ...defaultFcmTopics,
      ..._readMap(prefs, _topicsKey),
      ...?_topicOverrides,
    };
    final previous = _readMap(prefs, _subscribedKey);
    for (final slot in fcmChannels) {
      final raw = topics[slot.slotKey]?.toString().trim() ?? '';
      final topic = raw.replaceFirst(RegExp(r'^/topics/'), '');
      final desired = enabled && RegExp(r'^[a-zA-Z0-9\-_.~%]+$').hasMatch(topic)
          ? topic
          : '';
      final old = previous[slot.slotKey]?.toString() ?? '';
      try {
        if (old.isNotEmpty && old != desired) {
          if (await _android
                  .unsubscribeFromTopic(old)
                  .timeout(const Duration(seconds: 3)) !=
              true) {
            continue;
          }
          previous.remove(slot.slotKey);
          previous.remove('${slot.slotKey}Signature');
        }
        if (desired.isEmpty || (!_testing && Firebase.apps.isEmpty)) continue;
        final message = PCNoticeMessage(
          kind: slot.kind,
          balance: _balance,
          target: _target,
        );
        final signature = '$desired:${message.kind.name}:${message.amount}';
        if (previous['${slot.slotKey}Signature'] == signature &&
            old == desired) {
          continue;
        }
        if (await _android
                .subscribeToTopic(
                  desired,
                  _details(slot.channel, slot.name, message),
                  payload: slot.slotKey,
                )
                .timeout(const Duration(seconds: 3)) ==
            true) {
          previous[slot.slotKey] = desired;
          previous['${slot.slotKey}Signature'] = signature;
        }
      } catch (error) {
        debugPrint('FCM ${slot.slotKey}: $error');
      }
    }
    await prefs.setString(_subscribedKey, jsonEncode(previous));
  }

  Future<void> _refreshBroadcasts() async {
    final signature = '$_balance:$_target';
    if (_broadcastSignature == signature) return;
    for (var i = 0; i < _sceneNotifications.length; i++) {
      final (action, type, dataScheme) = _sceneNotifications[i];
      final copy = PCStepMotivationManager.PC_getMotivation(
        i % PCStepMotivationManager.templateCount,
        balance: _balance,
      );
      final message = PCNoticeMessage(
        kind: PCNoticeKind.account,
        balance: _balance,
        target: _target,
        titleOverride: copy.title,
        bodyOverride: copy.body,
      );
      await _android.showBroadcastNotification(
        _broadcastIds[i],
        message.title,
        message.body,
        const Duration(seconds: 12),
        action,
        _details('177notice1', 'Piggy Scene Reminder', message),
        message.payloadFor(type: type),
        dataScheme: dataScheme,
      );
    }
    _broadcastSignature = signature;
  }

  Future<void> _showSceneNotification(String type) async {
    if (_disposed || !_ready || !_isAndroid || !_guideReady) return;
    try {
      if (!await _permissionEnabled()) return;
      await _createChannels();
      final copy = PCStepMotivationManager.PC_getRandomMotivation(
        balance: _balance,
      );
      final message = PCNoticeMessage(
        kind: PCNoticeKind.account,
        balance: _balance,
        target: _target,
        titleOverride: copy.title,
        bodyOverride: copy.body,
      );
      await _plugin.show(
        2829,
        message.title,
        message.body,
        NotificationDetails(
          android: _details('177notice1', 'Piggy Scene Reminder', message),
        ),
        payload: message.payloadFor(type: type),
      );
    } catch (error) {
      debugPrint('Scene notification $type: $error');
    }
  }

  Future<void> refreshSchedules() async {
    if (_disposed || !_isAndroid) return;
    if (!_ready) {
      await initialize();
      return;
    }
    if (!_testing && !PCNewUserGuideController.instance.isLoaded) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final prefs = await SharedPreferences.getInstance();
        final enabled = _guideReady && await _permissionEnabled();
        await _migrate(prefs);
        if (!enabled) {
          await _refreshForegroundService(false);
          for (final id in [...schedules.map((s) => s.id), ..._broadcastIds]) {
            await _android.cancel(id);
          }
          await _refreshFcm(prefs, false);
          _broadcastSignature = null;
          continue;
        }
        await _createChannels();
        await _configureLocalNotificationCopies();
        await _refreshForegroundService(true);
        await _scheduleIntervals();
        await _refreshFcm(prefs, true);
        await _refreshBroadcasts();
      } while (_refreshAgain && !_disposed);
    } catch (error) {
      debugPrint('Notification refresh: $error');
    } finally {
      _refreshing = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _releaseStartupPermission?.call();
    _releaseStartupPermission = null;
    for (final timer in _timers) {
      timer.cancel();
    }
    _foregroundAds?.dispose();
    if (!_testing) {
      WidgetsBinding.instance.removeObserver(this);
      PCLocalProvider.instance.removeListener(_dataChanged);
      PCNewUserGuideController.instance.removeListener(_guideChanged);
    }
    banner.dispose();
    navigationReady.dispose();
    startupPermissionChanges.dispose();
  }
}

/// 后续替换文案的兼容入口，当前沿用项目已确认的英文余额和提现提示。
class PCStepMotivation {
  const PCStepMotivation({required this.title, required this.body});
  final String title, body;
}

class PCStepMotivationManager {
  static const _templates = [
    ('Piggy Almost Full!', 'You’ve saved {amount}—cash out before it spills!'),
    ('Cash-Out Time 🎉', 'Spin & play—your balance is ready to grab!'),
    (
      'Your Payout Is Ready! 💰',
      'Piggy bank is full and ready to pop—open the app to collect your cash.',
    ),
    (
      'Advertiser Just Paid You! 🎁',
      'Tap to feed your piggy & claim today’s payout.',
    ),
    ('Balance Near Max 💵', 'Almost full—withdraw before it’s gone!'),
  ];
  static const templateCount = 5;
  static final _random = Random();
  static int randomIndex() => _random.nextInt(templateCount);
  static PCStepMotivation PC_getRandomMotivation({double? balance}) =>
      PC_getMotivation(randomIndex(), balance: balance);
  static PCStepMotivation PC_getMotivation(int index, {double? balance}) {
    final (title, body) = _templates[index.abs() % templateCount];
    final value = balance ?? PCLocalProvider.instance.pc_dollar_number;
    final amount =
        '\$${(value.isFinite ? max(0.0, value) : 0.0).toStringAsFixed(2)}';
    return PCStepMotivation(
      title: title,
      body: body.replaceAll('{amount}', amount),
    );
  }
}
