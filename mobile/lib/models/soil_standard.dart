class NutrientRange {
  final double min;
  final double max;

  const NutrientRange(this.min, this.max);

  bool contains(double val) => val >= min && val <= max;
  bool isBelow(double val) => val < min;
  bool isAbove(double val) => val > max;
}

/// Tiêu chuẩn định mức độ phì & dinh dưỡng đất trồng nông nghiệp
class SoilStandard {
  static const NutrientRange nitrogen = NutrientRange(50, 100);    // mg/kg (Đạm)
  static const NutrientRange phosphorus = NutrientRange(30, 70);   // mg/kg (Lân)
  static const NutrientRange potassium = NutrientRange(80, 150);   // mg/kg (Kali)
  static const NutrientRange ph = NutrientRange(6.0, 7.2);         // pH
  static const NutrientRange ec = NutrientRange(500, 1500);        // µS/cm (Độ phì nhiêu)
  static const NutrientRange moisture = NutrientRange(50, 70);     // % (Độ ẩm đất)
}
