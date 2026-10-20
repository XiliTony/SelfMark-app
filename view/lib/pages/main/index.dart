import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:view/pages/market/index.dart';
import 'package:view/pages/mine/index.dart';
import 'package:view/pages/home/index.dart';
import 'package:view/pages/timer/index.dart';
import 'package:view/stores/UserController.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 定义数据 根据数据进行渲染4个导航
  // 一般应用程序的导航是固定的
  final List<Map<String, String>> _tabList = [
    // 插件市场标签
    {
      "icon": 'lib/assets/tab/market_normal.png', // 未选中状态图标
      "active_icon": 'lib/assets/tab/market_active.png', // 选中状态图标
      "name": '插件市场', // 标签名称
    },
    // 我的APP标签
    {
      "icon": 'lib/assets/tab/app_normal.png',
      "active_icon": 'lib/assets/tab/app_active.png',
      "name": '我的APP',
    },
    // 计时器标签
    {
      "icon": 'lib/assets/tab/ai_normal.png',
      "active_icon": 'lib/assets/tab/ai_active.png',
      "name": '小智助手',
    },
    // 个人标签
    {
      "icon": 'lib/assets/tab/mine_normal.png',
      "active_icon": 'lib/assets/tab/mine_active.png',
      "name": '个人',
    },
  ];

  int _currentIndex = 0;

  // 全局状态已在 main() 中注册，这里直接取用（IndexedStack下四个页面共享）
  final UserController _userController = Get.find<UserController>();

  @override
  void initState() {
    super.initState();
    // 恢复登录态：token 有值就拉用户信息，市场页会监听登录态自动加载插件
    _userController.restore();
  }

  List<Widget> _getChildren() {
    return [MarketPage(), PluginPage(), TimerPage(), MinePage()];
  }

  List<BottomNavigationBarItem> _getTabBarWidget() {
    // 使用函数循环生成循环项
    return List.generate(_tabList.length, (int index) {
      return BottomNavigationBarItem(
        icon: Image.asset(_tabList[index]["icon"]!, width: 30, height: 30),
        activeIcon: Image.asset(
          _tabList[index]["active_icon"]!,
          width: 30,
          height: 30,
        ),
        label: _tabList[index]["name"],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea避开安全区组件
      body: SafeArea(
        child: IndexedStack(
          /**
           *   ========== IndexedStack 索引栈 ==========
              作用：在多个子组件中，只显示 index 指定的那一个
              与 PageView / 直接切换子组件的区别：
              1. 所有 children 都会被构建并保留在 widget 树中
              2. 切换 index 时只改变可见性，不会销毁/重建组件
              3. 因此各页面的状态（滚动位置、输入内容等）会被保留
              代价：所有子组件一开始就全部构建，内存占用比按需构建更高
              适用场景：底部导航栏（BottomNavigationBar）这类需要频繁切换、
              且希望保留各页状态的场景
           */
          index: _currentIndex, // 当前显示第几个子组件
          children: _getChildren(), // 放置四个组件
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black, // 选中项颜色
        unselectedItemColor: Colors.black, //未选中项颜色（与选中一致，靠图标/标签样式区分）
        showUnselectedLabels: true, // 未选中项也显示文字标签
        onTap: (int index) {
          // 点击底部导航项：更新当前索引，触发 IndexedStack 切换页面
          setState(() {
            _currentIndex = index;
          });
        },
        currentIndex: _currentIndex, // 当前选中的索引，与 IndexedStack 共用
        items: _getTabBarWidget(), // 生成四个导航项
      ),
    );
  }
}
