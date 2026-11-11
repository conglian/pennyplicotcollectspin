import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

/// 全局弹窗队列：前一弹窗完整退场后才显示下一项。
///
/// 横幅、领奖到账动画等非路由浮层可用 [holdPresentation] 暂停队列，
/// 每次持有均须在退场或 dispose 时释放；释放函数可安全重复调用。
class PCDialogCoordinator extends ChangeNotifier {
  PCDialogCoordinator();

  static final instance = PCDialogCoordinator();

  final Queue<_DialogRequest> _pending = Queue<_DialogRequest>();
  final Map<Object, _DialogRequest> _requests = {};
  _DialogRequest? _active;
  int _holds = 0;
  bool _scheduled = false;
  bool _disposed = false;

  /// 包括正在进退场的弹窗、排队请求，以及非路由浮层的持有。
  bool get isBusy => isPresenting || pendingCount > 0 || _holds > 0;

  /// 路由从 push 到 completed 全程为 true，关闭动画期间仍占用展示权。
  bool get isPresenting => _active != null;

  /// 等待显示的弹窗数量，不包括当前弹窗或持有者自身。
  int get pendingCount => _pending.length;

  /// 当前非路由浮层的持有数量；持有者可扣除自身，判断是否需要让路。
  int get holdCount => _holds;

  /// 暂缓后续弹窗，允许多个浮层各自持有并独立释放。
  /// 不会关闭已显示弹窗；不要在持有期间等待自己尚未入队的弹窗。
  VoidCallback holdPresentation() {
    if (_disposed) return () {};
    _holds++;
    notifyListeners();
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_disposed) return;
      _holds--;
      notifyListeners();
      _schedule();
    };
  }

  /// 相同 [key] 的重复请求共享结果，失效请求返回 null；异常不阻塞后续项。
  /// [present] 必须在其浮层完整退出后才完成。
  Future<T?> enqueue<T>({
    required Object key,
    required Future<T?> Function() present,
    bool Function()? canPresent,
  }) {
    if (_disposed) return Future<T?>.value();
    final existing = _requests[key];
    if (existing != null) {
      return existing.result.future as Future<T?>;
    }
    final request = _DialogRequest<T>(
      key: key,
      present: present,
      canPresent: canPresent,
    );
    _requests[key] = request;
    _pending.add(request);
    notifyListeners();
    _schedule();
    return request.result.future;
  }

  /// 供本地 tipShow 系列统一使用；页面可以在排队期间销毁，故提前捕获导航器。
  Future<T?> showRoute<T>({
    required BuildContext context,
    required Object contentKey,
    required RawDialogRoute<T> Function() routeBuilder,
    bool Function()? canPresent,
    Future<void> Function()? onPresented,
  }) {
    if (!context.mounted) return Future<T?>.value();
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) return Future<T?>.value();
    final sourceRoute = ModalRoute.of(context);
    final active = _active;
    final fromActiveDialog =
        sourceRoute != null && identical(sourceRoute, active?.route);
    final ownerRoute = fromActiveDialog ? active?.ownerRoute : sourceRoute;
    final key = _DialogKey(navigator, contentKey);
    final wasAlreadyRequested = _requests.containsKey(key);

    final result = enqueue<T>(
      key: key,
      canPresent: () =>
          navigator.mounted &&
          (fromActiveDialog || context.mounted) &&
          (ownerRoute == null || ownerRoute.isActive) &&
          (canPresent?.call() ?? true),
      present: () async {
        final route = routeBuilder();
        _active?.route = route;
        _active?.ownerRoute = ownerRoute;
        final popped = navigator.push<T>(route);
        try {
          // 已实际 push 并占用队列展示权后才消费业务事件；排队被跳过的
          // 请求不会执行回调，也不会提前写入“已展示”记录。
          await onPresented?.call();
        } catch (_) {
          // 保存展示记录失败时撤回本路由，完整清理遮罩后再把错误交给业务。
          // 只操作自己的 route，不能误 pop 在回调期间新打开的其他页面。
          if (navigator.mounted && identical(route.navigator, navigator)) {
            if (route.isCurrent) {
              navigator.pop();
            } else if (route.isActive) {
              navigator.removeRoute(route);
            }
          }
          await route.completed;
          rethrow;
        }
        final result = await Future.any<T?>([
          popped,
          // 整个 Navigator 被替换时 Flutter 会 dispose 路由，但未必 pop；
          // completed 仍会完成，不能只等 popped 导致全局队列永久占用。
          route.completed,
        ]);
        // Navigator.push 的 Future 在 pop 时完成，completed 才表示遮罩和
        // reverse 动画已真正移除；队列必须等待后者，避免短暂叠两层。
        await route.completed;
        return result;
      },
    );

    // 弹窗内部直接请求下一弹窗时，先退出自身再交接展示权。
    // 同一弹窗的重复请求仅共享 Future，不会误关闭当前弹窗。
    if (!wasAlreadyRequested && fromActiveDialog && sourceRoute.isCurrent) {
      navigator.pop();
    }
    return result;
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_disposed || _active != null || _holds > 0 || _pending.isEmpty) {
        return;
      }
      final request = _pending.removeFirst();
      _active = request;
      notifyListeners();
      unawaited(_run(request));
    });
  }

  Future<void> _run(_DialogRequest request) async {
    dynamic result;
    Object? failure;
    StackTrace? failureStack;
    try {
      if (request.canPresent?.call() ?? true) result = await request.present();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    } finally {
      _requests.remove(request.key);
      if (identical(_active, request)) _active = null;
      if (!request.result.isCompleted) {
        if (failure == null) {
          request.result.complete(result);
        } else {
          request.result.completeError(failure, failureStack);
        }
      }
      if (!_disposed) {
        notifyListeners();
        // 先恢复 await tipShow 的业务回调，再开始下一项；调用方可立即
        // 持有展示权播放到账动画，不会被排队弹窗抢先覆盖。
        _schedule();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final request in _pending) {
      if (!request.result.isCompleted) request.result.complete();
    }
    _pending.clear();
    _requests.clear();
    super.dispose();
  }
}

class _DialogRequest<T> {
  _DialogRequest({required this.key, required this.present, this.canPresent});
  final Object key;
  final Future<T?> Function() present;
  final bool Function()? canPresent;
  final Completer<T?> result = Completer<T?>();
  Route<dynamic>? route;
  Route<dynamic>? ownerRoute;
}

class _DialogKey {
  const _DialogKey(this.navigator, this.contentKey);
  final NavigatorState navigator;
  final Object contentKey;

  @override
  bool operator ==(Object other) =>
      other is _DialogKey &&
      identical(navigator, other.navigator) &&
      contentKey == other.contentKey;

  @override
  int get hashCode => Object.hash(identityHashCode(navigator), contentKey);
}
