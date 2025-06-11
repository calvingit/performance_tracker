import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'logging.dart';

/// 性能测试数据记录工具类
///
/// 用于快速记录和分析Flutter应用的性能指标，包括：
/// - 页面加载时间
/// - 网络请求耗时
/// - 内存使用情况
/// - CPU使用率
/// - 帧率统计
/// - 自定义性能指标
///
/// 使用示例：
/// ```dart
/// // 开始记录页面加载性能
/// PerformanceTracker.instance.startPageLoad('HomePage');
///
/// // 结束记录
/// PerformanceTracker.instance.endPageLoad('HomePage');
///
/// // 记录网络请求
/// final stopwatch = PerformanceTracker.instance.startNetworkRequest('api/users');
/// // ... 执行网络请求
/// PerformanceTracker.instance.endNetworkRequest('api/users', stopwatch);
///
/// // 导出性能数据
/// await PerformanceTracker.instance.exportData();
/// ```
class PerformanceTracker {
  static final PerformanceTracker _instance = PerformanceTracker._internal();
  static PerformanceTracker get instance => _instance;

  PerformanceTracker._internal();

  /// 性能数据存储
  final List<PerformanceRecord> _records = [];

  /// 正在进行的性能测试记录
  final Map<String, Stopwatch> _activeTimers = {};

  /// 内存使用情况监控定时器
  Timer? _memoryMonitorTimer;

  /// 是否启用性能监控
  bool _isEnabled = !kReleaseMode;

  /// 最大记录数量，防止内存溢出
  int _maxRecords = 1000;

  /// 启用或禁用性能监控
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _stopMemoryMonitoring();
    }
  }

  /// 设置最大记录数量，默认1000
  void setMaxRecords(int maxRecords) {
    _maxRecords = maxRecords;
  }

  /// 检查是否启用
  bool get isEnabled => _isEnabled;

  /// 开始页面加载性能测试
  ///
  /// * [pageName] 页面名称，用于标识不同页面
  void startPageLoad(String pageName) {
    if (!_isEnabled) return;

    final key = 'page_load_$pageName';
    _activeTimers[key] = Stopwatch()..start();

    logger.debug('开始记录页面加载性能: $pageName');
  }

  /// 结束页面加载性能测试
  ///
  /// * [pageName] 页面名称
  /// * [additionalData] 额外的性能数据
  void endPageLoad(String pageName, [Map<String, dynamic>? additionalData]) {
    if (!_isEnabled) return;

    final key = 'page_load_$pageName';
    final stopwatch = _activeTimers.remove(key);

    if (stopwatch == null) {
      logger.warning('未找到页面加载计时器: $pageName');
      return;
    }

    stopwatch.stop();

    final record = PerformanceRecord(
      type: PerformanceType.pageLoad,
      name: pageName,
      duration: stopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
      additionalData: additionalData,
    );

    _addRecord(record);
    logger.debug('页面加载完成: $pageName, 耗时: ${stopwatch.elapsedMilliseconds}ms');
  }

  /// 开始网络请求性能测试
  ///
  /// * [requestName] 请求名称或URL
  ///
  /// 返回计时器，用于后续结束计时
  Stopwatch startNetworkRequest(String requestName) {
    if (!_isEnabled) return Stopwatch();

    final stopwatch = Stopwatch()..start();
    logger.debug('开始记录网络请求性能: $requestName');
    return stopwatch;
  }

  /// 结束网络请求性能测试
  ///
  /// * [requestName] 请求名称或URL
  /// * [stopwatch] 开始时返回的计时器
  /// * [success] 请求是否成功
  /// * [responseSize] 响应数据大小（字节）
  /// * [statusCode] HTTP状态码
  void endNetworkRequest(
    String requestName,
    Stopwatch stopwatch, {
    bool success = true,
    int? responseSize,
    int? statusCode,
  }) {
    if (!_isEnabled) return;

    stopwatch.stop();

    final record = PerformanceRecord(
      type: PerformanceType.networkRequest,
      name: requestName,
      duration: stopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
      additionalData: {
        'success': success,
        if (responseSize != null) 'responseSize': responseSize,
        if (statusCode != null) 'statusCode': statusCode,
      },
    );

    _addRecord(record);
    logger.debug('网络请求完成: $requestName, 耗时: ${stopwatch.elapsedMilliseconds}ms, 成功: $success');
  }

  /// 记录自定义性能指标
  ///
  /// * [name] 指标名称
  /// * [value] 指标值
  /// * [unit] 单位（如：ms, MB, %等）
  /// * [additionalData] 额外数据
  void recordCustomMetric(
    String name,
    double value, {
    String unit = '',
    Map<String, dynamic>? additionalData,
  }) {
    if (!_isEnabled) return;

    final record = PerformanceRecord(
      type: PerformanceType.customMetric,
      name: name,
      value: value,
      timestamp: DateTime.now(),
      additionalData: {
        if (unit.isNotEmpty) 'unit': unit,
        ...?additionalData,
      },
    );

    _addRecord(record);
    logger.debug('记录自定义指标: $name = $value $unit');
  }

  /// 开始内存监控
  ///
  /// * [intervalSeconds] 监控间隔（秒）
  void startMemoryMonitoring([int intervalSeconds = 5]) {
    if (!_isEnabled) return;

    _stopMemoryMonitoring();

    _memoryMonitorTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _recordMemoryUsage(),
    );

    logger.debug('开始内存监控，间隔: $intervalSeconds秒');
  }

  /// 停止内存监控
  void stopMemoryMonitoring() {
    _stopMemoryMonitoring();
    logger.debug('停止内存监控');
  }

  /// 内部停止内存监控方法
  void _stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
  }

  /// 记录内存使用情况
  void _recordMemoryUsage() {
    if (!_isEnabled) return;

    // 获取当前内存使用情况
    final info = ProcessInfo.currentRss;
    final memoryMB = info / (1024 * 1024); // 转换为MB

    recordCustomMetric(
      'memory_usage',
      memoryMB,
      unit: 'MB',
      additionalData: {
        'rss_bytes': info,
      },
    );
  }

  /// 记录帧率信息
  ///
  /// * [fps] 帧率值
  /// * [sceneName] 场景名称
  void recordFrameRate(double fps, [String sceneName = 'default']) {
    recordCustomMetric(
      'frame_rate_$sceneName',
      fps,
      unit: 'fps',
    );
  }

  /// 添加性能记录
  void _addRecord(PerformanceRecord record) {
    _records.add(record);

    // 限制记录数量，防止内存溢出
    if (_records.length > _maxRecords) {
      _records.removeRange(0, _records.length - _maxRecords);
    }
  }

  /// 公开的添加记录方法，供外部拦截器使用
  void addRecord(PerformanceRecord record) {
    if (!_isEnabled) return;
    _addRecord(record);
  }

  /// 获取所有性能记录
  List<PerformanceRecord> get records => List.unmodifiable(_records);

  /// 获取指定类型的性能记录
  List<PerformanceRecord> getRecordsByType(PerformanceType type) {
    return _records.where((record) => record.type == type).toList();
  }

  /// 获取指定名称的性能记录
  List<PerformanceRecord> getRecordsByName(String name) {
    return _records.where((record) => record.name == name).toList();
  }

  /// 获取性能统计信息
  PerformanceStats getStats([PerformanceType? type]) {
    final targetRecords = type != null
        ? getRecordsByType(type)
        : _records;

    if (targetRecords.isEmpty) {
      return PerformanceStats.empty();
    }

    final durations = targetRecords
        .where((r) => r.duration != null)
        .map((r) => r.duration!)
        .toList();

    final values = targetRecords
        .where((r) => r.value != null)
        .map((r) => r.value!)
        .toList();

    return PerformanceStats(
      totalRecords: targetRecords.length,
      avgDuration: durations.isNotEmpty
          ? durations.reduce((a, b) => a + b) / durations.length
          : null,
      maxDuration: durations.isNotEmpty
          ? durations.reduce((a, b) => a > b ? a : b)
          : null,
      minDuration: durations.isNotEmpty
          ? durations.reduce((a, b) => a < b ? a : b)
          : null,
      avgValue: values.isNotEmpty
          ? values.reduce((a, b) => a + b) / values.length
          : null,
      maxValue: values.isNotEmpty
          ? values.reduce((a, b) => a > b ? a : b)
          : null,
      minValue: values.isNotEmpty
          ? values.reduce((a, b) => a < b ? a : b)
          : null,
    );
  }

  /// 导出性能数据到文件
  ///
  /// * [fileName] 文件名，默认使用时间戳
  ///
  /// 返回导出的文件路径
  Future<String?> exportData([String? fileName]) async {
    if (!_isEnabled || _records.isEmpty) {
      logger.warning('性能监控未启用或无数据可导出');
      return null;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'performance_data_$timestamp.json';
      final file = File('${directory.path}/$name');

      final data = {
        'exportTime': DateTime.now().toIso8601String(),
        'totalRecords': _records.length,
        'stats': getStats().toJson(),
        'records': _records.map((r) => r.toJson()).toList(),
      };

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );

      logger.info('性能数据已导出到: ${file.path}');
      return file.path;
    } catch (e, stackTrace) {
      logger.severe(e, '导出性能数据失败', stackTrace);
      return null;
    }
  }

  /// 清空所有性能记录
  void clear() {
    _records.clear();
    _activeTimers.clear();
    logger.debug('已清空所有性能记录');
  }

  /// 释放资源
  void dispose() {
    _stopMemoryMonitoring();
    _activeTimers.clear();
    _records.clear();
  }
}

/// 性能记录类型
enum PerformanceType {
  /// 页面加载
  pageLoad,
  /// 网络请求
  networkRequest,
  /// 自定义指标
  customMetric,
  /// UI渲染性能
  uiRendering,
  /// 帧率监控
  frameRate,
  /// 卡顿检测
  jankDetection,
}

/// 性能记录数据模型
class PerformanceRecord {
  /// 性能类型
  final PerformanceType type;

  /// 记录名称
  final String name;

  /// 持续时间（毫秒）
  final int? duration;

  /// 数值（用于自定义指标）
  final double? value;

  /// 记录时间戳
  final DateTime timestamp;

  /// 额外数据
  final Map<String, dynamic>? additionalData;

  const PerformanceRecord({
    required this.type,
    required this.name,
    this.duration,
    this.value,
    required this.timestamp,
    this.additionalData,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'name': name,
      if (duration != null) 'duration': duration,
      if (value != null) 'value': value,
      'timestamp': timestamp.toIso8601String(),
      if (additionalData != null) 'additionalData': additionalData,
    };
  }

  /// 从JSON创建
  factory PerformanceRecord.fromJson(Map<String, dynamic> json) {
    return PerformanceRecord(
      type: PerformanceType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      name: json['name'],
      duration: json['duration'],
      value: json['value']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      additionalData: json['additionalData'],
    );
  }

  @override
  String toString() {
    return 'PerformanceRecord(type: $type, name: $name, duration: $duration, value: $value, timestamp: $timestamp)';
  }
}

/// 性能统计信息
class PerformanceStats {
  /// 总记录数
  final int totalRecords;

  /// 平均持续时间
  final double? avgDuration;

  /// 最大持续时间
  final int? maxDuration;

  /// 最小持续时间
  final int? minDuration;

  /// 平均数值
  final double? avgValue;

  /// 最大数值
  final double? maxValue;

  /// 最小数值
  final double? minValue;

  const PerformanceStats({
    required this.totalRecords,
    this.avgDuration,
    this.maxDuration,
    this.minDuration,
    this.avgValue,
    this.maxValue,
    this.minValue,
  });

  /// 创建空统计信息
  factory PerformanceStats.empty() {
    return const PerformanceStats(totalRecords: 0);
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'totalRecords': totalRecords,
      if (avgDuration != null) 'avgDuration': avgDuration,
      if (maxDuration != null) 'maxDuration': maxDuration,
      if (minDuration != null) 'minDuration': minDuration,
      if (avgValue != null) 'avgValue': avgValue,
      if (maxValue != null) 'maxValue': maxValue,
      if (minValue != null) 'minValue': minValue,
    };
  }

  @override
  String toString() {
    return 'PerformanceStats(totalRecords: $totalRecords, avgDuration: $avgDuration, maxDuration: $maxDuration, minDuration: $minDuration)';
  }
}

/// 性能测试辅助工具类
class PerformanceHelper {
  /// 测量代码块执行时间
  ///
  /// * [name] 测试名称
  /// * [action] 要测量的代码块
  ///
  /// 返回执行结果
  static Future<T> measure<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await action();
      stopwatch.stop();

      PerformanceTracker.instance.recordCustomMetric(
        name,
        stopwatch.elapsedMilliseconds.toDouble(),
        unit: 'ms',
        additionalData: {'success': true},
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      PerformanceTracker.instance.recordCustomMetric(
        name,
        stopwatch.elapsedMilliseconds.toDouble(),
        unit: 'ms',
        additionalData: {
          'success': false,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }

  /// 测量同步代码块执行时间
  ///
  /// * [name] 测试名称
  /// * [action] 要测量的代码块
  ///
  /// 返回执行结果
  static T measureSync<T>(
    String name,
    T Function() action,
  ) {
    final stopwatch = Stopwatch()..start();

    try {
      final result = action();
      stopwatch.stop();

      PerformanceTracker.instance.recordCustomMetric(
        name,
        stopwatch.elapsedMilliseconds.toDouble(),
        unit: 'ms',
        additionalData: {'success': true},
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      PerformanceTracker.instance.recordCustomMetric(
        name,
        stopwatch.elapsedMilliseconds.toDouble(),
        unit: 'ms',
        additionalData: {
          'success': false,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }
}
