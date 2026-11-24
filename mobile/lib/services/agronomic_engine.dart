import '../models/soil_telemetry.dart';

enum AlertSeverity { normal, warning, danger }

class DiagnosticItem {
  final String title;
  final String message;
  final AlertSeverity severity;
  final String recommendation;

  DiagnosticItem({
    required this.title,
    required this.message,
    required this.severity,
    required this.recommendation,
  });
}

class AgronomicDiagnosis {
  final double soilHealthScore; // 0 - 100%
  final String generalStatus;
  final AlertSeverity overallSeverity;
  final List<DiagnosticItem> issues;
  final List<String> fertilizerRecommendations;

  AgronomicDiagnosis({
    required this.soilHealthScore,
    required this.generalStatus,
    required this.overallSeverity,
    required this.issues,
    required this.fertilizerRecommendations,
  });
}

class AgronomicEngine {
  // Ngưỡng dinh dưỡng đất chuẩn nông nghiệp
  static const double targetNMin = 50.0;
  static const double targetNMax = 100.0;
  static const double targetPMin = 30.0;
  static const double targetPMax = 70.0;
  static const double targetKMin = 80.0;
  static const double targetKMax = 150.0;
  static const double targetPhMin = 6.0;
  static const double targetPhMax = 7.2;
  static const double targetEcMin = 500.0;
  static const double targetEcMax = 1500.0;
  static const double targetMoistMin = 50.0;
  static const double targetMoistMax = 70.0;

  static AgronomicDiagnosis evaluate({
    required SoilTelemetry telemetry,
  }) {
    final List<DiagnosticItem> issues = [];
    final List<String> fertilizers = [];
    int penaltyPoints = 0;

    // 1. Phân tích độ pH đất
    if (telemetry.ph < 5.5) {
      penaltyPoints += 25;
      issues.add(DiagnosticItem(
        title: 'Đất chua phèn (pH ${telemetry.ph.toStringAsFixed(1)})',
        message: 'Độ chua cao làm cố định Lân (P), ức chế vi sinh vật có ích và dễ giải phóng ion Nhôm/Sắt gây hại.',
        severity: AlertSeverity.danger,
        recommendation: 'Bón vôi nông nghiệp (CaCO3) hoặc Dolomite (15-20kg/100m²), xới nhẹ đất và tưới ẩm.',
      ));
      fertilizers.add('Vôi bột nông nghiệp hoặc Dolomite để hạ phèn cân bằng pH');
    } else if (telemetry.ph > 7.5) {
      penaltyPoints += 15;
      issues.add(DiagnosticItem(
        title: 'Đất có tính kiềm (pH ${telemetry.ph.toStringAsFixed(1)})',
        message: 'pH kiềm làm kết tủa các vi lượng thiết yếu như Sắt (Fe), Kẽm (Zn), Mangan (Mn).',
        severity: AlertSeverity.warning,
        recommendation: 'Bổ sung phân hữu cơ hoai mục, lưu huỳnh nông nghiệp hoặc acid humic để cân bằng pH về trung tính.',
      ));
    }

    // 2. Phân tích độ dẫn điện EC (Độ phì / Độ mặn của dung dịch đất)
    if (telemetry.ec < 300) {
      penaltyPoints += 25;
      issues.add(DiagnosticItem(
        title: 'Đất nghèo kiệt dinh dưỡng (EC ${telemetry.ec.toInt()} µS/cm)',
        message: 'Nồng độ ion khoáng hòa tan quá thấp, đất đang cạn kiệt nguồn dinh dưỡng dự trữ.',
        severity: AlertSeverity.warning,
        recommendation: 'Bón lót phân chuồng ủ hoai, phân trùn quế hoặc phân vi sinh để tái tạo độ phì nhiêu cho đất.',
      ));
      fertilizers.add('Phân hữu cơ vi sinh hoặc phân chuồng hoai mục');
    } else if (telemetry.ec > 2000) {
      penaltyPoints += 35;
      issues.add(DiagnosticItem(
        title: 'CẢNH BÁO: Đất quá mặn / Dư thừa phân bón (EC ${telemetry.ec.toInt()} µS/cm)',
        message: 'Nồng độ muối khoáng quá cao, có nguy cơ gây cháy rễ và ngộ độc hóa học cho đất.',
        severity: AlertSeverity.danger,
        recommendation: 'TẠM NGỪNG BÓN PHÂN. Tưới xả nhiều nước ngọt sạch để rửa bớt lượng muối khoáng dư thừa.',
      ));
    }

    // 3. Phân tích Đạm (Nitơ - N)
    if (telemetry.nitrogen < targetNMin) {
      penaltyPoints += 15;
      final diff = (targetNMin - telemetry.nitrogen).toInt();
      issues.add(DiagnosticItem(
        title: 'Hàm lượng Đạm thấp (N thiếu ~$diff mg/kg)',
        message: 'Đất thiếu nguồn đạm khoáng hóa hữu dụng, làm suy giảm hoạt tính vi sinh và độ phì nhiêu của đất.',
        severity: AlertSeverity.warning,
        recommendation: 'Bổ sung phân đạm hữu cơ, Urê hoặc phân hữu cơ vi sinh để cải tạo đất.',
      ));
      fertilizers.add('Phân đạm (Urê hoặc NPK giàu Nitơ)');
    } else if (telemetry.nitrogen > 150) {
      penaltyPoints += 10;
      issues.add(DiagnosticItem(
        title: 'Hàm lượng Đạm cao (N dư thừa)',
        message: 'Dư thừa đạm làm đất dễ tích tụ nitrat, chua hóa môi trường đất và mất cân bằng khoáng chất.',
        severity: AlertSeverity.warning,
        recommendation: 'Giảm lượng phân bón chứa đạm, tăng cường bón lân và kali để cân đối tỷ lệ N:P:K trong đất.',
      ));
    }

    // 4. Phân tích Lân (Photpho - P)
    if (telemetry.phosphorus < targetPMin) {
      penaltyPoints += 15;
      final diff = (targetPMin - telemetry.phosphorus).toInt();
      issues.add(DiagnosticItem(
        title: 'Hàm lượng Lân thấp (P thiếu ~$diff mg/kg)',
        message: 'Đất nghèo lân dễ tiêu, làm giảm khả năng cố định dinh dưỡng và trao đổi ion của keo đất.',
        severity: AlertSeverity.warning,
        recommendation: 'Bón bổ sung Super Lân hoặc phân lân nung chảy để nâng cao hàm lượng lân dễ tiêu trong đất.',
      ));
      fertilizers.add('Super Lân hoặc Phân Lân nung chảy');
    }

    // 5. Phân tích Kali (Potassium - K)
    if (telemetry.potassium < targetKMin) {
      penaltyPoints += 15;
      final diff = (targetKMin - telemetry.potassium).toInt();
      issues.add(DiagnosticItem(
        title: 'Hàm lượng Kali thấp (K thiếu ~$diff mg/kg)',
        message: 'Thiếu kali làm giảm dung tích hấp thu cation (CEC), giảm khả năng giữ nước và độ đệm của đất.',
        severity: AlertSeverity.warning,
        recommendation: 'Bón bổ sung Kali Clorua hoặc Kali Sunfat (K2SO4) để tăng tính đệm cho đất.',
      ));
      fertilizers.add('Kali Sunfat (K2SO4) hoặc tro bếp trấu');
    }

    // 6. Phân tích Độ ẩm đất (%)
    if (telemetry.moisture < targetMoistMin) {
      penaltyPoints += 15;
      issues.add(DiagnosticItem(
        title: 'Đất khô hạn (Độ ẩm ${telemetry.moisture.toStringAsFixed(1)}%)',
        message: 'Đất thiếu ẩm làm hạn chế quá trình hòa tan và hấp thu dinh dưỡng khoáng chất.',
        severity: AlertSeverity.warning,
        recommendation: 'Tưới thêm nước cho đất để duy trì độ ẩm tối ưu (50% - 70%).',
      ));
    } else if (telemetry.moisture > targetMoistMax + 10) {
      penaltyPoints += 15;
      issues.add(DiagnosticItem(
        title: 'Đất ngập úng (Độ ẩm ${telemetry.moisture.toStringAsFixed(1)}%)',
        message: 'Đất dư thừa nước kéo dài làm yếm khí, rễ thiếu oxy và sinh khí độc H2S/CH4.',
        severity: AlertSeverity.warning,
        recommendation: 'Ngưng tưới nước ngay, khơi thông rãnh thoát nước để đất được thông thoáng khí.',
      ));
    }

    // Điểm sức khỏe đất
    final healthScore = (100 - penaltyPoints).clamp(0, 100).toDouble();

    AlertSeverity overallSeverity;
    String generalStatus;

    if (healthScore >= 80) {
      overallSeverity = AlertSeverity.normal;
      generalStatus = 'Đất màu mỡ, hàm lượng dinh dưỡng rất cân đối';
    } else if (healthScore >= 50) {
      overallSeverity = AlertSeverity.warning;
      generalStatus = 'Đất ở mức trung bình, cần bổ sung dinh dưỡng';
    } else {
      overallSeverity = AlertSeverity.danger;
      generalStatus = 'Đất mất cân bằng hoặc suy thoái nghiêm trọng';
    }

    if (fertilizers.isEmpty && healthScore >= 80) {
      fertilizers.add('Đất đang trong trạng thái màu mỡ lý tưởng, chỉ cần duy trì tưới ẩm định kỳ.');
    }

    return AgronomicDiagnosis(
      soilHealthScore: healthScore,
      generalStatus: generalStatus,
      overallSeverity: overallSeverity,
      issues: issues,
      fertilizerRecommendations: fertilizers,
    );
  }
}
