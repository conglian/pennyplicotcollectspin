import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'PCNumberManager.dart';
import 'PCNewUserGuideController.dart';
import 'PCWithdrawValidation.dart';
import 'PCQuizController.dart';

enum PCProcessPromptKind {
  confirmAccount,
  reviewProgress,
  diamondReminder,
  officialNotice,
  quizRanking,
}

/// 3.7 待展示提示快照：触发点与随机种子一起保存，重启不重新生成事件。
class PCProcessPrompt {
  const PCProcessPrompt({
    required this.id,
    required this.kind,
    this.answerCount = 0,
    this.seed = 0,
    this.collected = 0,
    this.remaining = 0,
    this.fromProgress = 0,
    this.toProgress = 0,
    this.accountSaved = false,
  });
  final String id;
  final PCProcessPromptKind kind;
  final int answerCount, seed, fromProgress, toProgress;
  final double collected, remaining;
  final bool accountSaved;
  int get priority => switch (kind) {
    PCProcessPromptKind.confirmAccount => 90,
    PCProcessPromptKind.reviewProgress => 80,
    PCProcessPromptKind.diamondReminder => 70,
    PCProcessPromptKind.officialNotice => 60,
    PCProcessPromptKind.quizRanking => 50,
  };
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'answerCount': answerCount,
    'seed': seed,
    'collected': collected,
    'remaining': remaining,
    'fromProgress': fromProgress,
    'toProgress': toProgress,
    'accountSaved': accountSaved,
  };
  factory PCProcessPrompt.fromJson(Map<String, dynamic> raw) => PCProcessPrompt(
    id: raw['id'] as String,
    kind: PCProcessPromptKind.values.byName(raw['kind'] as String),
    answerCount: (raw['answerCount'] as num? ?? 0).toInt(),
    seed: (raw['seed'] as num? ?? 0).toInt(),
    collected: (raw['collected'] as num? ?? 0).toDouble(),
    remaining: (raw['remaining'] as num? ?? 0).toDouble(),
    fromProgress: (raw['fromProgress'] as num? ?? 0).toInt(),
    toProgress: (raw['toProgress'] as num? ?? 0).toInt(),
    accountSaved: raw['accountSaved'] == true,
  );
}

/// 3.7 流程提示：账号、8/15/20题排名、钻石审核和临界收集提醒。
/// 所有触发点本地防重；只维护展示记录，不修改奖励与真实提现状态。
class PCProcessFlowController extends ChangeNotifier {
  PCProcessFlowController({SharedPreferences? preferences, math.Random? random})
    : _prefs = preferences,
      _random = random ?? math.Random();
  static final instance = PCProcessFlowController();
  static const storageKey = 'pc_process_prompts_v1';
  SharedPreferences? _prefs;
  final math.Random _random;
  bool _loaded = false, _disposed = false;
  Future<void>? _refreshing;
  bool _refreshAgain = false, _guideComplete = false;
  Set<String> _seen = {};
  List<PCProcessPrompt> _pending = [];
  PCProcessPrompt? _active;
  int _reviewProgress = 0;
  bool get hasPending => _active != null || _pending.isNotEmpty;
  bool get isPresenting => _active != null;
  bool get isRefreshing => _refreshing != null;
  List<PCProcessPrompt> get pending => List.unmodifiable(_pending);
  PCProcessPrompt? get next => _pending.firstOrNull;
  int get reviewProgress => _reviewProgress;
  String get savedAccount => (_prefs?.getString('pc_account_id') ?? '').trim();

  /// 排队期间资料可能已由新用户流程完成，不再展示失效的旧账号提示。
  bool isPending(PCProcessPrompt prompt) =>
      !_seen.contains(prompt.id) && _pending.any((p) => p.id == prompt.id);

  Future<void> refresh({bool guideComplete = true}) {
    _guideComplete = guideComplete;
    _refreshAgain = true;
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _load() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (_loaded) return;
    try {
      final raw = jsonDecode(_prefs!.getString(storageKey) ?? '{}') as Map;
      _seen = (raw['seen'] as List? ?? []).whereType<String>().toSet();
      _reviewProgress = (raw['reviewProgress'] as num? ?? 0).toInt();
      _pending = (raw['pending'] as List? ?? [])
          .whereType<Map>()
          .map(
            (value) =>
                PCProcessPrompt.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList();
    } catch (_) {
      _seen = {};
      _pending = [];
      _reviewProgress = 0;
    }
    _loaded = true;
  }

  Future<void> _refresh() async {
    await _load();
    do {
      _refreshAgain = false;
      final guideConfirmed = await _syncGuideAccount();
      if (!_guideComplete) {
        if (guideConfirmed) {
          await _save();
          _notify();
        }
        continue;
      }
      final prefs = _prefs!;
      // 钻石首次审核从40%起，后续3.7审核沿用同一基线。
      try {
        final withdrawal =
            jsonDecode(prefs.getString('pc_withdrawal_flow_v1') ?? '{}') as Map;
        _reviewProgress = math.max(
          _reviewProgress,
          (withdrawal['reviewBaseline'] as num? ?? 0).toInt(),
        );
      } catch (_) {}
      final count = prefs.getInt('pc_quiz_num_index') ?? 0;
      final level = prefs.getInt('pc_pig_level') ?? 0;
      final balance = prefs.getDouble('pc_dollar_number') ?? 0;
      final account = (prefs.getString('pc_account_id') ?? '').trim();
      final target = PCNumberHelpers().pc_firstTarget;
      final diamonds = math
          .max(
            prefs.getDouble('pc_quiz_diamonds') ?? 0,
            level == 1 ? prefs.getDouble('pc_pig_level_index') ?? 0 : 0.0,
          )
          .clamp(0.0, 20.0);
      final remaining = ((20 - diamonds) * 100).round() / 100;
      _pending.removeWhere(
        (p) =>
            (level != 1 &&
                {
                  PCProcessPromptKind.reviewProgress,
                  PCProcessPromptKind.diamondReminder,
                  PCProcessPromptKind.officialNotice,
                }.contains(p.kind)) ||
            (p.id == 'account:first' && account.isNotEmpty),
      );
      if (account.isEmpty && count >= 3) {
        _add(
          PCProcessPrompt(
            id: 'account:first',
            kind: PCProcessPromptKind.confirmAccount,
            answerCount: count,
          ),
        );
      }
      if (account.isNotEmpty && balance / target > .8) {
        _add(
          PCProcessPrompt(
            id: 'account:80',
            kind: PCProcessPromptKind.confirmAccount,
            answerCount: count,
            accountSaved: true,
          ),
        );
      }
      final ranks = [8, 15, 20].where((value) => count >= value).toList();
      if (ranks.isNotEmpty) {
        final value = ranks.last;
        _supersede(PCProcessPromptKind.quizRanking, 'ranking:$value');
        for (final old in ranks.take(ranks.length - 1)) {
          _seen.add('ranking:$old');
        }
        _add(
          PCProcessPrompt(
            id: 'ranking:$value',
            kind: PCProcessPromptKind.quizRanking,
            answerCount: count,
            seed:
                _pending
                    .where((p) => p.id == 'ranking:$value')
                    .firstOrNull
                    ?.seed ??
                _random.nextInt(1 << 30),
          ),
        );
      }
      if (level == 1 && diamonds < 20) {
        final milestones = [
          (6.0, 75),
          (10.0, 89),
          (16.0, 99),
        ].where((m) => diamonds > m.$1).toList();
        if (milestones.isNotEmpty) {
          final value = milestones.last.$2;
          _supersede(PCProcessPromptKind.reviewProgress, 'review:$value');
          for (final old in milestones.take(milestones.length - 1)) {
            _seen.add('review:${old.$2}');
          }
          _add(
            PCProcessPrompt(
              id: 'review:$value',
              kind: PCProcessPromptKind.reviewProgress,
              collected: diamonds,
              remaining: remaining,
              fromProgress: _reviewProgress,
              toProgress: value,
            ),
          );
        }
        if (diamonds > 18) {
          _add(
            PCProcessPrompt(
              id: 'diamond:90',
              kind: PCProcessPromptKind.diamondReminder,
              collected: diamonds,
              remaining: remaining,
            ),
          );
        }
        final limits = [
          1.0,
          .1,
          .01,
        ].where((v) => remaining > 0 && remaining <= v).toList();
        if (limits.isNotEmpty) {
          final id = 'official:${limits.last}';
          _supersede(PCProcessPromptKind.officialNotice, id);
          for (final old in limits.take(limits.length - 1)) {
            _seen.add('official:$old');
          }
          _add(
            PCProcessPrompt(
              id: id,
              kind: PCProcessPromptKind.officialNotice,
              collected: diamonds,
              remaining: remaining,
            ),
          );
        }
      }
      // 等待奖励期间其它入口可能继续推进数量，展示时使用最新缓存。
      _pending = _pending
          .map(
            (p) => PCProcessPrompt.fromJson({
              ...p.toJson(),
              if (p.kind == PCProcessPromptKind.quizRanking)
                'answerCount': count,
              if ({
                PCProcessPromptKind.reviewProgress,
                PCProcessPromptKind.diamondReminder,
                PCProcessPromptKind.officialNotice,
              }.contains(p.kind)) ...{
                'collected': diamonds,
                'remaining': remaining,
                if (p.kind == PCProcessPromptKind.reviewProgress)
                  'fromProgress': _reviewProgress,
              },
            }),
          )
          .toList();
      _pending.sort((a, b) => b.priority.compareTo(a.priority));
      await _save();
      _notify();
    } while (_refreshAgain);
  }

  void _add(PCProcessPrompt p) {
    if (!_seen.contains(p.id) &&
        !_pending.any((v) => v.id == p.id) &&
        _active?.id != p.id) {
      _pending.add(p);
    }
  }

  void _supersede(PCProcessPromptKind kind, String latest) {
    _pending.removeWhere((p) {
      if (p.kind != kind || p.id == latest) return false;
      _seen.add(p.id);
      return true;
    });
  }

  /// 仅在真正创建展示路由时消费；活动标志保留至整条账号/确认横幅流程结束。
  Future<void> begin(PCProcessPrompt prompt) async {
    _active = prompt;
    _notify();
    final previousReviewProgress = _reviewProgress;
    final previousSeen = Set<String>.from(_seen);
    final previousPending = List<PCProcessPrompt>.from(_pending);
    _seen.add(prompt.id);
    _pending.removeWhere((p) => p.id == prompt.id);
    if (prompt.kind == PCProcessPromptKind.reviewProgress) {
      _reviewProgress = prompt.toProgress;
    }
    try {
      await _save();
    } catch (_) {
      _seen = previousSeen;
      _reviewProgress = previousReviewProgress;
      _pending = previousPending;
      _active = null;
      _notify();
      rethrow;
    }
    _notify();
  }

  void finish() {
    _active = null;
    _notify();
  }

  bool get hasPendingQuizReward {
    try {
      final data =
          jsonDecode(_prefs?.getString(PCQuizController.storageKey) ?? '{}')
              as Map;
      return data['pendingReward'] is Map;
    } catch (_) {
      return false;
    }
  }

  /// 新用户和3.7共用同一账号完成态；一次有效提交同时完成3题和80%两触发。
  void _markAccountConfirmed() {
    _seen.addAll(['account:first', 'account:80']);
    _pending.removeWhere((p) => p.kind == PCProcessPromptKind.confirmAccount);
  }

  /// 旧引导单独保存过账号；如原值仍在，补回完整账号，不覆盖已绑定的完整资料。
  Future<bool> _syncGuideAccount() async {
    String confirmedUser;
    try {
      final raw = jsonDecode(
        _prefs!.getString(PCNewUserGuideController.flowKey) ?? '{}',
      );
      if (raw is! Map) return false;
      confirmedUser = (raw['confirmedUser'] as String? ?? '').trim();
      if (confirmedUser.isEmpty &&
          (raw['accountConfirmed'] != true || savedAccount.isEmpty)) {
        return false;
      }
    } catch (_) {
      return false;
    }
    if (confirmedUser.isNotEmpty &&
        (savedAccount.isEmpty ||
            (PCWithdrawValidation.isLegacyMask(savedAccount) &&
                !PCWithdrawValidation.isLegacyMask(confirmedUser)))) {
      if (!await _prefs!.setString('pc_account_id', confirmedUser)) {
        throw StateError('Unable to save confirmed guide account');
      }
    }
    _markAccountConfirmed();
    return true;
  }

  Future<void> accountConfirmed() async {
    await _load();
    _markAccountConfirmed();
    await _save();
    _notify();
  }

  Future<void> _save() async {
    if (!await _prefs!.setString(
      storageKey,
      jsonEncode({
        'seen': _seen.toList(),
        'reviewProgress': _reviewProgress,
        'pending': _pending.map((p) => p.toJson()).toList(),
      }),
    )) {
      throw StateError('Unable to save process prompts');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
