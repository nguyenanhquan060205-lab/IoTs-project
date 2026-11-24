import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_standard.dart';
import 'package:soil_nutrient_app/models/soil_telemetry.dart';
import 'package:soil_nutrient_app/services/agronomic_engine.dart';
import 'package:soil_nutrient_app/services/soil_status.dart';

void expectStatus(SoilStatus status, String label, StatusLevel level) {
  expect(status.label, label);
  expect(status.level, level);
}

void main() {
  group('SoilStatus thresholds at their edges', () {
    test('Nutrients follow the standard range: below is short, above is excess', () {
      expectStatus(SoilStatus.nutrient(49.9, SoilStandard.nitrogen), 'Thiếu', StatusLevel.warn);
      expectStatus(SoilStatus.nutrient(50, SoilStandard.nitrogen), 'Đủ', StatusLevel.ok);
      expectStatus(SoilStatus.nutrient(100, SoilStandard.nitrogen), 'Đủ', StatusLevel.ok);
      expectStatus(SoilStatus.nutrient(100.1, SoilStandard.nitrogen), 'Dư', StatusLevel.danger);
      expectStatus(SoilStatus.nutrient(29, SoilStandard.phosphorus), 'Thiếu', StatusLevel.warn);
      expectStatus(SoilStatus.nutrient(151, SoilStandard.potassium), 'Dư', StatusLevel.danger);
    });

    test('Moisture: 50-70% is fine, red below 35% and above 80% like the station LEDs', () {
      expectStatus(SoilStatus.moisture(34.9), 'Khô', StatusLevel.danger);
      expectStatus(SoilStatus.moisture(35), 'Khô', StatusLevel.warn);
      expectStatus(SoilStatus.moisture(49.9), 'Khô', StatusLevel.warn);
      expectStatus(SoilStatus.moisture(50), 'Vừa', StatusLevel.ok);
      expectStatus(SoilStatus.moisture(70), 'Vừa', StatusLevel.ok);
      expectStatus(SoilStatus.moisture(70.1), 'Ướt', StatusLevel.warn);
      expectStatus(SoilStatus.moisture(80), 'Ướt', StatusLevel.warn);
      expectStatus(SoilStatus.moisture(80.1), 'Ướt', StatusLevel.danger);
    });

    test('pH: 6.0-7.2 is good, below 5.5 is the acid-sulfate alarm', () {
      expectStatus(SoilStatus.ph(5.4), 'Chua', StatusLevel.danger);
      expectStatus(SoilStatus.ph(5.5), 'Chua', StatusLevel.warn);
      expectStatus(SoilStatus.ph(5.9), 'Chua', StatusLevel.warn);
      expectStatus(SoilStatus.ph(6.0), 'Tốt', StatusLevel.ok);
      expectStatus(SoilStatus.ph(7.2), 'Tốt', StatusLevel.ok);
      expectStatus(SoilStatus.ph(7.3), 'Kiềm', StatusLevel.warn);
    });

    test('EC: 500-1500 is good, below 300 is depleted, above 2000 is salty', () {
      expectStatus(SoilStatus.ec(299), 'Nghèo', StatusLevel.danger);
      expectStatus(SoilStatus.ec(300), 'Nghèo', StatusLevel.warn);
      expectStatus(SoilStatus.ec(499), 'Nghèo', StatusLevel.warn);
      expectStatus(SoilStatus.ec(500), 'Tốt', StatusLevel.ok);
      expectStatus(SoilStatus.ec(1500), 'Tốt', StatusLevel.ok);
      expectStatus(SoilStatus.ec(1501), 'Mặn', StatusLevel.warn);
      expectStatus(SoilStatus.ec(2000), 'Mặn', StatusLevel.warn);
      expectStatus(SoilStatus.ec(2001), 'Mặn', StatusLevel.danger);
    });

    test('Every red status on screen comes with an item in the to-do list', () {
      SoilTelemetry reading({double ph = 6.4, double ec = 800, double moisture = 60}) => SoilTelemetry(
            nitrogen: 65, phosphorus: 33, potassium: 90, ph: ph, ec: ec, moisture: moisture, timestamp: DateTime.now());

      for (final t in [reading(ph: 5.4), reading(ec: 250), reading(ec: 2100), reading(moisture: 30), reading(moisture: 85)]) {
        final red = [SoilStatus.ph(t.ph), SoilStatus.ec(t.ec), SoilStatus.moisture(t.moisture)]
            .where((s) => s.level == StatusLevel.danger);
        expect(red, isNotEmpty);
        expect(AgronomicEngine.evaluate(telemetry: t).issues, isNotEmpty,
            reason: 'pH ${t.ph}, EC ${t.ec}, moisture ${t.moisture}');
      }
    });
  });
}
