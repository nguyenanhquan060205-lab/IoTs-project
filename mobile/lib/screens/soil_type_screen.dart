import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/soil_data_provider.dart';
import '../services/mqtt_service.dart';
import '../widgets/common.dart';
import '../widgets/soil_type_radio_cards.dart';

/// Tab Mẫu đất: chọn 1 trong 3 loại đất đang cắm đầu dò, xem mô tả và trạm đã nhận chưa
class SoilTypeScreen extends StatelessWidget {
  const SoilTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SoilDataProvider>();
    final soil = provider.selectedSoilType;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Chọn mẫu đất', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        actions: [ConnectionPill(state: provider.connectionState)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text(
              'Chọn đúng loại đất đang cắm đầu dò. Trạm dùng loại đất này để ước lượng đạm, lân, kali.',
              style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.ink2),
            ),
          ),
          SoilTypeRadioCards(selected: soil, onChanged: provider.selectSoilType),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        soil.label,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SoilSyncBadge(provider: provider),
                  ],
                ),
                const SizedBox(height: 12),
                _detail(Icons.place_outlined, 'Nơi lấy', soil.source),
                const SizedBox(height: 10),
                _detail(Icons.visibility_outlined, 'Nhận biết', soil.trait),
                const SizedBox(height: 10),
                _detail(
                  Icons.eco_outlined,
                  'Dự đoán dinh dưỡng',
                  soil.expectedLevel,
                  valueColor: SoilTypeRadioCards.levelColor(soil),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value, {Color valueColor = AppColors.ink}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.ink3),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: valueColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Trạng thái gửi loại đất tới trạm: đã nhận, đang gửi, chờ mạng hoặc chưa có tin
class SoilSyncBadge extends StatelessWidget {
  final SoilDataProvider provider;

  const SoilSyncBadge({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;

    if (provider.isSoilTypeSyncing) {
      if (provider.connectionState == AppMqttState.connected) {
        icon = Icons.sync_rounded;
        color = AppColors.warn;
        text = 'Đang gửi tới trạm...';
      } else {
        icon = Icons.cloud_off_rounded;
        color = AppColors.warn;
        text = 'Chờ có mạng để gửi';
      }
    } else if (provider.currentTelemetry.soilType == null) {
      icon = Icons.hourglass_empty_rounded;
      color = AppColors.ink3;
      text = 'Chưa có tin từ trạm';
    } else {
      icon = Icons.check_circle_rounded;
      color = AppColors.ok;
      text = 'Trạm đã nhận';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
