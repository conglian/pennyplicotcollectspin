import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCInterstitialAdService.dart';
import 'package:pennypilotcollectspin/PCTool/PCRewardedAdService.dart';

void main() {
  test('只有success映射true，cancelled和failed保持独立且都不能发奖', () async {
    final rewarded = PCRewardedAdService();
    final interstitial = PCInterstitialAdService();
    for (final outcome in PCAdOutcome.values) {
      rewarded.bindOutcomeHandler((_) async => outcome);
      interstitial.bindOutcomeHandler((_) async => outcome);
      interstitial.bindCachedOutcomeHandler((_) async => outcome);
      expect(await rewarded.requestOutcome('unit_rv'), outcome);
      expect(await rewarded.request('unit_rv'), outcome.isSuccess);
      expect(await interstitial.requestOutcome('unit_int'), outcome);
      expect(await interstitial.request('unit_int'), outcome.isSuccess);
      expect(await interstitial.requestCachedOutcome('cached_int'), outcome);
      expect(await interstitial.requestCached('cached_int'), outcome.isSuccess);
      expect(await rewarded.handler!('legacy_rv'), outcome.isSuccess);
    }
  });

  test('旧bool handler注入覆盖typed注册，false仍按无法展示处理', () async {
    final rewarded = PCRewardedAdService();
    final interstitial = PCInterstitialAdService();
    rewarded.bindOutcomeHandler((_) async => PCAdOutcome.cancelled);
    interstitial.bindOutcomeHandler((_) async => PCAdOutcome.cancelled);
    interstitial.bindCachedOutcomeHandler((_) async => PCAdOutcome.cancelled);
    rewarded.handler = (_) async => true;
    interstitial.handler = (_) async => true;
    interstitial.cachedHandler = (_) async => false;
    expect(await rewarded.requestOutcome('rv'), PCAdOutcome.success);
    expect(await interstitial.requestOutcome('int'), PCAdOutcome.success);
    expect(await interstitial.requestCachedOutcome('int'), PCAdOutcome.failed);
    rewarded.handler = null;
    interstitial.handler = null;
    interstitial.cachedHandler = null;
    expect(await rewarded.requestOutcome('rv'), PCAdOutcome.failed);
    expect(await interstitial.requestOutcome('int'), PCAdOutcome.failed);
    expect(await interstitial.requestCachedOutcome('int'), PCAdOutcome.failed);
  });

  test('普通与cached typed handler独立，更新一侧不能覆盖另一侧', () async {
    final service = PCInterstitialAdService();
    service.bindOutcomeHandler((_) async => PCAdOutcome.success);
    service.bindCachedOutcomeHandler((_) async => PCAdOutcome.cancelled);
    expect(await service.requestOutcome('one_int'), PCAdOutcome.success);
    expect(
      await service.requestCachedOutcome('two_int'),
      PCAdOutcome.cancelled,
    );
    service.handler = (_) async => false;
    expect(await service.requestOutcome('one_int'), PCAdOutcome.failed);
    expect(
      await service.requestCachedOutcome('two_int'),
      PCAdOutcome.cancelled,
    );
  });

  test('两笔在途广告各自持有结果，handler替换不改变旧请求', () async {
    final service = PCRewardedAdService();
    final pending = <String, Completer<PCAdOutcome>>{};
    service.bindOutcomeHandler((placement) {
      final result = Completer<PCAdOutcome>();
      pending[placement] = result;
      return result.future;
    });
    final first = service.requestOutcome('first_rv');
    final second = service.requestOutcome('second_rv');
    service.handler = (_) async => true;
    pending['second_rv']!.complete(PCAdOutcome.success);
    expect(await second, PCAdOutcome.success);
    pending['first_rv']!.complete(PCAdOutcome.cancelled);
    expect(await first, PCAdOutcome.cancelled);
    expect(await service.requestOutcome('third_rv'), PCAdOutcome.success);
  });

  test('缺少handler或handler异常均失败，不能误报成功/取消', () async {
    final rewarded = PCRewardedAdService();
    final interstitial = PCInterstitialAdService();
    expect(await rewarded.requestOutcome('rv'), PCAdOutcome.failed);
    expect(await interstitial.requestOutcome('int'), PCAdOutcome.failed);
    rewarded.bindOutcomeHandler((_) async => throw StateError('unavailable'));
    interstitial.bindOutcomeHandler(
      (_) async => throw StateError('unavailable'),
    );
    interstitial.cachedHandler = (_) async => throw StateError('unavailable');
    expect(await rewarded.requestOutcome('rv'), PCAdOutcome.failed);
    expect(await rewarded.request('rv'), isFalse);
    expect(await interstitial.requestOutcome('int'), PCAdOutcome.failed);
    expect(await interstitial.requestCachedOutcome('int'), PCAdOutcome.failed);
  });
}
