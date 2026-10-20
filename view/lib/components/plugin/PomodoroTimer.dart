import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:view/stores/PluginController.dart';
import 'package:view/utils/NotificationService.dart';

/// 番茄钟计时器组件（带波浪动画的圆形倒计时）
///
/// - 计时对象（label）来自插件配置
/// - 时长在开始前选择，只存在于运行时，不落库
/// - 用结束时间戳计算剩余秒数，切后台/锁屏回来不会漂移
/// - 到点发送本地通知
class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({super.key});

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final PluginController _pluginController = Get.find<PluginController>();

  static const List<int> _presetMinutes = [15, 25, 45, 60];

  int _totalSeconds = 25 * 60;
  int _remainingTime = 25 * 60;
  Timer? _timer;

  /// 本轮计时的结束时刻；暂停时清空。
  DateTime? _endAt;
  bool _isRunning = false;
  late Worker _durationWorker;

  late AnimationController _waveAnimationController; // 波浪流动动画
  late AnimationController _fadeAnimationController; // 波浪淡入淡出动画
  late Animation<double> _fadeAnimation;
  late AnimationController _moveAnimationController; // 文字下滑动画
  late Animation<double> _moveAnimation;

  /// 是否已经开始过（运行中或暂停中）。
  bool get _started => _isRunning || _remainingTime < _totalSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _totalSeconds = _pluginController.pomodoroMinutes.value * 60;
    _remainingTime = _totalSeconds;

    // 开始前切换时长：立即同步到圆环
    _durationWorker = ever<int>(_pluginController.pomodoroMinutes, (minutes) {
      if (!_started) {
        setState(() {
          _totalSeconds = minutes * 60;
          _remainingTime = _totalSeconds;
        });
      }
    });

    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));
    _moveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _moveAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _moveAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台时按结束时间重算，避免后台期间 Timer 被系统暂停导致倒计时变慢
    if (state == AppLifecycleState.resumed && _isRunning) {
      _tick();
    }
  }

  void _selectMinutes(int minutes) {
    if (_started) {
      return;
    }
    _pluginController.pomodoroMinutes.value = minutes;
  }

  /// 开始 / 暂停
  void _startPauseTimer() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    _endAt = DateTime.now().add(Duration(seconds: _remainingTime));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    NotificationService.instance.schedulePomodoroEnd(
      endAt: _endAt!,
      label: _pluginController.pomodoroLabel,
    );
    _waveAnimationController.repeat();
    _fadeAnimationController.forward();
    _moveAnimationController.forward();
    setState(() => _isRunning = true);
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _endAt = null;
    NotificationService.instance.cancelPomodoroEnd();
    _waveAnimationController.stop();
    _fadeAnimationController.reverse();
    _moveAnimationController.reverse();
    setState(() => _isRunning = false);
  }

  void _tick() {
    final endAt = _endAt;
    if (endAt == null) {
      return;
    }
    final remaining = endAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _onTimerComplete();
    } else if (remaining != _remainingTime) {
      setState(() => _remainingTime = remaining);
    }
  }

  /// 倒计时结束
  void _onTimerComplete() {
    _timer?.cancel();
    _timer = null;
    _endAt = null;
    _waveAnimationController.stop();
    _fadeAnimationController.reverse();
    _moveAnimationController.reverse();
    HapticFeedback.heavyImpact();
    setState(() {
      _isRunning = false;
      _remainingTime = _totalSeconds;
    });
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('专注完成！'),
          content: Text(
            '「${_pluginController.pomodoroLabel}」的专注已结束，休息一下吧。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        );
      },
    );
  }

  /// 停止并重置
  void _stopTimer() {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    _timer = null;
    _endAt = null;
    NotificationService.instance.cancelPomodoroEnd();
    _waveAnimationController.stop();
    _fadeAnimationController.reverse();
    _moveAnimationController.reverse();
    setState(() {
      _isRunning = false;
      _remainingTime = _totalSeconds;
    });
  }

  Widget _buildAnimatedButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: CustomCurve(),
      width: 80,
      height: _isRunning ? 48 : 80,
      child: GestureDetector(
        onTap: _startPauseTimer,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(_isRunning ? 24 : 25),
          ),
          child: Icon(
            _isRunning ? Icons.pause : Icons.play_arrow,
            size: 30,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  String get _statusText {
    if (_isRunning) return '专注中';
    if (_remainingTime < _totalSeconds) return '已暂停';
    return '准备开始';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _started ? 1 - _remainingTime / _totalSeconds : 0.0;
    final label = _pluginController.pomodoroLabel;

    // 可嵌入组件：不带 Scaffold，由宿主页面（我的APP）提供布局
    return Column(
      children: [
        // 开始前可选时长；开始后锁定
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(
                '计时对象：$label',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _presetMinutes.map((minutes) {
                  final selected =
                      _pluginController.pomodoroMinutes.value == minutes;
                  return ChoiceChip(
                    label: Text('$minutes 分钟'),
                    selected: selected,
                    onSelected:
                        _started ? null : (_) => _selectMinutes(minutes),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 圆形背景
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                // 波浪动画（裁剪在圆形内，水位随进度上升）
                ClipOval(
                  child: AnimatedBuilder(
                    animation: _waveAnimationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: WavePainter(
                          animation: _waveAnimationController,
                          colorScheme: colorScheme,
                          progress: progress,
                          fadeAnimation: _fadeAnimation,
                        ),
                        child: const SizedBox(
                          width: 200,
                          height: 200,
                        ),
                      );
                    },
                  ),
                ),
                // 倒计时文字与状态：开始后下滑到圆圈下方，颜色同步过渡
                AnimatedBuilder(
                  animation: _moveAnimation,
                  builder: (context, child) {
                    final textColor = ColorTween(
                      begin: colorScheme.onPrimary,
                      end: colorScheme.primary,
                    ).evaluate(_moveAnimation);
                    return Transform.translate(
                      offset: Offset(0, _moveAnimation.value * 220),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_remainingTime),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusText,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: textColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 底部按钮：开始/暂停 + 停止重置
        Padding(
          padding: const EdgeInsets.only(bottom: 32, top: 8),
          child: SizedBox(
            height: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedButton(),
                const SizedBox(width: 16),
                // 停止 / 重置按钮
                IconButton.filledTonal(
                  onPressed: _started ? _stopTimer : null,
                  icon: const Icon(Icons.stop_outlined),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    NotificationService.instance.cancelPomodoroEnd();
    _durationWorker.dispose();
    _waveAnimationController.dispose();
    _fadeAnimationController.dispose();
    _moveAnimationController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// 按钮动画使用的二次方曲线
class CustomCurve extends Curve {
  @override
  double transform(double t) {
    return t * t;
  }
}

/// 波浪画笔：绘制两层相位错开的正弦波，水位高度由 progress 决定
class WavePainter extends CustomPainter {
  final Animation<double> animation;
  final ColorScheme colorScheme;
  final double progress;
  final Animation<double> fadeAnimation;

  WavePainter({
    required this.animation,
    required this.colorScheme,
    required this.progress,
    required this.fadeAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = fadeAnimation.value;
    if (opacity == 0) return;

    final startHeight = size.height * 0.95;
    final y = startHeight - (startHeight * progress);

    // 将波浪裁剪在圆形区域内
    final clipPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ));
    canvas.clipPath(clipPath);

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final wave1 = _buildWavePath(size, now, 1.5, y);
    final wave2 = _buildWavePath(size, now + 0.5, 1.0, y);

    final paint1 = Paint()
      ..color = colorScheme.primaryContainer.withValues(alpha: 0.7 * opacity);
    final paint2 = Paint()
      ..color =
          colorScheme.secondaryContainer.withValues(alpha: 0.5 * opacity);

    canvas.drawPath(wave2, paint2);
    canvas.drawPath(wave1, paint1);
  }

  Path _buildWavePath(Size size, double time, double waveHeight, double y) {
    final path = Path();
    path.moveTo(0, y);
    for (var i = 0.0; i <= size.width; i++) {
      path.lineTo(
        i,
        y +
            math.sin((i / size.width * 4 * math.pi) + (time * 2 * math.pi)) *
                waveHeight *
                10,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return true; // 始终重绘以确保波浪流畅
  }
}
