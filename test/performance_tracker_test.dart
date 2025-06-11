import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:performance_tracker/performance_tracker.dart';

// 模拟 PathProvider 平台实现
class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/mock/documents';
  }

  @override
  Future<String?> getApplicationCachePath() {
    throw UnimplementedError();
  }

  @override
  Future<String?> getApplicationSupportPath() {
    throw UnimplementedError();
  }

  @override
  Future<String?> getDownloadsPath() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>?> getExternalCachePaths() {
    throw UnimplementedError();
  }

  @override
  Future<String?> getExternalStoragePath() {
    throw UnimplementedError();
  }

  @override
  Future<List<String>?> getExternalStoragePaths({StorageDirectory? type}) {
    throw UnimplementedError();
  }

  @override
  Future<String?> getLibraryPath() {
    throw UnimplementedError();
  }

  @override
  Future<String?> getTemporaryPath() {
    throw UnimplementedError();
  }
}

void main() {
  group('PerformanceTracker Tests', () {
    late PerformanceTracker tracker;

    setUp(() {
      // 替换 PathProviderPlatform 实例为模拟实现
      PathProviderPlatform.instance = MockPathProviderPlatform();

      // 创建新的 PerformanceTracker 实例
      tracker = PerformanceTracker.instance;
      tracker.setEnabled(true);
      tracker.clear();
    });

    tearDown(() {
      tracker.dispose();
    });

    test('初始化状态测试', () {
      expect(tracker.isEnabled, true);
      expect(tracker.records, isEmpty);
    });

    test('页面加载性能测试', () async {
      // 开始页面加载
      tracker.startPageLoad('TestPage');

      // 模拟一些操作
      await Future.delayed(const Duration(milliseconds: 50));

      // 结束页面加载
      tracker.endPageLoad('TestPage', {'test': 'data'});

      // 验证记录
      expect(tracker.records.length, 1);
      expect(tracker.records.first.type, PerformanceType.pageLoad);
      expect(tracker.records.first.name, 'TestPage');
      expect(tracker.records.first.duration, greaterThanOrEqualTo(50));
      expect(tracker.records.first.additionalData?['test'], 'data');
    });

    test('网络请求性能测试', () async {
      // 开始网络请求
      final stopwatch = tracker.startNetworkRequest('api/test');

      // 模拟网络请求
      await Future.delayed(const Duration(milliseconds: 50));

      // 结束网络请求
      tracker.endNetworkRequest(
        'api/test',
        stopwatch,
        success: true,
        responseSize: 1024,
        statusCode: 200,
      );

      // 验证记录
      expect(tracker.records.length, 1);
      expect(tracker.records.first.type, PerformanceType.networkRequest);
      expect(tracker.records.first.name, 'api/test');
      expect(tracker.records.first.duration, greaterThanOrEqualTo(50));
      expect(tracker.records.first.additionalData?['success'], true);
      expect(tracker.records.first.additionalData?['responseSize'], 1024);
      expect(tracker.records.first.additionalData?['statusCode'], 200);
    });

    test('自定义指标测试', () {
      // 记录自定义指标
      tracker.recordCustomMetric(
        'test_metric',
        42.5,
        unit: 'ms',
        additionalData: {'source': 'test'},
      );

      // 验证记录
      expect(tracker.records.length, 1);
      expect(tracker.records.first.type, PerformanceType.customMetric);
      expect(tracker.records.first.name, 'test_metric');
      expect(tracker.records.first.value, 42.5);
      expect(tracker.records.first.additionalData?['unit'], 'ms');
      expect(tracker.records.first.additionalData?['source'], 'test');
    });

    test('记录帧率测试', () {
      // 记录帧率
      tracker.recordFrameRate(60.0, 'test_scene');

      // 验证记录
      expect(tracker.records.length, 1);
      expect(tracker.records.first.type, PerformanceType.customMetric);
      expect(tracker.records.first.name, 'frame_rate_test_scene');
      expect(tracker.records.first.value, 60.0);
      expect(tracker.records.first.additionalData?['unit'], 'fps');
    });

    test('获取记录测试', () {
      // 添加不同类型的记录
      tracker.recordCustomMetric('metric1', 10.0);
      tracker.recordCustomMetric('metric2', 20.0);

      final stopwatch = tracker.startNetworkRequest('api/test');
      tracker.endNetworkRequest('api/test', stopwatch);

      tracker.startPageLoad('Page1');
      tracker.endPageLoad('Page1');

      // 验证总记录数
      expect(tracker.records.length, 4);

      // 按类型获取记录
      expect(
        tracker.getRecordsByType(PerformanceType.customMetric).length,
        2,
      );
      expect(
        tracker.getRecordsByType(PerformanceType.networkRequest).length,
        1,
      );
      expect(
        tracker.getRecordsByType(PerformanceType.pageLoad).length,
        1,
      );

      // 按名称获取记录
      expect(tracker.getRecordsByName('metric1').length, 1);
      expect(tracker.getRecordsByName('api/test').length, 1);
    });

    test('统计信息测试', () {
      // 添加测试数据
      for (int i = 1; i <= 5; i++) {
        tracker.recordCustomMetric('test_metric', i * 10.0);
      }

      // 获取统计信息
      final stats = tracker.getStats(PerformanceType.customMetric);

      // 验证统计结果
      expect(stats.totalRecords, 5);
      expect(stats.avgValue, 30.0); // (10+20+30+40+50)/5
      expect(stats.minValue, 10.0);
      expect(stats.maxValue, 50.0);
    });

    test('记录限制测试', () {
      // 添加超过限制的记录
      for (int i = 0; i < 1010; i++) {
        tracker.recordCustomMetric('test_metric', i.toDouble());
      }

      // 验证记录数量被限制
      expect(tracker.records.length, 1000);

      // 验证保留了最新的记录
      expect(tracker.records.last.value, 1009.0);
    });

    test('JSON序列化测试', () {
      // 创建测试记录
      final record = PerformanceRecord(
        type: PerformanceType.pageLoad,
        name: 'TestPage',
        duration: 100,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        additionalData: {'test': 'data'},
      );

      // 序列化为JSON
      final json = record.toJson();

      // 验证JSON字段
      expect(json['type'], 'pageLoad');
      expect(json['name'], 'TestPage');
      expect(json['duration'], 100);
      expect(json['timestamp'], '2023-01-01T12:00:00.000');
      expect(json['additionalData']['test'], 'data');

      // 从JSON反序列化
      final deserializedRecord = PerformanceRecord.fromJson(json);

      // 验证反序列化结果
      expect(deserializedRecord.type, PerformanceType.pageLoad);
      expect(deserializedRecord.name, 'TestPage');
      expect(deserializedRecord.duration, 100);
      expect(
        deserializedRecord.timestamp.toIso8601String(),
        '2023-01-01T12:00:00.000',
      );
      expect(deserializedRecord.additionalData?['test'], 'data');
    });

    test('PerformanceHelper.measure测试', () async {
      // 使用measure方法测量异步操作
      final result = await PerformanceHelper.measure<String>(
        'test_async_operation',
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'result';
        },
      );

      // 验证结果
      expect(result, 'result');

      // 验证性能记录
      final records = tracker.getRecordsByName('test_async_operation');
      expect(records.length, 1);
      expect(records.first.type, PerformanceType.customMetric);
      expect(records.first.duration, isNull);
      expect(records.first.value, greaterThanOrEqualTo(50.0));
      expect(records.first.additionalData?['success'], true);
    });

    test('PerformanceHelper.measureSync测试', () {
      // 使用measureSync方法测量同步操作
      final result = PerformanceHelper.measureSync<int>(
        'test_sync_operation',
        () {
          int sum = 0;
          for (int i = 0; i < 1000; i++) {
            sum += i;
          }
          return sum;
        },
      );

      // 验证结果
      expect(result, 499500); // 0+1+2+...+999 = 499500

      // 验证性能记录
      final records = tracker.getRecordsByName('test_sync_operation');
      expect(records.length, 1);
      expect(records.first.type, PerformanceType.customMetric);
      expect(records.first.additionalData?['success'], true);
    });

    test('异常处理测试', () {
      // 测试同步操作中的异常
      expect(
        () => PerformanceHelper.measureSync<void>(
          'test_exception',
          () => throw Exception('Test error'),
        ),
        throwsException,
      );

      // 验证异常被记录
      final records = tracker.getRecordsByName('test_exception');
      expect(records.length, 1);
      expect(records.first.additionalData?['success'], false);
      expect(records.first.additionalData?['error'], contains('Test error'));
    });

    test('导出数据测试', () async {
      // 添加测试数据
      tracker.recordCustomMetric('test_metric', 42.0);

      // 模拟文件写入
      final mockFile = MockFile();

      // 导出数据
      final filePath = await tracker.exportData('test_export.json');

      // 验证文件路径
      expect(filePath, '/mock/documents/test_export.json');
    });
  });
}

// 模拟File类
class MockFile extends Fake implements File {
  @override
  Future<File> writeAsString(String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    return this;
  }

  @override
  String get path => '/mock/documents/test_export.json';
}

// Mock基类
class Mock {}

// MockPlatformInterfaceMixin
mixin MockPlatformInterfaceMixin on Object {}
