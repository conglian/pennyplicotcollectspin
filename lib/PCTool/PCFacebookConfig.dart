import 'dart:convert';

/// Firebase下发的FB买量配置；三项同时有效才使用，避免混用不同应用的ID和Token。
class PCFacebookConfig {
  const PCFacebookConfig({
    required this.appId,
    required this.clientToken,
    required this.name,
  });
  static const remoteKey = 'c177pig_android_fb';
  static const defaults = PCFacebookConfig(
    appId: '1050787194686776',
    clientToken:
        '6ede48fdb5f676b804a0befca40cc00c2cc641c12142766af44ef7fd5caae083',
    name: 'C177GP',
  );
  final String appId, clientToken, name;

  static PCFacebookConfig fromRemote(String? raw) {
    try {
      final value = jsonDecode(raw ?? '');
      if (value is! Map) return defaults;
      final appId = value['app_id']?.toString().trim() ?? '';
      final token = value['client_token'];
      final name = value['name'];
      if (!RegExp(r'^[0-9]+$').hasMatch(appId) ||
          token is! String ||
          token.trim().isEmpty ||
          name is! String ||
          name.trim().isEmpty) {
        return defaults;
      }
      return PCFacebookConfig(
        appId: appId,
        clientToken: token.trim(),
        name: name.trim(),
      );
    } catch (_) {
      return defaults;
    }
  }
}
