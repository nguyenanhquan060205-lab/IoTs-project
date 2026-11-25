#ifndef ADC_FILTER_H
#define ADC_FILTER_H

#include <math.h>

/**
 * Kết quả lọc một loạt mẫu ADC
 */
struct AdcReading {
    int value;    // Giá trị ADC sau lọc
    float noise;  // Độ lệch chuẩn của các mẫu thô (đơn vị ADC) - cho biết mức nhiễu thực tế
};

/**
 * Bộ lọc trung bình cắt tỉa (Trimmed Mean): sắp xếp các mẫu, bỏ `trim` mẫu thấp nhất
 * và `trim` mẫu cao nhất rồi lấy trung bình phần còn lại. Khác trung bình thường,
 * vài mẫu gai nhiễu (chạm dây, nhiễu WiFi) bị loại bỏ hẳn thay vì kéo lệch kết quả.
 */
class AdcFilter {
public:
    // samples bị sắp xếp lại tại chỗ
    static AdcReading filter(int* samples, int count, int trim) {
        AdcReading result = {0, 0.0f};
        if (count <= 0) return result;
        if (trim < 0 || 2 * trim >= count) trim = 0;

        // Độ lệch chuẩn trên toàn bộ mẫu thô
        double sum = 0.0;
        for (int i = 0; i < count; i++) sum += samples[i];
        double mean = sum / count;
        double variance = 0.0;
        for (int i = 0; i < count; i++) variance += (samples[i] - mean) * (samples[i] - mean);
        result.noise = (float)sqrt(variance / count);

        // Sắp xếp chèn: chỉ khoảng 21 mẫu nên đủ nhanh và không cần bộ nhớ phụ
        for (int i = 1; i < count; i++) {
            int key = samples[i];
            int j = i - 1;
            while (j >= 0 && samples[j] > key) {
                samples[j + 1] = samples[j];
                j--;
            }
            samples[j + 1] = key;
        }

        long kept = 0;
        for (int i = trim; i < count - trim; i++) kept += samples[i];
        result.value = (int)lround((double)kept / (count - 2 * trim));
        return result;
    }
};

#endif // ADC_FILTER_H
