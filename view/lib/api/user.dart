// 登录接口API

import 'package:view/contants/index.dart';
import 'package:view/utils/DioRequest.dart';
import 'package:view/viewmodels/user.dart';

Future<UserInfo> loginAPI(Map<String, dynamic> data) async {
  return UserInfo.fromJSON(
    await dioRequest.post(HttpConstants.LOGIN, data: data),
  );
}

// 注册接口：后端注册成功直接返回token，注册即登录
Future<UserInfo> registerAPI(Map<String, dynamic> data) async {
  return UserInfo.fromJSON(
    await dioRequest.post(HttpConstants.REGISTER, data: data),
  );
}

Future<UserInfo> getUserInfoAPI() async {
  return UserInfo.fromJSON(
    await dioRequest.get(HttpConstants.USER_PROFILE),
  );
}

// 登出：后端把当前 token 的 jti 写入 Redis 黑名单，使其立即失效
Future<void> logoutAPI() async {
  await dioRequest.post(HttpConstants.LOGOUT);
}
