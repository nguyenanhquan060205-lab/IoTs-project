import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../providers/soil_data_provider.dart';
import '../services/mqtt_service.dart';
import 'common.dart';

/// Thẻ bật/tắt rơ-le máy bơm tưới và van dinh dưỡng trên trạm (lệnh SET_PUMP / SET_VALVE)
class ActuatorControls extends StatelessWidget {
  final SoilDataProvider provider;

  const ActuatorControls({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final online = provider.connectionState == AppMqttState.connected;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActuatorTile(
            provider: provider,
            actuator: Actuator.pump,
            icon: Icons.water_drop_outlined,
            title: 'Máy bơm tưới',
            onLabel: 'Đang chạy',
            offLabel: 'Đang tắt',
            enabled: online,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
          _ActuatorTile(
            provider: provider,
            actuator: Actuator.valve,
            icon: Icons.opacity_rounded,
            title: 'Van dinh dưỡng',
            onLabel: 'Đang mở',
            offLabel: 'Đang đóng',
            enabled: online,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              online
                  ? 'Trạm tự ngắt bơm khi độ ẩm đất trên 85%.'
                  : 'Cần kết nối với trạm để bật hoặc tắt.',
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActuatorTile extends StatelessWidget {
  final SoilDataProvider provider;
  final Actuator actuator;
  final IconData icon;
  final String title;
  final String onLabel;
  final String offLabel;
  final bool enabled;

  const _ActuatorTile({
    required this.provider,
    required this.actuator,
    required this.icon,
    required this.title,
    required this.onLabel,
    required this.offLabel,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final on = provider.actuatorState(actuator);
    final (status, color) = provider.isActuatorSyncing(actuator)
        ? ('Đang gửi lệnh tới trạm...', AppColors.warn)
        : !provider.hasActuatorReport
            ? ('Chưa rõ trạng thái', AppColors.ink3)
            : on
                ? (onLabel, AppColors.ok)
                : (offLabel, AppColors.ink2);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Icon(icon, color: on ? AppColors.accent : AppColors.ink3),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
      subtitle: Text(status, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      value: on,
      onChanged: enabled
          ? (value) {
              if (!provider.setActuator(actuator, value)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chưa kết nối được với trạm, hãy thử lại.')),
                );
              }
            }
          : null,
    );
  }
}
