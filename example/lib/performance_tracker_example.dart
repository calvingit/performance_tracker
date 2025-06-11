import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:dio/dio.dart';
import 'package:performance_tracker/performance_tracker.dart';
import 'package:performance_tracker/performance_tracker/logging.dart';

/// 性能追踪器使用示例
///
/// 展示如何使用 PerformanceTracker、PerformanceDioInterceptor、
/// PerformanceUIMonitor 和 PerformanceDashboard 进行全面性能监控
class PerformanceTrackerExample {
  static final _random = Random();
  static late Dio _dio;

  /// 运行完整示例
  static Future<void> runExample() async {
    logger.info('开始性能追踪示例');

    // 1. 初始化性能追踪器
    await _initializeTracker();

    // 2. 初始化网络监控
    _initializeNetworkMonitoring();

    // 3. 初始化UI性能监控
    _initializeUIMonitoring();

    // 4. 模拟页面加载性能测试
    await _simulatePageLoadPerformance();

    // 5. 模拟网络请求性能测试
    await _simulateNetworkPerformance();

    // 6. 记录自定义指标
    await _recordCustomMetrics();

    // 7. 模拟UI性能监控
    await _simulateUIPerformance();

    // 8. 获取并打印统计信息
    _printStatistics();

    // 9. 导出数据
    await _exportPerformanceData();

    logger.info('性能追踪示例完成');
  }

  /// 初始化性能追踪器
  static Future<void> _initializeTracker() async {
    logger.info('初始化性能追踪器');

    // 启用性能监控
    PerformanceTracker.instance.setEnabled(true);

    // 设置最大记录数
    PerformanceTracker.instance.setMaxRecords(1000);

    logger.info('性能追踪器初始化完成');
  }

  /// 初始化网络监控
  static void _initializeNetworkMonitoring() {
    logger.info('初始化网络监控');

    // 创建Dio实例
    _dio = Dio();

    // 添加性能监控拦截器
    _dio.addPerformanceInterceptor(
      enableDetailedLogging: true,
      recordRequestSize: true,
      recordResponseSize: true,
      maxUrlLength: 100,
    );

    logger.info('网络监控初始化完成');
  }

  /// 初始化UI性能监控
  static void _initializeUIMonitoring() {
    logger.info('初始化UI性能监控');

    // 启动UI性能监控
    PerformanceUIMonitor.instance.startMonitoring();

    logger.info('UI性能监控初始化完成');
  }

  /// 模拟页面加载性能测试
  static Future<void> _simulatePageLoadPerformance() async {
    logger.info('开始页面加载性能测试');

    for (int i = 0; i < 3; i++) {
      final pageName = '页面${i + 1}';

      // 开始页面加载计时
      PerformanceTracker.instance.startPageLoad(pageName);

      // 模拟页面加载时间
      final loadTime = _random.nextInt(1000) + 500; // 500-1500ms
      await Future.delayed(Duration(milliseconds: loadTime));

      // 结束页面加载计时
      PerformanceTracker.instance.endPageLoad(pageName, {
        'loadTime': loadTime,
        'route': '/page$i',
        'hasData': _random.nextBool(),
      });

      logger.info('完成页面加载: $pageName (${loadTime}ms)');
    }

    logger.info('页面加载性能测试完成');
  }

  /// 模拟网络请求性能测试
  static Future<void> _simulateNetworkPerformance() async {
    logger.info('开始网络请求性能测试');

    // 使用Dio进行网络请求，拦截器会自动记录性能数据
    for (int i = 0; i < 5; i++) {
      try {
        // 模拟不同的API端点
        final endpoints = [
          'https://jsonplaceholder.typicode.com/posts/1',
          'https://jsonplaceholder.typicode.com/users/1',
          'https://jsonplaceholder.typicode.com/albums/1',
          'https://httpbin.org/delay/1',
          'https://httpbin.org/status/200',
        ];

        final url = endpoints[i % endpoints.length];
        logger.info('发起网络请求: $url');

        final response = await _dio.get(url);
        logger.info('网络请求成功: ${response.statusCode}');
      } catch (e) {
        logger.warning('网络请求失败: $e');
      }

      // 添加一些延迟
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 也可以手动记录网络请求（用于非Dio请求）
    for (int i = 0; i < 3; i++) {
      final requestName = '手动记录请求 ${i + 1}';

      // 开始网络请求计时
      final stopWatch =
          PerformanceTracker.instance.startNetworkRequest(requestName);

      // 模拟网络延迟
      final delay = _random.nextInt(500) + 100; // 100-600ms
      await Future.delayed(Duration(milliseconds: delay));

      // 模拟请求成功/失败
      final success = _random.nextBool();

      // 结束网络请求计时
      PerformanceTracker.instance.endNetworkRequest(
        requestName,
        stopWatch,
        success: success,
      );

      logger.info(
          '完成手动网络请求: $requestName (${success ? "成功" : "失败"}, ${delay}ms)');
    }

    logger.info('网络请求性能测试完成');
  }

  /// 记录自定义指标
  static Future<void> _recordCustomMetrics() async {
    logger.info('开始记录自定义指标');

    // 使用 PerformanceHelper.measure 测量异步操作
    await PerformanceHelper.measure(
      '数据库查询',
      () async {
        // 模拟数据库查询
        await Future.delayed(Duration(milliseconds: _random.nextInt(200) + 50));
        return '查询结果';
      },
    );

    // 使用 PerformanceHelper.measureSync 测量同步操作
    PerformanceHelper.measureSync(
      '数据处理',
      () {
        // 模拟数据处理
        final data = List.generate(1000, (i) => _random.nextDouble());
        data.sort();
        return data.length;
      },
    );

    // 直接记录自定义指标
    PerformanceTracker.instance.recordCustomMetric(
      '内存使用率',
      _random.nextDouble() * 100,
      additionalData: {
        'unit': 'percentage',
        'threshold': 80.0,
      },
    );

    PerformanceTracker.instance.recordCustomMetric(
      'CPU使用率',
      _random.nextDouble() * 100,
      additionalData: {
              'unit': 'percentage',
        'cores': 4,
      },
    );

    logger.info('自定义指标记录完成');
  }

  /// 模拟UI性能监控
  static Future<void> _simulateUIPerformance() async {
    logger.info('开始UI性能监控测试');

    // 模拟页面切换
    for (int i = 0; i < 3; i++) {
      final pageName = '页面${i + 1}';

      // 开始页面监控
      PerformanceUIMonitor.instance.startPageMonitoring(pageName);

      // 模拟页面渲染时间
      await Future.delayed(Duration(milliseconds: _random.nextInt(1000) + 500));

      // 停止页面监控
      PerformanceUIMonitor.instance.stopMonitoring();

      logger.info('完成页面监控: $pageName');

      // 页面间隔
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // 模拟一些卡顿情况
    for (int i = 0; i < 2; i++) {
      // 手动记录卡顿
      PerformanceTracker.instance.addRecord(PerformanceRecord(
        type: PerformanceType.jankDetection,
        name: '模拟卡顿 ${i + 1}',
        timestamp: DateTime.now(),
        value: 20.0 + _random.nextDouble() * 10, // 20-30ms的帧时间
        additionalData: {
          'severity': _random.nextBool() ? 'severe' : 'mild',
          'page': '测试页面',
          'frameTime': 20.0 + _random.nextDouble() * 10,
        },
      ));
    }

    logger.info('UI性能监控测试完成');
  }

  /// 获取并打印统计信息
  static void _printStatistics() {
    logger.info('=== 性能统计信息 ===');

    // 获取总体统计
    final overallStats = PerformanceTracker.instance.getStats();
    logger.info('总体统计:');
    logger.info('  总记录数: ${overallStats.totalRecords}');
    logger.info(
        '  平均持续时间: ${overallStats.avgDuration?.toStringAsFixed(2) ?? "N/A"} ms');
    logger.info('  最大持续时间: ${overallStats.maxDuration ?? "N/A"} ms');
    logger.info('  最小持续时间: ${overallStats.minDuration ?? "N/A"} ms');

    // 获取各类型统计
    for (final type in PerformanceType.values) {
      final typeStats = PerformanceTracker.instance.getStats(type);
      if (typeStats.totalRecords > 0) {
        logger.info('${_getTypeDisplayName(type)}统计:');
        logger.info('  记录数: ${typeStats.totalRecords}');
        logger.info(
            '  平均持续时间: ${typeStats.avgDuration?.toStringAsFixed(2) ?? "N/A"} ms');
        logger.info('  最大持续时间: ${typeStats.maxDuration ?? "N/A"} ms');
      }
    }

    // 获取UI性能统计
    final uiStats = PerformanceUIMonitor.instance.getCurrentFrameStats();
    logger.info('UI性能统计:');
    logger.info('  当前帧率: ${uiStats['fps'].toStringAsFixed(1)} FPS');
    logger.info('  掉帧率: ${uiStats['jankPercentage'].toStringAsFixed(1)}%');
    logger.info('  总帧数: ${uiStats['totalFrames']}');
    logger.info('  掉帧数: ${uiStats['jankFrames']}');

    // 获取最近的记录
    final recentRecords = PerformanceTracker.instance.records.take(5).toList();
    logger.info('最近5条记录:');
    for (final record in recentRecords) {
      logger.info(
          '  ${record.name}: ${record.duration ?? record.value ?? "N/A"}${record.duration != null ? "ms" : ""} (${_getTypeDisplayName(record.type)})');
    }

    logger.info('=== 统计信息结束 ===');
  }

  /// 导出性能数据
  static Future<void> _exportPerformanceData() async {
    logger.info('开始导出性能数据');

    try {
      final filePath = await PerformanceTracker.instance.exportData();
      if (filePath != null) {
        logger.info('性能数据已导出到: $filePath');
      } else {
        logger.warning('性能数据导出失败');
      }
    } catch (e) {
      logger.severe('导出性能数据时发生错误: $e');
    }
  }

  /// 获取类型显示名称
  static String _getTypeDisplayName(PerformanceType type) {
    switch (type) {
      case PerformanceType.pageLoad:
        return '页面加载';
      case PerformanceType.networkRequest:
        return '网络请求';
      case PerformanceType.customMetric:
        return '自定义指标';
      case PerformanceType.jankDetection:
        return '卡顿检测';
      default:
        return type.toString();
    }
  }

  /// 页面加载性能测试示例
  static void trackPagePerformance(BuildContext context, String pageName) {
    // 在页面构建开始时调用
    PerformanceTracker.instance.startPageLoad(pageName);

    // 在页面完全加载后调用（例如在initState的异步加载完成后）
    // 通常在数据加载完成并更新UI后调用
    SchedulerBinding.instance.addPostFrameCallback((_) {
      PerformanceTracker.instance.endPageLoad(pageName, {
        'route': ModalRoute.of(context)?.settings.name,
        'orientation': MediaQuery.of(context).orientation.name,
      });
    });
  }

  /// 网络请求性能测试示例
  static Future<Map<String, dynamic>> fetchDataWithPerformanceTracking(
    String url,
    Future<Map<String, dynamic>> Function() apiCall,
  ) async {
    // 开始记录网络请求性能
    final stopwatch = PerformanceTracker.instance.startNetworkRequest(url);

    try {
      // 执行实际的网络请求
      final result = await apiCall();

      // 记录请求完成
      PerformanceTracker.instance.endNetworkRequest(
        url,
        stopwatch,
        success: true,
        responseSize: result.toString().length,
        statusCode: 200, // 假设成功状态码为200
      );

      return result;
    } catch (e) {
      // 记录请求失败
      PerformanceTracker.instance.endNetworkRequest(
        url,
        stopwatch,
        success: false,
      );

      rethrow;
    }
  }

  /// 使用辅助方法测量代码块性能
  static Future<void> measureOperationPerformance() async {
    // 测量异步操作
    final result = await PerformanceHelper.measure<List<String>>(
      'load_user_data',
      () async {
        // 模拟耗时操作
        await Future.delayed(const Duration(milliseconds: 300));
        return ['user1', 'user2', 'user3'];
      },
    );

    // 测量同步操作
    final _ = PerformanceHelper.measureSync<Map<String, int>>(
      'process_user_data',
      () {
        // 模拟数据处理
        final map = <String, int>{};
        for (var i = 0; i < result.length; i++) {
          map[result[i]] = i;
        }
        return map;
      },
    );
  }

  /// 记录自定义性能指标
  static void trackCustomMetrics(int itemCount, double scrollSpeed) {
    // 记录列表项数量
    PerformanceTracker.instance.recordCustomMetric(
      'list_item_count',
      itemCount.toDouble(),
      unit: 'items',
    );

    // 记录滚动速度
    PerformanceTracker.instance.recordCustomMetric(
      'scroll_speed',
      scrollSpeed,
      unit: 'px/s',
    );
  }

  /// 导出性能数据
  static Future<void> exportPerformanceData() async {
    // 导出所有收集的性能数据到JSON文件
    final filePath = await PerformanceTracker.instance.exportData();

    if (filePath != null) {
      logger.info('性能数据已导出到: $filePath');
      // 这里可以添加代码，将文件分享或上传到服务器
    }
  }

  /// 获取并打印性能统计信息
  static void printPerformanceStats() {
    // 获取所有性能数据的统计信息
    final allStats = PerformanceTracker.instance.getStats();
    logger.info('所有性能数据统计: $allStats');

    // 获取页面加载性能统计
    final pageLoadStats =
        PerformanceTracker.instance.getStats(PerformanceType.pageLoad);
    logger.info('页面加载性能统计: $pageLoadStats');

    // 获取网络请求性能统计
    final networkStats =
        PerformanceTracker.instance.getStats(PerformanceType.networkRequest);
    logger.info('网络请求性能统计: $networkStats');
  }

  /// 在应用退出时清理资源
  static void dispose() {
    PerformanceTracker.instance.dispose();
  }
}

/// 性能监控StatefulWidget示例
class PerformanceMonitoredPage extends StatefulWidget {
  final String pageName;

  const PerformanceMonitoredPage({
    super.key,
    required this.pageName,
  });

  @override
  State<PerformanceMonitoredPage> createState() =>
      _PerformanceMonitoredPageState();
}

class _PerformanceMonitoredPageState extends State<PerformanceMonitoredPage>
    with PerformanceMonitorMixin {
  List<String> _items = [];
  bool _isLoading = true;

  String get pageName => widget.pageName;

  @override
  void initState() {
    super.initState();

    // 开始记录页面加载性能
    PerformanceTracker.instance.startPageLoad(widget.pageName);

    // 模拟数据加载
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 使用性能辅助方法测量数据加载
      _items = await PerformanceHelper.measure<List<String>>(
        '${widget.pageName}_data_loading',
        () async {
          // 模拟网络请求
          await Future.delayed(const Duration(seconds: 1));
          return List.generate(100, (index) => '项目 ${index + 1}');
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // 在UI更新后结束页面加载性能记录
        SchedulerBinding.instance.addPostFrameCallback((_) {
          PerformanceTracker.instance.endPageLoad(widget.pageName, {
            'itemCount': _items.length,
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('性能监控示例: ${widget.pageName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              PerformanceTrackerExample._printStatistics();
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              PerformanceTrackerExample._exportPerformanceData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerformanceDashboard(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                // 每50项记录一次自定义指标
                if (index % 50 == 0) {
                  PerformanceTracker.instance.recordCustomMetric(
                    'visible_item_index',
                    index.toDouble(),
                  );
                }

                return ListTile(
                  title: Text(_items[index]),
                  onTap: () {
                    // 记录项目点击
                    PerformanceTracker.instance.recordCustomMetric(
                      'item_tap',
                      index.toDouble(),
                      additionalData: {'item': _items[index]},
                    );
                  },
                );
              },
            ),
    );
  }
}
