import 'dart:math';

import 'package:flutter/material.dart';

import '../../PCTool/PCAdaptiveLayout.dart';

import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

/// 广告加载失败、无网络和次数上限弹窗共用的状态面板。
class PCAdStatusDialog extends StatelessWidget {
  const PCAdStatusDialog({
    super.key,
    required this.titleAssetName,
    required this.iconName,
    required this.canvasHeight,
    required this.panelHeight,
    required this.buttonTop,
    required this.iconWidth,
    required this.iconHeight,
    required this.iconLeft,
    required this.iconTop,
    required this.imageSize,
    required this.imageLeft,
    required this.imageTop,
    required this.buttonText,
    required this.onButtonTap,
    this.onClose,
    this.description,
    this.descriptionTop,
  });

  final String titleAssetName;
  final String iconName;
  final double canvasHeight;
  final double panelHeight;
  final double buttonTop;
  final double iconWidth;
  final double iconHeight;
  final double iconLeft;
  final double iconTop;
  final double imageSize;
  final double imageLeft;
  final double imageTop;
  final String? description;
  final double? descriptionTop;
  final String buttonText;
  final VoidCallback onButtonTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return PCResponsiveDialog(
      designHeight: canvasHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            top: 124,
            width: 320,
            height: panelHeight,
            child: const PCImg(name: 'pc_guide3_bg'),
          ),
          Positioned(
            left: 12,
            top: 0,
            width: 336,
            height: 152,
            child: PCImg(name: titleAssetName),
          ),
          Positioned(
            left: iconLeft,
            top: iconTop,
            width: iconWidth,
            height: iconHeight,
            child: PCFigmaIcon(
              name: iconName,
              imageSize: imageSize,
              imageLeft: imageLeft,
              imageTop: imageTop,
            ),
          ),
          if (description != null)
            Positioned(
              left: 44,
              top: descriptionTop!,
              width: 272,
              height: 40,
              child: PCText(
                text: description!,
                size: 14,
                color: Colors.white,
                weight: FontWeight.w500,
                align: TextAlign.center,
                maxLines: 2,
              ),
            ),
          Positioned(
            left: 46,
            top: buttonTop,
            width: 268,
            height: 64,
            child: PCGreenDialogButton(text: buttonText, onTap: onButtonTap),
          ),
          Positioned(
            right: 8,
            top: 0,
            width: 48,
            height: 48,
            child: PCDialogCloseButton(
              onTap: onClose ?? () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用提示弹窗的缩放容器，按 360 设计宽度适配安全区域。
class PCResponsiveDialog extends StatelessWidget {
  const PCResponsiveDialog({
    super.key,
    required this.designHeight,
    required this.child,
  });

  final double designHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = max(0.0, constraints.maxWidth - 8);
          final availableHeight = max(0.0, constraints.maxHeight - 16);
          final scale = PCAdaptiveLayout.fitScale(
            width: availableWidth,
            height: availableHeight,
            designHeight: designHeight,
          );

          return Center(
            child: SizedBox(
              width: 360 * scale,
              height: designHeight * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(width: 360, height: designHeight, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 通用提示弹窗的图标裁剪组件，保留各状态图标的偏移和尺寸。
class PCFigmaIcon extends StatelessWidget {
  const PCFigmaIcon({
    super.key,
    required this.name,
    required this.imageSize,
    required this.imageLeft,
    required this.imageTop,
  });

  final String name;
  final double imageSize;
  final double imageLeft;
  final double imageTop;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned(
            left: imageLeft,
            top: imageTop,
            width: imageSize,
            height: imageSize,
            child: PCImg(name: name, fit: BoxFit.fill),
          ),
        ],
      ),
    );
  }
}

/// 通用提示弹窗的绿色主操作按钮。
class PCGreenDialogButton extends StatelessWidget {
  const PCGreenDialogButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_btn_bg')),
          PCStrokeText(
            text: text,
            size: 24,
            color: Colors.white,
            weight: FontWeight.w800,
            skWidth: 2.5,
            skColor: const Color(0xFF173600),
          ),
        ],
      ),
    );
  }
}

/// 通用提示弹窗的关闭按钮，提供 48 像素布局内的点击区域。
class PCDialogCloseButton extends StatelessWidget {
  const PCDialogCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const Center(
        child: PCImg(
          name: 'pc_closes_btn',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
