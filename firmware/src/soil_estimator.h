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
    const char* code;     // Mã loại đất trong bản tin MQTT (khớp với Mobile App)
    const char* label;    // Nhãn không dấu hiển thị trên OLED
    float ecPerMoisture;  // Mỗi 1% độ ẩm làm EC tăng thêm bao nhiêu µS/cm
    float phBase;         // pH của mẫu đất khi độ ẩm 50%
    float nitrogen;       // Hàm lượng Đạm điển hình của loại đất (mg/kg)
    float phosphorus;     // Hàm lượng Lân điển hình (mg/kg)
    float potassium;      // Hàm lượng Kali điển hình (mg/kg)
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
 */
class SoilEstimator {
public:
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
     * Hệ số theo loại đất: đất đóng bao nhiều phân hữu cơ nên giàu N-P-K và EC tăng nhanh theo độ ẩm,
     * đất bạc màu ít ion khoáng hòa tan nên nghèo N-P-K, EC tăng chậm và hơi chua.
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

        // 2-4. N, P, K (mg/kg đất): Là lượng dinh dưỡng có sẵn trong mẫu đất,
        // tưới thêm nước không làm đất giàu dinh dưỡng hơn nên không phụ thuộc độ ẩm
        data.nitrogen = soil.nitrogen + (noiseRandom * 0.08f);
        if (data.nitrogen < 10.0f) data.nitrogen = 10.0f;

        data.phosphorus = soil.phosphorus + (noiseRandom * 0.04f);
        if (data.phosphorus < 5.0f) data.phosphorus = 5.0f;

        data.potassium = soil.potassium + (noiseRandom * 0.09f);
        if (data.potassium < 15.0f) data.potassium = 15.0f;

        // 5. pH: Dao động quanh pH gốc của loại đất, hơi chua dần khi đất ẩm lên
        data.ph = soil.phBase - ((moisture - 50.0f) * 0.012f) + (noiseRandom * 0.005f);
        if (data.ph < 4.5f) data.ph = 4.5f;
        if (data.ph > 8.5f) data.ph = 8.5f;

        return data;
    }
};

#endif // SOIL_ESTIMATOR_H
