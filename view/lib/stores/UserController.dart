import 'package:get/get.dart';
import 'package:view/api/user.dart';
import 'package:view/stores/TokenManager.dart';
import 'package:view/viewmodels/user.dart';

// 需要共享的对象 要有一些共享的属性 属性需要响应式更新
class UserController extends GetxController {
  var user = UserInfo.fromJSON({}).obs; // user对象被监听了
  // 登录态是否已经尝试恢复过（避免启动瞬间误显示"未登录"）
  final ready = false.obs;

  bool get isLoggedIn => user.value.id.isNotEmpty;

  // 启动时恢复登录态：token有值就拉用户信息回显，失效则清掉
  Future<void> restore() async {
    try {
      if (tokenManager.getToken().isNotEmpty) {
        updateUserInfo(await getUserInfoAPI());
      }
    } catch (_) {
      await tokenManager.removeToken();
    } finally {
      ready.value = true;
    }
  }

  // 想要取值的话 需要 user.value
  void updateUserInfo(UserInfo newUser) {
    user.value = newUser;
  }

  // 退出登录：先让后端把 token 加入黑名单，再清本地
  Future<void> logout() async {
    try {
      await logoutAPI();
    } catch (_) {
      // 网络异常也要允许本地退出，避免用户卡在登录态
    }
    await tokenManager.removeToken();
    user.value = UserInfo.fromJSON({});
  }
}
