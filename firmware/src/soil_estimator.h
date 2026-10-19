#ifndef SOIL_ESTIMATOR_H
#define SOIL_ESTIMATOR_H

#include <math.h>

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
 * Ánh xạ từ tín hiệu ADC cảm biến nước/độ ẩm sang 7 thông số dinh dưỡng đất.
 */
class SoilEstimator {
public:
    /**
     * Chuyển đổi giá trị ADC thô sang % Độ ẩm với hỗ trợ cả 2 loại cảm biến:
     * - Cảm biến điện trở nước thông thường (Dry ADC < Wet ADC)
     * - Cảm biến điện dung không ăn mòn v1.2 (Dry ADC > Wet ADC)
     */
    static float calculateMoisture(int rawADC, int dryVal, int wetVal) {
        if (dryVal == wetVal) return 50.0f;
        float m = 0.0f;
        if (dryVal < wetVal) {
            // Cảm biến thông thường: ngoài không khí = 100-300, nhúng nước = 2500-3500
            m = (float)(rawADC - dryVal) * 100.0f / (float)(wetVal - dryVal);
        } else {
            // Cảm biến điện dung v1.2: ngoài không khí = 2800-3200, nhúng nước = 1200-1500
            m = (float)(dryVal - rawADC) * 100.0f / (float)(dryVal - wetVal);
        }
        if (m < 0.0f) m = 0.0f;
        if (m > 100.0f) m = 100.0f;
        return m;
    }

    /**
     * Ước lượng 7 chỉ số dinh dưỡng từ độ ẩm đất (%)
     */
    static SoilNutrientData estimate(float moisture, float noiseRandom = 0.0f) {
        SoilNutrientData data;
        data.moisture = moisture;

        // 1. EC (µS/cm): Nồng độ muối khoáng hòa tan trong dung dịch ẩm của đất
        data.ec = (moisture * 13.5f) + noiseRandom;
        if (data.ec < 150.0f) data.ec = 150.0f;
        if (data.ec > 2200.0f) data.ec = 2200.0f;

        // 2. Đạm (N): Tỷ lệ theo độ phì EC
        data.nitrogen = (data.ec * 0.085f) + (noiseRandom * 0.08f);
        if (data.nitrogen < 10.0f) data.nitrogen = 10.0f;

        // 3. Lân (P)
        data.phosphorus = (data.ec * 0.042f) + (noiseRandom * 0.04f);
        if (data.phosphorus < 5.0f) data.phosphorus = 5.0f;

        // 4. Kali (K)
        data.potassium = (data.ec * 0.115f) + (noiseRandom * 0.09f);
        if (data.potassium < 15.0f) data.potassium = 15.0f;

        // 5. pH: Cân bằng quanh ngưỡng 6.2 - 6.6
        data.ph = 6.5f - ((moisture - 50.0f) * 0.012f) + (noiseRandom * 0.005f);
        if (data.ph < 4.5f) data.ph = 4.5f;
        if (data.ph > 8.5f) data.ph = 8.5f;

        return data;
    }
};

#endif // SOIL_ESTIMATOR_H
