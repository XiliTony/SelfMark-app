import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'dart:ui';

import 'package:view/api/user.dart';
import 'package:view/stores/TokenManager.dart';
import 'package:view/stores/UserController.dart';
import 'package:view/utils/ApiException.dart';
import 'package:view/utils/LoadingDialog.dart';
import 'package:view/utils/ToastUtils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}
// SingleTickerProviderStateMixin：为 TabController 提供 Ticker（动画驱动），
//   因为 TabController 的 vsync 需要一个 TickerProvider。
// with 把多个 mixin 的功能混入一个类中，实现代码复用。
//   如果一个类拥有某个接口要求的全部成员，它就可以被当作那个接口使用。
// vsync 需要 TickerProvider，而 SingleTickerProviderStateMixin 实现了这个接口；
//   with 之后，_LoginPageState 获得了这个实现，因而也成为 TickerProvider，
//   所以能把 this 传给 vsync。
class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // Tab 控制器，管理"登录/注册"两个标签页的切换
  // late告诉编译器：这个变量我暂时不初始化，但保证在第一次使用前一定会赋值，你不用报错。
  late TabController _tabController;

  // 登录表单的输入控制器
  final TextEditingController _mobileController = TextEditingController(); // 手机号
  final TextEditingController _passwordController = TextEditingController(); // 密码
  // 注册表单的输入控制器
  final TextEditingController _regMobileController = TextEditingController(); // 手机号
  final TextEditingController _regPasswordController = TextEditingController(); // 密码
  final TextEditingController _regUsernameController = TextEditingController(); // 昵称

  // 两个tab各一个Form的key，用于触发表单校验
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  // 从全局拿用户控制器（MainPage里已经Get.put注册过了）
  final UserController _userController = Get.find<UserController>();

  @override
  void initState() {
    super.initState();
    // 创建 TabController：2 个
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // 释放控制器，避免内存泄漏
    _tabController.dispose();
    // 输入控制器也要释放
    _mobileController.dispose();
    _passwordController.dispose();
    _regMobileController.dispose();
    _regPasswordController.dispose();
    _regUsernameController.dispose();
    super.dispose();
  }

  // ==================== 业务逻辑 ====================

  // 登录：校验通过后调接口 → 存用户信息和token → 提示 → 返回上个页面
  Future<void> _login() async {
    try {
      LoadingDialog.show(context, message: "努力登录中");
      final res = await loginAPI({
        "mobile": _mobileController.text, // 后端字段名是mobile
        "password": _passwordController.text,
      });
      // 必须先写 token 再更新登录态：市场页监听到用户变化会立刻发请求，
      // 顺序反了会出现"请求已发出但 token 还没写入内存"的 401
      await tokenManager.setToken(res.token);
      _userController.updateUserInfo(res);
      if (!mounted) return;
      ToastUtils.showToast(context, "登录成功");
      Navigator.pop(context); // 返回上个页面
    } catch (e) {
      // 同样先判断页面是否还在，再用 context 弹提示
      if (!mounted) return;
      ToastUtils.showToast(
        context,
        e is ApiException ? e.message : "操作失败，请稍后重试",
      );
    } finally {
      // 页面还在才关 loading，避免操作已销毁的 context
      if (mounted) {
        LoadingDialog.hide(context);
      }
    }
  }

  // 注册：后端注册成功直接返回token，注册即登录
  Future<void> _register() async {
    try {
      LoadingDialog.show(context, message: "努力注册中");
      final res = await registerAPI({
        "mobile": _regMobileController.text,
        "password": _regPasswordController.text,
        "username": _regUsernameController.text, // 后端注册必填昵称
      });
      await tokenManager.setToken(res.token);
      _userController.updateUserInfo(res);
      if (!mounted) return;
      ToastUtils.showToast(context, "注册成功");
      Navigator.pop(context); // 返回上个页面
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showToast(
        context,
        e is ApiException ? e.message : "操作失败，请稍后重试",
      );
    } finally {
      if (mounted) {
        LoadingDialog.hide(context);
      }
    }
  }

  // ==================== 表单校验 ====================

  // 校验手机号（与后端 @Pattern ^1[3-9]\d{9}$ 保持一致）
  String? _validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return "手机号不能为空";
    }
    if (!RegExp(r"^1[3-9]\d{9}$").hasMatch(value)) {
      return "手机号格式不正确";
    }
    return null;
  }

  // 校验密码（后端仅限制不超过72字节，这里按6-16位字母数字下划线校验）
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "密码不能为空";
    }
    if (!RegExp(r"^[a-zA-Z0-9_]{6,16}$").hasMatch(value)) {
      return "请输入6-16位的字母数字或者下划线";
    }
    return null;
  }

  // 校验昵称（后端 @Size(max = 50)）
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return "昵称不能为空";
    }
    if (value.length > 50) {
      return "昵称最长50个字符";
    }
    return null;
  }

  // ==================== UI ====================

  Padding _buildLoginTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _loginFormKey, // 绑定key才能用currentState.validate()触发校验
        child: Column(
          children: [
            _buildTextField(
              '手机号',
              controller: _mobileController,
              validator: _validateMobile,
            ),
            SizedBox(height: 20),
            _buildTextField(
              '密码',
              controller: _passwordController,
              obscureText: true, // 密码框隐藏明文
              validator: _validatePassword,
            ),
            SizedBox(height: 30),
            _buildGrandientButton('登录', onTap: () {
              // 校验通过才发起登录请求
              if (_loginFormKey.currentState!.validate()) {
                _login();
              }
            }),
          ],
        ),
      ),
    );
  }

  Padding _buildRegisterTab() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _buildTextField(
              '手机号',
              controller: _regMobileController,
              validator: _validateMobile,
            ),
            SizedBox(height: 20),
            _buildTextField(
              '昵称',
              controller: _regUsernameController,
              validator: _validateUsername,
            ),
            SizedBox(height: 20),
            _buildTextField(
              '密码',
              controller: _regPasswordController,
              obscureText: true,
              validator: _validatePassword,
            ),
            SizedBox(height: 30),
            _buildGrandientButton('注册', onTap: () {
              if (_registerFormKey.currentState!.validate()) {
                _register();
              }
            }),
          ],
        ), // Column
      ), // Form
    ); // Padding
  }

  // 通用输入框：白色文字 + 白色下划线边框
  // 由TextField换成TextFormField，配合Form才能做输入校验
  TextFormField _buildTextField(
    String text, {
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller, // 输入控制器：代码里读取输入内容
      validator: validator, // 表单校验函数
      obscureText: obscureText, // 是否隐藏输入内容（密码框用）
      style: TextStyle(color: Colors.white), // 输入文字颜色
      cursorColor: Colors.white, // 光标颜色
      decoration: InputDecoration(
        hintText: text, // 占位提示
        hintStyle: TextStyle(color: Colors.white70), // 提示文字颜色
        // 未聚焦时的下划线边框
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        // 聚焦时的下划线边框
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
      ),
    );
  }

  // 渐变按钮：圆角 + 蓝紫渐变背景
  Container _buildGrandientButton(String text, {required VoidCallback onTap}) {
    return Container(
      width: double.infinity, // 占满可用宽度
      height: 50, // 按钮高度
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25), // 圆角胶囊形
        gradient: LinearGradient(colors: [Colors.blue, Colors.indigoAccent]), // 渐变配色
      ),
      child: GestureDetector(
        onTap: onTap, // 点击回调：由调用方决定是登录还是注册
        behavior: HitTestBehavior.opaque, // 让Container整个区域都可点击
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white, // 按钮文字白色
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 返回按钮：左上角悬浮的圆形按钮
  // 半透明白底 + 白色半透明边框，与毛玻璃卡片的风格保持统一
  Positioned _buildBackButton(BuildContext context) {
    return Positioned(
      top: 0, // 锚定在 Stack 的左上角
      left: 0,
      child: SafeArea(
        // SafeArea 避开状态栏，防止按钮被状态栏遮挡
        child: Padding(
          padding: EdgeInsets.all(16), // 与屏幕边缘留出间距
          child: GestureDetector(
            // pop 把路由栈栈顶的登录页弹出，返回上一页（mine 所在的主页）
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, // 按钮尺寸
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2), // 半透明白底（同卡片）
                shape: BoxShape.circle, // 圆形
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6), // 边框（同卡片）
                  width: 1,
                ),
              ),
              // Center 让箭头图标在 40x40 的圆形按钮内居中
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new, // 返回箭头图标
                  size: 18,
                  color: Colors.white, // 白色箭头，与页面文字风格一致
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        // Stack 层级（从下往上）：
        //   1. 背景图
        //   2. 黑色半透明遮罩
        //   3. 居中毛玻璃卡片
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/mine/login_background.jpg'),
                fit: BoxFit.cover, // 铺满且不变形
              ),
            ),
          ),
          // 压暗背景图，让上方文字更清晰
          Container(color: Colors.black.withValues(alpha: 0.3)),
          // 左上角返回按钮：点击返回 mine 页
          _buildBackButton(context),
          Center(
            child: ClipRRect(
              // 裁剪圆角，让 BackdropFilter 的模糊也被裁进圆角内
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                // 毛玻璃模糊滤镜
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 400,  // 卡片高度
                  width: 300, // 卡片宽度
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2), // 半透明白底
                    borderRadius: BorderRadius.circular(20), // 圆角
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), // 边框
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // 顶部 Tab 栏：登录 / 注册
                      TabBar(
                        // 绑定控制器：TabBar 从它读取当前选中项、切换动画进度
                        // 用户点击标签时，也会通过它切换索引
                        controller: _tabController,
                        // 指示器（选中高亮块）的宽度策略：
                        // TabBarIndicatorSize.tab = 铺满整个 tab 宽度
                        // 另一个可选值 .label 表示只包住文字
                        indicatorSize: TabBarIndicatorSize.tab,
                        // 自定义指示器外观：这里用蓝→靛蓝的渐变背景块
                        // 不写的话默认是一条下划线
                        indicator: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue, Colors.indigoAccent],
                          ),
                        ),
                        // 标签列表：数量要和 TabController 的 length 一致（这里是 2）
                        tabs: [
                          Tab(text: '登录'),
                          Tab(text: '注册'),
                        ],
                        labelColor: Colors.white, // 选中标签的文字颜色
                        unselectedLabelColor: Colors.white70, // 未选中标签的文字颜色（半透明白）
                      ),
                      // 下方内容区：随 Tab 切换显示对应表单
                      // TabBarView 只负责"内容页"这部分 UI
                      // 它和上面的 TabBar 共用同一个 controller，所以能双向同步：
                      //   - 点标签 → 内容跟着切
                      //   - 左右滑内容 → 标签跟着切
                      Expanded(
                        // Expanded 让内容区占满 Column 剩余的全部高度
                        // （Column 里必须给 TabBarView 一个确定高度，否则会溢出/报错）
                        child: TabBarView(
                          controller: _tabController, // 与 TabBar 共用，保证同步
                          children: [_buildLoginTab(), _buildRegisterTab()], // 第 0、1 个 tab 对应的内容
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
