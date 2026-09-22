import 'dart:math';
import 'package:app_settings/app_settings.dart';
import 'package:fl_toast/fl_toast.dart';
import 'package:flutter/material.dart';

import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';

enum ToolType { notice, nowifi, loadfaild, limted }

class PCDialogTool {
  // tosat
  static void toast(BuildContext buildContext, String text) async {
    await showAndroidToast(
      padding: 0.0.all(16),
      margin: 0.0.all(32),
      alignment: Alignment.center,
      backgroundColor: '#000000'.color(opacity: 0.8),
      duration: Duration(seconds: 2),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      context: buildContext,
    );
  }

  static void toastRanking(BuildContext buildContext, int num) async {
    await showAndroidToast(
      padding: 0.0.all(0),
      margin: 0.0.all(0),
      backgroundColor: Colors.transparent,
      alignment: Alignment.center,
      duration: Duration(seconds: 3),
      child: Container(
        width: 205,
        height: 50.5,
        decoration: BoxDecoration(
          color: '#000000'.color(opacity: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: 'Your Current rank: ',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: '$num',
                  style: TextStyle(color: '#16FF16'.color(), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      context: buildContext,
    );
  }
}

// 广告加载失败弹窗：支持关闭和重新加载回调。
class PCAdLoadingFailedDialog extends StatelessWidget {
  const PCAdLoadingFailedDialog({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _PCAdStatusDialog(
      titleAssetName: 'pc_ad_load_title_2x',
      iconName: 'pc_ad_load_failed_2x',
      canvasHeight: 428,
      panelHeight: 304,
      buttonTop: 340,
      iconWidth: 160,
      iconHeight: 160,
      iconLeft: 100,
      iconTop: 160,
      imageSize: 218,
      imageLeft: -28,
      imageTop: -19,
      buttonText: 'Try Again',
      onButtonTap: () {
        Navigator.of(context).pop();
        onRetry?.call();
      },
    );
  }
}

// 无网络弹窗：提示用户检查网络后关闭当前弹窗。
class PCNoNetworkDialog extends StatelessWidget {
  const PCNoNetworkDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return _PCAdStatusDialog(
      titleAssetName: 'pc_no_network_title_2x',
      iconName: 'pc_no_network_2x',
      canvasHeight: 428,
      panelHeight: 304,
      buttonTop: 340,
      iconWidth: 160,
      iconHeight: 160,
      iconLeft: 100,
      iconTop: 160,
      imageSize: 215,
      imageLeft: -27,
      imageTop: -26,
      buttonText: 'Got It',
      onButtonTap: () => Navigator.of(context).pop(),
    );
  }
}

// 广告观看次数达到上限弹窗。
class PCAdLimitReachedDialog extends StatelessWidget {
  const PCAdLimitReachedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return _PCAdStatusDialog(
      titleAssetName: 'pc_ad_limit_title_2x',
      iconName: 'pc_ad_limit_2x',
      canvasHeight: 472,
      panelHeight: 348,
      buttonTop: 384,
      iconWidth: 188,
      iconHeight: 160,
      iconLeft: 86,
      iconTop: 160,
      imageSize: 218,
      imageLeft: -15,
      imageTop: -19,
      description:
          "You've watched all available ads for today.\nTry again tomorrow.",
      descriptionTop: 324,
      buttonText: 'Got It',
      onButtonTap: () => Navigator.of(context).pop(),
    );
  }
}

// 推送通知引导弹窗：跳转到系统通知权限设置页。
class PCPushNotificationDialog extends StatelessWidget {
  const PCPushNotificationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return _PCResponsiveDialog(
      designHeight: 348,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 20,
            top: 4,
            width: 320,
            height: 344,
            child: PCImg(name: 'pc_guide3_bg'),
          ),
          const Positioned(
            left: 100,
            top: 20,
            width: 160,
            height: 160,
            child: _PCFigmaIcon(
              name: 'pc_push_notice_2x',
              imageSize: 234,
              imageLeft: -34,
              imageTop: -34,
            ),
          ),
          const Positioned(
            left: 34,
            right: 34,
            top: 184,
            height: 28,
            child: Center(
              child: PCStrokeText(
                text: 'Turn On Push Notifications',
                size: 20,
                color: Color(0xFFFFF28B),
                weight: FontWeight.w900,
                align: TextAlign.center,
                skWidth: 1.2,
                skColor: Color(0xFF285200),
              ),
            ),
          ),
          const Positioned(
            left: 44,
            top: 220,
            width: 272,
            height: 20,
            child: PCText(
              text: 'open the notification to receive cash',
              size: 14,
              color: Colors.white,
              weight: FontWeight.w500,
              align: TextAlign.center,
            ),
          ),
          Positioned(
            left: 46,
            top: 260,
            width: 268,
            height: 64,
            child: _PCGreenDialogButton(
              text: 'Go And Open',
              onTap: () => AppSettings.openAppSettings(
                type: AppSettingsType.notification,
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: -4,
            width: 48,
            height: 48,
            child: _PCDialogCloseButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PCAdStatusDialog extends StatelessWidget {
  const _PCAdStatusDialog({
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

  @override
  Widget build(BuildContext context) {
    return _PCResponsiveDialog(
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
            child: _PCFigmaIcon(
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
            child: _PCGreenDialogButton(text: buttonText, onTap: onButtonTap),
          ),
          Positioned(
            right: 8,
            top: 0,
            width: 48,
            height: 48,
            child: _PCDialogCloseButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PCResponsiveDialog extends StatelessWidget {
  const _PCResponsiveDialog({required this.designHeight, required this.child});

  final double designHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = max(0.0, constraints.maxWidth - 8);
          final availableHeight = max(0.0, constraints.maxHeight - 16);
          final scale = min(
            min(availableWidth / 360, availableHeight / designHeight),
            1.2,
          ).clamp(0.1, 1.2).toDouble();

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

class _PCFigmaIcon extends StatelessWidget {
  const _PCFigmaIcon({
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

class _PCGreenDialogButton extends StatelessWidget {
  const _PCGreenDialogButton({required this.text, required this.onTap});

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

class _PCDialogCloseButton extends StatelessWidget {
  const _PCDialogCloseButton({required this.onTap});

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
