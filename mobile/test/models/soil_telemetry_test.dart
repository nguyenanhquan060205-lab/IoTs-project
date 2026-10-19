import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_telemetry.dart';

void main() {
  group('SoilTelemetry Model Tests', () {
    test('SoilTelemetry.fromJson parses full standard telemetry JSON correctly', () {
      final json = {
        "device_id": "esp32_soil_station_01",
        "timestamp": 1729150000,
        "telemetry": {
          "nitrogen": 75.5,
          "phosphorus": 45.2,
          "potassium": 110.8,
          "ph": 6.5,
          "ec": 850.0,
          "moisture": 62.3,
          "temperature": 28.1
        },
        "actuators": {
          "pump": true,
          "nutrient_valve": false
        }
      };

      final telemetry = SoilTelemetry.fromJson(json);

      expect(telemetry.nitrogen, 75.5);
      expect(telemetry.phosphorus, 45.2);
      expect(telemetry.potassium, 110.8);
      expect(telemetry.ph, 6.5);
      expect(telemetry.ec, 850.0);
      expect(telemetry.moisture, 62.3);
      expect(telemetry.temperature, 28.1);
      expect(telemetry.pumpActive, true);
      expect(telemetry.valveActive, false);
      expect(telemetry.timestamp.millisecondsSinceEpoch, 1729150000 * 1000);
    });

    test('SoilTelemetry.fromJson handles missing or null fields gracefully', () {
      final json = <String, dynamic>{};
      final telemetry = SoilTelemetry.fromJson(json);

      expect(telemetry.nitrogen, 0.0);
      expect(telemetry.phosphorus, 0.0);
      expect(telemetry.potassium, 0.0);
      expect(telemetry.ph, 7.0); // default neutral pH
      expect(telemetry.ec, 0.0);
      expect(telemetry.moisture, 0.0);
      expect(telemetry.temperature, 0.0);
      expect(telemetry.pumpActive, false);
      expect(telemetry.valveActive, false);
      expect(telemetry.timestamp, isNotNull);
    });

    test('SoilTelemetry.initial provides reasonable default baseline values', () {
      final initial = SoilTelemetry.initial();

      expect(initial.nitrogen, 45.0);
      expect(initial.phosphorus, 28.0);
      expect(initial.potassium, 85.0);
      expect(initial.ph, 6.2);
      expect(initial.ec, 620.0);
      expect(initial.moisture, 48.5);
      expect(initial.temperature, 26.5);
      expect(initial.pumpActive, false);
      expect(initial.valveActive, false);
    });

    test('SoilTelemetry.copyWith updates specified fields only', () {
      final initial = SoilTelemetry.initial();
      final updated = initial.copyWith(
        pumpActive: true,
        moisture: 70.0,
      );

      expect(updated.pumpActive, true);
      expect(updated.moisture, 70.0);
      expect(updated.nitrogen, initial.nitrogen);
      expect(updated.ph, initial.ph);
    });
  });
}
