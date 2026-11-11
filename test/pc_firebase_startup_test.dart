@TestOn('vm')
library;

import 'package:firebase_core/firebase_core.dart';
// 仅替换 FlutterFire 的平台测试接口，不增加运行时依赖或调用真实 Firebase。
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/main.dart' as app;

class _UnavailableFirebase extends FirebasePlatform {
  _UnavailableFirebase(this.error);

  final Object error;
  int initializationAttempts = 0;
  int appLookups = 0;

  @override
  List<FirebaseAppPlatform> get apps => const [];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    initializationAttempts++;
    expect(name, isNull);
    expect(options, isNull, reason: '不能使用其他包名的凭据替代缺失的原生配置');
    throw error;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    appLookups++;
    throw StateError('No initialized Firebase app is available.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final missingConfiguration in <String, Object>{
    'Android 原生资源中缺少 FirebaseOptions': PlatformException(
      code: 'firebase_core',
      message: 'Failed to load FirebaseOptions from resource.',
    ),
    '没有可用的默认 Firebase 应用': FirebaseException(
      plugin: 'core',
      code: 'no-app',
      message: 'No Firebase App has been created.',
    ),
  }.entries) {
    test('${missingConfiguration.key}时完成启动，保留错误处理器且不访问 Crashlytics', () async {
      final originalDelegate = Firebase.delegatePackingProperty;
      final originalFlutterError = FlutterError.onError;
      final originalPlatformError = PlatformDispatcher.instance.onError;
      final unavailable = _UnavailableFirebase(missingConfiguration.value);
      const crashlyticsChannel = MethodChannel(
        'plugins.flutter.io/firebase_crashlytics',
      );
      final crashlyticsCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      Firebase.delegatePackingProperty = unavailable;
      messenger.setMockMethodCallHandler(crashlyticsChannel, (call) async {
        crashlyticsCalls.add(call);
        return null;
      });

      try {
        await expectLater(app.initializeFirebaseForStartup(), completes);

        expect(unavailable.initializationAttempts, 1);
        expect(unavailable.appLookups, 0);
        expect(crashlyticsCalls, isEmpty);
        expect(FlutterError.onError, same(originalFlutterError));
        expect(
          PlatformDispatcher.instance.onError,
          same(originalPlatformError),
        );
      } finally {
        Firebase.delegatePackingProperty = originalDelegate;
        FlutterError.onError = originalFlutterError;
        PlatformDispatcher.instance.onError = originalPlatformError;
        messenger.setMockMethodCallHandler(crashlyticsChannel, null);
      }
    });
  }
}
