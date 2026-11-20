/// 收款资料校验，兼容旧安装仅保存脱敏值的情况。
class PCWithdrawValidation {
  static bool isLegacyMask(String text) =>
      RegExp(r'^(?:[^*]+)?\*{2,}[^*]*$').hasMatch(text.trim());

  static String fullAccount(String text) =>
      isLegacyMask(text) ? '' : text.trim();

  static String displayAccount(String text, {String fallback = '—'}) {
    final value = fullAccount(text);
    return value.isEmpty ? fallback : value;
  }

  static bool email(String text) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text);
  static bool cashPhone(String text) => RegExp(r'^\d{10}$').hasMatch(text);
}
