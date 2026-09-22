import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pennypilotcollectspin/PCTool/pc_stroke_text.dart';
import 'package:pennypilotcollectspin/PCTool/pc_text.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PCTool/pc_LocalProvider.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/pc_img.dart';
import '../PCTool/pc_shou_icon.dart';
import '../PCBasic/PCTbaBar.dart';
import '../PCTool/PCQuizBank.dart';

final GlobalKey<PCQuizState> homeKey = GlobalKey<PCQuizState>();

class PCQuiz extends StatefulWidget {
  PCQuiz({super.key});

  @override
  State<PCQuiz> createState() => PCQuizState();
}

class PCQuizState extends State<PCQuiz> with SingleTickerProviderStateMixin {
  PCQuizBank? _quizBank;
  @override
  void initState() {
    super.initState();

    _loadQuizBank();
  }

  Future<void> _loadQuizBank() async {
    final bank = await PCQuizBank.load();
    if (!mounted) return;
    setState(() => _quizBank = bank);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PCLocalProvider>(
        builder: (context, provider, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              PCImg(
                name: 'pc_quiz_bg',
                width: 0.width(context),
                height: 0.height(context),
              ),
              Column(
                children: [
                  SizedBox(height: 64.h),
                  Container(
                    width: 328.w,
                    height: 108.h,
                    decoration: BoxDecoration(image: PCDImg('pc_quiz_top_bg')),
                    child: _topBalaceWidget(provider),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: 0.width(context),
                    height: 48,
                    child: _QuizProgressTimeline(
                      answeredCount: provider.pc_quiz_all_num,
                      onMilestoneTap: (index) => _openWheel(provider, index),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: 334.w,
                    height: 440.h,
                    decoration: BoxDecoration(
                      image: PCDImg('pc_quiz_content_bg'),
                    ),
                    child: _quizContenWidget(provider),
                  ),
                ],
              ),
              Positioned(
                top: 50.h,
                right: 20.w,
                child: Container(
                  width: 175.w,
                  height: 44.h,
                  decoration: BoxDecoration(image: PCDImg('pc_quiz_top_tips')),
                  child: Center(
                    child: PCText(
                      text: 'Super Easy Cash Today!',
                      size: 14,
                      color: '#9B620C'.color(),
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 50.h + 44.h,
                right: 160.w,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    image: PCDImg('pc_quiz_top_tips_bottom'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 顶部余额栏
  Widget _topBalaceWidget(PCLocalProvider provider) {
    const double withdrawTarget = 100;
    final double balance = provider.pc_dollar_number;
    final double remaining = math.max(0, withdrawTarget - balance);
    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'My Account: ',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: '\$${0.to2Double(provider.pc_dollar_number)}',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: '#FFD21C'.color(),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: .center,
          children: [
            Container(
              width: 232.w,
              height: 16.h,
              decoration: BoxDecoration(image: PCDImg('pc_quiz_top_pro')),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.h),
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1,
                        child: ColoredBox(color: '#FFDD1E'.color()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Container(
              width: 68.w,
              height: 24.h,
              decoration: BoxDecoration(image: PCDImg('pc_act_s_0')),
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  PCImg(name: 'pc_act_0', width: 16, height: 16),
                  SizedBox(width: 6.w),
                  PCText(
                    text: '\$100',
                    size: 14,
                    color: '#FFFFFF'.color(),
                    weight: FontWeight.w900,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: '#C87B7D'.color(),
              height: 1.15,
              fontFamily: 'CarlsbergSansBlack',
            ),
            children: [
              const TextSpan(text: 'Only \$'),
              TextSpan(
                text: remaining.toStringAsFixed(1),
                style: TextStyle(color: '#FFDD1D'.color()),
              ),
              const TextSpan(text: ' Left To Withdraw \$100'),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }

  // 答题内容
  Future<void> _recordAnswer(PCLocalProvider provider) async {
    final int nextCount = provider.pc_quiz_all_num + 1;
    final totalQuestions = _quizBank?.totalLength ?? 1;
    final int nextQuestion =
        ((provider.pc_quiz_num_index % totalQuestions) + 1) % totalQuestions;
    provider.pc_quiz_all_num = nextCount;
    provider.pc_quiz_num_index = nextQuestion;
    if (mounted) {
      setState(() {});
    }
    await provider.updateint(provider.pc_quiz_all_numName, nextCount);
    await provider.updateint(provider.pc_quiz_num_indexName, nextQuestion);
  }

  Future<void> _openWheel(PCLocalProvider provider, int index) async {
    await provider.updateint(provider.pc_quiz_tap_indexName, index);
    if (mounted) {
      PigsTabController.switchTo(2);
    }
  }

  Widget _quizContenWidget(PCLocalProvider provider) {
    final bank = _quizBank;
    if (bank == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final question = bank.questionAt(provider.pc_quiz_num_index);
    final category = bank.categoryAt(provider.pc_quiz_num_index);
    return Column(
      children: [
        SizedBox(height: 88.h),
        Container(
          width: 288.w,
          height: 172.h,
          decoration: BoxDecoration(image: PCDImg('pc_quiz_c_center')),
          child: Center(
            child: PCText(
              text: question.question,
              size: 16.sp,
              color: '#FFFFFF'.color(),
              weight: FontWeight.w600,
              align: .center,
              maxLines: 5,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        PCText(
          text: category,
          size: 12,
          color: '#FFE888'.color(),
          weight: FontWeight.w600,
        ),
        SizedBox(height: 8.h),
        _answerButton(provider, question.a, 'a'),
        SizedBox(height: 18.h),
        _answerButton(provider, question.b, 'b'),
      ],
    );
  }

  Widget _answerButton(PCLocalProvider provider, String label, String option) {
    return ParticleButton(
      child: SizedBox(
        width: 268.w,
        height: 58.h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(image: PCDImg('pc_quiz_btn')),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: PCStrokeText(
                  text: label,
                  size: 20.sp,
                  color: '#FFFFFF'.color(),
                  weight: FontWeight.w700,
                  skWidth: 1,
                  skColor: '#035297'.color(),
                ),
              ),
            ),
            if (option == 'a')
              const Positioned(right: -12, bottom: -12, child: PCShouIcon()),
          ],
        ),
      ),
      onTap: () => _recordAnswer(provider),
    );
  }
}

class _QuizProgressTimeline extends StatefulWidget {
  const _QuizProgressTimeline({
    required this.answeredCount,
    required this.onMilestoneTap,
  });

  final int answeredCount;
  final ValueChanged<int> onMilestoneTap;

  @override
  State<_QuizProgressTimeline> createState() => _QuizProgressTimelineState();
}

class _QuizProgressTimelineState extends State<_QuizProgressTimeline> {
  static const int _milestoneCount = 100;
  static const double _itemWidth = 96;
  static const double _sidePadding = 64;
  static const String _clickedMilestonesKey = 'pc_quiz_clicked_wheels';

  late final ScrollController _scrollController;
  final Set<int> _clickedMilestones = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadClickedMilestones();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToProgress(animate: false);
    });
  }

  Future<void> _loadClickedMilestones() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<int> saved = (prefs.getStringList(_clickedMilestonesKey) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .where((index) => index >= 0 && index < _milestoneCount)
        .toList();
    if (!mounted || saved.isEmpty) {
      return;
    }
    setState(() {
      _clickedMilestones.addAll(saved);
    });
  }

  Future<void> _saveClickedMilestones() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<int> values = _clickedMilestones.toList()..sort();
    await prefs.setStringList(
      _clickedMilestonesKey,
      values.map((index) => index.toString()).toList(),
    );
  }

  @override
  void didUpdateWidget(covariant _QuizProgressTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answeredCount != widget.answeredCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToProgress();
      });
    }
  }

  void _scrollToProgress({bool animate = true}) {
    if (!_scrollController.hasClients) {
      return;
    }

    final double itemWidth = _itemWidth.w;
    final double sidePadding = _sidePadding.w;
    final double viewportWidth = 328.w;
    final int currentIndex = ((widget.answeredCount - 2) / 3).round().clamp(
      0,
      _milestoneCount - 1,
    );
    final double target =
        currentIndex * itemWidth -
        ((viewportWidth - itemWidth) / 2 - sidePadding);
    final double offset = target.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double itemWidth = _itemWidth.w;
    final double sidePadding = _sidePadding.w;
    final double contentWidth =
        (sidePadding * 2) + (itemWidth * _milestoneCount);
    final int answered = widget.answeredCount.clamp(0, 300);

    return Center(
      child: SizedBox(
        width: 328.w,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PCImg(name: 'pc_quiz_pro_bg', width: 328.w, height: 20),
            ClipRect(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: contentWidth,
                  height: 48,
                  child: Stack(
                    children: [
                      _buildLeadingProgress(answered, sidePadding, itemWidth),
                      ...List.generate(
                        _milestoneCount,
                        (index) => _buildMilestone(
                          index,
                          answered,
                          sidePadding,
                          itemWidth,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingProgress(
    int answered,
    double sidePadding,
    double itemWidth,
  ) {
    final double progress = (answered / 2).clamp(0.0, 1.0).toDouble();
    const double progressHeight = 12;
    const double trackInset = 2;
    return Positioned(
      left: trackInset,
      top: (48 - progressHeight) / 2,
      width: sidePadding + (itemWidth / 2) - trackInset,
      height: progressHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: '#27D31D'.color(),
              borderRadius: BorderRadius.circular(progressHeight / 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestone(
    int index,
    int answered,
    double sidePadding,
    double itemWidth,
  ) {
    final int milestone = 2 + (index * 3);
    final bool unlocked = answered >= milestone;
    final bool showGlow = unlocked && !_clickedMilestones.contains(index);
    final double left = sidePadding + (index * itemWidth);
    final double segmentProgress = ((answered - milestone) / 3)
        .clamp(0.0, 1.0)
        .toDouble();

    return Positioned(
      left: left,
      top: 0,
      width: itemWidth,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (index < _milestoneCount - 1)
            Positioned(
              left: itemWidth / 2,
              top: (48 - 12) / 2,
              width: itemWidth,
              height: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: segmentProgress,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: '#27D31D'.color(),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ParticleButton(
              size: 48,
              onTap: () {
                if (!unlocked || _clickedMilestones.contains(index)) {
                  return;
                }
                setState(() {
                  _clickedMilestones.add(index);
                });
                _saveClickedMilestones();
                widget.onMilestoneTap(index);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (showGlow)
                    Positioned(
                      left: (itemWidth - 54.w) / 2,
                      top: -7,
                      width: 54.w,
                      height: 54,
                      child: const _QuizRotatingGlow(),
                    ),
                  Positioned(
                    left: (itemWidth - 40.w) / 2,
                    top: 0,
                    width: 40.w,
                    height: 40.w,
                    child: PCImg(
                      name: unlocked ? 'pc_quiz_wheel_s' : 'pc_quiz_wheel_n',
                      width: 40.w,
                      height: 40.w,
                    ),
                  ),
                  Positioned(
                    left: (itemWidth - 40.w) / 2,
                    top: 31,
                    width: 40.w,
                    height: 16,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PCImg(
                          name: 'pc_quiz_wheel_bottom_icon',
                          width: 40.w,
                          height: 16,
                        ),
                        PCStrokeText(
                          text: '$milestone',
                          size: 9,
                          color: Colors.white,
                          weight: FontWeight.w800,
                          skWidth: 0.8,
                          skColor: '#4A1200'.color(),
                        ),
                      ],
                    ),
                  ),
                  if (showGlow)
                    const Positioned(
                      right: 4,
                      top: 0,
                      child: PCShouIcon(size: 50),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizRotatingGlow extends StatefulWidget {
  const _QuizRotatingGlow();

  @override
  State<_QuizRotatingGlow> createState() => _QuizRotatingGlowState();
}

class _QuizRotatingGlowState extends State<_QuizRotatingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: PCImg(name: 'pc_quiz_guang_icon', width: 54.w, height: 54.w),
    );
  }
}
