// 全局的常量
class GlobalConstants {
  static const String BASE_URL = "http://10.0.2.2:8080"; // 基础地址
  static const int TIME_OUT = 10; // 超时时间
  static const int SUCCESS_CODE = 200; // 成功状态
  static const String TOKEN_KEY = "selfmark_token"; // token对应的持久化的 key
}

// 存放请求地址接口的常量（后端接口都以 /api 开头）
class HttpConstants {
  static const String LOGIN = "/api/auth/login"; // 登录请求地址
  static const String REGISTER = "/api/auth/register"; // 注册请求地址
  static const String LOGOUT = "/api/auth/logout"; // 退出登录地址
  static const String USER_PROFILE = "/api/users/me"; // 用户信息接口地址
}