// 管理路由
import 'package:flutter/material.dart';
import 'package:view/pages/login/index.dart';
import 'package:view/pages/main/index.dart';
import 'package:view/pages/plugin/axis/index.dart';
import 'package:view/pages/plugin/pomodoro/index.dart';

// 返回App根级组件
Widget getRootWidget() {
  return MaterialApp(
    // 命名路由，注册路由表
    initialRoute: '/', // 设置首页
    routes: getRootRoutes()
  );
}

// 返回该App的路由配置  
Map<String, Widget Function(BuildContext)> getRootRoutes() {
  return {
    '/': (context) => MainPage(), // 主页路由
    '/login': (context) => LoginPage(), // 登录页路由
    '/axis': (context) => AxisPage(), // 坐标轴插件路由
    '/pomodoro': (context) => PomodoroPage(), // 番茄钟插件路由
  };
}
