/// 插件相关数据模型。
///
/// 与后端 `GET /api/plugins`、安装/改配置/启停接口的返回结构一一对应。
library;

/// 插件市场条目（目录信息 + 当前用户的安装状态）。
class MarketPlugin {
  const MarketPlugin({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.sort,
    required this.installed,
    required this.userPluginId,
    required this.enabled,
    required this.config,
  });

  /// 目录 ID。
  final int id;

  /// 插件标识：quadrant-board / pomodoro，前端据此决定路由与渲染。
  final String code;

  final String name;
  final String? description;
  final int sort;

  /// 当前用户是否已安装。
  final bool installed;

  /// 已安装插件的实例 ID（未安装为 null）。
  final int? userPluginId;

  /// 已安装插件的启用状态（未安装为 null）。
  final bool? enabled;

  /// 已安装插件的配置（未安装为 null）。
  final Map<String, dynamic>? config;

  /// 已安装且启用。
  bool get isEnabled => installed && (enabled ?? false);

  factory MarketPlugin.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    return MarketPlugin(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      sort: (json['sort'] as num?)?.toInt() ?? 0,
      installed: json['installed'] == true || json['userPluginId'] != null,
      userPluginId: (json['userPluginId'] as num?)?.toInt(),
      enabled: json['enabled'] as bool?,
      config: rawConfig is Map<String, dynamic> ? rawConfig : null,
    );
  }

  MarketPlugin copyWith({
    bool? installed,
    int? userPluginId,
    bool? enabled,
    Map<String, dynamic>? config,
    bool clearConfig = false,
    bool clearInstance = false,
  }) {
    return MarketPlugin(
      id: id,
      code: code,
      name: name,
      description: description,
      sort: sort,
      installed: installed ?? this.installed,
      userPluginId: clearInstance ? null : (userPluginId ?? this.userPluginId),
      enabled: clearInstance ? null : (enabled ?? this.enabled),
      config: clearConfig ? null : (config ?? this.config),
    );
  }
}

/// 已安装插件实例（安装/改配置/启停接口的返回体）。
class InstalledPlugin {
  const InstalledPlugin({
    required this.id,
    required this.pluginId,
    required this.code,
    required this.name,
    required this.config,
    required this.enabled,
  });

  final int id;
  final int pluginId;
  final String code;
  final String name;
  final Map<String, dynamic> config;
  final bool enabled;

  factory InstalledPlugin.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['config'];
    return InstalledPlugin(
      id: (json['id'] as num?)?.toInt() ?? 0,
      pluginId: (json['pluginId'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      config: rawConfig is Map<String, dynamic> ? rawConfig : <String, dynamic>{},
      enabled: json['enabled'] == true,
    );
  }
}
