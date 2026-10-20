// 生成对应的class
// 对应后端 AuthResponse：{ id: Long, mobile: String, username: String, token: String }
class UserInfo {
  String id;
  String mobile;
  String username;
  String token;

  UserInfo({
    required this.id,
    required this.mobile,
    required this.username,
    required this.token,
  });

  // 将后端返回的数据转换为类
  factory UserInfo.fromJSON(Map<String, dynamic> json) => UserInfo(
    id: json["id"]?.toString() ?? "", // 后端id是Long(JSON数字) 转成字符串
    mobile: json["mobile"] ?? "",
    username: json["username"] ?? "",
    token: json["token"] ?? "",
  );
}
