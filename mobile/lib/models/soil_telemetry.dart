class SoilTelemetry {
  final double nitrogen; // mg/kg
  final double phosphorus; // mg/kg
  final double potassium; // mg/kg
  final double ph;
  final double ec; // µS/cm
  final double moisture; // %
  final double temperature; // °C
  final DateTime timestamp;
  final bool pumpActive;
  final bool valveActive;

  SoilTelemetry({
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
    required this.ec,
    required this.moisture,
    required this.temperature,
    required this.timestamp,
    this.pumpActive = false,
    this.valveActive = false,
  });

  factory SoilTelemetry.fromJson(Map<String, dynamic> json) {
    final telemetry = json['telemetry'] as Map<String, dynamic>? ?? json;
    final actuators = json['actuators'] as Map<String, dynamic>? ?? {};

    return SoilTelemetry(
      nitrogen: (telemetry['nitrogen'] as num?)?.toDouble() ?? 0.0,
      phosphorus: (telemetry['phosphorus'] as num?)?.toDouble() ?? 0.0,
      potassium: (telemetry['potassium'] as num?)?.toDouble() ?? 0.0,
      ph: (telemetry['ph'] as num?)?.toDouble() ?? 7.0,
      ec: (telemetry['ec'] as num?)?.toDouble() ?? 0.0,
      moisture: (telemetry['moisture'] as num?)?.toDouble() ?? 0.0,
      temperature: (telemetry['temperature'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as int) * 1000)
          : DateTime.now(),
      pumpActive: actuators['pump'] as bool? ?? false,
      valveActive: actuators['nutrient_valve'] as bool? ?? false,
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
      pumpActive: false,
      valveActive: false,
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
    bool? pumpActive,
    bool? valveActive,
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
      pumpActive: pumpActive ?? this.pumpActive,
      valveActive: valveActive ?? this.valveActive,
    );
  }
}
