import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../services/mqtt_service.dart';
import '../services/soil_status.dart';

Color levelColor(StatusLevel level) {
  switch (level) {
    case StatusLevel.ok:
      return AppColors.ok;
    case StatusLevel.warn:
      return AppColors.warn;
    case StatusLevel.danger:
      return AppColors.danger;
  }
}

/// Thẻ nền trắng bo góc dùng chung cho mọi trang
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: AppColors.line),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: AppColors.cardShadow),
      child: Material(
        color: AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: SizedBox(width: double.infinity, child: child)),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? hint;
  final bool first;

  const SectionTitle(this.title, {super.key, this.hint, this.first = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 4 : 28, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
            ),
          ),
          if (hint != null) Text(hint!, style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
        ],
      ),
    );
  }
}

class ConnectionPill extends StatelessWidget {
  final AppMqttState state;

  const ConnectionPill({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      AppMqttState.connected => ('Trực tuyến', AppColors.ok),
      AppMqttState.connecting => ('Đang nối', AppColors.warn),
      AppMqttState.error || AppMqttState.disconnected => ('Mất kết nối', AppColors.danger),
    };

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Tiêu đề trang 2 dòng: tên trang và giờ trạm gửi số đo gần nhất
class PageTitle extends StatelessWidget {
  final String title;
  final DateTime updatedAt;

  const PageTitle({super.key, required this.title, required this.updatedAt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
        ),
        Text(
          'Cập nhật lúc ${DateFormat('HH:mm · dd/MM').format(updatedAt)}',
          style: const TextStyle(fontSize: 13, color: AppColors.ink3),
        ),
      ],
    );
  }
}
