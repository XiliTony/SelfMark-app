import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/components/market/MkCards.dart';
import 'package:view/components/market/MkSearch.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/stores/UserController.dart';
import 'package:view/viewmodels/user.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  _MarketPageState createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final UserController _userController = Get.find<UserController>();
  final PluginController _pluginController = Get.find<PluginController>();

  // 监听登录态：登录成功（或启动恢复完成）后自动拉市场；退出登录后清空
  late final Worker _authWorker;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _authWorker = ever<UserInfo>(_userController.user, (user) {
      if (user.id.isEmpty) {
        _pluginController.plugins.clear();
      } else {
        _pluginController.load();
      }
    });
    if (_userController.isLoggedIn) {
      _pluginController.load();
    }
  }

  @override
  void dispose() {
    _authWorker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 启动恢复登录态期间先显示 loading，避免闪一下"未登录"
      if (!_userController.ready.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!_userController.isLoggedIn) {
        return _buildLoginGate();
      }
      if (_pluginController.isLoading.value &&
          _pluginController.plugins.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_pluginController.loadError.value.isNotEmpty &&
          _pluginController.plugins.isEmpty) {
        return _buildError(_pluginController.loadError.value);
      }

      return RefreshIndicator(
        onRefresh: () => _pluginController.load(silent: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MkSearch(
                onChanged: (value) => setState(() => _keyword = value),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(child: MkCards(keyword: _keyword)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      );
    });
  }

  Widget _buildLoginGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: Colors.black.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            const Text(
              '登录后即可浏览和安装插件',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.black26),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => _pluginController.load(),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}
