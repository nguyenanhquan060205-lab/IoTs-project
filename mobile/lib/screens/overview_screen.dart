import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_standard.dart';
import '../providers/soil_data_provider.dart';
import '../services/agronomic_engine.dart';
import '../services/soil_status.dart';
import '../widgets/common.dart';
import '../widgets/inline_alert.dart';
import '../widgets/soil_gauges.dart';
import '../widgets/soil_type_radio_cards.dart';
import 'soil_type_screen.dart';

/// Tab Tổng quan: đất đang tốt hay xấu, đang đo mẫu nào, chỉ số chính và việc nên làm
class OverviewScreen extends StatelessWidget {
  final VoidCallback onOpenSoil;
  final VoidCallback onOpenMetrics;

  const OverviewScreen({super.key, required this.onOpenSoil, required this.onOpenMetrics});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SoilDataProvider>();
    final telemetry = provider.currentTelemetry;
    final diagnosis = provider.currentDiagnosis;
    final soil = provider.selectedSoilType;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: PageTitle(title: 'Trạm đo đất', updatedAt: telemetry.timestamp),
        actions: [
          ConnectionPill(state: provider.connectionState),
          IconButton(
            tooltip: 'Mô phỏng dữ liệu ngẫu nhiên (Demo)',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink2),
            onPressed: provider.simulateRandomReading,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SummaryCard(diagnosis: diagnosis),
          const SectionTitle('Mẫu đất đang đo'),
          AppCard(
            onTap: onOpenSoil,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SoilTypeRadioCards.soilColor(soil),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(SoilTypeRadioCards.soilIcon(soil), color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soil.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      SoilSyncBadge(provider: provider),
                    ],
                  ),
                ),
                const Text('Đổi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent)),
                const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
              ],
            ),
          ),
          const SectionTitle('Chỉ số chính'),
          AppCard(
            onTap: onOpenMetrics,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _QuickStat(
                        label: 'Độ ẩm',
                        value: '${telemetry.moisture.toStringAsFixed(0)}%',
                        status: SoilStatus.moisture(telemetry.moisture),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      _QuickStat(
                        label: 'Đạm',
                        value: telemetry.nitrogen.toStringAsFixed(0),
                        status: SoilStatus.nutrient(telemetry.nitrogen, SoilStandard.nitrogen),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      _QuickStat(
                        label: 'Lân',
                        value: telemetry.phosphorus.toStringAsFixed(0),
                        status: SoilStatus.nutrient(telemetry.phosphorus, SoilStandard.phosphorus),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      _QuickStat(
                        label: 'Kali',
                        value: telemetry.potassium.toStringAsFixed(0),
                        status: SoilStatus.nutrient(telemetry.potassium, SoilStandard.potassium),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24, color: AppColors.line),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Xem đủ chỉ số và biểu đồ',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(
            'Việc nên làm',
            hint: diagnosis.issues.isEmpty ? null : '${diagnosis.issues.length} việc',
          ),
          if (diagnosis.issues.isEmpty)
            const AppCard(
              child: CalmState(
                title: 'Đất đang ổn, chưa cần làm gì',
                message: 'Tưới đều để giữ độ ẩm trong khoảng 50 - 70%.',
              ),
            )
          else
            for (final issue in diagnosis.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InlineAlert(
                  color: issue.severity == AlertSeverity.danger ? AppColors.danger : AppColors.warn,
                  icon: issue.severity == AlertSeverity.danger
                      ? Icons.priority_high_rounded
                      : Icons.warning_amber_rounded,
                  title: issue.title,
                  message: issue.recommendation,
                ),
              ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final SoilStatus status;

  const _QuickStat({required this.label, required this.value, required this.status});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value, ${status.label}',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
            const SizedBox(height: 4),
            Text(
              status.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: levelColor(status.level)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ tóm tắt đầu trang: tên trạm, điểm sức khỏe đất và một câu kết luận
class _SummaryCard extends StatelessWidget {
  final AgronomicDiagnosis diagnosis;

  const _SummaryCard({required this.diagnosis});

  @override
  Widget build(BuildContext context) {
    final (verdict, color) = switch (diagnosis.overallSeverity) {
      AlertSeverity.normal => ('Đất tốt', AppColors.ok),
      AlertSeverity.warning => ('Đất cần chăm thêm', AppColors.warn),
      AlertSeverity.danger => ('Đất đang có vấn đề', AppColors.danger),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors_rounded, size: 18, color: AppColors.ink3),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ESP32 Soil Station 01 · Đầu dò độ ẩm GPIO34',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ScoreRing(score: diagnosis.soilHealthScore, color: color),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdict,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diagnosis.generalStatus,
                      style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.ink3),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chỉ độ ẩm là số đo. Các chỉ số khác được ước lượng theo loại đất bạn chọn.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
