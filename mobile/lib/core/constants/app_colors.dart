import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Bảng màu giao diện sáng, dựng theo bộ token --ux-* của Lucian UX/UI Prompt
/// (https://lucianlabs.dev/uxui-prompt/). Nền giấy ấm và một màu lá cây làm điểm nhấn,
/// màu trạng thái được làm đậm hơn bản gốc để đọc rõ ngoài nắng.
class AppColors {
  // Nền và bề mặt (--ux-page, --ux-surface, --ux-surface-2, --ux-surface-3)
  static const Color page = Color(0xFFF4F2EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF5F3EF);
  static const Color surface3 = Color(0xFFEAE7E1);

  // Chữ (--ux-ink, --ux-ink-2, --ux-ink-3)
  static const Color ink = Color(0xFF16151B);
  static const Color ink2 = Color(0xFF57535F);
  static const Color ink3 = Color(0xFF7E7A87);

  // Đường kẻ (--ux-line, --ux-line-2)
  static const Color line = Color(0x1716151B);
  static const Color line2 = Color(0x2B16151B);

  // Điểm nhấn: xanh lá cây thay cho tím của bản gốc (--ux-accent, --ux-accent-soft, --ux-accent-ink)
  static const Color accent = Color(0xFF2E7D32);
  static const Color accentSoft = Color(0x1F2E7D32);
  static const Color accentInk = Color(0xFFFFFFFF);

  // Trạng thái (--ux-mint, --ux-warn, --ux-danger), đậm hơn để chữ đạt độ tương phản 4.5:1 trên nền trắng
  static const Color ok = Color(0xFF11845F);
  static const Color warn = Color(0xFFB95E12);
  static const Color danger = Color(0xFFC62E49);

  // Bóng đổ (--ux-shadow, --ux-shadow-strong)
  static const Color shadow = Color(0x24281E50);
  static const Color shadowStrong = Color(0x4D281E50);

  // Màu đất cho 3 loại mẫu: đậm -> nhạt theo độ màu mỡ
  static const Color soilRich = Color(0xFF5D4037);
  static const Color soilGarden = Color(0xFF8D6E63);
  static const Color soilPoor = Color(0xFFA1887F);

  /// Pha màu như color-mix(in srgb, color X%, base)
  static Color mix(Color color, double amount, [Color base = surface]) =>
      Color.lerp(base, color, amount)!;

  /// Bóng của thẻ: 0 0 0 1px line, 0 1px 2px shadow, 0 20px 40px -26px shadow-strong
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: shadow, blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: shadowStrong, blurRadius: 40, spreadRadius: -26, offset: Offset(0, 20)),
  ];
}

/// Đường cong chuyển động của Lucian (--ux-ease, --ux-spring)
class AppMotion {
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve spring = Cubic(0.34, 1.45, 0.64, 1);
}
