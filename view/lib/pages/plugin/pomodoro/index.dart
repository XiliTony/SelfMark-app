import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/models/plugin.dart';
import 'package:view/models/pomodoro_config.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/utils/ToastUtils.dart';

/// 番茄钟配置页：按 PRD 只编辑 label（计时对象），时长不落库。
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  _PomodoroPageState createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  final PluginController _controller = Get.find<PluginController>();

  late TextEditingController _labelController;
  bool _saving = false;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: PomodoroConfig.fromJson(_controller.pomodoro?.config).label,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    final plugin = _controller.pomodoro;
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
    setState(() {
      _labelController.text =
          PomodoroConfig.fromJson(_controller.pomodoro?.config).label;
    });
  }

  Future<void> _save() async {
    final plugin = _controller.pomodoro;
    if (plugin == null || !plugin.installed) {
      ToastUtils.showToast(context, '请先安装番茄钟插件');
      return;
    }
    if (_saving) {
      return;
    }
    final label = _labelController.text.trim().isEmpty
        ? PomodoroConfig.defaultLabel
        : _labelController.text.trim();
    setState(() => _saving = true);
    final error = await _controller.saveConfig(
      plugin,
      PomodoroConfig(label: label).toJson(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (error == null) {
      _labelController.text = label;
    }
    ToastUtils.showToast(context, error ?? '已保存');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final plugin = _controller.pomodoro;
      final installed = plugin?.installed ?? false;
      return Scaffold(
        appBar: AppBar(
          title: const Text('番茄钟'),
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
        ),
        body: installed ? _buildForm(plugin!) : _buildInstallGate(),
      );
    });
  }

  Widget _buildForm(MarketPlugin plugin) {
    final enabled = plugin.isEnabled;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '计时对象',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _labelController,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '例如：学习、写作、复盘',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              enabled ? '插件已启用，可在「我的APP」里开始计时。' : '插件当前已禁用，去插件市场打开开关后即可使用。',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '关于计时时长',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '时长在每次开始计时前临时选择，不会保存；'
                    '计时在本地运行，到点会发送本地通知，断网也能用。',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 56,
              color: Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text('番茄钟还没有安装', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              '安装后即可设置计时对象，并在「我的APP」里开始专注',
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
                  : const Text('安装番茄钟'),
            ),
          ],
        ),
      ),
    );
  }
}
