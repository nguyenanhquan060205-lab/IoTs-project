import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_telemetry.dart';
import 'package:soil_nutrient_app/models/soil_type.dart';

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
      expect(telemetry.temperature, isNull); // The station has no temperature sensor
      expect(telemetry.timestamp, isNotNull);
      expect(telemetry.soilType, isNull);
      expect(telemetry.adc, isNull);
    });

    test('SoilTelemetry.fromJson falls back to receive time when the station sends uptime instead of Unix time', () {
      final before = DateTime.now();
      final telemetry = SoilTelemetry.fromJson({"timestamp": 4821, "telemetry": {"moisture": 50.0}});

      expect(telemetry.timestamp.isBefore(before), isFalse);
    });

    test('SoilTelemetry.fromJson reads real time and the ADC calibration block', () {
      final json = {
        "timestamp": 1764000000,
        "telemetry": {"nitrogen": 64.0, "moisture": 45.6},
        "adc": {"raw": 1850, "noise": 12.3, "dry": 3950, "wet": 1320}
      };
      final telemetry = SoilTelemetry.fromJson(json);

      expect(telemetry.timestamp.millisecondsSinceEpoch, 1764000000 * 1000);
      expect(telemetry.adc!.raw, 1850);
      expect(telemetry.adc!.noise, 12.3);
      expect(telemetry.adc!.dry, 3950);
      expect(telemetry.adc!.wet, 1320);
    });

    test('SoilTelemetry.fromJson reads the soil type reported by the station', () {
      final json = {
        "device_id": "esp32_soil_station_01",
        "timestamp": 1729150000,
        "soil_type": "barren",
        "telemetry": {"nitrogen": 20.4, "moisture": 60.0}
      };

      expect(SoilTelemetry.fromJson(json).soilType, SoilType.barren);
    });

    test('SoilTelemetry.fromJson ignores an unknown soil type code', () {
      final json = {"soil_type": "clay", "telemetry": {"nitrogen": 50.0}};

      expect(SoilTelemetry.fromJson(json).soilType, isNull);
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
    });

    test('SoilTelemetry.copyWith updates specified fields only', () {
      final initial = SoilTelemetry.initial();
      final updated = initial.copyWith(
        temperature: 30.0,
        moisture: 70.0,
      );

      expect(updated.temperature, 30.0);
      expect(updated.moisture, 70.0);
      expect(updated.nitrogen, initial.nitrogen);
      expect(updated.ph, initial.ph);
    });
  });
}
