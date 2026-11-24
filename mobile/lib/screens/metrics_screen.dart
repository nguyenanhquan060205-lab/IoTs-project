import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_standard.dart';
import '../models/soil_telemetry.dart';
import '../providers/soil_data_provider.dart';
import '../services/soil_status.dart';
import '../widgets/common.dart';
import '../widgets/nutrient_radar.dart';
import '../widgets/rolling_stats_card.dart';
import '../widgets/soil_gauges.dart';

/// Tab Chỉ số: Đạm, Lân, Kali kèm biểu đồ radar, rồi độ ẩm, độ chua, độ phì so với mức tốt
class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SoilDataProvider>();
    final telemetry = provider.currentTelemetry;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: PageTitle(title: 'Chỉ số đất', updatedAt: telemetry.timestamp),
        actions: [ConnectionPill(state: provider.connectionState)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionTitle('Dinh dưỡng chính', hint: 'mg/kg đất', first: true),
          RollingStatsCard(
            unit: 'mg/kg',
            items: [
              _nutrientItem('Đạm (N)', telemetry.nitrogen, SoilStandard.nitrogen),
              _nutrientItem('Lân (P)', telemetry.phosphorus, SoilStandard.phosphorus),
              _nutrientItem('Kali (K)', telemetry.potassium, SoilStandard.potassium),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'So với mức chuẩn',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tam giác nằm trong vành xanh là đủ, lọt vào trong là thiếu, vượt ra ngoài là dư.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink3),
                ),
                const SizedBox(height: 8),
                NutrientRadar(
                  nitrogen: telemetry.nitrogen,
                  phosphorus: telemetry.phosphorus,
                  potassium: telemetry.potassium,
                ),
              ],
            ),
          ),
          const SectionTitle('Độ ẩm, độ chua, độ phì'),
          AppCard(
            child: Column(
              children: [
                _moistureRow(telemetry),
                const Divider(height: 32, color: AppColors.line),
                _phRow(telemetry),
                const Divider(height: 32, color: AppColors.line),
                _ecRow(telemetry),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Chỉ độ ẩm là số đo. Đạm, lân, kali, độ chua và độ phì được ước lượng từ độ ẩm và loại đất bạn chọn.',
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }

  StatItem _nutrientItem(String label, double value, NutrientRange range) {
    final status = SoilStatus.nutrient(value, range);
    return StatItem(
      value: value,
      label: label,
      status: status.label,
      statusColor: levelColor(status.level),
      hint: 'Chuẩn ${range.min.toInt()} - ${range.max.toInt()}',
    );
  }

  Widget _moistureRow(SoilTelemetry t) {
    final status = SoilStatus.moisture(t.moisture);
    return LevelRow(
      icon: Icons.water_drop_outlined,
      title: 'Độ ẩm',
      value: t.moisture.toStringAsFixed(1),
      unit: '%',
      status: status.label,
      statusColor: levelColor(status.level),
      reading: t.moisture,
      good: SoilStandard.moisture,
      scaleMin: 0,
      scaleMax: 100,
      goodLabel: 'Mức tốt: 50 - 70%',
    );
  }

  Widget _phRow(SoilTelemetry t) {
    final status = SoilStatus.ph(t.ph);
    return LevelRow(
      icon: Icons.science_outlined,
      title: 'Độ chua (pH)',
      value: t.ph.toStringAsFixed(1),
      unit: '',
      status: status.label,
      statusColor: levelColor(status.level),
      reading: t.ph,
      good: SoilStandard.ph,
      scaleMin: 4,
      scaleMax: 9,
      goodLabel: 'Mức tốt: pH 6.0 - 7.2',
    );
  }

  Widget _ecRow(SoilTelemetry t) {
    final status = SoilStatus.ec(t.ec);
    return LevelRow(
      icon: Icons.bolt_outlined,
      title: 'Độ phì (EC)',
      value: t.ec.toStringAsFixed(0),
      unit: 'µS/cm',
      status: status.label,
      statusColor: levelColor(status.level),
      reading: t.ec,
      good: SoilStandard.ec,
      scaleMin: 0,
      scaleMax: 2500,
      goodLabel: 'Mức tốt: 500 - 1500 µS/cm',
    );
  }
}
