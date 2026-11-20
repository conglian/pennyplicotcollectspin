import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../PCMainVC/PCQuizContentPanel.dart';
import '../../PCTool/PCAdaptiveLayout.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/PCAudioUtils.dart';
import '../../PCTool/pc_text.dart';
import 'PCGuideIdentity.dart';

/// 新用户三题引导（Answer & Unlock），与实际 Quiz 页面共用题板布局。
///
/// 读取页面题板的真实位置，题目、底板和选项保持重合；仅答案区域可点击。
/// 每题只接受一次点击，显示对错1秒后返回；由控制器安排领奖或下一题。
class PCGuideQuizDialog extends StatefulWidget {
  const PCGuideQuizDialog({
    super.key,
    required this.index,
    this.onAnswerSelected,
  });
  final int index;
  final ValueChanged<bool>? onAnswerSelected;

  /// 大屏题板可滚动，展示遮罩前先将真实题板完整移入可见区域。
  /// 仅由展示入口调用一次；不在build或动画帧内改变底层滚动位置。
  static Future<void> prepareForPresentation() async {
    await WidgetsBinding.instance.endOfFrame;
    final anchorContext = pcQuizContentTargetKey.currentContext;
    if (anchorContext == null || !anchorContext.mounted) return;
    if (Scrollable.maybeOf(anchorContext) == null) return;
    await Scrollable.ensureVisible(
      anchorContext,
      alignment: 1,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  static const questions = [
    ('Who gives you money here?', 'Advertisers', 'Other players'),
    (
      'When can you withdraw your cash?',
      'When you get a Golden Pig',
      'Any time',
    ),
    (
      'What’s the fastest way to fill your PiggyBoost?',
      'Watch more ads',
      'Wait without playing',
    ),
  ];

  @override
  State<PCGuideQuizDialog> createState() => _PCGuideQuizDialogState();
}

class _PCGuideQuizDialogState extends State<PCGuideQuizDialog> {
  Rect? _panel;
  Size? _lastSize;
  bool? _selected;
  Timer? _feedbackTimer;
  Timer? _hintTimer;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _selected == null) setState(() => _showHint = true);
    });
  }

  void _answer(bool first) {
    if (_selected != null) return;
    unawaited(PCAudioUtils().playQuizOptionAudio());
    PCAnalytics.event('new_quiz_guide_c');
    _hintTimer?.cancel();
    setState(() => _selected = first);
    widget.onAnswerSelected?.call(first);
    final route = ModalRoute.of(context);
    _feedbackTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && route?.isCurrent == true) Navigator.of(context).pop(first);
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (size == _lastSize) return;
    _lastSize = size;
    _panel = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor = pcQuizContentTargetKey.currentContext?.findRenderObject();
      if (anchor is RenderBox && anchor.attached && anchor.hasSize) {
        setState(
          () => _panel = anchor.localToGlobal(Offset.zero) & anchor.size,
        );
      }
    });
  }

  Rect _fallbackPanel(Size size) {
    final sx = size.width / 375;
    final sy = math.min(size.height / 812, (size.height - 81 - 48) / 636);
    return Rect.fromLTWH(
      (size.width - PCQuizContentPanel.designWidth * sx) * .5,
      196 * sy + 48,
      PCQuizContentPanel.designWidth * sx,
      PCQuizContentPanel.designHeight * sy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panel = _panel ?? _fallbackPanel(size);
    final question = PCGuideQuizDialog.questions[widget.index];
    final safeTop = MediaQuery.paddingOf(context).top + 8;
    final headerScale = math.min(
      1.15,
      math.min(
        (size.width - 32) / 300,
        math.max(1.0, panel.top - safeTop - 12) / 202,
      ),
    );
    final wideHeader = size.width >= 600;
    final headerWidth = wideHeader ? size.width - 32 : 300 * headerScale;
    final headerHeight = wideHeader
        ? math.max(1.0, panel.top - safeTop - 12)
        : 202 * headerScale;

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: (size.width - headerWidth) * .5,
            top: panel.top - 12 - headerHeight,
            width: headerWidth,
            height: headerHeight,
            child: wideHeader
                ? _WideQuizInstructions(
                    scale: PCAdaptiveLayout.widthScale(
                      size.width,
                      designWidth: 375,
                    ),
                  )
                : const FittedBox(
                    key: ValueKey('pcQuizGuideInstructions'),
                    child: SizedBox(
                      width: 300,
                      height: 202,
                      child: _QuizInstructions(),
                    ),
                  ),
          ),
          Positioned.fromRect(
            rect: panel,
            child: SizedBox.expand(
              key: const ValueKey('pcQuizGuidePanel'),
              child: PCQuizContentPanel(
                question: question.$1,
                optionA: question.$2,
                optionB: question.$3,
                category: '${widget.index + 1} / 3',
                questionFontSize: 18,
                selectedAnswer: _selected,
                hintAnswer: _showHint && _selected == null ? true : null,
                answerCorrect: _selected == null ? null : _selected == true,
                enabled: _selected == null,
                onAnswer: _answer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 题板上方的引导说明，按实际剩余空间等比缩放，避开题板和安全区域。
class _QuizInstructions extends StatelessWidget {
  const _QuizInstructions();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 24,
        top: 32,
        width: 260,
        height: 170,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE09A46), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF6D5), Color(0xFFFFE59A)],
            ),
          ),
          child: const PCText(
            text:
                "Answer & Unlock!\nAdvertisers want to confirm you're real.\n🎁 Pass their quiz = Unlock withdrawal access!\n👉 Start now – only 3 easy questions!",
            size: 13,
            color: Color(0xFF9B620C),
            weight: FontWeight.w500,
            height: 18 / 13,
            maxLines: 7,
          ),
        ),
      ),
      const Positioned(
        left: 44,
        top: 8,
        child: PCImg(name: pcGuideAvatarAsset, width: 48, height: 48),
      ),
      const Positioned(
        left: 48,
        top: 0,
        child: PCImg(name: 'pc_wheel_guide_crown', width: 20, height: 20),
      ),
    ],
  );
}

/// 宽屏说明卡利用横向空间排版，避免被题板上方高度压成小字号。
class _WideQuizInstructions extends StatelessWidget {
  const _WideQuizInstructions({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) => Stack(
    key: const ValueKey('pcQuizGuideInstructions'),
    children: [
      Positioned(
        left: 0,
        right: 0,
        top: 32,
        bottom: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE09A46), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF6D5), Color(0xFFFFE59A)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: PCText(
                    text:
                        "Answer & Unlock!\nAdvertisers want to confirm you're real.\n🎁 Pass their quiz = Unlock withdrawal access!\n👉 Start now – only 3 easy questions!",
                    size: 13 * scale,
                    height: 18 / 13,
                    color: const Color(0xFF9B620C),
                    weight: FontWeight.w500,
                    maxLines: 5,
                    align: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const Positioned(
        left: 24,
        top: 8,
        child: PCImg(name: pcGuideAvatarAsset, width: 48, height: 48),
      ),
      const Positioned(
        left: 28,
        top: 0,
        child: PCImg(name: 'pc_wheel_guide_crown', width: 20, height: 20),
      ),
    ],
  );
}
