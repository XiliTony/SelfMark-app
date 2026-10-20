import 'package:flutter/material.dart';
import 'package:view/models/plugin.dart';

/// 插件市场卡片：受控组件，状态完全来自后端返回的 [MarketPlugin]。
///
/// - 开关：未安装时点击 = 安装；已安装时点击 = 启用/禁用（配置保留）
/// - 点击卡片主体：未安装则先安装再进入编辑页，已安装直接进入编辑页
/// - 右上角菜单：卸载（仅已安装时显示）
class MkCard extends StatelessWidget {
  const MkCard({
    super.key,
    required this.plugin,
    required this.switchColor,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onUninstall,
  });

  final MarketPlugin plugin;
  final Color switchColor;

  /// 该插件正在执行写操作（安装/启停/卸载/保存），显示遮罩并禁用交互。
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onUninstall;

  String get _statusText {
    if (!plugin.installed) {
      return '点击安装';
    }
    return plugin.isEnabled ? '使用中 · 点击配置' : '已禁用 · 点击配置';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SizedBox(
      height: width * 0.50,
      width: width * 0.50,
      child: Card(
        color: plugin.isEnabled
            ? Colors.white
            : Colors.white.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        child: Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: busy ? null : onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plugin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (plugin.installed)
                          PopupMenuButton<String>(
                            tooltip: '更多操作',
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            // 限制最小点击区，避免把标题行撑到 48 高导致卡片溢出
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.black45,
                            ),
                            onSelected: (value) {
                              if (value == 'uninstall') {
                                onUninstall();
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'uninstall',
                                child: Text('卸载'),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((plugin.description ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          plugin.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: Colors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // RotatedBox 会让布局尺寸跟着旋转，这里给个固定高度避免撑破卡片
                        SizedBox(
                          width: 44,
                          height: 38,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Switch(
                                value: plugin.isEnabled,
                                activeThumbColor: switchColor,
                                onChanged: busy ? null : onToggle,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Image.asset(
                            plugin.code == 'quadrant-board'
                                ? 'lib/assets/market/axis.png'
                                : 'lib/assets/market/pomodoro.png',
                            height: width * 0.16,
                            width: width * 0.16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (busy)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.6),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
