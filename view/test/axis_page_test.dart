import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:view/models/board_config.dart';
import 'package:view/models/plugin.dart';
import 'package:view/pages/plugin/axis/index.dart';
import 'package:view/stores/PluginController.dart';

MarketPlugin _installedBoard({String active = 'quadrant'}) {
  final config = BoardConfig.defaults()..active = active;
  return MarketPlugin(
    id: 1,
    code: PluginController.boardCode,
    name: '画板',
    description: '测试',
    sort: 1,
    installed: true,
    userPluginId: 11,
    enabled: true,
    config: config.toJson(),
  );
}

void main() {
  setUp(() {
    Get.reset();
    Get.put(PluginController());
  });

  testWidgets('画板页可以切换到金字塔并显示三层默认命名', (tester) async {
    Get.find<PluginController>().plugins.add(_installedBoard());

    await tester.pumpWidget(const MaterialApp(home: AxisPage()));
    await tester.pumpAndSettle();

    // 默认二维坐标轴
    expect(find.text('二维坐标轴'), findsOneWidget);
    expect(find.text('重要且紧急'), findsOneWidget);

    await tester.tap(find.text('金字塔'));
    await tester.pumpAndSettle();

    expect(find.text('顶层目标'), findsOneWidget);
    expect(find.text('中层计划'), findsOneWidget);
    expect(find.text('底层行动'), findsOneWidget);
  });

  testWidgets('active=pyramid 时打开直接落在金字塔页', (tester) async {
    Get.find<PluginController>()
        .plugins
        .add(_installedBoard(active: 'pyramid'));

    await tester.pumpWidget(const MaterialApp(home: AxisPage()));
    await tester.pumpAndSettle();

    expect(find.text('顶层目标'), findsOneWidget);
    // 二维坐标轴页不在可见区域
    expect(find.text('重要且紧急'), findsNothing);
  });

  testWidgets('金字塔层名可以编辑', (tester) async {
    Get.find<PluginController>()
        .plugins
        .add(_installedBoard(active: 'pyramid'));

    await tester.pumpWidget(const MaterialApp(home: AxisPage()));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextFormField, '顶层目标');
    expect(field, findsOneWidget);
    await tester.enterText(field, '年度目标');
    await tester.pump();

    expect(find.text('年度目标'), findsOneWidget);
  });
}
