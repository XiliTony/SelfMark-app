/// 统一的接口业务异常。
///
/// 后端约定响应体 `{code, msg, data}`，[code] 与 HTTP 状态码保持一致
/// （401 未登录、403 越权、404 不存在、409 冲突……）。
class ApiException implements Exception {
  ApiException(this.code, this.message);

  /// 业务/HTTP 状态码；网络层失败时为 -1。
  final int code;

  /// 可直接展示给用户的提示文案。
  final String message;

  bool get isUnauthorized => code == 401;

  @override
  String toString() => message;
}
