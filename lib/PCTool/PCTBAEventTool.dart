import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tba_info/flutter_tba_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'PCLogger.dart';

const _installLogIdKey = 'pc_tba_install_log_id_v1';

Future<void> pc_session_fire() => _pcSafeReport(() async {
  asLog.info('[session] collecting TBA metadata');
  var baseBody = await PCRequestHelpers().baseBody();
  baseBody["fritz"] = 'lemon';
  await PCRequestHelpers().post(baseBody, 2);
}, operation: 'session');

Future<void> pc_ad_fire(Map<String, dynamic> body) => _pcSafeReport(() async {
  var baseBody = await PCRequestHelpers().baseBody();
  Map<String, dynamic> goat = {};
  for (String key in body.keys) {
    goat[key] = body[key];
  }
  baseBody["goat"] = goat;
  await PCRequestHelpers().post(baseBody, 3);
});

Future<void> pc_event_fire(String name, Map<String, dynamic> body) =>
    _pcSafeReport(() async {
      var baseBodys = await PCRequestHelpers().baseBody();
      baseBodys["fritz"] = name;
      for (String key in body.keys) {
        baseBodys['sob<${key}'] = body[key];
      }
      await PCRequestHelpers().post(baseBodys, 0);
    });

Future<bool> pc_install_fire() async {
  final prefs = await SharedPreferences.getInstance();
  var logId = prefs.getString(_installLogIdKey);
  if (logId == null) {
    logId = await FlutterTbaInfo.instance.getLogId();
    // 同一笔安装跨冷启动重试时沿用协议中的日志 ID。
    if (!await prefs.setString(_installLogIdKey, logId)) return false;
  }

  final request = PCRequestHelpers();
  final baseBody = await request.baseBody(logId: logId);
  final map = await FlutterTbaInfo.instance.getReferrerMap();
  baseBody["vikram"] = {
    "alumni": map['build'],
    'lumen': map['referrer_url'],
    "chili": map['install_version'],
    "sockeye": map['user_agent'],
    "sharpe": 'trail',
    "fop": map['referrer_click_timestamp_seconds'],
    "currant": map['install_begin_timestamp_seconds'],
    "hanukkah": map['referrer_click_timestamp_server_seconds'],
    "caution": map['install_begin_timestamp_server_seconds'],
    "pecos": map['install_first_seconds'],
    "upright": map['last_update_seconds'],
  };
  return await request.post(baseBody, 1) != null;
}

Future<void> _pcSafeReport(
  Future<void> Function() report, {
  String? operation,
}) async {
  try {
    await report();
  } catch (error) {
    if (operation != null) {
      asLog.error('[TBA][$operation] report failed (${error.runtimeType})');
    }
    // 设备信息插件或上报不可用时不把异常抛回UI业务。
  }
}

class PCRequestHelpers {
  static final PCRequestHelpers _instance = PCRequestHelpers._internal();

  factory PCRequestHelpers() {
    return _instance;
  }

  PCRequestHelpers._internal();

  static String cloak_Url =
      "https://sang.moolashjarpiggypro.com/rowena/trigram";

  static String tba_event_Url_test =
      "https://test-rich.moolashjarpiggypro.com/ferric/cytosine/foamy";

  static String tba_event_Url_release =
      "https://rich.moolashjarpiggypro.com/torr/whim/wan";

  static String tba_event_Url = kDebugMode
      ? tba_event_Url_test
      : tba_event_Url_release;

  final Map<String, String> normalHeader = {'Content-Type': 'application/json'};

  Map<String, String> eventHeader = {'Content-Type': 'application/json'};

  Future<dynamic> getCloak() async {
    var url = Uri.parse(
      "${cloak_Url}?monarchy=${await FlutterTbaInfo.instance.getBundleId()}&indwell=durance&pasteup=${await FlutterTbaInfo.instance.getAppVersion()}&sanford=${DateTime.now().millisecondsSinceEpoch}",
    );
    asLog.info("pennypilot play land config request ${url}");
    try {
      var response = await http.get(url, headers: normalHeader);
      return _handleResponse(response);
    } catch (e) {
      asLog.error("upload event [cloak] faild error $e");
    }
  }

  Future<String?> post(dynamic data, int type) async {
    var eventName = "";
    if (type == 0) {
      eventName = "event";
    } else if (type == 1) {
      eventName = "install";
    } else if (type == 2) {
      eventName = "session";
    } else {
      eventName = "ad";
    }
    var url = Uri.parse(tba_event_Url);
    asLog.info("upload event [$eventName] url $url \n $data");
    final client = http.Client();
    try {
      final request = client.post(
        url,
        headers: eventHeader,
        body: jsonEncode(data),
      );
      final response = type == 1
          ? await request.timeout(const Duration(seconds: 15))
          : await request;
      final body = _handleResponse(response);
      asLog.success("upload event [$eventName] success $body");
      return body;
    } catch (e) {
      // 安装留到下次 cloak 成功时重试，其它事件继续使用原有的地址回退。
      final isDnsFailure =
          e is SocketException ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network is unreachable');
      if (type != 1 && isDnsFailure && tba_event_Url != tba_event_Url_release) {
        final fallbackUrl = Uri.parse(tba_event_Url_release);
        asLog.error(
          "upload event [$eventName] test endpoint unavailable, retry release url $fallbackUrl",
        );
        try {
          final response = await http.post(
            fallbackUrl,
            headers: eventHeader,
            body: jsonEncode(data),
          );
          final body = _handleResponse(response);
          asLog.success(
            "upload event [$eventName] release fallback success $body",
          );
          return body;
        } catch (fallbackError) {
          asLog.error(
            "upload event [$eventName] release fallback failed $fallbackError",
          );
        }
      } else {
        asLog.error("upload event [$eventName] failed error $e");
      }
      return null;
    } finally {
      client.close();
    }
  }

  String _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body;
    } else {
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  }

  void _refreshHeader() async {
    eventHeader = {'Content-Type': 'application/json'};
  }

  void init() {
    _refreshHeader();
  }
}

// request parmerters
extension RequestHelpersExtension on PCRequestHelpers {
  Future<String> getConfigQueryString() async {
    var queryBody = {
      "monarchy": await FlutterTbaInfo.instance.getBundleId(),
      "indwell": 'durance',
      "pasteup": await FlutterTbaInfo.instance.getAppVersion(),
    };
    asLog.debug('queryBody=$queryBody');
    return Uri(queryParameters: queryBody).query;
  }

  // 通用字段
  Future<Map<String, dynamic>> baseBody({String? logId}) async {
    Map<String, dynamic> baseBody = {};

    Map<String, dynamic> woodruff = {
      "hid": await FlutterTbaInfo.instance.getAndroidId(),
      "monarchy": await FlutterTbaInfo.instance.getBundleId(),
      'sanford': DateTime.now().millisecondsSinceEpoch,
      "sloop": await FlutterTbaInfo.instance.getDeviceModel(),
      'petiole': await FlutterTbaInfo.instance.getDistinctId(),
      "indwell": 'durance',
      'molt': await FlutterTbaInfo.instance.getOsVersion(),
      "nobel": await FlutterTbaInfo.instance.getOsCountry(),
      'acacia': await FlutterTbaInfo.instance.getSystemLanguage(),
      "screw": await FlutterTbaInfo.instance.getGaid(),
    };
    baseBody['woodruff'] = woodruff;

    Map<String, dynamic> align = {
      'pasteup': await FlutterTbaInfo.instance.getAppVersion(),
      "reticent": logId ?? await FlutterTbaInfo.instance.getLogId(),
      "within": await FlutterTbaInfo.instance.getManufacturer(),
      'stealthy': await FlutterTbaInfo.instance.getBrand(),
      'erotica': await FlutterTbaInfo.instance.getOperator(),
    };
    baseBody['align'] = align;
    return baseBody;
  }
}
