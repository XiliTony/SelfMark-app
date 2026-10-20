import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/components/plugin/PomodoroTimer.dart';
import 'package:view/models/board_config.dart';
import 'package:view/models/plugin.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/stores/UserController.dart';

/// 「我的APP」= 插件容器：只渲染已安装且启用的插件。
class PluginPage extends StatelessWidget {
  const PluginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();
    final pluginController = Get.find<PluginController>();

    return Obx(() {
      if (!userController.isLoggedIn) {
        return const _EmptyHint(
          icon: Icons.lock_outline,
          text: '登录后，安装的插件会出现在这里',
        );
      }

      final enabledPlugins = pluginController.installedPlugins
          .where((plugin) => plugin.isEnabled)
          .toList();
      if (enabledPlugins.isEmpty) {
        return const _EmptyHint(
          icon: Icons.widgets_outlined,
          text: 'APP暂时没有任何插件~请前往插件市场选择',
        );
      }

      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: enabledPlugins
            .map((plugin) => _buildPlugin(context, plugin))
            .toList(),
      );
    });
  }

  Widget _buildPlugin(BuildContext context, MarketPlugin plugin) {
    if (plugin.code == PluginController.pomodoroCode) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: const PomodoroTimer(),
      );
    }
    if (plugin.code == PluginController.boardCode) {
      return _BoardPreview(
        plugin: plugin,
        config: BoardConfig.fromJson(plugin.config),
      );
    }
    // 未知插件类型：给一个通用占位，未来新增插件时前端再补渲染
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ListTile(
        title: Text(plugin.name),
        subtitle: const Text('该插件暂无可用的预览视图'),
      ),
    );
  }
}

/// 画板在「我的APP」里的只读预览：展示当前生效结构与命名。
class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.plugin, required this.config});

  final MarketPlugin plugin;
  final BoardConfig config;

  @override
  Widget build(BuildContext context) {
    final isPyramid = config.active == 'pyramid';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '画板',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  isPyramid ? '· 金字塔' : '· 二维坐标轴',
                  style: const TextStyle(color: Colors.black45, fontSize: 13),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/axis'),
                  child: const Text('编辑'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isPyramid)
              _buildPyramid()
            else
              _buildQuadrant(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadrant() {
    final regions = config.quadrants;
    return Column(
      children: [
        _axisCaption('Y 轴：${config.yAxisLabel}（${config.yLowLabel} → ${config.yHighLabel}）'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _regionBox(regions[1])),
            const SizedBox(width: 8),
            Expanded(child: _regionBox(regions[0])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _regionBox(regions[3])),
            const SizedBox(width: 8),
            Expanded(child: _regionBox(regions[2])),
          ],
        ),
        const SizedBox(height: 8),
        _axisCaption('X 轴：${config.xAxisLabel}（${config.xLowLabel} → ${config.xHighLabel}）'),
      ],
    );
  }

  // 用梯形堆出金字塔形状，避免看起来只是三条横条
  Widget _buildPyramid() {
    final layers = config.pyramid;
    const colors = [Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF90CAF9)];
    const bottomFactors = [0.5, 0.75, 1.0];
    const topFactors = [0.22, 0.5, 0.75];
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return Column(
          children: List.generate(layers.length, (index) {
            final width = maxWidth * bottomFactors[index];
            final topWidth = maxWidth * topFactors[index];
            final inset = width <= 0 ? 0.0 : (width - topWidth) / 2 / width;
            return SizedBox(
              height: 52,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: ClipPath(
                    clipper: _PreviewTrapezoidClipper(
                      topInsetRatio: inset.clamp(0.0, 0.5),
                    ),
                    child: Container(
                      color: colors[index % colors.length],
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        layers[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _regionBox(BoardRegion region) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        region.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _axisCaption(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: Colors.black45, fontSize: 12),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.black.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// 我的APP 金字塔预览用：上边缘按比例内缩的梯形。
class _PreviewTrapezoidClipper extends CustomClipper<Path> {
  _PreviewTrapezoidClipper({required this.topInsetRatio});

  final double topInsetRatio;

  @override
  Path getClip(Size size) {
    final inset = size.width * topInsetRatio;
    return Path()
      ..moveTo(inset, 0)
      ..lineTo(size.width - inset, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _PreviewTrapezoidClipper oldClipper) =>
      oldClipper.topInsetRatio != topInsetRatio;
}
