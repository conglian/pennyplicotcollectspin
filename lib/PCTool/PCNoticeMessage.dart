import 'dart:convert';

/// 通知对应的界面与按钮行为；金额始终来自本地余额。
enum PCNoticeKind { account, goal }

enum PCNoticeAction { withdraw, earn }

class PCNoticeMessage {
  const PCNoticeMessage({
    required this.kind,
    required this.balance,
    required this.target,
    this.titleOverride,
    this.bodyOverride,
  });

  final PCNoticeKind kind;
  final double balance;
  final double target;
  final String? titleOverride, bodyOverride;

  static String money(double value) {
    final safe = value.isFinite ? value.clamp(0, double.infinity) : 0.0;
    return '\$${safe.toStringAsFixed(2).replaceFirst(RegExp(r'\.00$'), '')}';
  }

  String get amount => money(balance);
  String get title =>
      titleOverride ??
      switch (kind) {
        PCNoticeKind.account => 'My Cash Account',
        PCNoticeKind.goal => '${money(target)} Unlocks Cashout',
      };
  String get body =>
      bodyOverride ??
      switch (kind) {
        PCNoticeKind.account => 'Your piggy bank balance is $amount.',
        PCNoticeKind.goal =>
          'Add A Little More To Your Piggy Bank And Get Closer To Withdrawal.',
      };
  String get button => switch (kind) {
    PCNoticeKind.account => 'Withdraw',
    PCNoticeKind.goal => 'Claim',
  };
  PCNoticeAction get action =>
      kind == PCNoticeKind.goal ? PCNoticeAction.earn : PCNoticeAction.withdraw;
  String get payload => jsonEncode({'pcNotice': 1, 'action': action.name});

  static PCNoticeAction? parseAction(String? payload) {
    final legacy = switch (payload) {
      'screenoff' ||
      'noti1' ||
      'noti3' ||
      'Media1' ||
      'Media3' ||
      'foreground' ||
      'unlock' ||
      'fcm1' => PCNoticeAction.withdraw,
      'noti2' ||
      'noti4' ||
      'Media2' ||
      'Media4' ||
      'screenon' ||
      'fcm2' => PCNoticeAction.earn,
      _ => null,
    };
    if (legacy != null) return legacy;
    try {
      final data = jsonDecode(payload ?? '');
      if (data is! Map || data['pcNotice'] != 1) return null;
      return switch (data['action']) {
        'withdraw' => PCNoticeAction.withdraw,
        'earn' => PCNoticeAction.earn,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

/// 固定通知四个单次触发点；站内提示复用金额和按钮语义。
class PCNoticeJob {
  const PCNoticeJob(this.id, this.minutes, this.kind);
  final int id;
  final int minutes;
  final PCNoticeKind kind;

  static const all = [
    PCNoticeJob(5590, 26, PCNoticeKind.account),
    PCNoticeJob(4562, 62, PCNoticeKind.goal),
    PCNoticeJob(7552, 117, PCNoticeKind.goal),
    PCNoticeJob(9475, 162, PCNoticeKind.goal),
  ];

  static Iterable<PCNoticeJob> get systemReminders => all;

  PCNoticeMessage message(double balance, double target) =>
      PCNoticeMessage(kind: kind, balance: balance, target: target);
}
