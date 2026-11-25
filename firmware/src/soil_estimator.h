#ifndef SOIL_ESTIMATOR_H
#define SOIL_ESTIMATOR_H

#include <math.h>
#include <string.h>

/**
 * 3 loại mẫu đất thí nghiệm, xếp từ giàu đến nghèo dinh dưỡng
 */
enum class SoilType {
    POTTING = 0,  // Đất dinh dưỡng đóng bao (Tribat, Sfarm, Namix...) - dự đoán dinh dưỡng Cao
    GARDEN  = 1,  // Đất vườn (đất thịt, nâu đậm, chứa mùn)          - dự đoán Trung bình
    BARREN  = 2   // Đất bạc màu / bãi đất trống, ít chất hữu cơ     - dự đoán Thấp
};

/**
 * Hệ số nông học riêng của từng loại đất
 */
struct SoilProfile {
    const char* code;         // Mã loại đất trong bản tin MQTT (khớp với Mobile App)
    const char* label;        // Nhãn không dấu hiển thị trên OLED
    float ecPerMoisture;      // Mỗi 1% độ ẩm làm EC tăng thêm bao nhiêu µS/cm
    float phBase;             // pH của mẫu đất khi độ ẩm 50%
    // Mức N, P, K bình thường của loại đất (mg/kg). Không phải số đo: chỉ dùng để so sánh và thông báo
    // N, P, K tính được đang thấp, bình thường hay cao so với loại đất này
    float nitrogenNormal;
    float phosphorusNormal;
    float potassiumNormal;
};

/**
 * So sánh một chỉ số với mức bình thường của loại đất.
 * Không đặt tên LOW / HIGH vì Arduino đã định nghĩa 2 tên đó cho mức điện áp chân GPIO.
 */
enum class NutrientLevel {
    BELOW = 0,   // Thấp hơn mức bình thường quá 20%
    NORMAL = 1,  // Trong khoảng ±20% quanh mức bình thường
    ABOVE = 2    // Cao hơn mức bình thường quá 20%
};

struct NpkLevels {
    NutrientLevel nitrogen;
    NutrientLevel phosphorus;
    NutrientLevel potassium;
};

/**
 * Cấu trúc dữ liệu chứa 7 chỉ số dinh dưỡng đất
 */
struct SoilNutrientData {
    float moisture;    // % (0.0 - 100.0)
    float ec;          // µS/cm (150 - 2200)
    float nitrogen;    // mg/kg (N)
    float phosphorus;  // mg/kg (P)
    float potassium;   // mg/kg (K)
    float ph;          // pH (4.5 - 8.5)
};

/**
 * Bộ suy diễn nông học thực nghiệm (Low-cost Heuristic Agronomic Estimation)
 * Trạm chỉ có cảm biến độ ẩm: độ ẩm đo được + loại đất App chọn -> 6 chỉ số đất.
 * Chuỗi tính: ADC -> độ ẩm -> EC -> N, P, K. Mọi chỉ số trừ độ ẩm đều là số ước lượng.
 */
class SoilEstimator {
public:
    // N, P, K dễ tiêu (mg/kg) trên mỗi 1 µS/cm EC, dùng chung cho mọi loại đất.
    // Chọn sao cho ở độ ẩm lý tưởng 60% (giữa khoảng 50 - 70%) mỗi loại đất cho đúng mức bình thường của nó,
    // ví dụ đất vườn: EC = 60 x 13.5 = 810 -> N = 64.8, P = 32.4, K = 89.1 (mức bình thường 65 / 33 / 90)
    static constexpr float N_PER_EC = 0.08f;
    static constexpr float P_PER_EC = 0.04f;
    static constexpr float K_PER_EC = 0.11f;
    // Lệch quá 20% so với mức bình thường của loại đất thì báo thấp / cao
    static constexpr float NORMAL_TOLERANCE = 0.20f;

    /**
     * Chuyển đổi giá trị ADC thô sang % Độ ẩm với hỗ trợ cả 2 chiều tín hiệu:
     * - Đầu dò cho ADC tăng khi ướt (Dry ADC < Wet ADC)
     * - Đầu dò cho ADC giảm khi ướt, ví dụ module LM393/FC-28 hoặc điện dung v1.2 (Dry ADC > Wet ADC)
     */
    static float calculateMoisture(int rawADC, int dryVal, int wetVal) {
        if (dryVal == wetVal) return 50.0f;
        float m = 0.0f;
        if (dryVal < wetVal) {
            m = (float)(rawADC - dryVal) * 100.0f / (float)(wetVal - dryVal);
        } else {
            m = (float)(dryVal - rawADC) * 100.0f / (float)(dryVal - wetVal);
        }
        if (m < 0.0f) m = 0.0f;
        if (m > 100.0f) m = 100.0f;
        return m;
    }

    /**
     * Hệ số theo loại đất: đất đóng bao nhiều phân hữu cơ nên EC tăng nhanh theo độ ẩm và mức N-P-K bình thường cao,
     * đất bạc màu ít ion khoáng hòa tan nên EC tăng chậm, mức N-P-K bình thường thấp và hơi chua.
     */
    static SoilProfile profile(SoilType type) {
        switch (type) {
            case SoilType::POTTING: return {"potting", "DONG BAO", 20.0f, 6.2f, 95.0f, 50.0f, 135.0f};
            case SoilType::BARREN:  return {"barren",  "BAC MAU",   4.0f, 5.8f, 20.0f, 10.0f,  30.0f};
            case SoilType::GARDEN:
            default:                return {"garden",  "DAT VUON", 13.5f, 6.5f, 65.0f, 33.0f,  90.0f};
        }
    }

    /**
     * Đổi mã loại đất nhận từ App ("potting" / "garden" / "barren") sang SoilType.
     * Trả về false nếu mã rỗng hoặc không hợp lệ (giữ nguyên out).
     */
    static bool parseSoilType(const char* code, SoilType& out) {
        if (code == nullptr) return false;
        const SoilType all[] = {SoilType::POTTING, SoilType::GARDEN, SoilType::BARREN};
        for (SoilType type : all) {
            if (strcmp(code, profile(type).code) == 0) {
                out = type;
                return true;
            }
        }
        return false;
    }

    /**
     * Ước lượng 6 chỉ số đất từ độ ẩm (%) theo loại đất đang đo
     */
    static SoilNutrientData estimate(float moisture, float noiseRandom = 0.0f,
                                     SoilType type = SoilType::GARDEN) {
        const SoilProfile soil = profile(type);
        SoilNutrientData data;
        data.moisture = moisture;

        // 1. EC (µS/cm): Nước hòa tan muối khoáng nên EC của đất tăng theo độ ẩm
        data.ec = (moisture * soil.ecPerMoisture) + noiseRandom;
        if (data.ec < 150.0f) data.ec = 150.0f;
        if (data.ec > 2200.0f) data.ec = 2200.0f;

        // 2-4. N, P, K dễ tiêu (mg/kg đất): dinh dưỡng phải hòa tan vào nước trong đất thì cây mới hút được,
        // và chính lượng ion hòa tan đó làm EC tăng. Nên N, P, K tính từ EC, tức là đổi theo độ ẩm đo được
        data.nitrogen = data.ec * N_PER_EC;
        if (data.nitrogen < 10.0f) data.nitrogen = 10.0f;

        data.phosphorus = data.ec * P_PER_EC;
        if (data.phosphorus < 5.0f) data.phosphorus = 5.0f;

        data.potassium = data.ec * K_PER_EC;
        if (data.potassium < 15.0f) data.potassium = 15.0f;

        // 5. pH: Dao động quanh pH gốc của loại đất, hơi chua dần khi đất ẩm lên
        data.ph = soil.phBase - ((moisture - 50.0f) * 0.012f) + (noiseRandom * 0.005f);
        if (data.ph < 4.5f) data.ph = 4.5f;
        if (data.ph > 8.5f) data.ph = 8.5f;

        return data;
    }

    /**
     * Một chỉ số so với mức bình thường: thấp hơn 80% là BELOW, cao hơn 120% là ABOVE
     */
    static NutrientLevel compareToNormal(float value, float normal) {
        if (value < normal * (1.0f - NORMAL_TOLERANCE)) return NutrientLevel::BELOW;
        if (value > normal * (1.0f + NORMAL_TOLERANCE)) return NutrientLevel::ABOVE;
        return NutrientLevel::NORMAL;
    }

    /**
     * N, P, K tính được so với mức bình thường của loại đất đang đo
     */
    static NpkLevels compareNpk(const SoilNutrientData& data, SoilType type) {
        const SoilProfile soil = profile(type);
        return {compareToNormal(data.nitrogen, soil.nitrogenNormal),
                compareToNormal(data.phosphorus, soil.phosphorusNormal),
                compareToNormal(data.potassium, soil.potassiumNormal)};
    }

    /**
     * Gộp 3 chỉ số thành 1 để báo trên OLED và đèn: có chỉ số thấp thì báo thấp (thiếu dinh dưỡng quan trọng hơn),
     * không thì có chỉ số cao thì báo cao, còn lại là bình thường
     */
    static NutrientLevel overallLevel(const NpkLevels& levels) {
        const NutrientLevel all[] = {levels.nitrogen, levels.phosphorus, levels.potassium};
        for (NutrientLevel level : all) {
            if (level == NutrientLevel::BELOW) return NutrientLevel::BELOW;
        }
        for (NutrientLevel level : all) {
            if (level == NutrientLevel::ABOVE) return NutrientLevel::ABOVE;
        }
        return NutrientLevel::NORMAL;
    }

    // Mã gửi trong bản tin MQTT
    static const char* levelCode(NutrientLevel level) {
        switch (level) {
            case NutrientLevel::BELOW: return "low";
            case NutrientLevel::ABOVE: return "high";
            case NutrientLevel::NORMAL:
            default:                   return "normal";
        }
    }

    // Nhãn ngắn không dấu cho OLED (tối đa 21 ký tự mỗi dòng) và Serial
    static const char* levelLabel(NutrientLevel level) {
        switch (level) {
            case NutrientLevel::BELOW: return "THAP";
            case NutrientLevel::ABOVE: return "CAO";
            case NutrientLevel::NORMAL:
            default:                   return "OK";
        }
    }
};

#endif // SOIL_ESTIMATOR_H
