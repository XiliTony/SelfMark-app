// 基于 dio 进行二次封装：注入 token、统一解包 {code, msg, data}、统一抛 ApiException
import 'package:dio/dio.dart';
import 'package:view/contants/index.dart';
import 'package:view/stores/TokenManager.dart';
import 'package:view/utils/ApiException.dart';

class DioRequest {
  // dio 请求对象
  final Dio _dio = Dio();

  DioRequest() {
    _dio.options
      ..baseUrl = GlobalConstants.BASE_URL
      ..connectTimeout = Duration(seconds: GlobalConstants.TIME_OUT)
      ..sendTimeout = Duration(seconds: GlobalConstants.TIME_OUT)
      ..receiveTimeout = Duration(seconds: GlobalConstants.TIME_OUT)
      ..contentType = Headers.jsonContentType
      ..responseType = ResponseType.json;
    _addInterceptor();
  }

  // 只负责注入 token；判错与解包集中在 _handleResponse，避免拦截器把状态码弄丢
  void _addInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (tokenManager.getToken().isNotEmpty) {
            request.headers["Authorization"] = "Bearer ${tokenManager.getToken()}";
          }
          handler.next(request);
        },
      ),
    );
  }

  Future<dynamic> get(String url, {Map<String, dynamic>? params}) {
    return _handleResponse(_dio.get(url, queryParameters: params));
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? data}) {
    return _handleResponse(_dio.post(url, data: data));
  }

  Future<dynamic> put(String url, {Map<String, dynamic>? data}) {
    return _handleResponse(_dio.put(url, data: data));
  }

  Future<dynamic> delete(String url) {
    return _handleResponse(_dio.delete(url));
  }

  // 解包统一响应体：成功只返回 data，失败抛出带 code/msg 的 ApiException
  Future<dynamic> _handleResponse(Future<Response<dynamic>> task) async {
    try {
      final Response<dynamic> res = await task;
      return _unwrap(res);
    } on DioException catch (error) {
      // 后端返回了响应（401/403/404/409……）：解包出业务提示
      if (error.response != null) {
        return _unwrap(error.response!);
      }
      // 纯网络层失败：连接不上、超时、DNS 等
      throw ApiException(-1, _networkMessage(error));
    }
  }

  dynamic _unwrap(Response<dynamic> res) {
    final body = res.data;
    if (body is Map && body["code"] == GlobalConstants.SUCCESS_CODE) {
      return body["data"];
    }
    final code = body is Map && body["code"] is int
        ? body["code"] as int
        : (res.statusCode ?? -1);
    final msg = body is Map && body["msg"] is String
        ? body["msg"] as String
        : "请求失败";
    throw ApiException(code, msg);
  }

  String _networkMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "连接服务器超时，请确认后端已启动";
      case DioExceptionType.connectionError:
        return "无法连接服务器，请检查网络";
      case DioExceptionType.cancel:
        return "请求已取消";
      default:
        return "网络异常，请稍后重试";
    }
  }
}

// 单例对象
final DioRequest dioRequest = DioRequest();
