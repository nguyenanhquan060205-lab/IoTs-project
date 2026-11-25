import 'soil_type.dart';

/// Mốc hiệu chuẩn đầu dò độ ẩm: khô (để ngoài không khí) hoặc ướt (nhúng vào cốc nước)
enum CalibrationPoint {
  dry('dry'),
  wet('wet');

  const CalibrationPoint(this.code);
  final String code;
}

/// Tín hiệu đầu dò độ ẩm ADC và mốc hiệu chuẩn đang lưu trên trạm
class AdcInfo {
  final int raw; // ADC sau lọc
  final double noise; // Độ lệch chuẩn các mẫu thô
  final int dry; // Mốc khô
  final int wet; // Mốc ướt

  const AdcInfo({
    required this.raw,
    required this.noise,
    required this.dry,
    required this.wet,
  });

  static AdcInfo? fromJson(Map<String, dynamic>? json) {
    if (json == null || json['raw'] == null) return null;
    return AdcInfo(
      raw: (json['raw'] as num).toInt(),
      noise: (json['noise'] as num?)?.toDouble() ?? 0.0,
      dry: (json['dry'] as num?)?.toInt() ?? 0,
      wet: (json['wet'] as num?)?.toInt() ?? 0,
    );
  }
}

class SoilTelemetry {
  // Trước mốc này là số giây tính từ lúc ESP32 khởi động (firmware cũ), không phải giờ thực
  static const int _minValidEpochSeconds = 1600000000;

  final double nitrogen; // mg/kg
  final double phosphorus; // mg/kg
  final double potassium; // mg/kg
  final double ph;
  final double ec; // µS/cm
  final double moisture; // %
  final double? temperature; // °C, trạm chưa gắn cảm biến nhiệt nên thường để trống
  final DateTime timestamp;
  final SoilType? soilType; // Loại đất trạm đang áp dụng (null nếu trạm không báo)
  final AdcInfo? adc;
  final bool? pump; // Rơ-le máy bơm đang bật (null nếu trạm không báo)
  final bool? valve; // Rơ-le van dinh dưỡng đang mở (null nếu trạm không báo)

  SoilTelemetry({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
    required this.ec,
    required this.moisture,
    this.temperature,
    required this.timestamp,
    this.soilType,
    this.adc,
    this.pump,
    this.valve,
  });

  factory SoilTelemetry.fromJson(Map<String, dynamic> json) {
    final telemetry = json['telemetry'] as Map<String, dynamic>? ?? json;
    final epochSeconds = (json['timestamp'] as num?)?.toInt();
    final actuators = json['actuators'] as Map<String, dynamic>?;

    return SoilTelemetry(
      nitrogen: (telemetry['nitrogen'] as num?)?.toDouble() ?? 0.0,
      phosphorus: (telemetry['phosphorus'] as num?)?.toDouble() ?? 0.0,
      potassium: (telemetry['potassium'] as num?)?.toDouble() ?? 0.0,
      ph: (telemetry['ph'] as num?)?.toDouble() ?? 7.0,
      ec: (telemetry['ec'] as num?)?.toDouble() ?? 0.0,
      moisture: (telemetry['moisture'] as num?)?.toDouble() ?? 0.0,
      temperature: (telemetry['temperature'] as num?)?.toDouble(),
      // Trạm chưa đồng bộ giờ NTP thì lấy giờ điện thoại nhận được bản tin
      timestamp: epochSeconds != null && epochSeconds >= _minValidEpochSeconds
          ? DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000)
          : DateTime.now(),
      soilType: SoilType.fromCode(json['soil_type'] as String?),
      adc: AdcInfo.fromJson(json['adc'] as Map<String, dynamic>?),
      pump: actuators?['pump'] as bool?,
      valve: actuators?['nutrient_valve'] as bool?,
    );
  }

  // Dữ liệu mẫu ban đầu khi vừa mở app
  factory SoilTelemetry.initial() {
    return SoilTelemetry(
      nitrogen: 45.0,
      phosphorus: 28.0,
      potassium: 85.0,
      ph: 6.2,
      ec: 620.0,
      moisture: 48.5,
      temperature: 26.5,
      timestamp: DateTime.now(),
    );
  }

  SoilTelemetry copyWith({
    double? nitrogen,
    double? phosphorus,
    double? potassium,
    double? ph,
    double? ec,
    double? moisture,
    double? temperature,
    DateTime? timestamp,
    SoilType? soilType,
    AdcInfo? adc,
    bool? pump,
    bool? valve,
  }) {
    return SoilTelemetry(
      nitrogen: nitrogen ?? this.nitrogen,
      phosphorus: phosphorus ?? this.phosphorus,
      potassium: potassium ?? this.potassium,
      ph: ph ?? this.ph,
      ec: ec ?? this.ec,
      moisture: moisture ?? this.moisture,
      temperature: temperature ?? this.temperature,
      timestamp: timestamp ?? this.timestamp,
      soilType: soilType ?? this.soilType,
      adc: adc ?? this.adc,
      pump: pump ?? this.pump,
      valve: valve ?? this.valve,
    );
  }
}
