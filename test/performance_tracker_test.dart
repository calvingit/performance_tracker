import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:performance_tracker/performance_tracker.dart';

/// 模拟 File 类
class MockFile extends Mock implements File {}

void main() {
  group('PerformanceTracker Tests', () {
    setUpAll(() {
      // 初始化Flutter测试环境
      TestWidgetsFlutterBinding.ensureInitialized();

      // 注册 fallback 值
      registerFallbackValue(File(''));
    });

    setUp(() {
      // 获取PerformanceTracker单例实例
      PerformanceTracker.instance
        ..setEnabled(true)
        ..clear();
    });

    tearDown(() {
      PerformanceTracker.instance.dispose();
    });

    test('初始化状态测试', () {
      expect(PerformanceTracker.instance.isEnabled, true);
      expect(PerformanceTracker.instance.records, isEmpty);
    });

    test('页面加载性能测试', () async {
      // 开始页面加载
      PerformanceTracker.instance.startPageLoad('TestPage');

      // 模拟一些操作
      await Future.delayed(const Duration(milliseconds: 50));

      // 结束页面加载
      PerformanceTracker.instance.endPageLoad('TestPage', {'test': 'data'});

      // 验证记录
      expect(PerformanceTracker.instance.records.length, 1);
      expect(PerformanceTracker.instance.records.first.type,
          PerformanceType.pageLoad);
      expect(PerformanceTracker.instance.records.first.name, 'TestPage');
      expect(PerformanceTracker.instance.records.first.duration,
          greaterThanOrEqualTo(50));
      expect(PerformanceTracker.instance.records.first.additionalData?['test'],
          'data');
    });

    test('网络请求性能测试', () async {
      // 开始网络请求
      final stopwatch =
          PerformanceTracker.instance.startNetworkRequest('api/test');

      // 模拟网络请求
      await Future.delayed(const Duration(milliseconds: 50));

      // 结束网络请求
      PerformanceTracker.instance.endNetworkRequest(
        'api/test',
        stopwatch,
        success: true,
        responseSize: 1024,
        statusCode: 200,
      );

      // 验证记录
      expect(PerformanceTracker.instance.records.length, 1);
      expect(PerformanceTracker.instance.records.first.type,
          PerformanceType.networkRequest);
      expect(PerformanceTracker.instance.records.first.name, 'api/test');
      expect(PerformanceTracker.instance.records.first.duration,
          greaterThanOrEqualTo(50));
      expect(
          PerformanceTracker.instance.records.first.additionalData?['success'],
          true);
      expect(
          PerformanceTracker
              .instance.records.first.additionalData?['responseSize'],
          1024);
      expect(
          PerformanceTracker
              .instance.records.first.additionalData?['statusCode'],
          200);
    });

    test('自定义指标测试', () {
      // 记录自定义指标
      PerformanceTracker.instance.recordCustomMetric(
        'test_metric',
        42.5,
        unit: 'ms',
        additionalData: {'source': 'test'},
      );

      // 验证记录
      expect(PerformanceTracker.instance.records.length, 1);
      expect(PerformanceTracker.instance.records.first.type,
          PerformanceType.customMetric);
      expect(PerformanceTracker.instance.records.first.name, 'test_metric');
      expect(PerformanceTracker.instance.records.first.value, 42.5);
      expect(PerformanceTracker.instance.records.first.additionalData?['unit'],
          'ms');
      expect(
          PerformanceTracker.instance.records.first.additionalData?['source'],
          'test');
    });

    test('记录帧率测试', () {
      // 记录帧率
      PerformanceTracker.instance.recordFrameRate(60.0, 'test_scene');

      // 验证记录
      expect(PerformanceTracker.instance.records.length, 1);
      expect(PerformanceTracker.instance.records.first.type,
          PerformanceType.customMetric);
      expect(PerformanceTracker.instance.records.first.name,
          'frame_rate_test_scene');
      expect(PerformanceTracker.instance.records.first.value, 60.0);
      expect(PerformanceTracker.instance.records.first.additionalData?['unit'],
          'fps');
    });

    test('获取记录测试', () {
      // 添加不同类型的记录
      PerformanceTracker.instance.recordCustomMetric('metric1', 10.0);
      PerformanceTracker.instance.recordCustomMetric('metric2', 20.0);

      final stopwatch =
          PerformanceTracker.instance.startNetworkRequest('api/test');
      PerformanceTracker.instance.endNetworkRequest('api/test', stopwatch);

      PerformanceTracker.instance.startPageLoad('Page1');
      PerformanceTracker.instance.endPageLoad('Page1');

      // 验证总记录数
      expect(PerformanceTracker.instance.records.length, 4);

      // 按类型获取记录
      expect(
        PerformanceTracker.instance
            .getRecordsByType(PerformanceType.customMetric)
            .length,
        2,
      );
      expect(
        PerformanceTracker.instance
            .getRecordsByType(PerformanceType.networkRequest)
            .length,
        1,
      );
      expect(
        PerformanceTracker.instance
            .getRecordsByType(PerformanceType.pageLoad)
            .length,
        1,
      );

      // 按名称获取记录
      expect(PerformanceTracker.instance.getRecordsByName('metric1').length, 1);
      expect(
          PerformanceTracker.instance.getRecordsByName('api/test').length, 1);
    });

    test('统计信息测试', () {
      // 添加测试数据
      for (int i = 1; i <= 5; i++) {
        PerformanceTracker.instance.recordCustomMetric('test_metric', i * 10.0);
      }

      // 获取统计信息
      final stats =
          PerformanceTracker.instance.getStats(PerformanceType.customMetric);

      // 验证统计结果
      expect(stats.totalRecords, 5);
      expect(stats.avgValue, 30.0); // (10+20+30+40+50)/5
      expect(stats.minValue, 10.0);
      expect(stats.maxValue, 50.0);
    });

    test('记录限制测试', () {
      // 添加超过限制的记录
      for (int i = 0; i < 1010; i++) {
        PerformanceTracker.instance
            .recordCustomMetric('test_metric', i.toDouble());
      }

      // 验证记录数量被限制
      expect(PerformanceTracker.instance.records.length, 1000);

      // 验证保留了最新的记录
      expect(PerformanceTracker.instance.records.last.value, 1009.0);
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
      final records =
          PerformanceTracker.instance.getRecordsByName('test_async_operation');
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
      final records =
          PerformanceTracker.instance.getRecordsByName('test_sync_operation');
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
      final records =
          PerformanceTracker.instance.getRecordsByName('test_exception');
      expect(records.length, 1);
      expect(records.first.additionalData?['success'], false);
      expect(records.first.additionalData?['error'], contains('Test error'));
    });

    test('导出数据测试', () async {
      // 添加测试数据
      PerformanceTracker.instance.recordCustomMetric('test_metric', 42.0);

      // 验证有数据可导出
      expect(PerformanceTracker.instance.records.length, 1);
      expect(PerformanceTracker.instance.records.first.name, 'test_metric');
      expect(PerformanceTracker.instance.records.first.value, 42.0);

      // 注意：实际的文件导出测试需要在集成测试中进行
      // 这里只测试数据准备部分
    }, skip: '文件系统操作需要在集成测试中验证');
  });
}
