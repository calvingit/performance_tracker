# Flutter 性能监控套件

一个功能强大的 Flutter 性能监控解决方案，包含性能数据记录、网络请求监控、UI 渲染监控和可视化仪表板等功能。

## 核心组件

- **PerformanceTracker**: 核心性能数据记录器
- **PerformanceDioInterceptor**: Dio 网络请求性能监控拦截器
- **PerformanceUIMonitor**: UI 渲染性能监控器
- **PerformanceDashboard**: 性能数据可视化仪表板

## 主要功能

### 核心性能监控

- 📊 **页面加载时间监控**: 自动记录页面加载性能
- 🌐 **网络请求性能追踪**: 监控 API 调用耗时和成功率
- 💾 **内存使用情况监控**: 实时跟踪内存占用
- ⚡ **CPU 使用率统计**: 监控应用 CPU 消耗
- 📈 **帧率统计**: 监控应用流畅度
- 🎯 **自定义性能指标**: 支持记录任意自定义指标

### 网络监控

- 🔍 **自动请求拦截**: Dio 拦截器自动记录所有网络请求
- 📊 **详细请求信息**: 记录请求方法、URL、状态码、响应大小等
- ⏱️ **请求耗时分析**: 精确测量网络请求时间
- 🚨 **错误监控**: 自动捕获和记录网络请求错误

### UI 性能监控

- 🎬 **实时帧率监控**: 持续监控应用帧率
- 🐌 **卡顿检测**: 自动检测和记录 UI 卡顿
- 📱 **页面性能追踪**: 监控特定页面的渲染性能
- 📊 **渲染统计**: 提供详细的 UI 渲染统计信息

### 数据可视化

- 📈 **实时仪表板**: 可视化性能数据展示
- 📊 **性能趋势图**: 展示性能数据变化趋势
- 🔍 **详细数据分析**: 提供深入的性能数据分析
- 📁 **数据导出功能**: 支持 JSON 格式数据导出

## 快速开始

### 1. 基础设置

```dart
import 'package:your_app/utils/performance_tracker.dart';
import 'package:your_app/utils/performance_dio_interceptor.dart';
import 'package:your_app/utils/performance_ui_monitor.dart';
import 'package:your_app/utils/performance_dashboard.dart';

// 启用性能监控
PerformanceTracker.instance.setEnabled(true);

// 设置最大记录数（可选）
PerformanceTracker.instance.setMaxRecords(1000);

// 启动UI性能监控
PerformanceUIMonitor.instance.startMonitoring();
```

### 2. 网络监控设置

```dart
// 创建Dio实例并添加性能监控拦截器
dio.interceptors.add(PerformanceDioInterceptor(
  enableDetailedLogging: true,
));
```

### 3. 页面加载监控

#### 手动监控

```dart
// 开始页面加载计时
PerformanceTracker.instance.startPageLoad('HomePage');

// 页面加载完成后结束计时
PerformanceTracker.instance.endPageLoad('HomePage', {
  'route': '/home',
  'hasData': true,
});
```

#### 使用 Mixin 自动监控

```dart
class MyPageState extends State<MyPage> with PerformanceMonitorMixin {
  @override
  String get pageName => 'MyPage';

  // 页面性能会自动监控
}
```

#### 使用 Widget 包装器

```dart
PerformanceMonitorWidget(
  pageName: 'MyPage',
  child: MyPageContent(),
)
```

### 4. 网络请求监控

配置了拦截器的Dio实例，所有请求会自动监控

手动监控:

```dart
// 开始网络请求计时
PerformanceTracker.instance.startNetworkRequest('API调用');

// 网络请求完成后结束计时
PerformanceTracker.instance.endNetworkRequest(
  'API调用',
  success: true,
  additionalData: {
    'url': 'https://api.example.com/data',
    'method': 'GET',
    'statusCode': 200,
  },
);
```

### 5. UI 性能监控

#### 页面级监控

```dart
// 开始监控特定页面
PerformanceUIMonitor.instance.startPageMonitoring('HomePage');

// 停止页面监控
PerformanceUIMonitor.instance.stopPageMonitoring();

// 获取当前帧率统计
final stats = PerformanceUIMonitor.instance.getCurrentFrameStats();
print('当前帧率: ${stats['fps']} FPS');
print('掉帧率: ${stats['jankPercentage']}%');
```

### 6. 辅助方法

```dart
// 测量异步操作性能
final result = await PerformanceHelper.measure(
  '数据库查询',
  () async {
    return await database.query('users');
  },
  additionalData: {'table': 'users'},
);

// 测量同步操作性能
final result = PerformanceHelper.measureSync(
  '数据处理',
  () {
    return processData(data);
  },
);
```

### 7. 自定义指标记录

```dart
// 记录数值型指标
PerformanceTracker.instance.recordCustomMetric(
  '内存使用率',
  value: 75.5,
  additionalData: {'unit': 'percentage'},
);

// 记录事件型指标
PerformanceTracker.instance.recordCustomMetric(
  '用户操作',
  additionalData: {
    'action': 'button_click',
    'screen': 'home',
  },
);
```

### 8. 获取统计信息

```dart
// 获取总体统计
final stats = PerformanceTracker.instance.getStats();
print('总记录数: ${stats.totalRecords}');
print('平均持续时间: ${stats.avgDuration} ms');

// 获取特定类型统计
final networkStats = PerformanceTracker.instance.getStats(PerformanceType.networkRequest);
print('网络请求平均耗时: ${networkStats.avgDuration} ms');

// 获取UI性能统计
final uiStats = PerformanceUIMonitor.instance.getCurrentFrameStats();
print('当前帧率: ${uiStats['fps']} FPS');
print('掉帧率: ${uiStats['jankPercentage']}%');

// 获取最近记录
final recentRecords = PerformanceTracker.instance.getRecentRecords(10);
```

### 9. 性能仪表板

```dart
// 打开性能仪表板
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const PerformanceDashboard(),
  ),
);
```

### 10. 数据导出

```dart
// 导出所有数据到JSON文件
final filePath = await PerformanceTracker.instance.exportData();
if (filePath != null) {
  print('数据已导出到: $filePath');
}

// 获取JSON格式的数据
final jsonData = PerformanceTracker.instance.toJson();
```

### 11. 资源清理

```dart
// 清空所有记录
PerformanceTracker.instance.clear();

// 停止UI监控
PerformanceUIMonitor.instance.stopMonitoring();

// 禁用性能监控
PerformanceTracker.instance.disable();
```

## 最佳实践

### 1. 性能监控策略

- **开发阶段**: 启用详细监控，包括所有类型的性能指标
- **测试阶段**: 重点监控关键路径和用户场景
- **生产环境**: 选择性监控，避免影响应用性能

### 2. 网络监控配置

- 在生产环境中禁用请求体和响应体日志记录
- 设置合理的 URL 长度限制
- 考虑对敏感信息进行脱敏处理

```dart
// 生产环境配置
dio.interceptors.add(PerformanceDioInterceptor(
  enableDetailedLogging: false,
  enableRequestBodyLogging: false,
  enableResponseBodyLogging: false,
  maxUrlLength: 50,
));
```

### 3. UI 性能监控

- 在关键页面启用 UI 监控
- 设置合理的卡顿阈值
- 定期分析帧率数据，识别性能问题

### 4. 数据管理

- 定期清理历史数据，避免内存占用过大
- 设置合理的最大记录数限制
- 在应用退出时导出重要数据
- 使用性能仪表板进行实时监控

### 5. 性能优化

- 根据监控数据识别性能瓶颈
- 重点优化耗时较长的操作
- 监控优化效果，形成闭环
- 利用可视化仪表板分析性能趋势

### 6. 团队协作

- 建立性能基准线
- 定期分享性能报告
- 将性能监控集成到 CI/CD 流程
- 使用仪表板进行团队性能评审

## 注意事项

### 性能影响

- 性能监控本身会消耗一定资源，建议在生产环境中谨慎使用
- UI 监控会持续运行，在不需要时及时停止
- 网络拦截器会增加请求处理时间，但影响很小

### 内存管理

- 大量的性能记录会占用内存，建议定期清理或设置记录数限制
- UI 监控会持续收集帧率数据，注意内存使用
- 可视化组件会缓存图表数据，定期清理

### 线程安全

- 所有工具类已考虑线程安全，可在多线程环境中使用
- UI 监控使用 Flutter 的调度器，确保线程安全

### 数据安全

- 网络拦截器可能记录敏感信息，生产环境中注意配置
- 导出的数据可能包含用户信息，请注意数据安全
- 建议对敏感数据进行脱敏处理

### 平台兼容性

- 所有功能在 iOS 和 Android 平台上均可正常使用
- UI 监控依赖 Flutter 框架的调度器
- 文件导出功能需要相应的存储权限

## 依赖要求

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.0.0 # 网络请求库
  path_provider: ^2.0.0 # 文件路径获取

dev_dependencies:
  flutter_test:
    sdk: flutter
```

- Flutter SDK: >=3.22.0
- Dart SDK: >=3.4.0

## 文件结构

```bash
lib/performance_tracker/
├── performance_tracker.dart              # 核心性能追踪器
├── performance_dio_interceptor.dart      # Dio网络监控拦截器
├── performance_ui_monitor.dart           # UI性能监控器
└── performance_dashboard.dart            # 性能数据可视化仪表板
test/
   └── performance_tracker_test.dart      # 单元测试
example/
   └── performance_tracker_example.dart   # 示例应用
```

## 完整示例

查看 `performance_tracker_example.dart` 文件获取完整的使用示例，包括：

- 基础性能监控设置
- 网络请求监控配置
- UI 性能监控使用
- 性能仪表板集成
- 数据导出和分析

## 更新日志

### v2.0.0

- 🎉 新增 Dio 网络请求监控拦截器
- 🎉 新增 UI 渲染性能监控功能
- 🎉 新增性能数据可视化仪表板
- 🎉 新增实时帧率监控和卡顿检测
- 🎉 新增性能监控 Mixin 和 Widget 包装器
- ✨ 改进数据导出功能
- ✨ 优化性能统计算法
- 🐛 修复内存泄漏问题

### v1.0.0

- 初始版本发布
- 支持页面加载、网络请求、自定义指标监控
- 提供统计分析和数据导出功能
