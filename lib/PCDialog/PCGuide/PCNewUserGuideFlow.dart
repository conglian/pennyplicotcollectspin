import 'dart:async';

import 'package:flutter/material.dart';

import '../../PCTool/PCNewUserGuideController.dart';
import '../../PCTool/PCAnalytics.dart';
import '../../PCTool/pc_extension_help.dart';
import '../../PCTool/pc_img.dart';
import '../../PCTool/pc_text.dart';
import '../PCOther/PCDialogTool.dart';
import 'PCGuide1Page.dart';
import 'PCGuide2Page.dart';
import 'PCGuide3Page.dart';

/// 承载引导1–3：页面只发出点击事件，控制器决定下一步并持久化进度。
class PCNewUserGuideFlow extends StatefulWidget {
  const PCNewUserGuideFlow({
    super.key,
    required this.onCompleted,
    this.controller,
  });

  final VoidCallback onCompleted;
  final PCNewUserGuideController? controller;

  @override
  State<PCNewUserGuideFlow> createState() => _PCNewUserGuideFlowState();
}

class _PCNewUserGuideFlowState extends State<PCNewUserGuideFlow> {
  late final PCNewUserGuideController _controller;
  bool _loadFailed = false;
  bool _completionSent = false;
  bool _advancing = false;
  Timer? _loadTimer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PCNewUserGuideController.instance;
    _load();
  }

  Future<void> _load({bool retry = false}) async {
    final generation = ++_loadGeneration;
    _loadTimer?.cancel();
    if (_loadFailed) setState(() => _loadFailed = false);
    _loadTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && generation == _loadGeneration && !_controller.isLoaded) {
        setState(() => _loadFailed = true);
      }
    });
    try {
      await (retry ? _controller.retryLoad() : _controller.load());
      if (!mounted || generation != _loadGeneration) return;
      setState(() {});
      _finishIfComplete();
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (generation == _loadGeneration) _loadTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _loadTimer?.cancel();
    super.dispose();
  }

  Future<void> _next(PCNewUserGuideStep step) async {
    if (_advancing || _controller.isSaving || _controller.currentStep != step) {
      return;
    }
    _advancing = true;
    PCAnalytics.event('${_event(step)}_c');
    try {
      await _controller.completeStep(step);
      if (mounted) _finishIfComplete();
    } catch (_) {
      if (mounted) {
        PCDialogTool.toast(context, 'Please try again');
      }
    } finally {
      _advancing = false;
    }
  }

  String _event(PCNewUserGuideStep step) => switch (step) {
    PCNewUserGuideStep.guide1 => 'new_guide_one',
    PCNewUserGuideStep.guide2 => 'new_guide_two',
    PCNewUserGuideStep.guide3 => 'new_guide_three',
    PCNewUserGuideStep.afterIntro => '',
  };

  void _finishIfComplete() {
    if (!_controller.isIntroComplete || _completionSent) return;
    _completionSent = true;
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isLoaded) {
          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                const PCImg(name: 'pc_guide_intro_bg', fit: BoxFit.cover),
                Center(
                  child: _loadFailed
                      ? !_controller.canRetryLoad
                            ? const PCText(
                                text: 'Please close and reopen the app.',
                                size: 18,
                                color: Colors.white,
                                weight: FontWeight.w700,
                                align: TextAlign.center,
                                maxLines: 2,
                              )
                            : ParticleButton(
                                onTap: () => _load(retry: true),
                                child: const PCText(
                                  text: 'Tap to try again',
                                  size: 18,
                                  color: Colors.white,
                                  weight: FontWeight.w700,
                                ),
                              )
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ],
            ),
          );
        }
        return switch (_controller.currentStep) {
          PCNewUserGuideStep.guide1 => PCAnalyticsExposure(
            key: const ValueKey('new_guide_one'),
            event: 'new_guide_one',
            child: PCGuide1Page(
              isBusy: _controller.isSaving,
              onNext: () => _next(PCNewUserGuideStep.guide1),
            ),
          ),
          PCNewUserGuideStep.guide2 => PCAnalyticsExposure(
            key: const ValueKey('new_guide_two'),
            event: 'new_guide_two',
            child: PCGuide2Page(
              isBusy: _controller.isSaving,
              onNext: () => _next(PCNewUserGuideStep.guide2),
            ),
          ),
          PCNewUserGuideStep.guide3 => PCAnalyticsExposure(
            key: const ValueKey('new_guide_three'),
            event: 'new_guide_three',
            child: PCGuide3Page(
              isBusy: _controller.isSaving,
              onNext: () => _next(PCNewUserGuideStep.guide3),
            ),
          ),
          PCNewUserGuideStep.afterIntro => const SizedBox.shrink(),
        };
      },
    ),
  );
}
