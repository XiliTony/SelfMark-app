// 插件市场与已安装插件相关接口
import 'package:view/contants/index.dart';
import 'package:view/models/plugin.dart';
import 'package:view/utils/DioRequest.dart';

Map<String, dynamic> _asMap(dynamic data) =>
    Map<String, dynamic>.from(data as Map);

/// 拉取插件市场：返回全部平台插件 + 当前用户安装状态。
Future<List<MarketPlugin>> fetchPluginMarket() async {
  final data = await dioRequest.get(HttpConstants.PLUGIN_MARKET);
  if (data is! List) {
    return <MarketPlugin>[];
  }
  return data
      .whereType<Map>()
      .map((item) => MarketPlugin.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

/// 安装插件：后端写入默认配置并返回实例。
Future<InstalledPlugin> installPlugin(String code) async {
  final data = await dioRequest.post(HttpConstants.pluginInstall(code));
  return InstalledPlugin.fromJson(_asMap(data));
}

/// 整体替换插件配置：必须提交完整 JSON 对象，后端不合并。
Future<InstalledPlugin> savePluginConfig(
  int userPluginId,
  Map<String, dynamic> config,
) async {
  final data = await dioRequest.put(
    HttpConstants.pluginConfig(userPluginId),
    data: config,
  );
  return InstalledPlugin.fromJson(_asMap(data));
}

/// 启用 / 禁用已安装插件（配置保留）。
Future<InstalledPlugin> setPluginEnabled(int userPluginId, bool enabled) async {
  final data = await dioRequest.put(
    HttpConstants.pluginEnabled(userPluginId),
    data: {'enabled': enabled},
  );
  return InstalledPlugin.fromJson(_asMap(data));
}

/// 卸载插件：实例与配置一并物理删除。
Future<void> uninstallPlugin(int userPluginId) async {
  await dioRequest.delete(HttpConstants.userPlugin(userPluginId));
}
