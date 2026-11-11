import 'package:adjust_sdk/adjust_attribution.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennypilotcollectspin/PCTool/PCAnalytics.dart';
import 'package:pennypilotcollectspin/PCTool/pc_init_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final events = <(String, Map<String, dynamic>)>[];

  setUp(() {
    events.clear();
    PCAnalytics.reporter = (name, body) => events.add((name, body));
  });
  tearDown(PCAnalytics.resetForTesting);

  test('未收到真实归因回调不补报adjust_suc', () {
    PCSDKHelpers();
    expect(events, isEmpty);
  });

  test('真实回调trackerName严格等于Organic为A，其余包含null为B', () {
    for (final tracker in <String?>[
      'Organic',
      'Facebook',
      'organic',
      '',
      null,
    ]) {
      PCSDKHelpers().handleAdjustAttribution(
        AdjustAttribution(trackerName: tracker),
      );
    }
    expect(
      events
          .where((event) => event.$1 == 'adjust_suc')
          .map((event) => event.$2),
      [
        {'adjust_user': '0'},
        {'adjust_user': '1'},
        {'adjust_user': '1'},
        {'adjust_user': '1'},
        {'adjust_user': '1'},
      ],
    );
  });
}
