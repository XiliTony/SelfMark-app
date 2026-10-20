/// 番茄钟（pomodoro）插件配置模型。
///
/// 按 PRD 约定，config 只持久化 [label]（计时对象）；
/// 计时时长由用户在开始计时前临时选择，不落库。
library;

class PomodoroConfig {
  PomodoroConfig({required this.label});

  final String label;

  static const String defaultLabel = '专注';

  factory PomodoroConfig.fromJson(Map<String, dynamic>? json) {
    final value = json?['label'];
    if (value is String && value.trim().isNotEmpty) {
      return PomodoroConfig(label: value);
    }
    return PomodoroConfig(label: defaultLabel);
  }

  Map<String, dynamic> toJson() => {'label': label};
}
