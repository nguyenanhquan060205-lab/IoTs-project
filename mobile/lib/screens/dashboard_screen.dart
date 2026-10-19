import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_standard.dart';
import '../models/soil_telemetry.dart';
import '../providers/soil_data_provider.dart';
import '../services/agronomic_engine.dart';
import '../services/mqtt_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SoilDataProvider>();
    final telemetry = provider.currentTelemetry;
    final diagnosis = provider.currentDiagnosis;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dinh Dưỡng Đất Thông Minh',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Cập nhật: ${DateFormat('HH:mm:ss dd/MM').format(telemetry.timestamp)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          _buildConnectionPill(provider),
          IconButton(
            tooltip: 'Mô phỏng dữ liệu ngẫu nhiên (Demo)',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => provider.simulateRandomReading(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStationInfoCard(telemetry),
            const SizedBox(height: 16),
            _buildHealthBanner(diagnosis),
            const SizedBox(height: 16),
            const Text(
              'HÀM LƯỢNG DINH DƯỠNG CỐT LÕI (NPK)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildNutrientCard(
                    title: 'Nitơ (N - Đạm)',
                    value: telemetry.nitrogen,
                    unit: 'mg/kg',
                    target: SoilStandard.nitrogen,
                    color: AppColors.nitrogen,
                    icon: Icons.eco,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildNutrientCard(
                    title: 'Photpho (P - Lân)',
                    value: telemetry.phosphorus,
                    unit: 'mg/kg',
                    target: SoilStandard.phosphorus,
                    color: AppColors.phosphorus,
                    icon: Icons.grain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildNutrientCard(
                    title: 'Kali (K)',
                    value: telemetry.potassium,
                    unit: 'mg/kg',
                    target: SoilStandard.potassium,
                    color: AppColors.potassium,
                    icon: Icons.local_florist,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'CHỈ SỐ LÝ - HÓA MÔI TRƯỜNG',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildMetricCard(
                  title: 'Độ pH Đất',
                  value: telemetry.ph.toStringAsFixed(1),
                  unit: 'pH',
                  subtitle: _getPhDescription(telemetry.ph),
                  color: AppColors.phColor,
                  icon: Icons.science,
                ),
                _buildMetricCard(
                  title: 'Độ Dẫn Điện (EC)',
                  value: telemetry.ec.toInt().toString(),
                  unit: 'µS/cm',
                  subtitle: _getEcDescription(telemetry.ec),
                  color: AppColors.ecColor,
                  icon: Icons.bolt,
                ),
                _buildMetricCard(
                  title: 'Độ Ẩm Đất',
                  value: telemetry.moisture.toStringAsFixed(1),
                  unit: '%',
                  subtitle: 'Chuẩn: 50 - 70%',
                  color: AppColors.moistureColor,
                  icon: Icons.water_drop,
                ),
                _buildMetricCard(
                  title: 'Nhiệt Độ Đất',
                  value: telemetry.temperature.toStringAsFixed(1),
                  unit: '°C',
                  subtitle: 'Tầng đất mặt (Canh tác)',
                  color: Colors.orangeAccent,
                  icon: Icons.thermostat,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRadarChartSection(telemetry),
            const SizedBox(height: 16),
            _buildActuatorControl(provider),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoCard(SoilTelemetry telemetry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sensors, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trạm Đo: ESP32 Soil Station 01',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Đầu dò Analog ADC (GPIO34) • Báo Cáo Sức Khỏe Mẫu Đất',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionPill(SoilDataProvider provider) {
    Color color;
    String text;

    switch (provider.connectionState) {
      case AppMqttState.connected:
        color = AppColors.optimal;
        text = 'Online';
        break;
      case AppMqttState.connecting:
        color = AppColors.warning;
        text = 'Đang nối';
        break;
      case AppMqttState.error:
      case AppMqttState.disconnected:
        color = AppColors.danger;
        text = 'Offline';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBanner(AgronomicDiagnosis diagnosis) {
    Color bannerColor;
    IconData icon;

    switch (diagnosis.overallSeverity) {
      case AlertSeverity.normal:
        bannerColor = AppColors.optimal;
        icon = Icons.check_circle_outline;
        break;
      case AlertSeverity.warning:
        bannerColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertSeverity.danger:
        bannerColor = AppColors.danger;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: bannerColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉ Số Sức Khỏe Đất: ${diagnosis.soilHealthScore.toInt()}/100',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: bannerColor,
                      ),
                    ),
                    Text(
                      diagnosis.generalStatus,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (diagnosis.issues.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 20),
            const Text(
              'Chẩn đoán & Cảnh báo chi tiết:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...diagnosis.issues.map((issue) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: Text(
                          '${issue.title}: ${issue.recommendation}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildNutrientCard({
    required String title,
    required double value,
    required String unit,
    required NutrientRange target,
    required Color color,
    required IconData icon,
  }) {
    String status = 'Tối ưu';
    Color statusColor = AppColors.optimal;

    if (target.isBelow(value)) {
      status = 'Thiếu';
      statusColor = AppColors.warning;
    } else if (target.isAbove(value)) {
      status = 'Thừa';
      statusColor = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.toInt().toString(),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color),
          ),
          Text(
            'Chuẩn: ${target.min.toInt()}-${target.max.toInt()}',
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChartSection(SoilTelemetry telemetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BIỂU ĐỒ RADAR CÂN BẰNG DINH DƯỠNG N-P-K',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Màu xanh lá: Ngưỡng Đất Màu Mỡ Chuẩn | Màu xanh ngọc: Đo Thực Tế',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                radarBorderData: const BorderSide(color: Colors.white24, width: 1),
                gridBorderData: const BorderSide(color: Colors.white10, width: 1),
                tickBorderData: const BorderSide(color: Colors.transparent),
                ticksTextStyle: const TextStyle(fontSize: 9, color: Colors.white38),
                radarBackgroundColor: Colors.transparent,
                getTitle: (index, angle) {
                  switch (index) {
                    case 0:
                      return const RadarChartTitle(text: 'Nitơ (N)');
                    case 1:
                      return const RadarChartTitle(text: 'Photpho (P)');
                    case 2:
                      return const RadarChartTitle(text: 'Kali (K)');
                    default:
                      return const RadarChartTitle(text: '');
                  }
                },
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.primary.withValues(alpha: 0.2),
                    borderColor: AppColors.primary,
                    entryRadius: 3,
                    dataEntries: const [
                      RadarEntry(value: 75.0),  // Mức đạm chuẩn (50 - 100)
                      RadarEntry(value: 50.0),  // Mức lân chuẩn (30 - 70)
                      RadarEntry(value: 115.0), // Mức kali chuẩn (80 - 150)
                    ],
                    borderWidth: 2,
                  ),
                  RadarDataSet(
                    fillColor: AppColors.accent.withValues(alpha: 0.4),
                    borderColor: AppColors.accent,
                    entryRadius: 4,
                    dataEntries: [
                      RadarEntry(value: telemetry.nitrogen),
                      RadarEntry(value: telemetry.phosphorus),
                      RadarEntry(value: telemetry.potassium),
                    ],
                    borderWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorControl(SoilDataProvider provider) {
    final telemetry = provider.currentTelemetry;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ĐIỀU KHIỂN THIẾT BỊ NGOẠI VI (RELAY 2 KÊNH)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: telemetry.pumpActive
                        ? AppColors.primaryDark.withValues(alpha: 0.3)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: telemetry.pumpActive ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water,
                            color: telemetry.pumpActive ? AppColors.primary : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bơm Nước Tưới',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                telemetry.pumpActive ? 'Đang BẬT' : 'Đang TẮT',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: telemetry.pumpActive
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: telemetry.pumpActive,
                        activeThumbColor: AppColors.primary,
                        onChanged: (_) => provider.togglePump(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: telemetry.valveActive
                        ? AppColors.primaryDark.withValues(alpha: 0.3)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: telemetry.valveActive ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_florist,
                            color: telemetry.valveActive ? AppColors.primary : Colors.white38,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Van Châm Dinh Dưỡng',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                telemetry.valveActive ? 'Đang BẬT' : 'Đang TẮT',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: telemetry.valveActive
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: telemetry.valveActive,
                        activeThumbColor: AppColors.primary,
                        onChanged: (_) => provider.toggleValve(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPhDescription(double ph) {
    if (ph < 5.5) return 'Chua phèn';
    if (ph <= 7.0) return 'Trung tính lý tưởng';
    return 'Kiềm tính';
  }

  String _getEcDescription(double ec) {
    if (ec < 300) return 'Nghèo kiệt';
    if (ec <= 1500) return 'Phì nhiêu tốt';
    return 'Quá cao / Mặn';
  }
}
