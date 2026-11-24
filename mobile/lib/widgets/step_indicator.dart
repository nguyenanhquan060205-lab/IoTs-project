// Lucian UX/UI Prompt #042 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#042
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Thanh các bước (dựa trên "Step-by-step wizard"): đường nối tô dần tới bước hiện tại,
/// bước đã xong hiện dấu tích tự vẽ, bước hiện tại có vòng sáng. Bấm bước đã xong để quay lại.
class StepIndicator extends StatelessWidget {
  final List<String> labels;
  final int current;
  final ValueChanged<int>? onDoneStepTap;

  const StepIndicator({super.key, required this.labels, required this.current, this.onDoneStepTap});

  static const double _slot = 72;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final progress = labels.length > 1 ? current / (labels.length - 1) : 0.0;

    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          // Đường nối từ tâm bước đầu tới tâm bước cuối
          Positioned(
            left: _slot / 2,
            right: _slot / 2,
            top: 16,
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: AppColors.surface3)),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
                      curve: AppMotion.ease,
                      builder: (context, value, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: const ColoredBox(color: AppColors.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < labels.length; i++)
                SizedBox(
                  width: _slot,
                  child: _StepDot(
                    number: i + 1,
                    label: labels[i],
                    done: i < current,
                    isCurrent: i == current,
                    reduceMotion: reduceMotion,
                    onTap: i < current && onDoneStepTap != null ? () => onDoneStepTap!(i) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool done;
  final bool isCurrent;
  final bool reduceMotion;
  final VoidCallback? onTap;

  const _StepDot({
    required this.number,
    required this.label,
    required this.done,
    required this.isCurrent,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Duration ms(int value) => reduceMotion ? Duration.zero : Duration(milliseconds: value);
    final state = done ? 'đã xong, bấm để quay lại' : isCurrent ? 'đang làm' : 'chưa tới';

    return Semantics(
      button: onTap != null,
      label: 'Bước $number, $label, $state',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedScale(
              scale: isCurrent ? 1.08 : 1,
              duration: ms(450),
              curve: AppMotion.spring,
              child: AnimatedContainer(
                duration: ms(350),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.accent : AppColors.surface,
                  border: done ? null : Border.all(color: isCurrent ? AppColors.accent : AppColors.line2, width: 2),
                  boxShadow: isCurrent ? const [BoxShadow(color: AppColors.accentSoft, spreadRadius: 5)] : null,
                ),
                alignment: Alignment.center,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: done ? 1 : 0),
                  duration: ms(450),
                  // Dấu tích vẽ trong 0.35 s sau 0.1 s trễ
                  curve: const Interval(0.22, 1, curve: AppMotion.ease),
                  builder: (context, check, _) => check > 0
                      ? CustomPaint(size: const Size(16, 16), painter: _CheckPainter(check))
                      : Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isCurrent ? AppColors.accent : AppColors.ink3,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            AnimatedDefaultTextStyle(
              duration: ms(300),
              style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: done || isCurrent ? AppColors.ink : AppColors.ink3,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.visible, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dấu tích M3.5 8.4 l3 3 6-6.4 trong hộp 16x16, vẽ dần theo [progress]
class _CheckPainter extends CustomPainter {
  final double progress;

  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3.5, 8.4)
      ..relativeLineTo(3, 3)
      ..relativeLineTo(6, -6.4);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = AppColors.accentInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) => oldDelegate.progress != progress;
}
