import 'PCNoticeMessage.dart';

/// 3.7 站内提现播报。金额仅展示，不变更本人的余额或领奖状态。
class PCSocialPayoutNotice {
  const PCSocialPayoutNotice({
    required this.sequence,
    required this.name,
    required this.title,
    required this.bodyTemplate,
    required this.amount,
    required this.avatarName,
  });

  final int sequence;
  final String name;
  final String title;
  final String bodyTemplate;
  final double amount;
  final String avatarName;

  String get amountText => PCNoticeMessage.money(amount);
  String get body => '$name ${bodyTemplate.replaceAll('{amount}', amountText)}';

  static const templates = <(String, String, String)>[
    (
      'Mary',
      '🎉 PayPal Payout Success',
      'received {amount} via PayPal successfully 💰',
    ),
    ('James', '💸 Cash Out Completed', 'just cashed out {amount} to PayPal ✅'),
    (
      'Linda',
      '🎯 Another Winner Paid',
      'received {amount} in her PayPal account',
    ),
    (
      'Robert',
      '💰 Big Payout Alert',
      'successfully withdrew {amount} via PayPal',
    ),
    ('Sarah', '🎉 Withdrawal Sent', 'just received {amount} through PayPal'),
    ('Michael', '💸 PayPal Transfer Done', 'cashed out {amount} successfully'),
    ('Emily', '🎯 Cash Out Success', 'received {amount} via PayPal'),
    ('David', '💰 Winner Notification', 'just withdrew {amount} to PayPal'),
    (
      'Jessica',
      '🎉 Payout Completed',
      'received {amount} in her PayPal wallet',
    ),
    (
      'Chris',
      '💸 Real Cash Paid',
      'successfully cashed out {amount} via PayPal',
    ),
    ('Amanda', '🎯 PayPal Reward Sent', 'received {amount} successfully'),
    ('Daniel', '💰 Cash Out Confirmed', 'just received {amount} via PayPal'),
    ('Laura', '🎉 Lucky Player Paid', 'cashed out {amount} successfully'),
    ('Kevin', '💸 Withdrawal Success', 'received {amount} through PayPal'),
    ('Nicole', '🎯 Another PayPal Payout', 'just withdrew {amount}'),
    ('Brian', '💰 Big Win Delivered', 'received {amount} via PayPal 🎰'),
    ('Rachel', '🎉 Cash Out Alert', 'successfully received {amount}'),
    ('Jason', '💸 Reward Sent', 'cashed out {amount} via PayPal'),
    ('Olivia', '🎯 Payout Completed', 'received {amount} successfully'),
    ('Andrew', '💰 PayPal Cash Out', 'just received {amount} in PayPal'),
  ];
}
