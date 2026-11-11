import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCFacebookConfig.dart';
import 'package:pennypilotcollectspin/PCTool/pc_init_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.example.pennyplicotcollectspin/facebook');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('远程FB配置完整有效时使用同一组凭据，映射到Android既有通道', () async {
    await PCFacebookAnalytics.initializeFromRemote(
      jsonEncode({
        'app_id': ' 123456789 ',
        'client_token': ' remote-token ',
        'name': ' Campaign FB ',
      }),
    );
    expect(calls.single.method, 'initFacebook');
    expect(calls.single.arguments, {
      'app_id': '123456789',
      'client_token': 'remote-token',
      'app_name': 'Campaign FB',
    });
  });

  test('下发为空、JSON错误或字段缺失时整组回退默认值，不混用远程AppID和默认Token', () async {
    for (final raw in <String?>[
      null,
      '',
      '   ',
      'invalid',
      '{"app_id":"123456789" "client_token":"token","name":"Remote"}',
      '[]',
      '{}',
      '{"app_id":"123456789","name":"Remote"}',
      '{"app_id":"invalid","client_token":"token","name":"Remote"}',
      '{"app_id":"123456789","client_token":" ","name":"Remote"}',
    ]) {
      final config = PCFacebookConfig.fromRemote(raw);
      expect(identical(config, PCFacebookConfig.defaults), true);
      final countBefore = calls.length;
      await PCFacebookAnalytics.initializeFromRemote(raw);
      expect(calls.length, countBefore + 1, reason: '默认分支只初始化一次，不能递归');
      expect(calls.last.arguments, {
        'app_id': '1050787194686776',
        'client_token':
            '6ede48fdb5f676b804a0befca40cc00c2cc641c12142766af44ef7fd5caae083',
        'app_name': 'C177GP',
      });
    }
  });

  test('远程原生初始化失败只回退一次完整默认配置', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if ((call.arguments as Map)['app_id'] == '123456789') {
            throw PlatformException(code: 'FB_REMOTE_INIT_FAILED');
          }
          return null;
        });
    await PCFacebookAnalytics.initializeFromRemote(
      '{"app_id":"123456789","client_token":"remote-token","name":"Remote"}',
    );
    expect(calls, hasLength(2));
    expect(calls.first.arguments, {
      'app_id': '123456789',
      'client_token': 'remote-token',
      'app_name': 'Remote',
    });
    final fallback = PCFacebookConfig.defaults;
    expect(calls.last.arguments, {
      'app_id': fallback.appId,
      'client_token': fallback.clientToken,
      'app_name': fallback.name,
    });
  });

  test('默认初始化失败不递归，远程和默认均失败也不阻断其他SDK', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw PlatformException(code: 'FB_INIT_FAILED');
        });
    await expectLater(
      PCFacebookAnalytics.initializeFromRemote(null),
      completes,
    );
    expect(calls, hasLength(1));
    calls.clear();
    await expectLater(
      PCFacebookAnalytics.initializeFromRemote(
        '{"app_id":"123456789","client_token":"remote-token","name":"Remote"}',
      ),
      completes,
    );
    expect(calls, hasLength(2));
  });

  test('广告收益原值和币种传递到Android，非法收益不产生事件，桥接异常不向业务抛出', () async {
    await PCFacebookAnalytics.logPurchase(.0123, 'USD');
    expect(calls.single.method, 'logPurchase');
    expect(calls.single.arguments, {'amount': .0123, 'currency': 'USD'});
    for (final amount in [-1.0, double.nan, double.infinity]) {
      await PCFacebookAnalytics.logPurchase(amount, 'USD');
    }
    expect(calls, hasLength(1));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'FB_UNAVAILABLE');
        });
    await expectLater(PCFacebookAnalytics.logPurchase(.02, 'USD'), completes);
  });
}
