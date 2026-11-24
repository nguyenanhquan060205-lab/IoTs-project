// Lucian UX/UI Prompt #426 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#426
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class StatItem {
  final double value;
  final String label;
  final String status;
  final Color statusColor;
  final String? hint; // Dòng phụ dưới nhãn, ví dụ mức chuẩn

  const StatItem({
    required this.value,
    required this.label,
    required this.status,
    required this.statusColor,
    this.hint,
  });
}

/// Thẻ 3 con số lớn ngăn bằng đường kẻ mảnh (dựa trên "Stats"): mỗi chữ số lăn như đồng hồ
/// công-tơ-mét rồi dừng ở giá trị, khi số đo đổi thì chữ số lăn tới giá trị mới.
class RollingStatsCard extends StatelessWidget {
  final List<StatItem> items;
  final String unit;

  const RollingStatsCard({super.key, required this.items, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.cardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: AppColors.line2),
              Expanded(child: _StatCell(item: items[i], unit: unit)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final StatItem item;
  final String unit;

  const _StatCell({required this.item, required this.unit});

  @override
  Widget build(BuildContext context) {
    final text = item.value.round().toString();

    return Semantics(
      label: '${item.label}: $text $unit, ${item.status}${item.hint != null ? ', ${item.hint}' : ''}',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: _RollingDigit.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < text.length; i++)
                  // Khóa theo vị trí tính từ hàng đơn vị để cột chữ số giữ nguyên khi số có thêm chữ số
                  _RollingDigit(key: ValueKey(text.length - i), digit: int.parse(text[i]), order: i),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(item.label, style: const TextStyle(fontSize: 14, color: AppColors.ink2)),
          if (item.hint != null) ...[
            const SizedBox(height: 2),
            Text(item.hint!, style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.status,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: item.statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một cột chữ số 0-9 lặp 2 lần, trượt dọc để hiện chữ số cần thiết.
/// Vị trí nghỉ là bản thứ hai (chữ số + 10) để lần đầu lăn trọn một vòng như bản gốc.
class _RollingDigit extends StatefulWidget {
  static const double height = 36;

  final int digit;
  final int order; // Thứ tự từ trái sang, mỗi chữ số trễ thêm 70 ms

  const _RollingDigit({super.key, required this.digit, required this.order});

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit> with SingleTickerProviderStateMixin {
  static const Curve _roll = Cubic(0.25, 1.12, 0.4, 1);

  late final AnimationController _controller;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    final delay = widget.order * 70;
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1300 + delay));
    _position = _tween(0, widget.digit + 10.0, delay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed) _start();
  }

  @override
  void didUpdateWidget(covariant _RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _position = _tween(_position.value, widget.digit + 10.0, widget.order * 70);
      _controller.reset();
      _start();
    }
  }

  Animation<double> _tween(double from, double to, int delayMs) {
    final total = 1300 + delayMs;
    return Tween<double>(begin: from, end: to).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(delayMs / total, 1, curve: _roll),
    ));
  }

  void _start() {
    // Người dùng tắt hiệu ứng chuyển động: hiện ngay giá trị cuối
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 19,
        height: _RollingDigit.height,
        child: AnimatedBuilder(
          animation: _position,
          builder: (context, child) => OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(0, -_position.value * _RollingDigit.height),
              child: child,
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 20; i++)
                SizedBox(
                  height: _RollingDigit.height,
                  child: Center(
                    child: Text(
                      '${i % 10}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
