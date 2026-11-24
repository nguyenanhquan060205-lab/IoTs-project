import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class BottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge; // Số hiện trong chấm đỏ, 0 thì ẩn

  const BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
  });
}

/// Thanh điều hướng dưới đáy kiểu Facebook: mọi tab luôn có biểu tượng và chữ,
/// tab đang chọn đổi sang màu lá với biểu tượng đậm, vạch nhỏ ở mép trên trượt theo.
class AppBottomNav extends StatelessWidget {
  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 450),
                    curve: AppMotion.spring,
                    top: 0,
                    left: tabWidth * currentIndex + tabWidth * 0.25,
                    width: tabWidth * 0.5,
                    height: 3,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(child: _NavTab(item: items[i], selected: i == currentIndex, onTap: () => onTap(i))),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.ink3;
    final badgeText = item.badge > 9 ? '9+' : '${item.badge}';

    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0 ? '${item.label}, ${item.badge} việc cần làm' : item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? item.selectedIcon : item.icon, size: 26, color: color),
                if (item.badge > 0)
                  Positioned(
                    left: 16,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeText,
                        style: const TextStyle(fontSize: 10.5, height: 1, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
