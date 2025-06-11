import 'package:dio/dio.dart';
import 'performance_tracker.dart';
import 'logging.dart';

/// Dio网络请求性能监控拦截器
///
/// 自动记录所有通过Dio发起的网络请求性能数据，包括：
/// - 请求耗时
/// - 请求成功/失败状态
/// - 响应数据大小
/// - HTTP状态码
/// - 请求方法和URL
///
/// 使用示例：
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(PerformanceDioInterceptor());
/// ```
class PerformanceDioInterceptor extends Interceptor {
  /// 请求开始时间记录
  final Map<RequestOptions, Stopwatch> _requestTimers = {};

  /// 是否启用详细日志
  final bool enableDetailedLogging;

  /// 是否记录请求体大小
  final bool recordRequestSize;

  /// 是否记录响应体大小
  final bool recordResponseSize;

  /// 最大记录的URL长度，超过部分会被截断
  final int maxUrlLength;

  PerformanceDioInterceptor({
    this.enableDetailedLogging = false,
    this.recordRequestSize = true,
    this.recordResponseSize = true,
    this.maxUrlLength = 200,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!PerformanceTracker.instance.isEnabled) {
      handler.next(options);
      return;
    }

    // 开始计时
    final stopwatch = Stopwatch()..start();
    _requestTimers[options] = stopwatch;

    if (enableDetailedLogging) {
      logger.debug('开始网络请求: ${options.method} ${_truncateUrl(options.uri.toString())}');
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _recordNetworkPerformance(
      response.requestOptions,
      success: true,
      statusCode: response.statusCode,
      responseSize: recordResponseSize ? _calculateResponseSize(response) : null,
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordNetworkPerformance(
      err.requestOptions,
      success: false,
      statusCode: err.response?.statusCode,
      responseSize: recordResponseSize && err.response != null
          ? _calculateResponseSize(err.response!)
          : null,
      error: err.message,
    );

    handler.next(err);
  }

  /// 记录网络请求性能数据
  void _recordNetworkPerformance(
    RequestOptions options, {
    required bool success,
    int? statusCode,
    int? responseSize,
    String? error,
  }) {
    final stopwatch = _requestTimers.remove(options);
    if (stopwatch == null) {
      logger.warning('未找到请求计时器: ${options.uri}');
      return;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;

    // 构建请求标识
    final requestName = '${options.method} ${_truncateUrl(options.uri.toString())}';

    // 构建额外数据
    final additionalData = <String, dynamic>{
      'method': options.method,
      'url': options.uri.toString(),
      'success': success,
      if (statusCode != null) 'statusCode': statusCode,
      if (responseSize != null) 'responseSize': responseSize,
      if (recordRequestSize) 'requestSize': _calculateRequestSize(options),
      if (error != null) 'error': error,
      'headers': options.headers.length,
      if (options.queryParameters.isNotEmpty)
        'queryParams': options.queryParameters.length,
    };

    // 记录性能数据
    final record = PerformanceRecord(
      type: PerformanceType.networkRequest,
      name: requestName,
      duration: duration,
      timestamp: DateTime.now(),
      additionalData: additionalData,
    );

    PerformanceTracker.instance.addRecord(record);

    if (enableDetailedLogging) {
      logger.debug(
        '网络请求完成: $requestName, '
        '耗时: ${duration}ms, '
        '成功: $success'
        '${statusCode != null ? ', 状态码: $statusCode' : ''}'
        '${responseSize != null ? ', 响应大小: ${_formatBytes(responseSize)}' : ''}',
      );
    }
  }

  /// 计算请求数据大小
  int _calculateRequestSize(RequestOptions options) {
    int size = 0;

    // URL长度
    size += options.uri.toString().length;

    // Headers大小
    options.headers.forEach((key, value) {
      size += key.length + value.toString().length;
    });

    // 请求体大小
    if (options.data != null) {
      if (options.data is String) {
        size += (options.data as String).length;
      } else if (options.data is List<int>) {
        size += (options.data as List<int>).length;
      } else {
        // 对于其他类型，估算大小
        size += options.data.toString().length;
      }
    }

    return size;
  }

  /// 计算响应数据大小
  int _calculateResponseSize(Response response) {
    if (response.data == null) return 0;

    if (response.data is String) {
      return (response.data as String).length;
    } else if (response.data is List<int>) {
      return (response.data as List<int>).length;
    } else if (response.data is Map || response.data is List) {
      // 对于JSON数据，转换为字符串计算大小
      return response.data.toString().length;
    } else {
      return response.data.toString().length;
    }
  }

  /// 截断URL长度
  String _truncateUrl(String url) {
    if (url.length <= maxUrlLength) return url;
    return '${url.substring(0, maxUrlLength)}...';
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// 清理资源
  void dispose() {
    _requestTimers.clear();
  }
}
