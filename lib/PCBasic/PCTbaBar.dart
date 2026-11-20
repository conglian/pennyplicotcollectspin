import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import '../PCMainVC/PCCash.dart';
import '../PCMainVC/PCQuiz.dart';
import '../PCMainVC/PCWheel.dart';
import '../PCTool/pc_extension_help.dart';
import '../PCTool/PCAdaptiveLayout.dart';
import '../PCTool/PCNoticeHelp.dart';
import '../PCTool/PCNoticeMessage.dart';
import '../PCTool/PCNotificationPermissionHost.dart';
import '../PCTool/PCWithdrawalFlowHost.dart';
import '../PCTool/PCProcessFlowHost.dart';
import '../PCTool/pc_stroke_text.dart';

/// 底部 Wheel 按钮的实际布局锚点，供引导高亮复用。
final GlobalKey pcWheelNavigationTargetKey = GlobalKey(
  debugLabel: 'pcWheelNavigationTarget',
);

/// 底部导航和转盘引导全程使用同一张高清图，避免切换时换图跳变。
PersistentBottomNavBarItem pcNavBarItem(
  String asset,
  String title, {
  double unselectedMaxSize = 44,
}) => PersistentBottomNavBarItem(
  icon: Image.asset(
    '${asset}_selected_hd'.image(),
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  ),
  iconSize: unselectedMaxSize,
  title: title,
  activeColorPrimary: Colors.transparent,
  inactiveColorPrimary: Colors.transparent,
);

class PigsTabController {
  PigsTabController._();

  /// 当前选中的 tab
  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  /// 外部切换
  static void switchTo(int index) {
    currentIndex.value = index;
  }
}

final GlobalKey<_PigsBottomExampleState> homeKey =
    GlobalKey<_PigsBottomExampleState>();

class PigsBottomExample extends StatefulWidget {
  const PigsBottomExample({Key? key}) : super(key: key);

  @override
  State<PigsBottomExample> createState() => _PigsBottomExampleState();
}

class _PigsBottomExampleState extends State<PigsBottomExample> {
  /// ✅ 不再自己维护 int
  final ValueNotifier<int> _indexNotifier = PigsTabController.currentIndex;

  // final List<Widget> _screens = const [(), (), ()];

  final List<Widget> _screenbs = [PChome(), PCQuiz(), PCWheel(), PCCash()];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    PCNoticeHelp.instance.attachNavigation(_openNotice, context: context);
  }

  void _openNotice(PCNoticeAction action) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    PigsTabController.switchTo(action == PCNoticeAction.withdraw ? 3 : 1);
  }

  @override
  void dispose() {
    PCNoticeHelp.instance.detachNavigation(_openNotice);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      /// ✅ 只监听 index
      body: ValueListenableBuilder<int>(
        valueListenable: _indexNotifier,
        builder: (_, index, __) {
          return PCNotificationPermissionHost(
            isHomeVisible: index == 0,
            child: PCProcessFlowHost(
              onGoQuiz: () => PigsTabController.switchTo(1),
              child: PCWithdrawalFlowHost(
                onGoQuiz: () => PigsTabController.switchTo(1),
                onGoWheel: () => PigsTabController.switchTo(2),
                child: IndexedStack(index: index, children: _screenbs),
              ),
            ),
          );
        },
      ),

      /// ✅ 底部栏也监听
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _indexNotifier,
        builder: (_, index, __) {
          return CustomNavBarWidget(
            [
              pcNavBarItem('pc_earn', 'Earn'),
              pcNavBarItem('pc_quiz', 'Quiz', unselectedMaxSize: 83),
              pcNavBarItem('pc_wheel', 'Wheel'),
              pcNavBarItem('pc_cash', 'Cash'),
            ],
            selectedIndex: index,
            onItemSelected: PigsTabController.switchTo,
          );
        },
      ),
    );
  }
}

class CustomNavBarWidget extends StatefulWidget {
  const CustomNavBarWidget(
    this.items, {
    required this.selectedIndex,
    required this.onItemSelected,
    Key? key,
  }) : super(key: key);

  final int selectedIndex;
  final List<PersistentBottomNavBarItem> items;
  final ValueChanged<int> onItemSelected;

  @override
  State<CustomNavBarWidget> createState() => _CustomNavBarWidgetState();
}

class _CustomNavBarWidgetState extends State<CustomNavBarWidget>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final scale = PCAdaptiveLayout.navigationScale(
      MediaQuery.sizeOf(context).width,
    );
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('pc_tabbar_bg'.image()),
          fit: BoxFit.fill,
        ),
        color: Color.fromARGB(60, 200, 20, 82),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 81 * scale,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(widget.items.length, (index) {
              final item = widget.items[index];
              final bool isSelected = widget.selectedIndex == index;
              return Expanded(
                child: ParticleButton(
                  onTap: () => widget.onItemSelected(index),
                  child: KeyedSubtree(
                    key: index == 2 ? pcWheelNavigationTargetKey : null,
                    child: PCNavBarItemView(item: item, isSelected: isSelected),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// 底部导航项与引导高亮共用同一布局，图标大小、文字和选中状态保持一致。
class PCNavBarItemView extends StatelessWidget {
  const PCNavBarItemView({
    super.key,
    required this.item,
    required this.isSelected,
  });
  final PersistentBottomNavBarItem item;
  final bool isSelected;
  @override
  Widget build(BuildContext context) {
    final scale = PCAdaptiveLayout.navigationScale(
      MediaQuery.sizeOf(context).width,
    );
    final idleSize = math.min(50 * scale, item.iconSize);
    return SizedBox(
      height: 81 * scale,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: isSelected ? 1.0 : 0.0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        child: isSelected ? item.inactiveIcon ?? item.icon : item.icon,
        builder: (context, progress, icon) {
          // 沿用选中态的最终尺寸和中心点。点击切换时三项视觉变化共用进度。
          final iconSize = lerpDouble(idleSize, 78.125 * scale, progress)!;
          final iconCenter = lerpDouble(39, 23.25, progress)! * scale;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                top: iconCenter - iconSize / 2,
                width: iconSize,
                height: iconSize,
                child: icon!,
              ),
              Positioned(
                bottom: 14 * scale,
                child: PCStrokeText(
                  text: item.title ?? '',
                  size: 14 * scale,
                  color: Color.lerp(
                    const Color(0xFF4FC931),
                    const Color(0xFFFFEB36),
                    progress,
                  )!,
                  weight: FontWeight.w700,
                  skWidth: 2 * scale,
                  skColor: Color.lerp(
                    const Color(0xFF062600),
                    Colors.black,
                    progress,
                  )!,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
