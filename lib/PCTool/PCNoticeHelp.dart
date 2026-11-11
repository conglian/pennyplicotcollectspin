import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
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

/// 媒体/固定通知各自独立的ID、通道及单次触发时间。
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

/// 通知唯一入口：4媒体、1前台服务、4固定单次提醒，以及2个FCM槽。
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
    PCNotificationSchedule(
      5590,
      '177notice1',
      'Piggy Reminder 1',
      26,
      'noti1',
      kind: PCNoticeKind.account,
    ),
    PCNotificationSchedule(4562, '177notice2', 'Piggy Reminder 2', 62, 'noti2'),
    PCNotificationSchedule(
      7552,
      '177notice3',
      'Piggy Reminder 3',
      117,
      'noti3',
      kind: PCNoticeKind.goal,
    ),
    PCNotificationSchedule(
      9475,
      '177notice4',
      'Piggy Reminder 4',
      162,
      'noti4',
    ),
    PCNotificationSchedule(
      4738,
      '177notice0',
      'Piggy Media 1',
      29,
      'Media1',
      media: true,
      kind: PCNoticeKind.account,
    ),
    PCNotificationSchedule(
      2788,
      '177notice21',
      'Piggy Media 2',
      59,
      'Media2',
      media: true,
    ),
    PCNotificationSchedule(
      2934,
      '177notice31',
      'Piggy Media 3',
      119,
      'Media3',
      media: true,
      kind: PCNoticeKind.goal,
    ),
    PCNotificationSchedule(
      1320,
      '177notice41',
      'Piggy Media 4',
      159,
      'Media4',
      media: true,
    ),
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
  static const _planKey = 'pc_notification_plan_v3';
  static const _topicsKey = 'pc_notification_fcm_topics_v1';
  static const _subscribedKey = 'pc_notification_fcm_subscribed_v1';
  static const _migrationKey = 'pc_notification_channels_migrated_v3';
  static const _broadcastIds = [2829, 1029];

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

  /// 每次冷启动只申请一次系统通知权限；普通刷新或回前台不会再次申请。
  Future<void> initializeForStartup() =>
      _startupPermission ??= _initializeForStartup();

  /// 召回弹窗只等待已经开始的启动申请，不能因此触发新的系统授权请求。
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
      final enabled = await _permissionEnabled();
      if (_disposed || _startupPermissionExpired) return;
      if (!enabled) {
        _startupSystemRequestPending = true;
        try {
          if (_isAndroid) {
            await _android.requestNotificationsPermission();
          } else {
            await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true);
          }
        } finally {
          _startupSystemRequestPending = false;
        }
      }
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

  /// 兼容更新文件入口；初始化不主动申请权限，沿用现有通知引导的用户操作。
  Future<void> PC_initNotice(BuildContext context) => initialize();
  Future<void> PC_startForegroundService() => refreshSchedules();
  Future<void> PC_setNoticeStatus() async {
    await initialize();
    if (_isAndroid && _supported) {
      await _android.requestNotificationsPermission();
    }
    await refreshSchedules();
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
    final lower = (payload ?? '').toLowerCase();
    PCAnalytics.event('inform_c', {
      'type': lower.contains('fcm')
          ? 'fcm'
          : lower.contains('unlock') || lower.contains('screen')
          ? 'unlock'
          : 'local',
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
    PCNoticeMessage message, {
    bool media = false,
  }) => AndroidNotificationDetails(
    channel,
    name,
    icon: 'pc_notification_small',
    importance: Importance.high,
    priority: Priority.high,
    autoCancel: true,
    onlyAlertOnce: true,
    styleInformation: media
        ? MediaStyleInformation(image: 'pc_notice_account_icon')
        : _beauty(message),
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

  Future<void> _migrate(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationKey) == true) return;
    await _android.stopForegroundService();
    for (final id in [8852, 1268, 6722, 1195, 17759]) {
      await _android.cancel(id);
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

  /// 单次计划保留绝对时间；刷新余额不推迟，已发项不按间隔重排。
  Future<void> _scheduleOnce(SharedPreferences prefs) async {
    final revision = schedules.map((s) => '${s.id}:${s.minutes}').join(',');
    var plan = _readMap(prefs, _planKey);
    if (plan['revision'] != revision || plan['anchor'] is! int) {
      plan = {
        'revision': revision,
        'anchor': DateTime.now().millisecondsSinceEpoch,
        'issued': <int>[],
        'signatures': <String, String>{},
      };
      await prefs.setString(_planKey, jsonEncode(plan));
    }
    final anchor = DateTime.fromMillisecondsSinceEpoch(
      plan['anchor'] as int,
      isUtc: true,
    );
    final issued = (plan['issued'] as List? ?? []).whereType<int>().toSet();
    final suspended = (plan['suspended'] as List? ?? [])
        .whereType<int>()
        .toSet();
    final signatures = Map<String, dynamic>.from(
      plan['signatures'] as Map? ?? {},
    );
    final copyIndices = Map<String, dynamic>.from(
      plan['copyIndices'] as Map? ?? {},
    );
    final pending = (await _android.pendingNotificationRequests())
        .map((p) => p.id)
        .toSet();
    for (final schedule in schedules) {
      final due = anchor.add(Duration(minutes: schedule.minutes));
      final key = '${schedule.id}';
      var copyIndex = copyIndices[key];
      if (copyIndex is! int ||
          copyIndex < 0 ||
          copyIndex >= PCStepMotivationManager.templateCount) {
        copyIndex = PCStepMotivationManager.randomIndex();
        copyIndices[key] = copyIndex;
      }
      final copy = PCStepMotivationManager.PC_getMotivation(
        copyIndex,
        balance: _balance,
      );
      final original = schedule.message(_balance, _target);
      final message = PCNoticeMessage(
        kind: original.kind == PCNoticeKind.account
            ? PCNoticeKind.goal
            : original.kind,
        balance: _balance,
        target: _target,
        titleOverride: copy.title,
        bodyOverride: copy.body,
      );
      final signature =
          '${message.kind.name}:${message.amount}:${message.title}:${message.body}';
      if ((issued.contains(schedule.id) &&
              !pending.contains(schedule.id) &&
              !suspended.contains(schedule.id)) ||
          !due.isAfter(DateTime.now())) {
        suspended.remove(schedule.id);
        continue;
      }
      if (pending.contains(schedule.id) &&
          signatures['${schedule.id}'] == signature) {
        continue;
      }
      try {
        await _android.zonedSchedule(
          schedule.id,
          message.title,
          message.body,
          tz.TZDateTime.from(due, tz.UTC),
          _details(
            schedule.channel,
            schedule.nameKey,
            message,
            media: schedule.media,
          ),
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: schedule.payload,
        );
        issued.add(schedule.id);
        suspended.remove(schedule.id);
        signatures['${schedule.id}'] = signature;
        plan = {
          ...plan,
          'issued': issued.toList(),
          'signatures': signatures,
          'suspended': suspended.toList(),
          'copyIndices': copyIndices,
        };
        await prefs.setString(_planKey, jsonEncode(plan));
      } catch (error) {
        debugPrint('Notification ${schedule.id}: $error');
      }
    }
    await prefs.setString(
      _planKey,
      jsonEncode({
        ...plan,
        'suspended': suspended.toList(),
        'copyIndices': copyIndices,
      }),
    );
  }

  Future<void> _suspendPlan(SharedPreferences prefs) async {
    final plan = _readMap(prefs, _planKey);
    if (plan.isEmpty) return;
    final pending = (await _android.pendingNotificationRequests())
        .map((p) => p.id)
        .toSet();
    final suspended = (plan['suspended'] as List? ?? [])
        .whereType<int>()
        .toSet();
    suspended.addAll(
      schedules.where((s) => pending.contains(s.id)).map((s) => s.id),
    );
    await prefs.setString(
      _planKey,
      jsonEncode({...plan, 'suspended': suspended.toList()}),
    );
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
    for (var i = 0; i < _broadcastIds.length; i++) {
      final schedule = schedules[i];
      final copy = PCStepMotivationManager.PC_getRandomMotivation(
        balance: _balance,
      );
      final message = PCNoticeMessage(
        kind: PCNoticeKind.goal,
        balance: _balance,
        target: _target,
        titleOverride: copy.title,
        bodyOverride: copy.body,
      );
      await _android.showBroadcastNotification(
        _broadcastIds[i],
        message.title,
        message.body,
        const Duration(seconds: 30),
        i == 0
            ? 'android.intent.action.SCREEN_OFF'
            : 'android.intent.action.SCREEN_ON',
        _details(schedule.channel, schedule.nameKey, message),
        i == 0 ? 'screenoff' : 'screenon',
        randomMessages: [
          for (
            var index = 0;
            index < PCStepMotivationManager.templateCount;
            index++
          )
            {
              'title': PCStepMotivationManager.PC_getMotivation(
                index,
                balance: _balance,
              ).title,
              'body': PCStepMotivationManager.PC_getMotivation(
                index,
                balance: _balance,
              ).body,
            },
        ],
      );
    }
    _broadcastSignature = signature;
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
          await _suspendPlan(prefs);
          await _refreshForegroundService(false);
          for (final id in [...schedules.map((s) => s.id), ..._broadcastIds]) {
            await _android.cancel(id);
          }
          await _refreshFcm(prefs, false);
          _broadcastSignature = null;
          continue;
        }
        await _createChannels();
        await _refreshForegroundService(true);
        await _scheduleOnce(prefs);
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
