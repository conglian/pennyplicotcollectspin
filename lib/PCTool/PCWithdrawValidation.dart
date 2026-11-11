/// 新用户提现资料的纯校验规则；完整账号只用于当前表单，不写入引导存档。
class PCWithdrawValidation {
  static bool email(String text) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text);
  static bool cashPhone(String text) => RegExp(r'^\d{10}$').hasMatch(text);
  static bool cpf(String text) => RegExp(r'^\d{11}$').hasMatch(text);
  static bool name(String text) =>
      text.trim().isNotEmpty && !text.contains('@');
  static bool pixPhone(String text) =>
      RegExp(r'^\+55\d{10,11}$').hasMatch(text);
  static bool evp(String text) => text.length == 36 && text.contains('-');

  /// 排队当前账号只显示首尾各两位，兼容旧版已脱敏缓存。
  static String maskQueueAccount(String text) {
    final value = text.trim();
    if (RegExp(r'^[^*]+\*{2,}[^*]*$').hasMatch(value)) {
      return value;
    }
    if (value.length <= 4) return '***';
    return '${value.substring(0, 2)}***${value.substring(value.length - 2)}';
  }

  static String mask(String text) => text.length <= 4
      ? '***${text.substring(text.length - 1)}'
      : '${text.substring(0, 1)}***${text.substring(text.length - 4)}';
}
