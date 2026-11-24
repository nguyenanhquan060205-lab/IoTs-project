import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_telemetry.dart';
import 'package:soil_nutrient_app/services/agronomic_engine.dart';

void main() {
  group('AgronomicEngine Soil Nutrition Analysis Tests', () {
    test('Detects acidic soil (pH < 5.5) with high severity and lime recommendation', () {
      final telemetry = SoilTelemetry(
        nitrogen: 65.0,
        phosphorus: 45.0,
        potassium: 110.0,
        ph: 4.8, // Acidic
        ec: 850.0,
        moisture: 60.0,
        temperature: 27.0,
        timestamp: DateTime.now(),
      );

      final diag = AgronomicEngine.evaluate(telemetry: telemetry);

      expect(diag.issues.any((i) => i.title.contains('chua phèn')), isTrue);
      expect(diag.fertilizerRecommendations.any((r) => r.contains('Vôi')), isTrue);
      expect(diag.issues.firstWhere((i) => i.title.contains('chua phèn')).severity, AlertSeverity.danger);
    });

    test('Detects alkaline soil (pH > 7.5) with warning severity', () {
      final telemetry = SoilTelemetry(
        nitrogen: 65.0,
        phosphorus: 45.0,
        potassium: 110.0,
        ph: 7.8, // Alkaline
        ec: 850.0,
        moisture: 60.0,
        temperature: 27.0,
        timestamp: DateTime.now(),
      );

      final diag = AgronomicEngine.evaluate(telemetry: telemetry);

      expect(diag.issues.any((i) => i.title.contains('kiềm')), isTrue);
    });

    test('Detects nutrient toxicity / soil salinity (EC > 2000) with danger alert', () {
      final telemetry = SoilTelemetry(
        nitrogen: 120.0,
        phosphorus: 95.0,
        potassium: 220.0,
        ph: 6.5,
        ec: 2300.0, // High salinity / over-fertilization
        moisture: 60.0,
        temperature: 27.0,
        timestamp: DateTime.now(),
      );

      final diag = AgronomicEngine.evaluate(telemetry: telemetry);

      expect(diag.issues.any((i) => i.title.contains('Đất quá mặn') || i.title.contains('phân bón')), isTrue);
      final issue = diag.issues.firstWhere((i) => i.title.contains('Đất quá mặn') || i.title.contains('phân bón'));
      expect(issue.severity, AlertSeverity.danger);
      expect(issue.recommendation, contains('TẠM NGỪNG BÓN PHÂN'));
    });

    test('Detects low moisture (drought) and suggests watering', () {
      final telemetry = SoilTelemetry(
        nitrogen: 65.0,
        phosphorus: 45.0,
        potassium: 110.0,
        ph: 6.4,
        ec: 850.0,
        moisture: 35.0, // Drought (< 50%)
        temperature: 28.0,
        timestamp: DateTime.now(),
      );

      final diag = AgronomicEngine.evaluate(telemetry: telemetry);

      expect(diag.issues.any((i) => i.title.contains('Đất khô hạn')), isTrue);
      expect(diag.issues.firstWhere((i) => i.title.contains('Đất khô hạn')).recommendation, contains('Tưới thêm nước'));
    });

    test('Detects waterlogged soil when moisture is too high (> 80%)', () {
      final telemetry = SoilTelemetry(
        nitrogen: 65.0,
        phosphorus: 45.0,
        potassium: 110.0,
        ph: 6.4,
        ec: 850.0,
        moisture: 88.0, // Waterlogged
        temperature: 26.0,
        timestamp: DateTime.now(),
      );

      final diag = AgronomicEngine.evaluate(telemetry: telemetry);

      expect(diag.issues.any((i) => i.title.contains('Đất ngập úng')), isTrue);
      expect(diag.issues.firstWhere((i) => i.title.contains('Đất ngập úng')).recommendation, contains('Ngưng tưới'));
    });

    test('Gives high score and normal severity for balanced conditions', () {
      final telemetry = SoilTelemetry(
        nitrogen: 75.0,
        phosphorus: 50.0,
        potassium: 115.0,
        ph: 6.5,
        ec: 850.0,
        moisture: 60.0,
        temperature: 26.5,
        timestamp: DateTime.now(),
      );

      final diag = AgronomicEngine.evaluate(telemetry: telemetry);

      expect(diag.soilHealthScore, greaterThanOrEqualTo(80.0));
      expect(diag.overallSeverity, AlertSeverity.normal);
      expect(diag.generalStatus, contains('màu mỡ'));
    });
  });
}
