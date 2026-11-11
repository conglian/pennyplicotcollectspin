import 'dart:math' as math;

/// 页面及弹窗共用的画布倍率，文字与容器一起适配，避免字号重复放大。
class PCAdaptiveLayout {
  PCAdaptiveLayout._();

  static const maxCanvasScale = 1.6;

  /// 导航项与引导高亮共用倍率；小屏不缩小点击区域，大屏最多放大到1.3倍。
  static double navigationScale(double width) =>
      widthScale(width, designWidth: 375, minScale: 1, maxScale: 1.3);

  static double navigationBarHeight(double width) =>
      81 * navigationScale(width);

  /// 流式页面按自身可用宽度缩放，宽屏保持可读的字号与间距上限。
  static double widthScale(
    double width, {
    double designWidth = 360,
    double minScale = .1,
    double maxScale = maxCanvasScale,
  }) {
    final scale = width / designWidth;
    return scale.isFinite ? scale.clamp(minScale, maxScale).toDouble() : 1;
  }

  /// 固定设计画布同时受可用宽高约束，防止长弹窗超出小屏安全区。
  static double fitScale({
    required double width,
    required double height,
    double designWidth = 360,
    required double designHeight,
    double maxScale = maxCanvasScale,
  }) {
    final scale = math.min(width / designWidth, height / designHeight);
    return scale.isFinite ? scale.clamp(.1, maxScale).toDouble() : 1;
  }
}
