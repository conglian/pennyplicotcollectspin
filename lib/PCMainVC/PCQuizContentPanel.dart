import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_shou_icon.dart';
import '../PCTool/pc_stroke_text.dart';
import '../PCTool/pc_text.dart';

/// 实际答题板的布局锚点，供新用户引导读取屏幕上的位置和尺寸。
final GlobalKey pcQuizContentTargetKey = GlobalKey(debugLabel: 'pcQuizContent');

/// Quiz 页面与三题引导共用的题板、题目和选项，按同一设计坐标适配大小屏。
class PCQuizContentPanel extends StatelessWidget {
  const PCQuizContentPanel({
    super.key,
    required this.question,
    this.optionA = '',
    this.optionB = '',
    this.category = '',
    this.onAnswer,
    this.questionFontSize = 18,
    this.hintAnswer = true,
    this.selectedAnswer,
    this.answerCorrect,
    this.enabled = true,
    this.onResumeReward,
    this.resumeLabel = 'Claim Reward',
    this.showResumeHint = false,
  });

  static const designWidth = 334.0;
  static const designHeight = 440.0;

  final String? question;
  final String optionA;
  final String optionB;
  final String category;
  final ValueChanged<bool>? onAnswer;
  final double questionFontSize;
  final bool? hintAnswer;
  final bool? selectedAnswer;
  final bool? answerCorrect;
  final bool enabled;
  final VoidCallback? onResumeReward;
  final String resumeLabel;
  final bool showResumeHint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sx = constraints.maxWidth / designWidth;
      final sy = constraints.maxHeight / designHeight;
      final textScale = math.min(sx, sy);

      Widget answer(String text, bool first) => Positioned(
        left: 33 * sx,
        top: (first ? 264 : 340) * sy,
        width: 268 * sx,
        height: 58 * sy,
        child: ParticleButton(
          enabled: enabled && onAnswer != null,
          onTap: () => onAnswer?.call(first),
          child: SizedBox.expand(
            key: ValueKey(first ? 'pcQuizAnswerA' : 'pcQuizAnswerB'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 14 * sx,
                      right:
                          (hintAnswer == first || selectedAnswer == first
                              ? 42
                              : 14) *
                          sx,
                    ),
                    // 对错反馈复用设计中的独立金边按钮，文字和状态图标保持原生绘制。
                    decoration: BoxDecoration(
                      image: PCDImg(
                        selectedAnswer != first
                            ? 'pc_quiz_btn'
                            : answerCorrect == true
                            ? 'pc_quiz_answer_correct'
                            : 'pc_quiz_answer_wrong',
                      ),
                    ),
                    alignment: Alignment.center,
                    child: PCStrokeText(
                      text: text,
                      size: 22 * textScale,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      maxLines: 2,
                      skWidth: 1,
                      skColor: selectedAnswer != first
                          ? const Color(0xFF035297)
                          : answerCorrect == true
                          ? const Color(0xFF173600)
                          : const Color(0xFF67001B),
                    ),
                  ),
                ),
                if (selectedAnswer == first)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        key: ValueKey(
                          answerCorrect == true
                              ? 'pcQuizCorrect'
                              : 'pcQuizWrong',
                        ),
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 16 * sx),
                        child: Icon(
                          answerCorrect == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 28 * textScale,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (hintAnswer == first && selectedAnswer == null)
                  Positioned(
                    right: -12 * sx,
                    bottom: -12 * sy,
                    child: IgnorePointer(
                      child: PCShouIcon(size: 60 * textScale),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      return Stack(
        children: [
          const Positioned.fill(child: PCImg(name: 'pc_quiz_content_bg')),
          if (question == null)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else ...[
            Positioned(
              left: 23 * sx,
              top: 88 * sy,
              width: 288 * sx,
              height: 140 * sy,
              child: Container(
                key: const ValueKey('pcQuizQuestion'),
                padding: EdgeInsets.symmetric(horizontal: 12 * sx),
                decoration: BoxDecoration(image: PCDImg('pc_quiz_c_center')),
                alignment: Alignment.center,
                child: PCText(
                  text: question!,
                  size: questionFontSize * textScale,
                  color: Colors.white,
                  weight: FontWeight.w600,
                  align: TextAlign.center,
                  maxLines: 5,
                ),
              ),
            ),
            answer(optionA, true),
            answer(optionB, false),
            if (onResumeReward != null)
              Positioned(
                left: 65 * sx,
                right: 65 * sx,
                bottom: 4 * sy,
                height: 29 * sy,
                child: ParticleButton(
                  key: const ValueKey('pcQuizResumeReward'),
                  breathing: resumeLabel.toLowerCase().contains('claim'),
                  onTap: onResumeReward!,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF078C19),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: PCText(
                          text: resumeLabel,
                          size: 15 * textScale,
                          color: Colors.white,
                          weight: FontWeight.w800,
                        ),
                      ),
                      if (showResumeHint)
                        Positioned(
                          key: const ValueKey('pcQuizResumeHint'),
                          right: -18 * sx,
                          bottom: -8 * sy,
                          child: IgnorePointer(
                            child: PCShouIcon(size: 44 * textScale),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}
