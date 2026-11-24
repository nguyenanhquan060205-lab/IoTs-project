import '../models/soil_standard.dart';

enum StatusLevel { ok, warn, danger }

/// Nhãn trạng thái bằng lời thường cho từng chỉ số, dựa trên mức chuẩn trong [SoilStandard].
/// Ra ngoài mức chuẩn là "cần chú ý"; vượt ngưỡng hệ chuyên gia báo động hoặc đèn đỏ của trạm là "nguy hiểm".
class SoilStatus {
  final String label;
  final StatusLevel level;

  const SoilStatus(this.label, this.level);

  static SoilStatus nutrient(double value, NutrientRange range) {
    if (range.isBelow(value)) return const SoilStatus('Thiếu', StatusLevel.warn);
    if (range.isAbove(value)) return const SoilStatus('Dư', StatusLevel.danger);
    return const SoilStatus('Đủ', StatusLevel.ok);
  }

  // Ngưỡng 35% / 80% trùng với đèn đỏ của trạm và cảnh báo ngập úng của hệ chuyên gia
  static SoilStatus moisture(double value) {
    final range = SoilStandard.moisture;
    if (range.isBelow(value)) {
      return SoilStatus('Khô', value < 35 ? StatusLevel.danger : StatusLevel.warn);
    }
    if (range.isAbove(value)) {
      return SoilStatus('Ướt', value > 80 ? StatusLevel.danger : StatusLevel.warn);
    }
    return const SoilStatus('Vừa', StatusLevel.ok);
  }

  // pH dưới 5.5 là ngưỡng "đất chua phèn" của hệ chuyên gia
  static SoilStatus ph(double value) {
    final range = SoilStandard.ph;
    if (range.isBelow(value)) {
      return SoilStatus('Chua', value < 5.5 ? StatusLevel.danger : StatusLevel.warn);
    }
    if (range.isAbove(value)) return const SoilStatus('Kiềm', StatusLevel.warn);
    return const SoilStatus('Tốt', StatusLevel.ok);
  }

  // EC dưới 300 là "nghèo kiệt", trên 2000 là "quá mặn" theo hệ chuyên gia
  static SoilStatus ec(double value) {
    final range = SoilStandard.ec;
    if (range.isBelow(value)) {
      return SoilStatus('Nghèo', value < 300 ? StatusLevel.danger : StatusLevel.warn);
    }
    if (range.isAbove(value)) {
      return SoilStatus('Mặn', value > 2000 ? StatusLevel.danger : StatusLevel.warn);
    }
    return const SoilStatus('Tốt', StatusLevel.ok);
  }
}
