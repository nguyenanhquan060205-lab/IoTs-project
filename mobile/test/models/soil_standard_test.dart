import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_standard.dart';

void main() {
  group('SoilStandard and NutrientRange Tests', () {
    test('NutrientRange boundary checks work correctly', () {
      const range = NutrientRange(50.0, 100.0);

      expect(range.contains(50.0), isTrue);
      expect(range.contains(100.0), isTrue);
      expect(range.contains(75.0), isTrue);

      expect(range.isBelow(49.9), isTrue);
      expect(range.isBelow(50.0), isFalse);

      expect(range.isAbove(100.1), isTrue);
      expect(range.isAbove(100.0), isFalse);
    });

    test('SoilStandard contains standard agricultural soil baseline targets', () {
      expect(SoilStandard.nitrogen.min, 50.0);
      expect(SoilStandard.nitrogen.max, 100.0);
      expect(SoilStandard.phosphorus.min, 30.0);
      expect(SoilStandard.phosphorus.max, 70.0);
      expect(SoilStandard.potassium.min, 80.0);
      expect(SoilStandard.potassium.max, 150.0);
      expect(SoilStandard.ph.min, 6.0);
      expect(SoilStandard.ph.max, 7.2);
    });
  });
}
