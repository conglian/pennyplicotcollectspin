import 'default_style_information.dart';

class BeautyStyleInformation extends DefaultStyleInformation {
  const BeautyStyleInformation({
    this.title = "",
    this.body = "",
    this.image = "",
    this.button = "",
    this.appIcon = "",
    this.template = "",
    this.amount = "",
  }) : super(false, false);

  /// 可选 PennyPilot 模板：account / goal；空值继续使用旧样式。
  final String template;
  final String amount;
  final String title;
  final String body;
  final String image;
  final String button;
  final String appIcon;
}
