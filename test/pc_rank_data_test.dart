import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pennypilotcollectspin/PCMainVC/PCHome.dart';
import 'package:pennypilotcollectspin/PCTool/PCRankData.dart';
import 'package:pennypilotcollectspin/PCTool/pc_img.dart';

List<Map<String, dynamic>> rows(List<PCUserData> users) =>
    users.map((user) => user.toJson()).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('榜单保持 56 人、用户不重复、收益降序且使用有效头像', () {
    final users = PCUserDataManager.generatePCUserData();
    expect(users, hasLength(56));
    expect(users.map((user) => user.id).toSet(), hasLength(56));
    expect(users.map((user) => user.avatarIndex).toSet(), hasLength(54));
    for (var i = 0; i < users.length; i++) {
      expect(users[i].avatarIndex, inInclusiveRange(0, 53));
      expect(users[i].avatarName, matches(r'^pc_rank_avatar_\d{2}$'));
      expect(
        users[i].totalEarning,
        i < 3 ? inInclusiveRange(100, 200) : inInclusiveRange(0, 100),
      );
      if (i > 0) {
        expect(
          users[i].totalEarning,
          lessThanOrEqualTo(users[i - 1].totalEarning),
        );
      }
    }
  });

  test('同日重开和重新加载本地缓存，用户、头像和数据都不变', () async {
    final first = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 21, 1),
    );
    final again = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 21, 23, 59),
    );
    expect(rows(again), rows(first));
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('pc_daily_ranking_v2')!;
    SharedPreferences.setMockInitialValues({'pc_daily_ranking_v2': saved});
    final coldStart = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 21, 18),
    );
    expect(rows(coldStart), rows(first));
  });

  test('零点切换日期时并发请求只生成同一份新榜单，随后当天保持不变', () async {
    final yesterday = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 21, 23, 59, 59),
    );
    final requests = await Future.wait(
      List.generate(
        8,
        (_) => PCUserDataManager.getPCUserData(now: DateTime(2026, 10, 22)),
      ),
    );
    final today = requests.first;
    for (final request in requests) {
      expect(rows(request), rows(today));
    }
    expect(today, hasLength(yesterday.length));
    expect(
      today
          .map((user) => user.id)
          .toSet()
          .intersection(yesterday.map((user) => user.id).toSet()),
      isEmpty,
    );
    expect(
      today.map((user) => user.totalEarning).toList(),
      isNot(yesterday.map((user) => user.totalEarning).toList()),
    );
    for (var i = 0; i < today.length; i++) {
      expect(today[i].avatarIndex, isNot(yesterday[i].avatarIndex));
    }
    final sameDay = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 22, 20),
    );
    expect(rows(sameDay), rows(today));
  });

  test('隔天冷启动从昨天的持久化快照更新，新的日期也一并保存', () async {
    final yesterday = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 21, 20),
    );
    final prefs = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues({
      'pc_daily_ranking_v2': prefs.getString('pc_daily_ranking_v2')!,
    });
    final today = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 23, 9),
    );
    expect(today, hasLength(56));
    expect(rows(today), isNot(rows(yesterday)));
    final reloaded = await PCUserDataManager.loadPCUserData();
    expect(rows(reloaded), rows(today));
    final saved = await SharedPreferences.getInstance();
    expect(
      jsonDecode(saved.getString('pc_daily_ranking_v2')!)['date'],
      '2026-10-23',
    );
  });

  test('旧版当天缓存补齐头像后迁移，不重新生成当天用户和收益', () async {
    final oldUsers = PCUserDataManager.generatePCUserData();
    final oldRows = rows(oldUsers)
        .map((row) => Map<String, dynamic>.from(row)..remove('avatarIndex'))
        .toList();
    SharedPreferences.setMockInitialValues({
      'lastUpdate': DateTime(2026, 10, 21, 9).toIso8601String(),
      'PCUserData': oldRows.map(jsonEncode).toList(),
    });
    final migrated = await PCUserDataManager.getPCUserData(
      now: DateTime(2026, 10, 21, 20),
    );
    expect(
      migrated.map((user) => user.username).toList(),
      oldUsers.map((user) => user.username).toList(),
    );
    expect(
      migrated.map((user) => user.totalEarning).toList(),
      oldUsers.map((user) => user.totalEarning).toList(),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pc_daily_ranking_v2'), isNotNull);
    expect(
      rows(
        await PCUserDataManager.getPCUserData(now: DateTime(2026, 10, 21, 23)),
      ),
      rows(migrated),
    );
  });

  for (final broken in [
    {
      'lastUpdate': 'invalid-date',
      'PCUserData': <String>['invalid-json'],
    },
    {'pc_daily_ranking_v2': '{broken'},
    {
      'pc_daily_ranking_v2': jsonEncode({'date': '2026-10-21', 'users': []}),
    },
    {
      'pc_daily_ranking_v2': jsonEncode({
        'date': '2026-10-21',
        'users': List.filled(56, {'id': 1}),
      }),
    },
  ]) {
    test(
      '异常缓存恢复完整榜单：${broken.keys.first}/${broken.values.first.toString().length}',
      () async {
        SharedPreferences.setMockInitialValues(broken);
        final restored = await PCUserDataManager.getPCUserData(
          now: DateTime(2026, 10, 21, 10),
        );
        expect(restored, hasLength(56));
        expect(
          rows(
            await PCUserDataManager.getPCUserData(
              now: DateTime(2026, 10, 21, 11),
            ),
          ),
          rows(restored),
        );
      },
    );
  }

  test('下次刷新时间为本地下一日零点，正确跨月跨年', () {
    expect(
      PCUserDataManager.nextRefreshAt(DateTime(2026, 10, 31, 23, 59)),
      DateTime(2026, 11, 1),
    );
    expect(
      PCUserDataManager.nextRefreshAt(DateTime(2026, 12, 31, 12)),
      DateTime(2027, 1, 1),
    );
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('排行榜在 $size 绑定前三名与列表头像，可滚动到第 56 名', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final users = PCUserDataManager.generatePCUserData();
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, child) => MaterialApp(
            home: Scaffold(
              body: PCHomeRankingSection(data: users, scale: size.width / 375),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        final avatar = tester.widget<PCImg>(
          find.byKey(ValueKey('pcRankAvatar${i + 1}')),
        );
        expect(avatar.name, users[i].avatarName);
      }
      expect(find.text(users[3].username), findsOneWidget);
      final fourthImages = tester.widgetList<PCImg>(
        find.descendant(
          of: find.byKey(const ValueKey('pcRankRow4')),
          matching: find.byType(PCImg),
        ),
      );
      expect(
        fourthImages.any((image) => image.name == users[3].avatarName),
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('pcRankRow56')),
        300,
      );
      expect(find.text(users[55].username), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
