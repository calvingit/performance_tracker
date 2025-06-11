import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'performance_tracker.dart';
import 'performance_ui_monitor.dart';

/// 性能数据可视化仪表板
///
/// 提供以下功能：
/// - 实时性能数据展示
/// - 性能趋势图表
/// - 详细数据分析
/// - 数据导出功能
///
/// 使用示例：
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => const PerformanceDashboard(),
///   ),
/// );
/// ```
class PerformanceDashboard extends StatefulWidget {
  const PerformanceDashboard({super.key});

  @override
  State<PerformanceDashboard> createState() => _PerformanceDashboardState();
}

class _PerformanceDashboardState extends State<PerformanceDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isRealTimeMode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('性能监控仪表板'),
        actions: [
          IconButton(
            icon: Icon(_isRealTimeMode ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isRealTimeMode = !_isRealTimeMode;
              });
            },
            tooltip: _isRealTimeMode ? '暂停实时更新' : '开启实时更新',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
            tooltip: '导出数据',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearData,
            tooltip: '清空数据',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '概览'),
            Tab(icon: Icon(Icons.network_check), text: '网络'),
            Tab(icon: Icon(Icons.phone_android), text: 'UI性能'),
            Tab(icon: Icon(Icons.analytics), text: '详细数据'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildNetworkTab(),
          _buildUIPerformanceTab(),
          _buildDetailedDataTab(),
        ],
      ),
    );
  }

  /// 构建概览标签页
  Widget _buildOverviewTab() {
    return StreamBuilder<void>(
      stream: _isRealTimeMode
          ? Stream.periodic(const Duration(seconds: 1))
          : const Stream.empty(),
      builder: (context, snapshot) {
        final stats = PerformanceTracker.instance.getStats();
        final uiStats = PerformanceUIMonitor.instance.getCurrentFrameStats();
        final records = PerformanceTracker.instance.records;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildStatsGrid(stats, uiStats),
              const SizedBox(height: 16),
              _buildRecentActivityCard(records),
              const SizedBox(height: 16),
              _buildPerformanceTrendChart(records),
            ],
          ),
        );
      },
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard() {
    final isTrackerEnabled = PerformanceTracker.instance.isEnabled;
    final isUIMonitoring = PerformanceUIMonitor.instance.isMonitoring;
    final currentPage = PerformanceUIMonitor.instance.currentPage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '监控状态',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatusIndicator('性能追踪', isTrackerEnabled),
                const SizedBox(width: 24),
                _buildStatusIndicator('UI监控', isUIMonitoring),
              ],
            ),
            if (currentPage != null) ...[
              const SizedBox(height: 8),
              Text('当前页面: $currentPage', style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator(String label, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  /// 构建统计网格
  Widget _buildStatsGrid(PerformanceStats stats, Map<String, dynamic> uiStats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          '总记录数',
          stats.totalRecords.toString(),
          Icons.data_usage,
          Colors.blue,
        ),
        _buildStatCard(
          '平均响应时间',
          stats.avgDuration != null
              ? '${stats.avgDuration!.toStringAsFixed(1)}ms'
              : 'N/A',
          Icons.timer,
          Colors.orange,
        ),
        _buildStatCard(
          '当前帧率',
          '${(uiStats['fps'] as double).toStringAsFixed(1)} FPS',
          Icons.speed,
          Colors.green,
        ),
        _buildStatCard(
          '掉帧率',
          '${(uiStats['jankPercentage'] as double).toStringAsFixed(1)}%',
          Icons.warning,
          (uiStats['jankPercentage'] as double) > 5 ? Colors.red : Colors.green,
        ),
      ],
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建最近活动卡片
  Widget _buildRecentActivityCard(List<PerformanceRecord> records) {
    final recentRecords = records.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近活动',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (recentRecords.isEmpty)
              const Text('暂无数据', style: TextStyle(color: Colors.grey))
            else
              ...recentRecords.map((record) => _buildActivityItem(record)),
          ],
        ),
      ),
    );
  }

  /// 构建活动项
  Widget _buildActivityItem(PerformanceRecord record) {
    final typeIcon = _getTypeIcon(record.type);
    final timeAgo = _formatTimeAgo(record.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(typeIcon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              record.name,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeAgo,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 构建性能趋势图表
  Widget _buildPerformanceTrendChart(List<PerformanceRecord> records) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '性能趋势',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildSimpleChart(records),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建网络标签页
  Widget _buildNetworkTab() {
    return StreamBuilder<void>(
      stream: _isRealTimeMode
          ? Stream.periodic(const Duration(seconds: 2))
          : const Stream.empty(),
      builder: (context, snapshot) {
        final networkRecords = PerformanceTracker.instance
            .getRecordsByType(PerformanceType.networkRequest);
        final networkStats = PerformanceTracker.instance
            .getStats(PerformanceType.networkRequest);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetworkStatsCard(networkStats),
              const SizedBox(height: 16),
              _buildNetworkRequestsList(networkRecords),
            ],
          ),
        );
      },
    );
  }

  /// 构建网络统计卡片
  Widget _buildNetworkStatsCard(PerformanceStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '网络请求统计',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNetworkStatItem(
                  '总请求数',
                  stats.totalRecords.toString(),
                ),
                _buildNetworkStatItem(
                  '平均耗时',
                  stats.avgDuration != null
                      ? '${stats.avgDuration!.toStringAsFixed(0)}ms'
                      : 'N/A',
                ),
                _buildNetworkStatItem(
                  '最长耗时',
                  stats.maxDuration != null
                      ? '${stats.maxDuration}ms'
                      : 'N/A',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建网络统计项
  Widget _buildNetworkStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  /// 构建网络请求列表
  Widget _buildNetworkRequestsList(List<PerformanceRecord> records) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近网络请求',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              const Text('暂无网络请求数据', style: TextStyle(color: Colors.grey))
            else
              ...records.take(10).map((record) => _buildNetworkRequestItem(record)),
          ],
        ),
      ),
    );
  }

  /// 构建网络请求项
  Widget _buildNetworkRequestItem(PerformanceRecord record) {
    final success = record.additionalData?['success'] ?? true;
    final statusCode = record.additionalData?['statusCode'];
    final responseSize = record.additionalData?['responseSize'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: success ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${record.duration}ms',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (statusCode != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'HTTP $statusCode',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (responseSize != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatBytes(responseSize),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(record.timestamp),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 构建UI性能标签页
  Widget _buildUIPerformanceTab() {
    return StreamBuilder<void>(
      stream: _isRealTimeMode
          ? Stream.periodic(const Duration(seconds: 1))
          : const Stream.empty(),
      builder: (context, snapshot) {
        final uiStats = PerformanceUIMonitor.instance.getCurrentFrameStats();
        final frameRecords = PerformanceTracker.instance
            .getRecordsByType(PerformanceType.frameRate);
        final jankRecords = PerformanceTracker.instance
            .getRecordsByType(PerformanceType.jankDetection);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUIStatsCard(uiStats),
              const SizedBox(height: 16),
              _buildFrameRateChart(frameRecords),
              const SizedBox(height: 16),
              _buildJankDetectionCard(jankRecords),
            ],
          ),
        );
      },
    );
  }

  /// 构建UI统计卡片
  Widget _buildUIStatsCard(Map<String, dynamic> stats) {
    final fps = stats['fps'] as double;
    final jankPercentage = stats['jankPercentage'] as double;
    final totalFrames = stats['totalFrames'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UI性能统计',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUIStatItem(
                  '当前帧率',
                  '${fps.toStringAsFixed(1)} FPS',
                  fps >= 55 ? Colors.green : fps >= 30 ? Colors.orange : Colors.red,
                ),
                _buildUIStatItem(
                  '掉帧率',
                  '${jankPercentage.toStringAsFixed(1)}%',
                  jankPercentage <= 5 ? Colors.green : jankPercentage <= 15 ? Colors.orange : Colors.red,
                ),
                _buildUIStatItem(
                  '总帧数',
                  totalFrames.toString(),
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建UI统计项
  Widget _buildUIStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  /// 构建帧率图表
  Widget _buildFrameRateChart(List<PerformanceRecord> records) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '帧率趋势',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildFrameRateLineChart(records),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡顿检测卡片
  Widget _buildJankDetectionCard(List<PerformanceRecord> records) {
    final recentJanks = records.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '卡顿检测',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (recentJanks.isEmpty)
              const Text('暂无卡顿检测数据', style: TextStyle(color: Colors.grey))
            else
              ...recentJanks.map((record) => _buildJankItem(record)),
          ],
        ),
      ),
    );
  }

  /// 构建卡顿项
  Widget _buildJankItem(PerformanceRecord record) {
    final severity = record.additionalData?['severity'] ?? 'unknown';
    final page = record.additionalData?['page'] ?? 'unknown';
    final frameTime = record.value ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: severity == 'severe' ? Colors.red : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${severity == 'severe' ? '严重' : '轻微'}卡顿 - $page',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '帧时间: ${frameTime.toStringAsFixed(2)}ms',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(record.timestamp),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 构建详细数据标签页
  Widget _buildDetailedDataTab() {
    return StreamBuilder<void>(
      stream: _isRealTimeMode
          ? Stream.periodic(const Duration(seconds: 2))
          : const Stream.empty(),
      builder: (context, snapshot) {
        final records = PerformanceTracker.instance.records;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '共 ${records.length} 条记录',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _copyAllData,
                    icon: const Icon(Icons.copy),
                    label: const Text('复制数据'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[records.length - 1 - index]; // 倒序显示
                  return _buildDetailedRecordItem(record);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 构建详细记录项
  Widget _buildDetailedRecordItem(PerformanceRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(_getTypeIcon(record.type)),
        title: Text(
          record.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_formatTimeAgo(record.timestamp)} - ${_getTypeDisplayName(record.type)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.duration != null)
                  _buildDetailRow('持续时间', '${record.duration}ms'),
                if (record.value != null)
                  _buildDetailRow('数值', record.value.toString()),
                _buildDetailRow('时间戳', record.timestamp.toIso8601String()),
                if (record.additionalData != null) ...
                  record.additionalData!.entries.map(
                    (entry) => _buildDetailRow(entry.key, entry.value.toString()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建详细信息行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建简单图表
  Widget _buildSimpleChart(List<PerformanceRecord> records) {
    if (records.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    // 获取最近的数据点
    final recentRecords = records
        .where((r) => r.duration != null)
        .take(20)
        .toList();

    if (recentRecords.isEmpty) {
      return const Center(
        child: Text('暂无时间数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return CustomPaint(
      painter: SimpleChartPainter(recentRecords),
      child: Container(),
    );
  }

  /// 构建帧率折线图
  Widget _buildFrameRateLineChart(List<PerformanceRecord> records) {
    if (records.isEmpty) {
      return const Center(
        child: Text('暂无帧率数据', style: TextStyle(color: Colors.grey)),
      );
    }

    final recentRecords = records.take(20).toList();

    return CustomPaint(
      painter: FrameRateChartPainter(recentRecords),
      child: Container(),
    );
  }

  /// 导出数据
  Future<void> _exportData() async {
    try {
      final filePath = await PerformanceTracker.instance.exportData();
      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据已导出到: $filePath'),
            action: SnackBarAction(
              label: '复制路径',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: filePath));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 清空数据
  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有性能数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      PerformanceTracker.instance.clear();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据已清空')),
        );
      }
    }
  }

  /// 复制所有数据
  Future<void> _copyAllData() async {
    try {
      final records = PerformanceTracker.instance.records;
      final jsonData = records.map((r) => r.toJson()).toList();
      final jsonString = jsonData.toString();

      await Clipboard.setData(ClipboardData(text: jsonString));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据已复制到剪贴板')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('复制失败: $e')),
        );
      }
    }
  }

  /// 获取类型图标
  IconData _getTypeIcon(PerformanceType type) {
    switch (type) {
      case PerformanceType.pageLoad:
        return Icons.web;
      case PerformanceType.networkRequest:
        return Icons.network_check;
      case PerformanceType.customMetric:
        return Icons.analytics;
      case PerformanceType.uiRendering:
        return Icons.phone_android;
      case PerformanceType.frameRate:
        return Icons.speed;
      case PerformanceType.jankDetection:
        return Icons.warning;
    }
  }

  /// 获取类型显示名称
  String _getTypeDisplayName(PerformanceType type) {
    switch (type) {
      case PerformanceType.pageLoad:
        return '页面加载';
      case PerformanceType.networkRequest:
        return '网络请求';
      case PerformanceType.customMetric:
        return '自定义指标';
      case PerformanceType.uiRendering:
        return 'UI渲染';
      case PerformanceType.frameRate:
        return '帧率监控';
      case PerformanceType.jankDetection:
        return '卡顿检测';
    }
  }

  /// 格式化时间差
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// 简单图表绘制器
class SimpleChartPainter extends CustomPainter {
  final List<PerformanceRecord> records;

  SimpleChartPainter(this.records);

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final maxDuration = records
        .map((r) => r.duration ?? 0)
        .reduce((a, b) => math.max(a, b))
        .toDouble();

    if (maxDuration == 0) return;

    for (int i = 0; i < records.length; i++) {
      final x = (i / (records.length - 1)) * size.width;
      final y = size.height - ((records[i].duration ?? 0) / maxDuration) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 帧率图表绘制器
class FrameRateChartPainter extends CustomPainter {
  final List<PerformanceRecord> records;

  FrameRateChartPainter(this.records);

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    const maxFps = 60.0;

    for (int i = 0; i < records.length; i++) {
      final x = (i / (records.length - 1)) * size.width;
      final fps = records[i].value ?? 0.0;
      final y = size.height - (fps / maxFps) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 绘制60fps基准线
    final baselinePaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width, 0),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
