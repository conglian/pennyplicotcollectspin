import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCDialogCoordinator.dart';
import 'package:pennypilotcollectspin/PCTool/pc_extension_help.dart';

Future<void> flushQueue() => Future<void>.delayed(Duration.zero);

void main() {
  test('队列逐项展示，前一项完全结束之前不启动下一项', () async {
    final queue = PCDialogCoordinator();
    final firstExit = Completer<String?>();
    final secondExit = Completer<String?>();
    final started = <String>[];
    final first = queue.enqueue<String>(
      key: 'first',
      present: () {
        started.add('first');
        return firstExit.future;
      },
    );
    final second = queue.enqueue<String>(
      key: 'second',
      present: () {
        started.add('second');
        return secondExit.future;
      },
    );
    await flushQueue();
    expect(started, ['first']);
    expect(queue.isPresenting, isTrue);
    expect(queue.pendingCount, 1);
    firstExit.complete('closed');
    expect(await first, 'closed');
    await flushQueue();
    expect(started, ['first', 'second']);
    secondExit.complete('claimed');
    expect(await second, 'claimed');
    expect(queue.isBusy, isFalse);
    queue.dispose();
  });

  test('多个浮层独立持有，重复释放安全，最后一个退出才允许弹窗', () async {
    final queue = PCDialogCoordinator();
    var notifications = 0;
    queue.addListener(() => notifications++);
    final releaseBanner = queue.holdPresentation();
    final releaseReward = queue.holdPresentation();
    expect(queue.holdCount, 2);
    var started = false;
    final result = queue.enqueue<int>(
      key: 'dialog',
      present: () async {
        started = true;
        return 7;
      },
    );
    await flushQueue();
    expect(queue.isBusy, isTrue);
    expect(queue.isPresenting, isFalse);
    expect(queue.pendingCount, 1);
    releaseBanner();
    releaseBanner();
    expect(queue.holdCount, 1);
    await flushQueue();
    expect(started, isFalse);
    releaseReward();
    expect(queue.holdCount, 0);
    expect(await result, 7);
    expect(queue.isBusy, isFalse);
    expect(notifications, greaterThanOrEqualTo(6));
    queue.dispose();
  });

  test('同一弹窗的重复触发共享结果，只执行一次', () async {
    final queue = PCDialogCoordinator();
    final exit = Completer<bool?>();
    var calls = 0;
    Future<bool?> present() {
      calls++;
      return exit.future;
    }

    final first = queue.enqueue<bool>(key: 'same', present: present);
    await flushQueue();
    final duplicate = queue.enqueue<bool>(key: 'same', present: present);
    expect(queue.pendingCount, 0);
    exit.complete(true);
    expect(await first, isTrue);
    expect(await duplicate, isTrue);
    expect(calls, 1);
    queue.dispose();
  });

  test('失效请求跳过，展示异常不会卡住后续队列', () async {
    final queue = PCDialogCoordinator();
    var skippedWasShown = false;
    final skipped = queue.enqueue<bool>(
      key: 'stale',
      canPresent: () => false,
      present: () async {
        skippedWasShown = true;
        return true;
      },
    );
    final failed = queue.enqueue<void>(
      key: 'broken',
      present: () async {
        throw StateError('broken');
      },
    );
    final failureCheck = expectLater(failed, throwsStateError);
    final next = queue.enqueue<String>(key: 'next', present: () async => 'ok');
    expect(await skipped, isNull);
    await failureCheck;
    expect(await next, 'ok');
    expect(skippedWasShown, isFalse);
    expect(queue.isBusy, isFalse);
    queue.dispose();
  });

  test('await 弹窗返回后可立即持有播放到账动画，排队弹窗不会抢先', () async {
    final queue = PCDialogCoordinator();
    final exit = Completer<bool?>();
    var nextStarted = false;
    final first = queue.enqueue<bool>(key: 'first', present: () => exit.future);
    VoidCallback? releaseEffect;
    final afterClaim = () async {
      await first;
      releaseEffect = queue.holdPresentation();
    }();
    final next = queue.enqueue<void>(
      key: 'next',
      present: () async {
        nextStarted = true;
      },
    );
    await flushQueue();
    exit.complete(true);
    await afterClaim;
    await flushQueue();
    expect(nextStarted, isFalse);
    releaseEffect!();
    await next;
    expect(nextStarted, isTrue);
    queue.dispose();
  });

  testWidgets('三个 tipShow 入口串行，关闭动画期间不会覆盖显示', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    final first = pageContext.tipShow(
      const _TestDialog(key: ValueKey('blur'), label: 'blur'),
      blurSigma: 4,
      bc: Colors.red,
    );
    final second = pageContext.tipShow2(
      const _TestDialog(key: ValueKey('plain'), label: 'plain'),
      scaleContent: false,
      bc: Colors.transparent,
    );
    final third = pageContext.tipShowAdvanced(
      const _TestDialog(key: ValueKey('advanced'), label: 'advanced'),
      blurSigma: 6,
    );
    await tester.pumpAndSettle();
    expect(find.text('blur'), findsOneWidget);
    expect(find.text('plain'), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
    var firstClosed = false;
    unawaited(first.then((_) => firstClosed = true));
    Navigator.of(pageContext).pop('first-result');
    await tester.pump(const Duration(milliseconds: 60));
    expect(firstClosed, isFalse);
    expect(find.text('plain'), findsNothing);
    expect(PCDialogCoordinator.instance.isPresenting, isTrue);
    await tester.pumpAndSettle();
    expect(await first, 'first-result');
    expect(find.text('blur'), findsNothing);
    expect(find.text('plain'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    Navigator.of(pageContext).pop(true);
    await tester.pumpAndSettle();
    expect(await second, isTrue);
    expect(find.text('plain'), findsNothing);
    expect(find.text('advanced'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    Navigator.of(pageContext).pop(false);
    await tester.pumpAndSettle();
    expect(await third, isFalse);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('重复点击同一个入口只显示一次，返回同一结果', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final first = pageContext.tipShow2(const _TestDialog(label: 'same'));
    await tester.pumpAndSettle();
    final second = pageContext.tipShow2(const _TestDialog(label: 'same'));
    await tester.pump();
    expect(find.text('same'), findsOneWidget);
    expect(PCDialogCoordinator.instance.pendingCount, 0);
    Navigator.of(pageContext).pop(42);
    await tester.pumpAndSettle();
    expect(await first, 42);
    expect(await second, 42);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('弹窗内发起下一弹窗先退出自身，不等待自身造成死锁', (tester) async {
    late BuildContext pageContext;
    Future<dynamic>? next;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final first = pageContext.tipShow2(
      Builder(
        builder: (dialogContext) {
          return Center(
            child: TextButton(
              onPressed: () => next = dialogContext.tipShow2(
                const _TestDialog(key: ValueKey('nested'), label: 'nested'),
              ),
              child: const Text('continue'),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('continue'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('nested'), findsNothing);
    await tester.pumpAndSettle();
    expect(await first, isNull);
    expect(find.text('continue'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
    Navigator.of(pageContext).pop('next-result');
    await tester.pumpAndSettle();
    expect(await next, 'next-result');
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('排队期间页面退出，失效 context 不会在别的页面弹窗', (tester) async {
    late BuildContext pageContext;
    late BuildContext temporaryContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    unawaited(
      Navigator.of(pageContext).push(
        MaterialPageRoute<void>(
          builder: (context) {
            temporaryContext = context;
            return const Scaffold(body: Text('temporary'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final release = PCDialogCoordinator.instance.holdPresentation();
    final stale = temporaryContext.tipShow2(const _TestDialog(label: 'stale'));
    Navigator.of(temporaryContext).pop();
    await tester.pumpAndSettle();
    expect(temporaryContext.mounted, isFalse);
    release();
    await tester.pumpAndSettle();
    expect(await stale, isNull);
    expect(find.text('stale'), findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('Navigator 整体销毁仍释放当前项，队列不被未完成的 popped 卡死', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final active = pageContext.tipShow2(
      const _TestDialog(key: ValueKey('active'), label: 'active'),
    );
    final queued = pageContext.tipShow2(
      const _TestDialog(key: ValueKey('queued'), label: 'queued'),
    );
    await tester.pumpAndSettle();
    expect(PCDialogCoordinator.instance.isPresenting, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(await active, isNull);
    expect(await queued, isNull);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('排队中失去业务展示资格时跳过，不执行 onPresented', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final release = PCDialogCoordinator.instance.holdPresentation();
    var allowed = true;
    var presented = 0;
    final request = pageContext.tipShow2(
      const _TestDialog(label: 'conditional'),
      canPresent: () => allowed,
      onPresented: () async {
        presented++;
      },
    );
    await tester.pump();
    allowed = false;
    release();
    await tester.pumpAndSettle();
    expect(await request, isNull);
    expect(presented, 0);
    expect(find.text('conditional'), findsNothing);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('实际 push 后执行一次 onPresented，重复请求共享展示记录与返回值', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    var presented = 0;
    var wasPushed = false;
    var hadPresentationOwnership = false;
    Future<void> onPresented() async {
      wasPushed =
          Navigator.of(pageContext).canPop() &&
          !ModalRoute.of(pageContext)!.isCurrent;
      hadPresentationOwnership = PCDialogCoordinator.instance.isPresenting;
      presented++;
    }

    final first = pageContext.tipShow2(
      const _TestDialog(label: 'presented'),
      onPresented: onPresented,
    );
    final duplicate = pageContext.tipShow2(
      const _TestDialog(label: 'presented'),
      onPresented: onPresented,
    );
    await tester.pumpAndSettle();
    expect(presented, 1);
    expect(wasPushed, isTrue);
    expect(hadPresentationOwnership, isTrue);
    Navigator.of(pageContext).pop(true);
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await duplicate, isTrue);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });

  testWidgets('onPresented 保存失败时安全撤回该路由并继续下一条', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final failed = pageContext.tipShow2(
      const _TestDialog(key: ValueKey('failed'), label: 'failed'),
      onPresented: () async {
        throw StateError('save failed');
      },
    );
    final failureCheck = expectLater(failed, throwsStateError);
    final next = pageContext.tipShow2(
      const _TestDialog(key: ValueKey('next'), label: 'next'),
    );
    await tester.pumpAndSettle();
    await failureCheck;
    expect(find.text('failed'), findsNothing);
    expect(find.text('next'), findsOneWidget);
    expect(PCDialogCoordinator.instance.isPresenting, isTrue);
    Navigator.of(pageContext).pop(5);
    await tester.pumpAndSettle();
    expect(await next, 5);
    expect(PCDialogCoordinator.instance.isBusy, isFalse);
  });
}

class _TestDialog extends StatelessWidget {
  const _TestDialog({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) =>
      Center(child: Material(child: Text(label)));
}
