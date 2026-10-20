/// 画板（quadrant-board）插件配置模型。
///
/// 后端把 config 当不透明 JSON 存取，结构由前端约定：
/// ```json
/// {
///   "active": "quadrant",
///   "quadrant": {
///     "xAxisLabel": "紧急度", "yAxisLabel": "重要度",
///     "xLowLabel": "不紧急", "xHighLabel": "紧急",
///     "yLowLabel": "不重要", "yHighLabel": "重要",
///     "regions": [{"key":"q1","name":"重要且紧急"}, ...]
///   },
///   "pyramid": {"regions": [{"key":"p1","name":"顶层目标"}, ...]}
/// }
/// ```
/// 读取时对缺失字段一律回退默认值，保证老配置/新配置都能正常渲染。
library;

class BoardRegion {
  BoardRegion({required this.key, required this.name});

  final String key;
  String name;
}

class BoardConfig {
  BoardConfig({
    required this.active,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.xLowLabel,
    required this.xHighLabel,
    required this.yLowLabel,
    required this.yHighLabel,
    required this.quadrants,
    required this.pyramid,
  });

  /// 当前生效结构：quadrant | pyramid。
  String active;
  String xAxisLabel;
  String yAxisLabel;
  String xLowLabel;
  String xHighLabel;
  String yLowLabel;
  String yHighLabel;

  /// 四个象限，顺序固定 q1、q2、q3、q4。
  final List<BoardRegion> quadrants;

  /// 金字塔三层，顺序固定 p1、p2、p3。
  final List<BoardRegion> pyramid;

  static const String defaultActive = 'quadrant';
  static const String defaultXAxisLabel = '紧急度';
  static const String defaultYAxisLabel = '重要度';
  static const String defaultXLowLabel = '不紧急';
  static const String defaultXHighLabel = '紧急';
  static const String defaultYLowLabel = '不重要';
  static const String defaultYHighLabel = '重要';

  static const List<List<String>> _quadrantDefaults = [
    ['q1', '重要且紧急'],
    ['q2', '重要不紧急'],
    ['q3', '紧急不重要'],
    ['q4', '不重要不紧急'],
  ];

  static const List<List<String>> _pyramidDefaults = [
    ['p1', '顶层目标'],
    ['p2', '中层计划'],
    ['p3', '底层行动'],
  ];

  factory BoardConfig.defaults() {
    return BoardConfig.fromJson(null);
  }

  /// 从后端 config 解析；任何缺失/类型不符的字段都回退默认值。
  factory BoardConfig.fromJson(Map<String, dynamic>? json) {
    final quadrant = json?['quadrant'] is Map<String, dynamic>
        ? json!['quadrant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final pyramid = json?['pyramid'] is Map<String, dynamic>
        ? json!['pyramid'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return BoardConfig(
      active: json?['active'] == 'pyramid' ? 'pyramid' : 'quadrant',
      xAxisLabel: _readLabel(quadrant['xAxisLabel'], defaultXAxisLabel),
      yAxisLabel: _readLabel(quadrant['yAxisLabel'], defaultYAxisLabel),
      xLowLabel: _readLabel(quadrant['xLowLabel'], defaultXLowLabel),
      xHighLabel: _readLabel(quadrant['xHighLabel'], defaultXHighLabel),
      yLowLabel: _readLabel(quadrant['yLowLabel'], defaultYLowLabel),
      yHighLabel: _readLabel(quadrant['yHighLabel'], defaultYHighLabel),
      quadrants: _readRegions(quadrant['regions'], _quadrantDefaults),
      pyramid: _readRegions(pyramid['regions'], _pyramidDefaults),
    );
  }

  /// 序列化为后端要求的完整配置对象（整体替换语义，必须提交全量字段）。
  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'quadrant': {
        'xAxisLabel': xAxisLabel,
        'yAxisLabel': yAxisLabel,
        'xLowLabel': xLowLabel,
        'xHighLabel': xHighLabel,
        'yLowLabel': yLowLabel,
        'yHighLabel': yHighLabel,
        'regions': quadrants
            .map((region) => {'key': region.key, 'name': region.name})
            .toList(),
      },
      'pyramid': {
        'regions': pyramid
            .map((region) => {'key': region.key, 'name': region.name})
            .toList(),
      },
    };
  }

  static String _readLabel(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return fallback;
  }

  static List<BoardRegion> _readRegions(
    dynamic raw,
    List<List<String>> defaults,
  ) {
    final stored = <String, String>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['key'] is String && item['name'] is String) {
          stored[item['key'] as String] = item['name'] as String;
        }
      }
    }
    return defaults
        .map((entry) => BoardRegion(
              key: entry[0],
              name: _readLabel(stored[entry[0]], entry[1]),
            ))
        .toList();
  }
}
