import 'package:flutter_test/flutter_test.dart';
import 'package:view/models/board_config.dart';
import 'package:view/models/pomodoro_config.dart';

void main() {
  group('BoardConfig', () {
    test('缺少配置时全部回退默认值', () {
      final config = BoardConfig.fromJson(null);

      expect(config.active, 'quadrant');
      expect(config.xAxisLabel, '紧急度');
      expect(config.yAxisLabel, '重要度');
      expect(config.xLowLabel, '不紧急');
      expect(config.xHighLabel, '紧急');
      expect(config.quadrants.map((region) => region.key).toList(), [
        'q1',
        'q2',
        'q3',
        'q4',
      ]);
      expect(config.quadrants.first.name, '重要且紧急');
      expect(config.pyramid.length, 3);
    });

    test('老配置缺少 4 端标签时按默认值补齐', () {
      final config = BoardConfig.fromJson({
        'active': 'pyramid',
        'quadrant': {
          'xAxisLabel': '截止时间',
          'yAxisLabel': '影响程度',
          'regions': [
            {'key': 'q1', 'name': '马上办'},
          ],
        },
      });

      expect(config.active, 'pyramid');
      expect(config.xAxisLabel, '截止时间');
      expect(config.yAxisLabel, '影响程度');
      expect(config.xLowLabel, BoardConfig.defaultXLowLabel);
      expect(config.quadrants.first.name, '马上办');
      expect(config.quadrants[1].name, '重要不紧急');
      expect(config.pyramid.first.name, '顶层目标');
    });

    test('序列化包含完整结构与 active，可往返解析', () {
      final source = BoardConfig.fromJson(null);
      source.active = 'pyramid';
      source.xHighLabel = '马上';
      source.quadrants[0].name = '立刻做';

      final json = source.toJson();
      final restored = BoardConfig.fromJson(json);

      expect(json['active'], 'pyramid');
      expect(json['quadrant']['xHighLabel'], '马上');
      expect(restored.active, 'pyramid');
      expect(restored.xHighLabel, '马上');
      expect(restored.quadrants[0].name, '立刻做');
      expect(restored.pyramid.length, 3);
    });
  });

  group('PomodoroConfig', () {
    test('缺少 label 时使用默认值', () {
      expect(PomodoroConfig.fromJson(null).label, '专注');
      expect(PomodoroConfig.fromJson({'label': '  '}).label, '专注');
      expect(PomodoroConfig.fromJson({'label': '深度工作'}).label, '深度工作');
    });

    test('只序列化 label，不包含时长', () {
      final json = PomodoroConfig(label: '学习').toJson();
      expect(json, {'label': '学习'});
    });
  });
}
