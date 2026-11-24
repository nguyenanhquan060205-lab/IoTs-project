import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_type.dart';

void main() {
  group('SoilType Tests', () {
    test('Codes match the firmware soil profiles', () {
      expect(SoilType.values.map((t) => t.code), ['potting', 'garden', 'barren']);
    });

    test('Expected nutrient levels go from high to low', () {
      expect(SoilType.values.map((t) => t.expectedLevel), ['Cao', 'Trung bình', 'Thấp']);
    });

    test('fromCode maps known codes and rejects others', () {
      expect(SoilType.fromCode('potting'), SoilType.potting);
      expect(SoilType.fromCode('garden'), SoilType.garden);
      expect(SoilType.fromCode('barren'), SoilType.barren);
      expect(SoilType.fromCode('clay'), isNull);
      expect(SoilType.fromCode(''), isNull);
      expect(SoilType.fromCode(null), isNull);
    });
  });
}
