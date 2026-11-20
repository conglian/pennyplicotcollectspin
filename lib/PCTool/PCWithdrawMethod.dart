/// 目前可用的提现渠道。保持原缓存与图标编号，Cash App 仍为 2。
enum PCWithdrawMethod {
  paypal(0, 'PayPal', 'pc_withdraw_paypal_2x'),
  cashApp(2, 'Cash App', 'pc_withdraw_cashapp_2x');

  const PCWithdrawMethod(this.storageIndex, this.label, this.formAsset);

  final int storageIndex;
  final String label;
  final String formAsset;

  String get paymentAsset => 'pc_act_$storageIndex';

  static PCWithdrawMethod? fromStorageIndex(int? index) => switch (index) {
    0 => paypal,
    2 => cashApp,
    _ => null,
  };

  static PCWithdrawMethod forDisplay(int? index) =>
      fromStorageIndex(index) ?? paypal;
}
