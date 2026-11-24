/// 3 loại mẫu đất dùng để đo thí nghiệm, xếp từ giàu đến nghèo dinh dưỡng.
/// [code] phải khớp với mã loại đất trong firmware ESP32 (SoilEstimator::profile).
enum SoilType {
  potting(
    code: 'potting',
    label: 'Đất dinh dưỡng đóng bao',
    shortLabel: 'Đóng bao',
    place: 'Mua ở cửa hàng cây cảnh',
    source: 'Mua ở cửa hàng cây cảnh (Tribat, Sfarm, Namix...)',
    trait: 'Phối trộn sẵn phân hữu cơ, tro trấu, xơ dừa',
    expectedLevel: 'Cao',
  ),
  garden(
    code: 'garden',
    label: 'Đất vườn (đất thịt)',
    shortLabel: 'Đất vườn',
    place: 'Chậu cây, bồn hoa, vườn nhà',
    source: 'Lấy từ chậu cây, bồn hoa, vườn nhà',
    trait: 'Màu nâu đậm, chứa mùn',
    expectedLevel: 'Trung bình',
  ),
  barren(
    code: 'barren',
    label: 'Đất bạc màu / bãi đất trống',
    shortLabel: 'Bạc màu',
    place: 'Đất trống, ven đường',
    source: 'Lấy ở khu đất trống, ven đường, công trình chưa xây dựng',
    trait: 'Màu nhạt, ít rễ cây, ít chất hữu cơ',
    expectedLevel: 'Thấp',
  );

  const SoilType({
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.place,
    required this.source,
    required this.trait,
    required this.expectedLevel,
  });

  final String code;
  final String label;
  final String shortLabel;
  final String place; // Nơi lấy mẫu, bản ngắn gọn cho thẻ chọn
  final String source; // Nơi lấy mẫu đất
  final String trait; // Đặc điểm nhận biết
  final String expectedLevel; // Dự đoán mức dinh dưỡng

  /// Trả về null nếu mã rỗng hoặc không thuộc 3 loại đất trên
  static SoilType? fromCode(String? code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}
