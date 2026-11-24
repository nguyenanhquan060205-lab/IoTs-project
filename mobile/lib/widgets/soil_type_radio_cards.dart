// Lucian UX/UI Prompt #015 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#015
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../models/soil_type.dart';

/// Thẻ chọn loại đất (dựa trên "Plan radio cards"): khung viền xanh trượt tới thẻ được chọn,
/// chấm tròn bên trong bật lên. Bấm vào thẻ, hoặc dùng phím mũi tên lên/xuống.
class SoilTypeRadioCards extends StatelessWidget {
  final SoilType selected;
  final ValueChanged<SoilType> onChanged;

  const SoilTypeRadioCards({super.key, required this.selected, required this.onChanged});

  static const double _optionHeight = 78;
  static const double _gap = 10;

  static Color levelColor(SoilType type) {
    switch (type) {
      case SoilType.potting:
        return AppColors.ok;
      case SoilType.garden:
        return AppColors.warn;
      case SoilType.barren:
        return AppColors.danger;
    }
  }

  static Color soilColor(SoilType type) {
    switch (type) {
      case SoilType.potting:
        return AppColors.soilRich;
      case SoilType.garden:
        return AppColors.soilGarden;
      case SoilType.barren:
        return AppColors.soilPoor;
    }
  }

  static IconData soilIcon(SoilType type) {
    switch (type) {
      case SoilType.potting:
        return Icons.inventory_2_outlined;
      case SoilType.garden:
        return Icons.yard_outlined;
      case SoilType.barren:
        return Icons.landscape_outlined;
    }
  }

  void _move(int delta) {
    const types = SoilType.values;
    final next = (types.indexOf(selected) + delta + types.length) % types.length;
    onChanged(types[next]);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final index = SoilType.values.indexOf(selected);

    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
          _move(1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowLeft) {
          _move(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        container: true,
        label: 'Loại đất đang đo',
        child: Stack(
          children: [
            // Khung chọn nằm dưới các thẻ: chỉ viền 2px và bóng lộ ra quanh thẻ được chọn
            AnimatedPositioned(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 550),
              curve: AppMotion.spring,
              left: 0,
              right: 0,
              top: index * (_optionHeight + _gap),
              height: _optionHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      const BoxShadow(color: AppColors.accent, spreadRadius: 2),
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.7),
                        blurRadius: 36,
                        spreadRadius: -20,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                for (final type in SoilType.values)
                  Padding(
                    padding: EdgeInsets.only(bottom: type == SoilType.values.last ? 0 : _gap),
                    child: SizedBox(
                      height: _optionHeight,
                      child: _SoilOption(
                        type: type,
                        checked: type == selected,
                        reduceMotion: reduceMotion,
                        onTap: () => onChanged(type),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoilOption extends StatefulWidget {
  final SoilType type;
  final bool checked;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _SoilOption({
    required this.type,
    required this.checked,
    required this.reduceMotion,
    required this.onTap,
  });

  @override
  State<_SoilOption> createState() => _SoilOptionState();
}

class _SoilOptionState extends State<_SoilOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final checked = widget.checked;
    final levelColor = SoilTypeRadioCards.levelColor(type);
    Duration ms(int value) => widget.reduceMotion ? Duration.zero : Duration(milliseconds: value);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: checked,
      button: true,
      label: '${type.label}, dự đoán dinh dưỡng ${type.expectedLevel}',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: ms(400),
        curve: AppMotion.spring,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  // Chấm radio: viền đổi màu, chấm trong bật lên bằng đường cong lò xo
                  AnimatedContainer(
                    duration: ms(300),
                    curve: AppMotion.ease,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: checked ? AppColors.accent : AppColors.line2, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      scale: checked ? 1 : 0,
                      duration: ms(450),
                      curve: AppMotion.spring,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SoilTypeRadioCards.soilColor(type),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(SoilTypeRadioCards.soilIcon(type), color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                type.shortLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: levelColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                type.expectedLevel,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: levelColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
