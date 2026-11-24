// Lucian UX/UI Prompt #416 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#416
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';

/// Thanh tab chia đoạn (dựa trên "Tabs"): chọn tab thì mép trước của nút trượt chạy tới trước,
/// mép sau đuổi theo như thạch. Dùng được phím mũi tên trái/phải, Home và End.
class SegmentedTabs<T> extends StatefulWidget {
  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedTabs({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<SegmentedTabs<T>> createState() => _SegmentedTabsState<T>();
}

class _SegmentedTabsState<T> extends State<SegmentedTabs<T>> with SingleTickerProviderStateMixin {
  // Mép dẫn chạy 0.38 s, mép sau 0.62 s, cùng đường cong cubic-bezier(.3,1.25,.45,1)
  static const Curve _jelly = Cubic(0.3, 1.25, 0.45, 1);
  static const double _fastShare = 0.38 / 0.62;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620), value: 1);
  int _from = 0;
  int _to = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.values.indexOf(widget.selected);
  }

  @override
  void didUpdateWidget(covariant SegmentedTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.values.indexOf(widget.selected);
    if (next == _to) return;
    _from = _to;
    _to = next;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    final count = widget.values.length;
    widget.onChanged(widget.values[(index + count) % count]);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.values.length;

    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight) {
          _select(_to + 1);
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          _select(_to - 1);
        } else if (key == LogicalKeyboardKey.home) {
          _select(0);
        } else if (key == LogicalKeyboardKey.end) {
          _select(count - 1);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / count;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final movingRight = _to >= _from;
                final fast = const Interval(0, _fastShare, curve: _jelly).transform(_controller.value);
                final slow = _jelly.transform(_controller.value);
                final leftT = movingRight ? slow : fast;
                final rightT = movingRight ? fast : slow;
                final left = (_from + (_to - _from) * leftT) * tabWidth;
                final right = (count - 1 - _from - (_to - _from) * rightT) * tabWidth;

                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      right: right,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.line),
                          boxShadow: const [
                            BoxShadow(color: AppColors.shadow, blurRadius: 2, offset: Offset(0, 1)),
                            BoxShadow(color: AppColors.shadowStrong, blurRadius: 14, spreadRadius: -8, offset: Offset(0, 6)),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: i == _to,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _select(i),
                                child: SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 250),
                                      style: DefaultTextStyle.of(context).style.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: i == _to ? AppColors.ink : AppColors.ink3,
                                      ),
                                      child: Text(widget.labelOf(widget.values[i])),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
