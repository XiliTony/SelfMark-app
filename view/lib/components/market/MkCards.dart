import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/components/market/MkCard.dart';
import 'package:view/models/plugin.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/utils/ToastUtils.dart';

/// 插件卡片列表：数据全部来自 [PluginController]，支持关键字本地过滤。
class MkCards extends StatelessWidget {
  const MkCards({super.key, this.keyword = ''});

  final String keyword;

  List<MarketPlugin> _filter(List<MarketPlugin> source) {
    final key = keyword.trim().toLowerCase();
    if (key.isEmpty) {
      return source;
    }
    return source.where((plugin) {
      return plugin.name.toLowerCase().contains(key) ||
          plugin.code.toLowerCase().contains(key) ||
          (plugin.description ?? '').toLowerCase().contains(key);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PluginController>();

    return Obx(() {
      final plugins = _filter(controller.plugins);
      if (plugins.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              '没有找到匹配的插件',
              style: TextStyle(color: Colors.black45),
            ),
          ),
        );
      }
      return Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 10,
        children: plugins
            .map(
              (plugin) => MkCard(
                plugin: plugin,
                busy: controller.isBusy(plugin.code),
                switchColor: plugin.code == PluginController.boardCode
                    ? Colors.green
                    : Colors.red,
                onToggle: (value) => _toggle(context, plugin, value),
                onEdit: () => _openPlugin(context, plugin),
                onUninstall: () => _uninstall(context, plugin),
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> _toggle(
    BuildContext context,
    MarketPlugin plugin,
    bool value,
  ) async {
    final controller = Get.find<PluginController>();
    // 未安装时打开开关 = 安装；已安装时 = 启用/禁用（配置保留）
    final successMessage = plugin.installed
        ? (value ? '已启用' : '已禁用')
        : '安装成功';
    final error = plugin.installed
        ? await controller.setEnabled(plugin, value)
        : await controller.install(plugin);
    if (!context.mounted) {
      return;
    }
    ToastUtils.showToast(context, error ?? successMessage);
  }

  // 卸载走三点菜单，实例与配置一并删除，所以先确认一次
  Future<void> _uninstall(BuildContext context, MarketPlugin plugin) async {
    final confirmed = await _confirmUninstall(context, plugin);
    if (!confirmed || !context.mounted) {
      return;
    }
    final error = await Get.find<PluginController>().uninstall(plugin);
    if (!context.mounted) {
      return;
    }
    ToastUtils.showToast(context, error ?? '已卸载');
  }

  Future<void> _openPlugin(BuildContext context, MarketPlugin plugin) async {
    final controller = Get.find<PluginController>();
    if (!plugin.installed) {
      // 未安装时点击卡片：先安装（后端写默认配置），成功后再进编辑页
      final error = await controller.install(plugin);
      if (error != null) {
        if (context.mounted) {
          ToastUtils.showToast(context, error);
        }
        return;
      }
      if (!context.mounted) {
        return;
      }
    }
    final route = plugin.code == PluginController.boardCode
        ? '/axis'
        : '/pomodoro';
    await Navigator.pushNamed(context, route);
  }

  // 卸载会删除实例与配置，所以先确认一次
  Future<bool> _confirmUninstall(
    BuildContext context,
    MarketPlugin plugin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('卸载插件'),
        content: Text(
          '卸载「${plugin.name}」会删除已保存的配置，'
          '重新安装会恢复默认命名。确定卸载吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
