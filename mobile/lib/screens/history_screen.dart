import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_standard.dart';
import '../services/history_repository.dart';
import '../widgets/inline_alert.dart';
import '../widgets/segmented_tabs.dart';
import '../widgets/soil_type_radio_cards.dart';

/// Khoảng thời gian xem lịch sử, độ dài mỗi điểm trung bình và bước nhãn trục thời gian
enum HistoryRange {
  day('24 giờ', Duration(hours: 24), Duration(minutes: 10), 'mỗi 10 phút', Duration(hours: 6)),
  week('7 ngày', Duration(days: 7), Duration(hours: 1), 'mỗi giờ', Duration(days: 1)),
  month('30 ngày', Duration(days: 30), Duration(hours: 6), 'mỗi 6 giờ', Duration(days: 7));

  const HistoryRange(this.label, this.span, this.bucket, this.bucketLabel, this.labelStep);
  final String label;
  final Duration span;
  final Duration bucket;
  final String bucketLabel;
  final Duration labelStep;
}

/// Chỉ số có thể xem trên biểu đồ, kèm mức tốt để vẽ đường tham chiếu
enum HistoryMetric {
  moisture('Độ ẩm', '%', SoilStandard.moisture),
  nitrogen('Đạm N', 'mg/kg', SoilStandard.nitrogen),
  phosphorus('Lân P', 'mg/kg', SoilStandard.phosphorus),
  potassium('Kali K', 'mg/kg', SoilStandard.potassium),
  ph('Độ chua pH', '', SoilStandard.ph),
  ec('Độ phì EC', 'µS/cm', SoilStandard.ec);

  const HistoryMetric(this.label, this.unit, this.standard);
  final String label;
  final String unit;
  final NutrientRange standard;

  double valueOf(HistoryPoint point) {
    switch (this) {
      case HistoryMetric.moisture:
        return point.moisture;
      case HistoryMetric.ec:
        return point.ec;
      case HistoryMetric.nitrogen:
        return point.nitrogen;
      case HistoryMetric.phosphorus:
        return point.phosphorus;
      case HistoryMetric.potassium:
        return point.potassium;
      case HistoryMetric.ph:
        return point.ph;
    }
  }
}

class _HistoryData {
  final HistoryRange range; // Khoảng đã dùng để tải, có thể khác khoảng vừa chọn trong lúc đang tải lại
  final DateTime from;
  final List<HistoryPoint> series;
  final List<DailySummary> days;

  const _HistoryData(this.range, this.from, this.series, this.days);
}

class HistoryScreen extends StatefulWidget {
  final HistoryRepository repository;
  final bool active; // Đang là tab được chọn: mỗi lần mở lại tab thì tải số đo mới nhất

  const HistoryScreen({super.key, required this.repository, this.active = true});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryRange _range = HistoryRange.day;
  HistoryMetric _metric = HistoryMetric.moisture;
  late Future<_HistoryData> _data = _load();

  Future<_HistoryData> _load() async {
    final range = _range;
    final from = DateTime.now().subtract(range.span);
    final series = await widget.repository.loadSeries(from: from, bucket: range.bucket);
    final days = await widget.repository.loadDailySummaries(from: from);
    return _HistoryData(range, from, series, days);
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  // Đang xem trang này mà App vừa lưu thêm số đo thì vẽ lại ngay, không phải chuyển tab
  void _onSaved() {
    if (widget.active && mounted) _reload();
  }

  @override
  void initState() {
    super.initState();
    widget.repository.savedCount.addListener(_onSaved);
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.repository, oldWidget.repository)) {
      oldWidget.repository.savedCount.removeListener(_onSaved);
      widget.repository.savedCount.addListener(_onSaved);
    }
    if (widget.active && !oldWidget.active) _reload();
  }

  @override
  void dispose() {
    widget.repository.savedCount.removeListener(_onSaved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Lịch sử đo', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink2),
            onPressed: _reload,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          _reload();
          await _data;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SegmentedTabs<HistoryRange>(
              values: HistoryRange.values,
              labelOf: (range) => range.label,
              selected: _range,
              onChanged: (range) {
                _range = range;
                _reload();
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in HistoryMetric.values)
                  ChoiceChip(
                    label: Text(metric.label),
                    selected: metric == _metric,
                    onSelected: (_) => setState(() => _metric = metric),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<_HistoryData>(
              future: _data,
              builder: (context, snapshot) {
                // Đang tải lại thì giữ số liệu cũ trên màn hình, chỉ hiện vòng quay ở lần tải đầu
                if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
                  return const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  );
                }
                final data = snapshot.data;
                if (data == null || data.series.isEmpty) {
                  return _card(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CalmState(
                        icon: Icons.history_rounded,
                        color: AppColors.ink3,
                        title: 'Chưa có số đo nào trong khoảng này',
                        message: 'Mở app và kết nối với trạm đo để bắt đầu ghi lịch sử.',
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartCard(data),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 28, 4, 12),
                      child: Text(
                        'Trung bình theo ngày',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
                      ),
                    ),
                    ...data.days.map(_buildDailyCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'App tự lưu 1 số đo mỗi phút khi đang mở và nhận dữ liệu từ trạm, giữ lại 30 ngày gần nhất.',
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildChartCard(_HistoryData data) {
    final metric = _metric;
    final range = data.range;
    final bucketMs = range.bucket.inMilliseconds;

    // Ngắt nét vẽ ở những khoảng app không mở, tránh nối thẳng qua khoảng không có số đo
    final spots = <FlSpot>[];
    for (var i = 0; i < data.series.length; i++) {
      final point = data.series[i];
      if (i > 0 &&
          point.time.difference(data.series[i - 1].time).inMilliseconds > 2 * bucketMs) {
        spots.add(FlSpot.nullSpot);
      }
      spots.add(FlSpot(point.time.millisecondsSinceEpoch.toDouble(), metric.valueOf(point)));
    }

    final values = data.series.map(metric.valueOf);
    var minY = [values.reduce((a, b) => a < b ? a : b), metric.standard.min].reduce((a, b) => a < b ? a : b);
    var maxY = [values.reduce((a, b) => a > b ? a : b), metric.standard.max].reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1 + (metric == HistoryMetric.ph ? 0.1 : 1);
    minY = (minY - padding).clamp(0, double.infinity).toDouble();
    maxY = maxY + padding;

    final minX = data.from.millisecondsSinceEpoch.toDouble();
    final maxX = DateTime.now().millisecondsSinceEpoch.toDouble();
    final timeFormat = DateFormat(range == HistoryRange.day ? 'HH:mm' : 'dd/MM');
    final latest = metric.valueOf(data.series.last);
    final unitSuffix = metric.unit.isEmpty ? '' : ' ${metric.unit}';

    return _card(
      padding: const EdgeInsets.fromLTRB(14, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric.label,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatValue(latest)}$unitSuffix',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.ink,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'trung bình ${range.bucketLabel}',
                  style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        // Mép trên/dưới là số lẻ do chừa lề, không phải mốc chia
                        if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                        return Text(
                          _formatValue(value),
                          style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: range.labelStep.inMilliseconds.toDouble(),
                      getTitlesWidget: (value, meta) {
                        // Bỏ nhãn ở 2 mép để chữ không bị cắt
                        if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            timeFormat.format(DateTime.fromMillisecondsSinceEpoch(value.toInt())),
                            style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    for (final y in [metric.standard.min, metric.standard.max])
                      HorizontalLine(
                        y: y,
                        color: AppColors.ok.withValues(alpha: 0.7),
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                      ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.ink,
                    getTooltipItems: (touched) => touched
                        .map((spot) => LineTooltipItem(
                              '${DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()))}\n'
                              '${_formatValue(spot.y)}$unitSuffix',
                              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.page),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: AppColors.accent,
                    barWidth: 2.5,
                    dotData: FlDotData(show: data.series.length <= 30),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Container(width: 18, height: 2, color: AppColors.ok),
                const SizedBox(width: 6),
                Text(
                  'Mức tốt: ${_formatValue(metric.standard.min)} - ${_formatValue(metric.standard.max)}$unitSuffix',
                  style: const TextStyle(fontSize: 13, color: AppColors.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCard(DailySummary day) {
    final soil = day.soilType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: soil != null ? SoilTypeRadioCards.soilColor(soil) : AppColors.surface3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                soil != null ? SoilTypeRadioCards.soilIcon(soil) : Icons.help_outline_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          soil?.label ?? 'Chưa rõ loại đất',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM').format(day.day),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đạm ${day.nitrogen.toStringAsFixed(0)} · Lân ${day.phosphorus.toStringAsFixed(0)} · Kali ${day.potassium.toStringAsFixed(0)} mg/kg',
                    style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ẩm ${day.moisture.toStringAsFixed(0)}% · pH ${day.ph.toStringAsFixed(1)} · EC ${day.ec.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${day.count} lần đo',
                    style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(double value) {
    if (_metric == HistoryMetric.ph) return value.toStringAsFixed(1);
    return value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}
