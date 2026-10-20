import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/routes/index.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/stores/TokenManager.dart';
import 'package:view/stores/UserController.dart';

Future<void> main() async {
  // 先初始化持久化的 token，再启动 UI，避免首屏请求发出去时还没有 token
  WidgetsFlutterBinding.ensureInitialized();
  await tokenManager.init();
  // 全局注册共享状态（市场页、我的APP、编辑页都通过 Get.find 获取）
  Get.put(UserController());
  Get.put(PluginController());
  runApp(getRootWidget());
}
