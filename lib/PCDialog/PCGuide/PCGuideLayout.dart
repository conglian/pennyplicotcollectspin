import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../PCMainVC/PCHome.dart' show pcHomePigTargetKey;

/// 引导弹窗共用的首页存钱罐位置；目标尚未布局时使用设计稿兜底位置。
Rect pcHomePigRect(BuildContext context) {
  final RenderObject? renderObject = pcHomePigTargetKey.currentContext
      ?.findRenderObject();
  if (renderObject is RenderBox &&
      renderObject.attached &&
      renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  final Size screenSize = MediaQuery.sizeOf(context);
  return Rect.fromLTWH((screenSize.width - 168.w) * 0.5, 218.h, 168.w, 140.h);
}
