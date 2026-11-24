import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_standard.dart';

/// Biểu đồ radar N-P-K so với mức chuẩn.
/// Mỗi trục tính theo % của mức chuẩn giữa (Đạm 75, Lân 50, Kali 115 mg/kg) để 3 chất cùng một thang:
/// vành xanh là khoảng chuẩn của từng chất, tam giác xanh đậm là đất đang đo.
class NutrientRadar extends StatelessWidget {
  final double nitrogen;
  final double phosphorus;
  final double potassium;

  const NutrientRadar({
    super.key,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
  });

  static const _ranges = [SoilStandard.nitrogen, SoilStandard.phosphorus, SoilStandard.potassium];
  static const _titles = ['Đạm (N)', 'Lân (P)', 'Kali (K)'];

  static double _percent(double value, NutrientRange range) => value / ((range.min + range.max) / 2) * 100;

  static List<RadarEntry> _entries(List<double> values) => [
        for (var i = 0; i < 3; i++) RadarEntry(value: _percent(values[i], _ranges[i])),
      ];

  static RadarDataSet _anchor(double value) => RadarDataSet(
        dataEntries: [for (var i = 0; i < 3; i++) RadarEntry(value: value)],
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        borderWidth: 0,
        entryRadius: 0,
      );

  @override
  Widget build(BuildContext context) {
    final measured = [nitrogen, phosphorus, potassium];

    return Semantics(
      label: 'Biểu đồ so với mức chuẩn: Đạm ${nitrogen.round()}, Lân ${phosphorus.round()}, Kali ${potassium.round()} mg/kg',
      excludeSemantics: true,
      child: Column(
        children: [
          // fl_chart vẽ nhãn đỉnh trên ra ngoài khung biểu đồ, chừa chỗ để không đè lên chữ phía trên
          const SizedBox(height: 40),
          SizedBox(
            height: 230,
            child: RadarChart(
              RadarChartData(
                // Tâm là 0% để khoảng cách tới tâm tỉ lệ đúng với lượng dinh dưỡng
                isMinValueAtCenter: true,
                radarShape: RadarShape.polygon,
                tickCount: 2,
                ticksTextStyle: const TextStyle(fontSize: 1, color: Colors.transparent),
                tickBorderData: const BorderSide(color: AppColors.line),
                gridBorderData: const BorderSide(color: AppColors.line),
                radarBorderData: const BorderSide(color: AppColors.line2),
                radarBackgroundColor: Colors.transparent,
                radarTouchData: RadarTouchData(enabled: false),
                titlePositionPercentageOffset: 0.12,
                titleTextStyle: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2,
                    ),
                getTitle: (index, _) => RadarChartTitle(text: '${_titles[index]}\n${measured[index].round()}'),
                dataSets: [
                  // 2 bộ trong suốt giữ tâm ở 0% và vành ngoài ở 160% cho mọi lần đo
                  _anchor(0),
                  _anchor(160),
                  RadarDataSet(
                    dataEntries: _entries([for (final r in _ranges) r.max]),
                    fillColor: AppColors.ok.withValues(alpha: 0.16),
                    borderColor: AppColors.ok.withValues(alpha: 0.7),
                    borderWidth: 1.5,
                    entryRadius: 0,
                  ),
                  // Phủ màu nền bên trong mức tối thiểu để còn lại đúng một vành chuẩn
                  RadarDataSet(
                    dataEntries: _entries([for (final r in _ranges) r.min]),
                    fillColor: AppColors.surface,
                    borderColor: AppColors.ok.withValues(alpha: 0.7),
                    borderWidth: 1.5,
                    entryRadius: 0,
                  ),
                  RadarDataSet(
                    dataEntries: _entries(measured),
                    fillColor: AppColors.accent.withValues(alpha: 0.18),
                    borderColor: AppColors.accent,
                    borderWidth: 2.5,
                    entryRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(AppColors.ok.withValues(alpha: 0.4), 'Mức chuẩn'),
              const SizedBox(width: 18),
              _legend(AppColors.accent, 'Đất đang đo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
      ],
    );
  }
}
