import 'package:flutter/cupertino.dart';
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
              PersistentBottomNavBarItem(
                icon: Image.asset('pc_earn_n'.image()),
                inactiveIcon: Image.asset('pc_earn_s'.image()),
                title: 'Earn',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
              PersistentBottomNavBarItem(
                icon: Image.asset('pc_quiz_n'.image()),
                inactiveIcon: Image.asset('pc_quiz_s'.image()),
                title: 'Quiz',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
              PersistentBottomNavBarItem(
                icon: Image.asset('pc_wheel_n'.image()),
                inactiveIcon: Image.asset('pc_wheel_s'.image()),
                title: 'Wheel',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
              PersistentBottomNavBarItem(
                icon: Image.asset('pc_cash_n'.image()),
                inactiveIcon: Image.asset('pc_cash_s'.image()),
                title: 'Cash',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
            ],
            selectedIndex: index,

            /// ✅ 不再 setState
            onItemSelected: (i) {
              if (i == 1) {
                // cs_event_fire('wheel_c', {'source_from' : 'home'});
              } else if (i == 2) {
                // cs_event_fire('cash_page', {'page_from' : 'tab'});
              }
              PigsTabController.switchTo(i);
            },
          );
          return CustomNavBarWidget(
            [
              PersistentBottomNavBarItem(
                icon: Image.asset('ps_home_icon'.image()),
                inactiveIcon: Image.asset('ps_home_icon'.image()),
                title: 'Piggy',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
              PersistentBottomNavBarItem(
                icon: Image.asset('ps_quiz_icon'.image()),
                inactiveIcon: Image.asset('ps_quiz_icon'.image()),
                title: 'Quiz',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
              PersistentBottomNavBarItem(
                icon: Image.asset('ps_wheel_icon'.image()),
                inactiveIcon: Image.asset('ps_wheel_icon'.image()),
                title: 'Wheel',
                activeColorPrimary: Colors.transparent,
                inactiveColorPrimary: Colors.transparent,
              ),
            ],
            selectedIndex: index,

            /// ✅ 不再 setState
            onItemSelected: (i) {
              PigsTabController.switchTo(i);
            },
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
    return SizedBox(
      height: 81 * scale,
      child: Stack(
        clipBehavior: Clip.none, // 👈 关键
        alignment: Alignment.center,
        children: [
          /// 图标
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            top: (isSelected ? -8 : 14) * scale, // 👈 关键点
            child: AnimatedScale(
              scale: isSelected ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              child: SizedBox(
                width: 50 * scale * (isSelected ? 1.25 : 1.0),
                height: 50 * scale * (isSelected ? 1.25 : 1.0),
                child: isSelected ? item.inactiveIcon : item.icon,
              ),
            ),
          ),

          /// 文字
          Positioned(
            bottom: 14 * scale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: isSelected ? 1 : 1,
              child: PCStrokeText(
                text: item.title ?? '',
                size: 14 * scale,
                color: isSelected ? '#FFEB36'.color() : '#4FC931'.color(),
                weight: FontWeight.w700,
                skWidth: 2 * scale,
                skColor: isSelected ? '#000000'.color() : '#062600'.color(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
