import 'package:get/get.dart';
import 'package:view/api/plugin.dart';
import 'package:view/models/plugin.dart';
import 'package:view/models/pomodoro_config.dart';
import 'package:view/stores/TokenManager.dart';
import 'package:view/stores/UserController.dart';
import 'package:view/utils/ApiException.dart';
import 'package:view/viewmodels/user.dart';

/// 插件全局状态控制器：以服务端数据为唯一事实来源。
///
/// 负责市场列表、安装/启停/卸载/保存配置，以及跨页面共享的番茄钟运行时长。
/// 所有写操作成功后都会用接口返回的实例回填本地列表，保证 UI 与后端一致。
class PluginController extends GetxController {
  static const String boardCode = 'quadrant-board';
  static const String pomodoroCode = 'pomodoro';

  /// 市场列表（含当前用户安装状态）。
  final plugins = <MarketPlugin>[].obs;

  /// 首次加载/手动刷新时的整页 loading。
  final isLoading = false.obs;

  /// 整页加载失败提示。
  final loadError = ''.obs;

  /// 正在执行写操作的插件 code（用于单个卡片的 loading 与防重复点击）。
  final busyCodes = <String>[].obs;

  /// 番茄钟本次计时选择的时长（分钟）。按 PRD 只存在于运行时，不落库。
  final pomodoroMinutes = 25.obs;

  UserController get _user => Get.find<UserController>();

  MarketPlugin? of(String code) {
    for (final plugin in plugins) {
      if (plugin.code == code) {
        return plugin;
      }
    }
    return null;
  }

  List<MarketPlugin> get installedPlugins =>
      plugins.where((plugin) => plugin.installed).toList(growable: false);

  MarketPlugin? get pomodoro => of(pomodoroCode);

  String get pomodoroLabel =>
      PomodoroConfig.fromJson(pomodoro?.config).label;

  bool isBusy(String code) => busyCodes.contains(code);

  /// 拉取市场列表。未登录时只清空，不发请求。
  Future<void> load({bool silent = false}) async {
    if (!_user.isLoggedIn) {
      plugins.clear();
      loadError.value = '';
      return;
    }
    if (!silent) {
      isLoading.value = true;
    }
    loadError.value = '';
    try {
      final list = await fetchPluginMarket();
      list.sort((a, b) => a.sort.compareTo(b.sort));
      plugins.assignAll(list);
    } on ApiException catch (error) {
      loadError.value = error.message;
      await _handleAuthError(error);
    } finally {
      isLoading.value = false;
    }
  }

  /// 安装插件；成功返回 null，失败返回可展示的错误文案。
  Future<String?> install(MarketPlugin plugin) async {
    if (isBusy(plugin.code) || plugin.installed) {
      return null;
    }
    busyCodes.add(plugin.code);
    try {
      final installed = await installPlugin(plugin.code);
      _applyInstalled(installed);
      return null;
    } on ApiException catch (error) {
      await _handleAuthError(error);
      return error.message;
    } finally {
      busyCodes.remove(plugin.code);
    }
  }

  /// 启用/禁用已安装插件。
  Future<String?> setEnabled(MarketPlugin plugin, bool enabled) async {
    final id = plugin.userPluginId;
    if (id == null) {
      return '请先安装插件';
    }
    if (isBusy(plugin.code)) {
      return null;
    }
    busyCodes.add(plugin.code);
    try {
      final installed = await setPluginEnabled(id, enabled);
      _applyInstalled(installed);
      return null;
    } on ApiException catch (error) {
      await _handleAuthError(error);
      return error.message;
    } finally {
      busyCodes.remove(plugin.code);
    }
  }

  /// 卸载插件：实例与配置一并删除，重新安装会得到新的默认配置。
  Future<String?> uninstall(MarketPlugin plugin) async {
    final id = plugin.userPluginId;
    if (id == null) {
      return null;
    }
    if (isBusy(plugin.code)) {
      return null;
    }
    busyCodes.add(plugin.code);
    try {
      await uninstallPlugin(id);
      final index = plugins.indexWhere((item) => item.code == plugin.code);
      if (index >= 0) {
        plugins[index] = plugins[index].copyWith(
          installed: false,
          clearInstance: true,
          clearConfig: true,
        );
      }
      return null;
    } on ApiException catch (error) {
      await _handleAuthError(error);
      return error.message;
    } finally {
      busyCodes.remove(plugin.code);
    }
  }

  /// 整体替换插件配置。
  Future<String?> saveConfig(
    MarketPlugin plugin,
    Map<String, dynamic> config,
  ) async {
    final id = plugin.userPluginId;
    if (id == null) {
      return '请先安装插件';
    }
    if (isBusy(plugin.code)) {
      return null;
    }
    busyCodes.add(plugin.code);
    try {
      final installed = await savePluginConfig(id, config);
      _applyInstalled(installed);
      return null;
    } on ApiException catch (error) {
      await _handleAuthError(error);
      return error.message;
    } finally {
      busyCodes.remove(plugin.code);
    }
  }

  /// 把接口返回的实例回填到市场列表，触发相关页面刷新。
  void _applyInstalled(InstalledPlugin installed) {
    final index = plugins.indexWhere((item) => item.code == installed.code);
    if (index < 0) {
      return;
    }
    plugins[index] = plugins[index].copyWith(
      installed: true,
      userPluginId: installed.id,
      enabled: installed.enabled,
      config: installed.config,
    );
  }

  /// 401：token 失效，清理本地登录态，让市场页回到登录门禁。
  Future<void> _handleAuthError(ApiException error) async {
    if (!error.isUnauthorized) {
      return;
    }
    await tokenManager.removeToken();
    if (Get.isRegistered<UserController>()) {
      _user.user.value = UserInfo.fromJSON({});
    }
    plugins.clear();
  }
}
