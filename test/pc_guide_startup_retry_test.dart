import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCDialog/PCGuide/PCNewUserGuideFlow.dart';
import 'package:pennypilotcollectspin/PCTool/PCNewUserGuideController.dart';

class _PendingGuide extends PCNewUserGuideController {
  final pending = Completer<void>();
  int reads = 0;
  bool loaded = false;
  @override
  bool get isLoaded => loaded;
  @override
  bool get isIntroComplete => loaded;
  @override
  PCNewUserGuideStep get currentStep => PCNewUserGuideStep.afterIntro;
  @override
  Future<void> load() {
    reads++;
    return pending.future;
  }

  @override
  Future<void> retryLoad() => load();
}

void main() {
  testWidgets('未知引导状态不会永久转圈，8秒后可重试，恢复后只完成一次', (tester) async {
    final guide = _PendingGuide();
    addTearDown(guide.dispose);
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PCNewUserGuideFlow(
          controller: guide,
          onCompleted: () => completions++,
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('Tap to try again'), findsOneWidget);
    await tester.tap(find.text('Tap to try again'));
    await tester.pump();
    expect(guide.reads, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    guide.loaded = true;
    guide.pending.complete();
    await tester.pump();
    expect(completions, 1);
    expect(find.text('Tap to try again'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('读取等待时销毁会取消重试计时器，晚错误不更新旧页面', (tester) async {
    final guide = _PendingGuide();
    addTearDown(guide.dispose);
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PCNewUserGuideFlow(
          controller: guide,
          onCompleted: () => completions++,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    guide.pending.completeError(StateError('late preferences failure'));
    await tester.pump(const Duration(seconds: 8));
    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });
}
