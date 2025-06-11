import 'dart:async';
import 'dart:math';
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
  static final PerformanceUIMonitor _instance =
      PerformanceUIMonitor._internal();
  static PerformanceUIMonitor get instance => _instance;

  PerformanceUIMonitor._internal();

  /// 是否正在监控
  bool _isMonitoring = false;

  /// 帧率监控定时器
  Timer? _frameRateTimer;

  /// 当前页面名称
  String? _currentPageName;

  /// 帧时间记录
  final List<FrameTiming> _frameTimings = [];

  /// 帧时间戳记录（用于计算真实帧间隔）
  final List<DateTime> _frameTimestamps = [];

  /// 设备刷新率（Hz）
  double _deviceRefreshRate = 60.0;

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
    _frameTimings.clear();
    _frameTimestamps.clear();

    // 获取设备刷新率
    _detectDeviceRefreshRate();

    // 注册帧时间回调
    SchedulerBinding.instance.addTimingsCallback(_onFrameTiming);

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

    // 移除帧时间回调
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTiming);

    // 记录最终统计
    _recordFinalStats();

    logger.debug(
        '停止UI性能监控${_currentPageName != null ? ': $_currentPageName' : ''}');
    _currentPageName = null;
  }

  /// 开始页面监控
  void startPageMonitoring(String pageName) {
    stopMonitoring();
    startMonitoring(pageName);
  }

  /// 帧时间回调处理
  void _onFrameTiming(List<FrameTiming> timings) {
    if (!_isMonitoring) return;

    final now = DateTime.now();

    for (final timing in timings) {
      _frameTimings.add(timing);
      _frameTimestamps.add(now);

      // 限制记录数量
      if (_frameTimings.length > _maxFrameRecords) {
        _frameTimings.removeAt(0);
        _frameTimestamps.removeAt(0);
      }

      // 检测卡顿
      _detectJank(timing);
    }
  }

  /// 检测卡顿
  void _detectJank(FrameTiming timing) {
    final buildTimeMs = timing.buildDuration.inMicroseconds / 1000.0;
    final rasterTimeMs = timing.rasterDuration.inMicroseconds / 1000.0;
    final totalTimeMs = timing.totalSpan.inMicroseconds / 1000.0;

    // 检测UI线程卡顿
    if (buildTimeMs > _severeJankThreshold) {
      _recordJankEvent('severe_build', buildTimeMs);
    } else if (buildTimeMs > _jankThreshold) {
      _recordJankEvent('mild_build', buildTimeMs);
    }

    // 检测光栅线程卡顿
    if (rasterTimeMs > _severeJankThreshold) {
      _recordJankEvent('severe_raster', rasterTimeMs);
    } else if (rasterTimeMs > _jankThreshold) {
      _recordJankEvent('mild_raster', rasterTimeMs);
    }

    // 检测总体卡顿
    if (totalTimeMs > _severeJankThreshold) {
      _recordJankEvent('severe_total', totalTimeMs);
    } else if (totalTimeMs > _jankThreshold) {
      _recordJankEvent('mild_total', totalTimeMs);
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
        'threshold':
            severity == 'severe' ? _severeJankThreshold : _jankThreshold,
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

  /// 检测设备刷新率
  void _detectDeviceRefreshRate() {
    try {

      _deviceRefreshRate = 60.0; // 默认60Hz

      final platformDispatcher = PlatformDispatcher.instance;

      // 获取主显示器信息（通常是设备主屏幕）
      if (platformDispatcher.displays.isNotEmpty) {
        final mainDisplay = platformDispatcher.displays.first;
        _deviceRefreshRate = mainDisplay.refreshRate;
      }

      // 备用方案：通过 Flutter 引擎获取帧率
      _deviceRefreshRate = SchedulerBinding
          .instance.platformDispatcher.views.first.display.refreshRate;

      logger.debug('检测到设备刷新率: ${_deviceRefreshRate}Hz');
    } catch (e) {
      _deviceRefreshRate = 60.0;
      logger.warning('无法检测设备刷新率，使用默认值: ${_deviceRefreshRate}Hz');
    }
  }

  /// 计算并记录帧率
  void _calculateAndRecordFrameRate() {
    if (_frameTimings.isEmpty || _frameTimestamps.isEmpty) return;

    // 1. 计算真实显示帧率（基于帧间隔）
    double displayFps = 0.0;
    if (_frameTimestamps.length >= 2) {
      final timeSpan = _frameTimestamps.last.difference(_frameTimestamps.first);
      final totalSeconds = timeSpan.inMicroseconds / 1000000.0;
      if (totalSeconds > 0) {
        displayFps = (_frameTimestamps.length - 1) / totalSeconds;
        // 限制最大FPS为设备刷新率的1.1倍（允许小幅超出）
        displayFps = displayFps.clamp(0.0, _deviceRefreshRate * 1.1);
      }
    }

    // 2. 计算性能指标（基于处理时间）
    final totalMicroseconds = _frameTimings
        .map((timing) => timing.totalSpan.inMicroseconds)
        .reduce((a, b) => a + b);
    final avgFrameTimeMs = totalMicroseconds / _frameTimings.length / 1000.0;
    final processingFps = avgFrameTimeMs > 0 ? 1000.0 / avgFrameTimeMs : 0.0;

    // 计算掉帧统计（基于总时间）
    final jankFrames = _frameTimings
        .where((timing) =>
            timing.totalSpan.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final severeJankFrames = _frameTimings
        .where((timing) =>
            timing.totalSpan.inMicroseconds / 1000.0 > _severeJankThreshold)
        .length;

    // 计算UI线程掉帧统计
    final buildJankFrames = _frameTimings
        .where((timing) =>
            timing.buildDuration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final buildSevereJankFrames = _frameTimings
        .where((timing) =>
            timing.buildDuration.inMicroseconds / 1000.0 > _severeJankThreshold)
        .length;

    // 计算光栅线程掉帧统计
    final rasterJankFrames = _frameTimings
        .where((timing) =>
            timing.rasterDuration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final rasterSevereJankFrames = _frameTimings
        .where((timing) =>
            timing.rasterDuration.inMicroseconds / 1000.0 >
            _severeJankThreshold)
        .length;

    // 计算平均构建和光栅时间
    final avgBuildTimeMs = _frameTimings
            .map((timing) => timing.buildDuration.inMicroseconds)
            .reduce((a, b) => a + b) /
        _frameTimings.length /
        1000.0;
    final avgRasterTimeMs = _frameTimings
            .map((timing) => timing.rasterDuration.inMicroseconds)
            .reduce((a, b) => a + b) /
        _frameTimings.length /
        1000.0;

    // 计算显示帧率相关统计
    final expectedFrameInterval = 1000.0 / _deviceRefreshRate; // 期望帧间隔(ms)
    final displayJankFrames =
        _calculateDisplayJankFrames(expectedFrameInterval);
    final displaySevereJankFrames =
        _calculateDisplaySevereJankFrames(expectedFrameInterval);

    // 记录显示帧率数据
    final displayRecord = PerformanceRecord(
      type: PerformanceType.frameRate,
      name: 'display_fps_${_currentPageName ?? 'global'}',
      value: displayFps,
      timestamp: DateTime.now(),
      additionalData: {
        'type': 'display_fps',
        'deviceRefreshRate': _deviceRefreshRate,
        'expectedFrameInterval': expectedFrameInterval,
        'totalFrames': _frameTimestamps.length,
        'displayJankFrames': displayJankFrames,
        'displaySevereJankFrames': displaySevereJankFrames,
        'displayJankPercentage': _frameTimestamps.isNotEmpty
            ? (displayJankFrames / _frameTimestamps.length * 100)
            : 0.0,
        'displaySevereJankPercentage': _frameTimestamps.isNotEmpty
            ? (displaySevereJankFrames / _frameTimestamps.length * 100)
            : 0.0,
        'page': _currentPageName,
        'interval': _frameRateInterval,
      },
    );

    // 记录处理性能数据
    final processingRecord = PerformanceRecord(
      type: PerformanceType.frameRate,
      name: 'processing_fps_${_currentPageName ?? 'global'}',
      value: processingFps,
      timestamp: DateTime.now(),
      additionalData: {
        'type': 'processing_fps',
        'avgFrameTime': avgFrameTimeMs,
        'avgBuildTime': avgBuildTimeMs,
        'avgRasterTime': avgRasterTimeMs,
        'totalFrames': _frameTimings.length,
        'jankFrames': jankFrames,
        'severeJankFrames': severeJankFrames,
        'buildJankFrames': buildJankFrames,
        'buildSevereJankFrames': buildSevereJankFrames,
        'rasterJankFrames': rasterJankFrames,
        'rasterSevereJankFrames': rasterSevereJankFrames,
        'jankPercentage': _frameTimings.isNotEmpty
            ? (jankFrames / _frameTimings.length * 100)
            : 0.0,
        'buildJankPercentage': _frameTimings.isNotEmpty
            ? (buildJankFrames / _frameTimings.length * 100)
            : 0.0,
        'rasterJankPercentage': _frameTimings.isNotEmpty
            ? (rasterJankFrames / _frameTimings.length * 100)
            : 0.0,
        'page': _currentPageName,
        'interval': _frameRateInterval,
      },
    );

    // 提交两个记录
    PerformanceTracker.instance.addRecord(displayRecord);
    PerformanceTracker.instance.addRecord(processingRecord);

    if (kDebugMode) {
      logger.info(
        '显示帧率: ${displayFps.toStringAsFixed(1)}fps, '
        '处理帧率: ${processingFps.toStringAsFixed(1)}fps, '
        '平均帧时间: ${avgFrameTimeMs.toStringAsFixed(2)}ms, '
        '掉帧率: ${(_frameTimings.isNotEmpty ? (jankFrames / _frameTimings.length * 100) : 0.0).toStringAsFixed(1)}% '
        '(页面: ${_currentPageName ?? 'global'})',
      );
    }
  }

  /// 计算显示帧率卡顿帧数
  int _calculateDisplayJankFrames(double expectedFrameInterval) {
    if (_frameTimestamps.length < 2) return 0;

    int jankCount = 0;
    for (int i = 1; i < _frameTimestamps.length; i++) {
      final interval = _frameTimestamps[i]
              .difference(_frameTimestamps[i - 1])
              .inMicroseconds /
          1000.0;
      if (interval > expectedFrameInterval * 1.5) {
        // 超过期望间隔1.5倍视为卡顿
        jankCount++;
      }
    }
    return jankCount;
  }

  /// 计算显示帧率严重卡顿帧数
  int _calculateDisplaySevereJankFrames(double expectedFrameInterval) {
    if (_frameTimestamps.length < 2) return 0;

    int severeJankCount = 0;
    for (int i = 1; i < _frameTimestamps.length; i++) {
      final interval = _frameTimestamps[i]
              .difference(_frameTimestamps[i - 1])
              .inMicroseconds /
          1000.0;
      if (interval > expectedFrameInterval * 2.0) {
        // 超过期望间隔2倍视为严重卡顿
        severeJankCount++;
      }
    }
    return severeJankCount;
  }

  /// 记录最终统计
  void _recordFinalStats() {
    if (_frameTimings.isEmpty) return;

    final totalFrames = _frameTimings.length;
    final jankFrames = _frameTimings
        .where((timing) =>
            timing.totalSpan.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final severeJankFrames = _frameTimings
        .where((timing) =>
            timing.totalSpan.inMicroseconds / 1000.0 > _severeJankThreshold)
        .length;
    final buildJankFrames = _frameTimings
        .where((timing) =>
            timing.buildDuration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;
    final rasterJankFrames = _frameTimings
        .where((timing) =>
            timing.rasterDuration.inMicroseconds / 1000.0 > _jankThreshold)
        .length;

    final record = PerformanceRecord(
      type: PerformanceType.uiRendering,
      name: 'ui_performance_summary_${_currentPageName ?? 'global'}',
      timestamp: DateTime.now(),
      additionalData: {
        'totalFrames': totalFrames,
        'jankFrames': jankFrames,
        'severeJankFrames': severeJankFrames,
        'buildJankFrames': buildJankFrames,
        'rasterJankFrames': rasterJankFrames,
        'jankPercentage':
            totalFrames > 0 ? (jankFrames / totalFrames * 100) : 0.0,
        'severeJankPercentage':
            totalFrames > 0 ? (severeJankFrames / totalFrames * 100) : 0.0,
        'buildJankPercentage':
            totalFrames > 0 ? (buildJankFrames / totalFrames * 100) : 0.0,
        'rasterJankPercentage':
            totalFrames > 0 ? (rasterJankFrames / totalFrames * 100) : 0.0,
        'page': _currentPageName,
        'monitoringDuration':
            _frameRateInterval * (_frameTimings.length / 60).ceil(),
      },
    );

    PerformanceTracker.instance.addRecord(record);
  }

  /// 获取当前帧率统计
  Map<String, dynamic> getCurrentFrameStats() {
    if (_frameTimings.isEmpty && _frameTimestamps.isEmpty) {
      return {
        'displayFps': 0.0,
        'processingFps': 0.0,
        'avgFrameTime': 0.0,
        'avgBuildTime': 0.0,
        'avgRasterTime': 0.0,
        'totalFrames': 0,
        'jankFrames': 0,
        'buildJankFrames': 0,
        'rasterJankFrames': 0,
        'displayJankFrames': 0,
        'jankPercentage': 0.0,
        'buildJankPercentage': 0.0,
        'rasterJankPercentage': 0.0,
        'displayJankPercentage': 0.0,
        'deviceRefreshRate': _deviceRefreshRate,
      };
    }

    // 计算处理帧率（基于FrameTiming）
    double processingFps = 0.0;
    double avgFrameTimeMs = 0.0;
    double avgBuildTimeMs = 0.0;
    double avgRasterTimeMs = 0.0;
    int jankFrames = 0;
    int buildJankFrames = 0;
    int rasterJankFrames = 0;

    if (_frameTimings.isNotEmpty) {
      final totalMicroseconds = _frameTimings
          .map((timing) => timing.totalSpan.inMicroseconds)
          .reduce((a, b) => a + b);
      avgFrameTimeMs = totalMicroseconds / _frameTimings.length / 1000.0;
      processingFps = avgFrameTimeMs > 0 ? 1000.0 / avgFrameTimeMs : 0.0;

      avgBuildTimeMs = _frameTimings
              .map((timing) => timing.buildDuration.inMicroseconds)
              .reduce((a, b) => a + b) /
          _frameTimings.length /
          1000.0;
      avgRasterTimeMs = _frameTimings
              .map((timing) => timing.rasterDuration.inMicroseconds)
              .reduce((a, b) => a + b) /
          _frameTimings.length /
          1000.0;

      jankFrames = _frameTimings
          .where((timing) =>
              timing.totalSpan.inMicroseconds / 1000.0 > _jankThreshold)
          .length;
      buildJankFrames = _frameTimings
          .where((timing) =>
              timing.buildDuration.inMicroseconds / 1000.0 > _jankThreshold)
          .length;
      rasterJankFrames = _frameTimings
          .where((timing) =>
              timing.rasterDuration.inMicroseconds / 1000.0 > _jankThreshold)
          .length;
    }

    // 计算显示帧率（基于帧时间戳）
    double displayFps = 0.0;
    int displayJankFrames = 0;

    if (_frameTimestamps.length >= 2) {
      final totalDuration =
          _frameTimestamps.last.difference(_frameTimestamps.first);
      final frameCount = _frameTimestamps.length - 1;
      if (totalDuration.inMicroseconds > 0 && frameCount > 0) {
        displayFps = frameCount * 1000000.0 / totalDuration.inMicroseconds;
        // 限制显示帧率不超过设备刷新率的1.1倍
        displayFps = min(displayFps, _deviceRefreshRate * 1.1);
      }

      final expectedFrameInterval = 1000.0 / _deviceRefreshRate;
      displayJankFrames = _calculateDisplayJankFrames(expectedFrameInterval);
    }

    return {
      'displayFps': displayFps,
      'processingFps': processingFps,
      'avgFrameTime': avgFrameTimeMs,
      'avgBuildTime': avgBuildTimeMs,
      'avgRasterTime': avgRasterTimeMs,
      'totalFrames': max(_frameTimings.length, _frameTimestamps.length),
      'jankFrames': jankFrames,
      'buildJankFrames': buildJankFrames,
      'rasterJankFrames': rasterJankFrames,
      'displayJankFrames': displayJankFrames,
      'jankPercentage': _frameTimings.isNotEmpty
          ? (jankFrames / _frameTimings.length * 100)
          : 0.0,
      'buildJankPercentage': _frameTimings.isNotEmpty
          ? (buildJankFrames / _frameTimings.length * 100)
          : 0.0,
      'rasterJankPercentage': _frameTimings.isNotEmpty
          ? (rasterJankFrames / _frameTimings.length * 100)
          : 0.0,
      'displayJankPercentage': _frameTimestamps.isNotEmpty
          ? (displayJankFrames / _frameTimestamps.length * 100)
          : 0.0,
      'deviceRefreshRate': _deviceRefreshRate,
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
    _frameTimings.clear();
    _frameTimestamps.clear();
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
  State<PerformanceMonitorWidget> createState() =>
      _PerformanceMonitorWidgetState();
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
