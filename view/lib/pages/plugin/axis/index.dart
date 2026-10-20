import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/models/board_config.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/utils/ToastUtils.dart';

/// 画板插件配置页：读取后端 config 渲染，保存时整体 PUT 回后端。
///
/// 结构（二维坐标轴 / 金字塔）与「当前生效结构」都来自 config：
/// 切换 Tab 会写入 active，两个结构的命名各自独立保存，切换不丢。
class AxisPage extends StatefulWidget {
  const AxisPage({super.key});

  @override
  _AxisPageState createState() => _AxisPageState();
}

class _AxisPageState extends State<AxisPage>
    with SingleTickerProviderStateMixin {
  final PluginController _controller = Get.find<PluginController>();

  // 坐标轴线颜色
  final Color _axisColor = Colors.blueGrey;
  // 象限输入框背景色
  final Color _quadrantFillColor = const Color(0xFFF7F8FA);

  late final TabController _tabController;
  BoardConfig _config = BoardConfig.defaults();

  late TextEditingController _xAxisLabel;
  late TextEditingController _yAxisLabel;
  late TextEditingController _xLowLabel;
  late TextEditingController _xHighLabel;
  late TextEditingController _yLowLabel;
  late TextEditingController _yHighLabel;
  final List<TextEditingController> _quadrantControllers = [];
  final List<TextEditingController> _pyramidControllers = [];

  bool _saving = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _config = BoardConfig.fromJson(
      _controller.of(PluginController.boardCode)?.config,
    );
    _tabController = TabController(
      length: 2,
      initialIndex: _config.active == 'pyramid' ? 1 : 0,
      vsync: this,
    );
    _tabController.addListener(_handleTabChanged);
    _bindControllers();
  }

  void _bindControllers() {
    _xAxisLabel = TextEditingController(text: _config.xAxisLabel);
    _yAxisLabel = TextEditingController(text: _config.yAxisLabel);
    _xLowLabel = TextEditingController(text: _config.xLowLabel);
    _xHighLabel = TextEditingController(text: _config.xHighLabel);
    _yLowLabel = TextEditingController(text: _config.yLowLabel);
    _yHighLabel = TextEditingController(text: _config.yHighLabel);
    _quadrantControllers
      ..clear()
      ..addAll(
        _config.quadrants.map((r) => TextEditingController(text: r.name)),
      );
    _pyramidControllers
      ..clear()
      ..addAll(
        _config.pyramid.map((r) => TextEditingController(text: r.name)),
      );
  }

  void _disposeControllers() {
    _xAxisLabel.dispose();
    _yAxisLabel.dispose();
    _xLowLabel.dispose();
    _xHighLabel.dispose();
    _yLowLabel.dispose();
    _yHighLabel.dispose();
    for (final controller in _quadrantControllers) {
      controller.dispose();
    }
    for (final controller in _pyramidControllers) {
      controller.dispose();
    }
  }

  // 切换结构：写入 active，两个结构的命名互不影响
  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final active = _tabController.index == 1 ? 'pyramid' : 'quadrant';
    if (_config.active != active) {
      setState(() => _config.active = active);
    }
  }

  Future<void> _install() async {
    final plugin = _controller.of(PluginController.boardCode);
    if (plugin == null || _installing) {
      return;
    }
    setState(() => _installing = true);
    final error = await _controller.install(plugin);
    if (!mounted) {
      return;
    }
    setState(() => _installing = false);
    if (error != null) {
      ToastUtils.showToast(context, error);
      return;
    }
    final installed = _controller.of(PluginController.boardCode);
    setState(() {
      // 复用已有控制器，避免销毁仍挂在树上的 TextField 控制器
      _applyConfig(BoardConfig.fromJson(installed?.config));
      _tabController.index = _config.active == 'pyramid' ? 1 : 0;
    });
  }

  // 把配置写回已有控制器（安装完成/外部配置变化时调用）
  void _applyConfig(BoardConfig config) {
    _config = config;
    _xAxisLabel.text = config.xAxisLabel;
    _yAxisLabel.text = config.yAxisLabel;
    _xLowLabel.text = config.xLowLabel;
    _xHighLabel.text = config.xHighLabel;
    _yLowLabel.text = config.yLowLabel;
    _yHighLabel.text = config.yHighLabel;
    for (var i = 0; i < _quadrantControllers.length; i++) {
      _quadrantControllers[i].text = config.quadrants[i].name;
    }
    for (var i = 0; i < _pyramidControllers.length; i++) {
      _pyramidControllers[i].text = config.pyramid[i].name;
    }
  }

  Future<void> _save() async {
    final plugin = _controller.of(PluginController.boardCode);
    if (plugin == null || !plugin.installed) {
      ToastUtils.showToast(context, '请先安装画板插件');
      return;
    }
    if (_saving) {
      return;
    }
    _collect();
    setState(() => _saving = true);
    final error = await _controller.saveConfig(plugin, _config.toJson());
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ToastUtils.showToast(context, error ?? '已保存');
  }

  // 把输入框里的值收集回 config；空值回退默认，避免存空字符串
  void _collect() {
    // 以当前可见 Tab 为准：切 Tab 动画还没结束时，listener 可能还没写入 active
    _config.active = _tabController.index == 1 ? 'pyramid' : 'quadrant';
    final defaults = BoardConfig.defaults();
    _config.xAxisLabel = _fallback(_xAxisLabel.text, defaults.xAxisLabel);
    _config.yAxisLabel = _fallback(_yAxisLabel.text, defaults.yAxisLabel);
    _config.xLowLabel = _fallback(_xLowLabel.text, defaults.xLowLabel);
    _config.xHighLabel = _fallback(_xHighLabel.text, defaults.xHighLabel);
    _config.yLowLabel = _fallback(_yLowLabel.text, defaults.yLowLabel);
    _config.yHighLabel = _fallback(_yHighLabel.text, defaults.yHighLabel);
    for (var i = 0; i < _quadrantControllers.length; i++) {
      _config.quadrants[i].name = _fallback(
        _quadrantControllers[i].text,
        defaults.quadrants[i].name,
      );
    }
    for (var i = 0; i < _pyramidControllers.length; i++) {
      _config.pyramid[i].name = _fallback(
        _pyramidControllers[i].text,
        defaults.pyramid[i].name,
      );
    }
  }

  String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final plugin = _controller.of(PluginController.boardCode);
      final installed = plugin?.installed ?? false;
      return Scaffold(
        appBar: AppBar(
          title: const Text('画板'),
          actions: [
            if (installed)
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            const SizedBox(width: 8),
          ],
          bottom: installed
              ? TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: '二维坐标轴'), Tab(text: '金字塔')],
                )
              : null,
        ),
        body: installed ? _buildBody() : _buildInstallGate(),
      );
    });
  }

  Widget _buildInstallGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 56,
              color: Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text('画板还没有安装', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              '安装后即可自定义坐标轴与金字塔的命名',
              style: TextStyle(color: Colors.black45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _installing ? null : _install,
              child: _installing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('安装画板'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: TabBarView(
        controller: _tabController,
        children: [_buildAxisView(), _buildPyramidView()],
      ),
    );
  }

  // ==================== 平面坐标轴 ====================
  Widget _buildAxisView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          _buildDimensionRow(),
          const SizedBox(height: 8),
          // ===== Y轴顶端（正方向） =====
          Column(
            children: [
              Icon(Icons.arrow_upward, size: 16, color: _axisColor),
              SizedBox(width: 84, child: _buildAxisEndField(_yHighLabel)),
              Container(width: 2, height: 10, color: _axisColor),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                // X轴左端（负方向）
                SizedBox(
                  width: 84,
                  child: Row(
                    children: [
                      Expanded(child: _buildAxisEndField(_xLowLabel)),
                      Container(width: 10, height: 2, color: _axisColor),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildQuadrantField(
                                _quadrantControllers[1],
                              ),
                            ),
                            Container(width: 2, color: _axisColor),
                            Expanded(
                              child: _buildQuadrantField(
                                _quadrantControllers[0],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 2, color: _axisColor),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildQuadrantField(
                                _quadrantControllers[3],
                              ),
                            ),
                            Container(width: 2, color: _axisColor),
                            Expanded(
                              child: _buildQuadrantField(
                                _quadrantControllers[2],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // X轴右端（正方向）
                SizedBox(
                  width: 84,
                  child: Row(
                    children: [
                      Container(width: 10, height: 2, color: _axisColor),
                      Expanded(child: _buildAxisEndField(_xHighLabel)),
                      Icon(Icons.arrow_forward, size: 14, color: _axisColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ===== Y轴底端（负方向） =====
          Column(
            children: [
              Container(width: 2, height: 10, color: _axisColor),
              SizedBox(width: 84, child: _buildAxisEndField(_yLowLabel)),
            ],
          ),
        ],
      ),
    );
  }

  // 两个维度的名称（写入 config 的 xAxisLabel / yAxisLabel）
  Widget _buildDimensionRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _xAxisLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'X 轴（横向）',
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _yAxisLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Y 轴（纵向）',
              labelStyle: const TextStyle(fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAxisEndField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: _axisColor,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildQuadrantField(TextEditingController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: TextFormField(
          controller: controller,
          maxLines: 3,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: _quadrantFillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }

  // ==================== 金字塔 ====================
  Widget _buildPyramidView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;
        // 金字塔只占可用高度的 65%，避免撑满页面
        final pyramidHeight = totalHeight * 0.65;
        const layerCount = 3;
        final layerHeight = pyramidHeight / layerCount;

        // 三层底宽：构成三角形——顶层为一点，底层满宽
        final bottomWidths = [
          totalWidth / 3,
          totalWidth * 2 / 3,
          totalWidth,
        ];
        final topWidths = [0.0, bottomWidths[0], bottomWidths[1]];

        final layerColors = [
          Colors.blue.shade700,
          Colors.blue.shade500,
          Colors.blue.shade300,
        ];

        return Center(
          child: SizedBox(
            height: pyramidHeight,
            child: Column(
              children: List.generate(layerCount, (i) {
                return SizedBox(
                  height: layerHeight,
                  child: Center(
                    child: _buildPyramidLayer(
                      width: bottomWidths[i],
                      topWidth: topWidths[i],
                      color: layerColors[i],
                      controller: _pyramidControllers[i],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // 金字塔单层：梯形裁剪 + 输入框
  Widget _buildPyramidLayer({
    required double width,
    required double topWidth,
    required Color color,
    required TextEditingController controller,
  }) {
    // topInsetRatio = (底宽 - 顶宽) / 2 / 底宽，控制上边缘左右缩进
    final topInsetRatio =
        topWidth >= width ? 0.0 : (width - topWidth) / 2 / width;
    return SizedBox(
      width: width,
      child: ClipPath(
        clipper: TrapezoidClipper(topInsetRatio: topInsetRatio),
        child: Container(
          height: double.infinity,
          color: color,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}

// 梯形裁剪器：topInsetRatio 控制上边缘左右各缩进的比例（0~0.5）
class TrapezoidClipper extends CustomClipper<Path> {
  final double topInsetRatio;

  TrapezoidClipper({this.topInsetRatio = 0.0});

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
  bool shouldReclip(covariant TrapezoidClipper old) =>
      old.topInsetRatio != topInsetRatio;
}
