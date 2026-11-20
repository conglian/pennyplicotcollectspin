import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 首页排行榜用户；头像与昵称、收益、广告次数一起缓存到当天榜单。
class PCUserData {
  final int id;
  final String username;
  final double totalEarning;
  final int adsWatched;
  final int avatarIndex;

  const PCUserData({
    required this.id,
    required this.username,
    required this.totalEarning,
    required this.adsWatched,
    this.avatarIndex = 0,
  });

  String get avatarName =>
      'pc_rank_avatar_${(avatarIndex % PCUserDataManager.avatarCount + 1).toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'totalEarning': totalEarning,
    'adsWatched': adsWatched,
    'avatarIndex': avatarIndex,
  };

  factory PCUserData.fromJson(Map<String, dynamic> json) {
    final id = int.parse(json['id'].toString());
    final username = json['username'] as String;
    final earning = double.parse(json['totalEarning'].toString());
    final ads = int.parse(json['adsWatched'].toString());
    if (username.trim().isEmpty ||
        !earning.isFinite ||
        earning < 0 ||
        ads < 0) {
      throw const FormatException('排行榜用户数据无效');
    }
    // 兼容旧版缓存：当天不换人，按原用户 ID 稳定补齐头像。
    final avatar = int.tryParse(json['avatarIndex'].toString()) ?? id;
    return PCUserData(
      id: id,
      username: username,
      totalEarning: earning,
      adsWatched: ads,
      avatarIndex: avatar % PCUserDataManager.avatarCount,
    );
  }
}

/// 本地每日榜单：固定 56 人，按设备本地日期在零点更新。
class PCUserDataManager {
  static const int userCount = 56;
  static const int avatarCount = 54;
  static const String _lastUpdateKey = 'lastUpdate';
  static const String _dataKey = 'PCUserData';
  static const String _snapshotKey = 'pc_daily_ranking_v2';
  static final Random _random = Random();
  static Future<List<PCUserData>>? _loading;

  /// 使用日历的下一天，兼容本地夏令时，不能简单加 24 小时。
  static DateTime nextRefreshAt(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1);

  static String _day(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  /// 保留原有收益和广告次数范围，刷新时更换用户、头像和数据。
  static List<PCUserData> generatePCUserData({
    List<PCUserData> previous = const [],
  }) {
    final earnings = <double>[];
    final ads = <int>[];
    for (var i = 0; i < userCount; i++) {
      earnings.add(
        i < 3 ? 100 + _random.nextDouble() * 100 : _random.nextDouble() * 100,
      );
      ads.add(i < 3 ? 100 + _random.nextInt(100) : _random.nextInt(100));
    }
    earnings.sort((a, b) => b.compareTo(a));
    ads.sort((a, b) => b.compareTo(a));
    final avatars = List.generate(avatarCount, (i) => i)..shuffle(_random);
    final usedIds = previous.map((user) => user.id).toSet();
    const regions = ['Texas', 'Brazil'];

    return List.generate(userCount, (i) {
      late int id;
      do {
        id = 1000 + _random.nextInt(9000);
      } while (!usedIds.add(id));
      final username = 'User $id (${regions[_random.nextInt(regions.length)]})';
      var avatar = avatars[i % avatars.length];
      if (i < previous.length && avatar == previous[i].avatarIndex) {
        avatar = (avatar + 1) % avatarCount;
      }
      return PCUserData(
        id: id,
        username: username,
        totalEarning: double.parse(earnings[i].toStringAsFixed(2)),
        adsWatched: ads[i],
        avatarIndex: avatar,
      );
    });
  }

  /// 日期和榜单存在同一份快照中，避免写入中断造成日期与数据错配。
  static Future<void> savePCUserData(
    List<PCUserData> data, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapshotKey,
      jsonEncode({
        'date': _day(now ?? DateTime.now()),
        'users': data.map((user) => user.toJson()).toList(),
      }),
    );
  }

  static List<PCUserData> _users(dynamic rows) {
    if (rows is! List) return const [];
    try {
      final users = rows
          .map(
            (row) => PCUserData.fromJson(
              Map<String, dynamic>.from(
                row is String ? jsonDecode(row) : row as Map,
              ),
            ),
          )
          .toList();
      if (users.length != userCount) return const [];
      return List.unmodifiable(users);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static Map<String, dynamic>? _snapshot(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_snapshotKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// 加载缓存，兼容旧版本的 PCUserData / lastUpdate 存储。
  static Future<List<PCUserData>> loadPCUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _snapshot(prefs);
    return _users(snapshot?['users'] ?? prefs.getStringList(_dataKey));
  }

  /// 同日复用缓存；跨天冷启动、回前台或零点定时器均调用此入口。
  /// 并发读取串行检查，确保多个界面不会为同一天重复生成榜单。
  static Future<List<PCUserData>> getPCUserData({DateTime? now}) async {
    final pending = _loading;
    if (pending != null) {
      await pending;
      return getPCUserData(now: now);
    }
    final request = _readOrRefresh(now ?? DateTime.now());
    _loading = request;
    try {
      return await request;
    } finally {
      _loading = null;
    }
  }

  static Future<List<PCUserData>> _readOrRefresh(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _snapshot(prefs);
    final cached = _users(snapshot?['users'] ?? prefs.getStringList(_dataKey));
    final oldDate = DateTime.tryParse(prefs.getString(_lastUpdateKey) ?? '');
    final cachedDay =
        snapshot?['date'] ?? (oldDate == null ? null : _day(oldDate.toLocal()));
    if (cachedDay == _day(now) && cached.isNotEmpty) {
      if (snapshot == null) await savePCUserData(cached, now: now);
      return cached;
    }
    final fresh = generatePCUserData(previous: cached);
    await savePCUserData(fresh, now: now);
    return List.unmodifiable(fresh);
  }
}
