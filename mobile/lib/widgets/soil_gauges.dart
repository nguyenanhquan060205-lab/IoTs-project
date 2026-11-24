import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_standard.dart';

/// Vòng điểm sức khỏe đất 0-100, cung màu chạy từ đỉnh theo chiều kim đồng hồ
class ScoreRing extends StatelessWidget {
  final double score;
  final Color color;
  final double size;

  const ScoreRing({super.key, required this.score, required this.color, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Điểm sức khỏe đất ${score.round()} trên 100',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: score.clamp(0, 100).toDouble()),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
        curve: AppMotion.ease,
        builder: (context, value, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(value / 100, color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.round()}',
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text('điểm', style: TextStyle(fontSize: 12, color: AppColors.ink3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _RingPainter(this.fraction, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.surface3
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// Một dòng chỉ số kèm thanh so với mức chuẩn: dải xanh là khoảng tốt, chấm tròn là số đo hiện tại
class LevelRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final double reading;
  final NutrientRange good;
  final double scaleMin;
  final double scaleMax;
  final String goodLabel;

  const LevelRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    required this.reading,
    required this.good,
    required this.scaleMin,
    required this.scaleMax,
    required this.goodLabel,
  });

  double _fraction(double v) => ((v - scaleMin) / (scaleMax - scaleMin)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: '$title $value $unit, $status. $goodLabel',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(unit, style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
              ],
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const markerSize = 18.0;
              return SizedBox(
                height: markerSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (markerSize - 8) / 2,
                      height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface3,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: width * _fraction(good.min),
                      width: width * (_fraction(good.max) - _fraction(good.min)),
                      top: (markerSize - 8) / 2,
                      height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.ok.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
                      curve: AppMotion.ease,
                      left: (width * _fraction(reading) - markerSize / 2).clamp(0.0, width - markerSize),
                      top: 0,
                      width: markerSize,
                      height: markerSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 3),
                          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1))],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(goodLabel, style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
        ],
      ),
    );
  }
}
