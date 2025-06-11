import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'performance_tracker.dart';
import 'logging.dart';

/// UI渲染性能监控器
///
/// 提供以下功能：
/// - 实时帧率监控
/// - 卡顿检测
/// - 渲染时间统计
/// - 掉帧统计
///
/// 使用示例：
/// ```dart
/// // 在应用启动时初始化
/// PerformanceUIMonitor.instance.startMonitoring();
///
/// // 在特定页面监控
/// PerformanceUIMonitor.instance.startPageMonitoring('HomePage');
/// ```
class PerformanceUIMonitor {
  static final PerformanceUIMonitor _instance = PerformanceUIMonitor._internal();
  static PerformanceUIMonitor get instance => _instance;

  PerformanceUIMonitor._internal();

  /// 是否正在监控
  bool _isMonitoring = false;

  /// 帧率监控定时器
  Timer? _frameRateTimer;

  /// 当前页面名称
  String? _currentPageName;

  /// 帧时间记录
  final List<Duration> _frameTimes = [];

  /// 上一帧时间戳
  Duration? _lastFrameTime;

  /// 卡顿阈值（毫秒）
  static const int _jankThreshold = 16; // 60fps对应16.67ms

  /// 严重卡顿阈值（毫秒）
  static const int _severeJankThreshold = 32; // 30fps对应33.33ms

  /// 帧率统计间隔（秒）
  static const int _frameRateInterval = 5;

  /// 最大帧时间记录数量
  static const int _maxFrameRecords = 300; // 5秒 * 60fps

  /// 开始UI性能监控
  ///
  /// * [pageName] 页面名称，用于标识监控范围
  void startMonitoring([String? pageName]) {
    if (!PerformanceTracker.instance.isEnabled || _isMonitoring) return;

    _isMonitoring = true;
    _currentPageName = pageName;
    _frameTimes.clear();
    _lastFrameTime = null;

    // 注册帧回调
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);

    // 启动帧率统计定时器
    _frameRateTimer = Timer.periodic(
      const Duration(seconds: _frameRateInterval),
      (_) => _calculateAndRecordFrameRate(),
    );

    logger.debug('开始UI性能监控${pageName != null ? ': $pageName' : ''}');
  }

  /// 停止UI性能监控
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _frameRateTimer?.cancel();
    _frameRateTimer = null;

    // 移除帧回调
    // SchedulerBinding.instance.removePersistentFrameCallback(_onFrame);

    // 记录最终统计
    _recordFinalStats();

    logger.debug('停止UI性能监控${_currentPageName != null ? ': $_currentPageName' : ''}');
    _currentPageName = null;
  }

  /// 开始页面监控
  void startPageMonitoring(String pageName) {
    stopMonitoring();
    startMonitoring(pageName);
  }

  /// 帧回调处理
  void _onFrame(Duration timestamp) {
    if (!_isMonitoring) return;

    if (_lastFrameTime != null) {
      final frameDuration = timestamp - _lastFrameTime!;
      _frameTimes.add(frameDuration);

      // 限制记录数量
      if (_frameTimes.length > _maxFrameRecords) {
        _frameTimes.removeAt(0);
      }

      // 检测卡顿
      _detectJank(frameDuration);
    }

    _lastFrameTime = timestamp;
  }

  /// 检测卡顿
  void _detectJank(Duration frameDuration) {
    final frameTimeMs = frameDuration.inMicroseconds / 1000.0;

    if (frameTimeMs > _severeJankThreshold) {
      // 严重卡顿
      _recordJankEvent('severe', frameTimeMs);
    } else if (frameTimeMs > _jankThreshold) {
      // 轻微卡顿
      _recordJankEvent('mild', frameTimeMs);
    }
  }

  /// 记录卡顿事件
  void _recordJankEvent(String severity, double frameTimeMs) {
    final record = PerformanceRecord(
      type: PerformanceType.jankDetection,
      name: 'jank_${severity}_${_currentPageName ?? 'unknown'}',
      value: frameTimeMs,
      timestamp: DateTime.now(),
      additionalData: {
        'severity': severity,
        'threshold': severity == 'severe' ? _severeJankThreshold : _jankThreshold,
        'page': _currentPageName,
      },
    );

    PerformanceTracker.instance.addRecord(record);

    if (kDebugMode) {
      logger.warning(
        '检测到${severity == 'severe' ? '严重' : '轻微'}卡顿: '
        '${frameTimeMs.toStringAsFixed(2)}ms '
        '(页面: ${_currentPageName ?? 'unknown'})',
      );
    }
  }

  /// 计算并记录帧率
  void _calculateAndRecordFrameRate() {
    if (_frameTimes.isEmpty) return;

    // 计算平均帧时间
    final totalMicroseconds = _frameTimes
        .map((duration) => duration.inMicroseconds)
        .reduce((a, b) => a + b);
    final avgFrameTimeMs = totalMicroseconds / _frameTimes.length / 1000.0;

    // 计算帧率
    final fps = avgFrameTimeMs > 0 ? 1000.0 / avgFrameTimeMs : 0.0;

    // 计算掉帧统计
    final jankFrames = _frameTimes
        .where((duration) => duration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final severeJankFrames = _frameTimes
        .where((duration) => duration.inMicroseconds / 1000.0 > _severeJankThreshold)
        .length;

    // 记录帧率数据
    final record = PerformanceRecord(
      type: PerformanceType.frameRate,
      name: 'frame_rate_${_currentPageName ?? 'global'}',
      value: fps,
      timestamp: DateTime.now(),
      additionalData: {
        'avgFrameTime': avgFrameTimeMs,
        'totalFrames': _frameTimes.length,
        'jankFrames': jankFrames,
        'severeJankFrames': severeJankFrames,
        'jankPercentage': _frameTimes.isNotEmpty ? (jankFrames / _frameTimes.length * 100) : 0.0,
        'page': _currentPageName,
        'interval': _frameRateInterval,
      },
    );

    PerformanceTracker.instance.addRecord(record);

    if (kDebugMode && fps < 50) {
      logger.warning(
        '帧率较低: ${fps.toStringAsFixed(1)}fps '
        '(页面: ${_currentPageName ?? 'global'}, '
        '掉帧: $jankFrames/${_frameTimes.length})',
      );
    }
  }

  /// 记录最终统计
  void _recordFinalStats() {
    if (_frameTimes.isEmpty) return;

    final totalFrames = _frameTimes.length;
    final jankFrames = _frameTimes
        .where((duration) => duration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final severeJankFrames = _frameTimes
        .where((duration) => duration.inMicroseconds / 1000.0 > _severeJankThreshold)
        .length;

    final record = PerformanceRecord(
      type: PerformanceType.uiRendering,
      name: 'ui_performance_summary_${_currentPageName ?? 'global'}',
      timestamp: DateTime.now(),
      additionalData: {
        'totalFrames': totalFrames,
        'jankFrames': jankFrames,
        'severeJankFrames': severeJankFrames,
        'jankPercentage': totalFrames > 0 ? (jankFrames / totalFrames * 100) : 0.0,
        'severeJankPercentage': totalFrames > 0 ? (severeJankFrames / totalFrames * 100) : 0.0,
        'page': _currentPageName,
        'monitoringDuration': _frameRateInterval * (_frameTimes.length / 60).ceil(),
      },
    );

    PerformanceTracker.instance.addRecord(record);
  }

  /// 获取当前帧率统计
  Map<String, dynamic> getCurrentFrameStats() {
    if (_frameTimes.isEmpty) {
      return {
        'fps': 0.0,
        'avgFrameTime': 0.0,
        'totalFrames': 0,
        'jankFrames': 0,
        'jankPercentage': 0.0,
      };
    }

    final totalMicroseconds = _frameTimes
        .map((duration) => duration.inMicroseconds)
        .reduce((a, b) => a + b);
    final avgFrameTimeMs = totalMicroseconds / _frameTimes.length / 1000.0;
    final fps = avgFrameTimeMs > 0 ? 1000.0 / avgFrameTimeMs : 0.0;
    final jankFrames = _frameTimes
        .where((duration) => duration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;

    return {
      'fps': fps,
      'avgFrameTime': avgFrameTimeMs,
      'totalFrames': _frameTimes.length,
      'jankFrames': jankFrames,
      'jankPercentage': _frameTimes.isNotEmpty ? (jankFrames / _frameTimes.length * 100) : 0.0,
      'page': _currentPageName,
    };
  }

  /// 是否正在监控
  bool get isMonitoring => _isMonitoring;

  /// 当前监控的页面
  String? get currentPage => _currentPageName;

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _frameTimes.clear();
  }
}

/// UI性能监控Widget
///
/// 自动在Widget生命周期中启动和停止UI性能监控
class PerformanceMonitorWidget extends StatefulWidget {
  final Widget child;
  final String? pageName;
  final bool autoStart;

  const PerformanceMonitorWidget({
    super.key,
    required this.child,
    this.pageName,
    this.autoStart = true,
  });

  @override
  State<PerformanceMonitorWidget> createState() => _PerformanceMonitorWidgetState();
}

class _PerformanceMonitorWidgetState extends State<PerformanceMonitorWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceUIMonitor.instance.startPageMonitoring(
          widget.pageName ?? widget.runtimeType.toString(),
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.autoStart) {
      PerformanceUIMonitor.instance.stopMonitoring();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        PerformanceUIMonitor.instance.stopMonitoring();
        break;
      case AppLifecycleState.resumed:
        if (widget.autoStart) {
          PerformanceUIMonitor.instance.startPageMonitoring(
            widget.pageName ?? widget.runtimeType.toString(),
          );
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// UI性能监控Mixin
///
/// 为StatefulWidget提供便捷的UI性能监控功能
mixin PerformanceMonitorMixin<T extends StatefulWidget> on State<T> {
  String? get performancePageName => null;
  bool get enablePerformanceMonitoring => true;

  @override
  void initState() {
    super.initState();
    if (enablePerformanceMonitoring) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerformanceUIMonitor.instance.startPageMonitoring(
          performancePageName ?? T.toString(),
        );
      });
    }
  }

  @override
  void dispose() {
    if (enablePerformanceMonitoring) {
      PerformanceUIMonitor.instance.stopMonitoring();
    }
    super.dispose();
  }
}
