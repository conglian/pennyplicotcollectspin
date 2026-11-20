import '../../PCTool/PCWithdrawValidation.dart';
import '../../PCTool/PCAnalytics.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../PCTool/pc_GradientText.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_stroke_text.dart';
import '../../PCTool/pc_text.dart';
import 'PCOtherDialogWidgets.dart';

/// 3.7 答题审核排行弹窗（Top Answerer，Figma 211:838）。
/// 背景铺满屏幕；本人从第 3/4 行升至第一后循环放大缩小，其他资料由 seed 固定。
/// Keep Answer, Speed Cash 返回 true，由宿主关闭后切答题；右上关闭仅收起，不改答题次数。
class PCQuizRankingDialog extends StatefulWidget {
  const PCQuizRankingDialog({
    super.key,
    required this.answerCount,
    required this.account,
    required this.seed,
  });
  final int answerCount;
  final String account;
  final int seed;

  @override
  State<PCQuizRankingDialog> createState() => _PCQuizRankingDialogState();
}

class _PCQuizRankingDialogState extends State<PCQuizRankingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final List<_RankingPerson> _people;
  Timer? _nextStep;
  bool _started = false;
  bool _reduceMotion = false;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    final random = math.Random(widget.seed);
    final count = math.max(0, widget.answerCount);
    final others = List.generate(
      3,
      (index) => _RankingPerson(
        id: 'other$index',
        account: _randomAccount(random),
        count: math.max(0, count - (3 + random.nextInt(4))),
        avatar:
            'pc_rank_avatar_${(1 + random.nextInt(54)).toString().padLeft(2, '0')}',
      ),
    )..sort((a, b) => b.count.compareTo(a.count));
    _people = others
      ..insert(
        2 + random.nextInt(2),
        _RankingPerson(
          id: 'self',
          account: PCWithdrawValidation.displayAccount(
            widget.account,
            fallback: 'Me',
          ),
          count: count,
          avatar: 'pc_guide_intro_user',
          isSelf: true,
        ),
      );
  }

  String _randomAccount(math.Random random) =>
      'player${1000 + random.nextInt(9000)}@example.com';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _moveToFirst();
      _pulse.value = .6;
    } else {
      _scheduleMove();
    }
  }

  void _moveToFirst() {
    final self = _people.removeAt(
      _people.indexWhere((person) => person.isSelf),
    );
    _people.insert(0, self);
  }

  void _scheduleMove() {
    _nextStep = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final index = _people.indexWhere((person) => person.isSelf);
      if (index == 0) return;
      setState(() {
        final self = _people.removeAt(index);
        _people.insert(index - 1, self);
      });
      if (index > 1) _scheduleMove();
    });
  }

  void _startCelebration() {
    // AnimatedPositioned 的最后一步真正结束后才开始缩放，不在上移途中闪动。
    if (!mounted || _reduceMotion || _celebrating || !_people.first.isSelf) {
      return;
    }
    _celebrating = true;
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _nextStep?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: SizedBox.expand(
                key: ValueKey('pcQuizRankFullscreenBackground'),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AspectRatio(
                    aspectRatio: 360 / 200,
                    child: PCImg(
                      key: ValueKey('pcQuizRankFireworks'),
                      name: 'pc_process_rank_glow',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
              ),
            ),
          ),
          PCResponsiveDialog(
            designHeight: 780,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(
                  left: 20,
                  right: 20,
                  top: 120,
                  height: 40,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PCGradientText(
                      'Top Answerer',
                      fontSize: 32,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFE449),
                          Color(0xFFFFF8CD),
                          Color(0xFFFFE02E),
                          Color(0xFFFF8F07),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  right: 20,
                  top: 164,
                  height: 28,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PCGradientText(
                      'Withdrawal Made Easy!!',
                      fontSize: 20,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFE449),
                          Color(0xFFFFF8CD),
                          Color(0xFFFFE02E),
                          Color(0xFFFF8F07),
                        ],
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < _people.length; index++)
                  AnimatedPositioned(
                    key: ValueKey('pcQuizRankPosition_${_people[index].id}'),
                    left: 20,
                    top: 232.0 + 88 * index,
                    width: 320,
                    height: 72,
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    onEnd: _people[index].isSelf && index == 0
                        ? _startCelebration
                        : null,
                    child: _RankingRow(
                      person: _people[index],
                      pulse: _pulse,
                      reduceMotion: _reduceMotion,
                    ),
                  ),
                Positioned(
                  left: 46,
                  top: 596,
                  width: 268,
                  height: 64,
                  child: ParticleButton(
                    key: const ValueKey('pcQuizRankContinue'),
                    onTap: () {
                      PCAnalytics.event('process_rank_pop_c');
                      Navigator.of(context).pop(true);
                    },
                    child: const SizedBox.expand(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: PCImg(
                              key: ValueKey('pcQuizRankButtonBackground'),
                              name: 'pc_btn_bg',
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: PCStrokeText(
                                text: 'Keep Answer, Speed Cash',
                                size: 18,
                                color: Colors.white,
                                weight: FontWeight.w700,
                                skWidth: 2,
                                skColor: Color(0xFF173600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 56,
                  width: 48,
                  height: 48,
                  child: PCDialogCloseButton(
                    onTap: () {
                      PCAnalytics.event('process_rank_pop_close');
                      Navigator.of(context).pop(false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RankingPerson {
  const _RankingPerson({
    required this.id,
    required this.account,
    required this.count,
    required this.avatar,
    this.isSelf = false,
  });
  final String id;
  final String account;
  final int count;
  final String avatar;
  final bool isSelf;
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.person,
    required this.pulse,
    required this.reduceMotion,
  });
  final _RankingPerson person;
  final Animation<double> pulse;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (_, child) => Transform.scale(
      key: ValueKey('pcQuizRankScale_${person.id}'),
      scale: person.isSelf && !reduceMotion
          ? 1 + .04 * Curves.easeInOutSine.transform(pulse.value)
          : 1,
      child: Container(
        key: ValueKey('pcQuizRankRow_${person.id}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: person.isSelf
                ? const Color(0xFFFFE54E)
                : const Color(0xFFFFD75F),
            width: person.isSelf ? 2 : 1,
          ),
          gradient: LinearGradient(
            colors: person.isSelf
                ? const [
                    Color(0xFFF3B808),
                    Color(0xFFE94819),
                    Color(0xFFD61C16),
                  ]
                : const [Color(0xFFCA7F07), Color(0xFFAA450B)],
          ),
          boxShadow: person.isSelf
              ? [
                  BoxShadow(
                    color: const Color(
                      0xFFFFE54E,
                    ).withValues(alpha: .25 + .4 * pulse.value),
                    blurRadius: 4 + 6 * pulse.value,
                    spreadRadius: .5,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
            ),
            clipBehavior: Clip.antiAlias,
            child: PCImg(name: person.avatar, fit: BoxFit.cover),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PCText(
                text: person.account,
                size: 14,
                color: Colors.white,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 132,
            height: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PCText(
                    text: 'Answer ',
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                  PCText(
                    text: '${person.count}',
                    size: 24,
                    color: const Color(0xFFFFDD1D),
                    weight: FontWeight.w700,
                  ),
                  const PCText(
                    text: ' Right',
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
