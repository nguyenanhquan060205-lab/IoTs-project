// Lucian UX/UI Prompt #072 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#072
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Một dòng cảnh báo (dựa trên "Collapsing inline alerts"): nền pha màu trạng thái, vạch màu bên trái,
/// ô biểu tượng cùng màu. Bỏ nút đóng của bản gốc vì lời khuyên được tính lại mỗi lần trạm gửi số liệu.
class InlineAlert extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  const InlineAlert({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.mix(color, 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 17, color: AppColors.accentInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.ink2),
                      ),
                    ],
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

/// Trạng thái "mọi thứ ổn" của cùng phần tử: vòng tròn xanh có dấu tích và một câu ngắn
class CalmState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Color color;

  const CalmState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.check_rounded,
    this.color = AppColors.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.ink2),
          ),
        ],
      ],
    );
  }
}
