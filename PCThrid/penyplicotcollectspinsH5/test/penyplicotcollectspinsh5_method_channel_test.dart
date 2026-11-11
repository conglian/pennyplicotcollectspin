import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penyplicotcollectspinsh5/penyplicotcollectspinsh5_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPenyplicotcollectspinsh5 platform;
  const MethodChannel channel = MethodChannel('penyplicotcollectspinsh5');
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final logs = <String>[];
  late DebugPrintCallback previousDebugPrint;

  Future<void> emit(MethodCall call) async {
    final response = Completer<ByteData?>();
    // 模拟 Android 向 Flutter 发送真实编码的平台消息，不调用私有处理函数。
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(call),
      response.complete,
    );
    final reply = await response.future;
    expect(reply, isNotNull);
    expect(codec.decodeEnvelope(reply!), isNull);
  }

  setUp(() {
    platform = MethodChannelPenyplicotcollectspinsh5();
    calls.clear();
    logs.clear();
    previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    messenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      return methodCall.method == 'getPlatformVersion' ? '42' : null;
    });
  });

  tearDown(() {
    debugPrint = previousDebugPrint;
    channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('create使用既有插件通道及create方法，不传入伪造Activity', () async {
    await platform.create();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'create');
    expect(calls.single.arguments, isNull);
  });

  test('create将Activity或原生调用异常回传给宿主', () async {
    for (final code in ['H5_NO_ACTIVITY', 'H5_CREATE_FAILED']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: code);
          });
      await expectLater(
        platform.create(),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', code)),
      );
    }
  });

  test('create不掩盖缺失Android桥接', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw MissingPluginException();
        });
    await expectLater(
      platform.create(),
      throwsA(isA<MissingPluginException>()),
    );
  });

  test('网页开始和结束回调各打印一次完整URL及查询参数', () async {
    await platform.create();
    final url =
        'https://example.com/game?source=app&redirect=https%3A%2F%2Fexample.com%2Fnext&value='
        '${List.filled(1200, 'x').join()}#reward';
    for (final event in ['onPageStarted', 'onPageFinished']) {
      await emit(MethodCall('onPageLog', {'event': event, 'url': url}));
    }
    expect(logs, [
      '[H5] onPageStarted url=$url',
      '[H5] onPageFinished url=$url',
    ]);
    expect(calls, hasLength(1));
  });

  test('create尚未返回时已能接收首次网页地址', () async {
    final native = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      await native.future;
      return null;
    });
    var returned = false;
    final pending = platform.create().then((_) => returned = true);
    await emit(
      const MethodCall('onPageLog', {
        'event': 'onPageStarted',
        'url': 'https://example.com/first?step=1',
      }),
    );
    expect(returned, isFalse);
    expect(logs, ['[H5] onPageStarted url=https://example.com/first?step=1']);
    native.complete();
    await pending;
    expect(returned, isTrue);
  });

  test('非法参数和未知回调安全忽略，不打印伪造地址', () async {
    await platform.create();
    for (final arguments in <Object?>[
      null,
      'not a map',
      [],
      {},
      {'event': 'onPageStarted'},
      {'event': 'onPageStarted', 'url': 1},
      {'event': 'onPageFinished', 'url': ''},
      {'event': 'onPageFinished', 'url': '   '},
      {'event': 'unknown', 'url': 'https://example.com/'},
      {'event': 1, 'url': 'https://example.com/'},
    ]) {
      await emit(MethodCall('onPageLog', arguments));
    }
    await emit(
      const MethodCall('unknownCallback', {
        'event': 'onPageStarted',
        'url': 'https://example.com/',
      }),
    );
    expect(logs, isEmpty);
  });

  test('重复create不叠加监听或重复打印同一回调', () async {
    await Future.wait([platform.create(), platform.create()]);
    await emit(
      const MethodCall('onPageLog', {
        'event': 'onPageFinished',
        'url': 'https://example.com/ready',
      }),
    );
    expect(calls.where((call) => call.method == 'create'), hasLength(2));
    expect(logs, ['[H5] onPageFinished url=https://example.com/ready']);
  });

  test('WebView可独立启用日志，不调用初始化也能接收原生地址', () async {
    platform.startPageLogging();
    platform.startPageLogging();
    await emit(
      const MethodCall('onPageLog', {
        'event': 'onPageStarted',
        'url': 'https://example.com/platform-view?source=chest',
      }),
    );
    expect(calls, isEmpty);
    expect(logs, [
      '[H5] onPageStarted url=https://example.com/platform-view?source=chest',
    ]);
  });
}
