#include <iostream>
#include <cassert>
#include <cmath>
#include "../src/soil_estimator.h"

void testCalibrationStandardSensor() {
    std::cout << "[TEST] Running Standard Resistive Sensor Calibration Test...\n";
    int dry = 200;
    int wet = 3000;

    // Below dry
    float mDry = SoilEstimator::calculateMoisture(100, dry, wet);
    assert(mDry == 0.0f);

    // Exact dry
    mDry = SoilEstimator::calculateMoisture(200, dry, wet);
    assert(mDry == 0.0f);

    // Midpoint
    float mMid = SoilEstimator::calculateMoisture(1600, dry, wet);
    assert(std::fabs(mMid - 50.0f) < 0.1f);

    // Exact wet
    float mWet = SoilEstimator::calculateMoisture(3000, dry, wet);
    assert(std::fabs(mWet - 100.0f) < 0.1f);

    // Above wet
    float mSuperWet = SoilEstimator::calculateMoisture(4000, dry, wet);
    assert(mSuperWet == 100.0f);
    std::cout << "  -> Passed standard calibration tests!\n";
}

void testCalibrationCapacitiveSensor() {
    std::cout << "[TEST] Running Capacitive Sensor (Inverted) Calibration Test...\n";
    // Capacitive v1.2: In air = 3000, in water = 1200
    int dry = 3000;
    int wet = 1200;

    // In air (dry)
    float mDry = SoilEstimator::calculateMoisture(3200, dry, wet);
    assert(mDry == 0.0f);

    mDry = SoilEstimator::calculateMoisture(3000, dry, wet);
    assert(mDry == 0.0f);

    // Midpoint
    float mMid = SoilEstimator::calculateMoisture(2100, dry, wet);
    assert(std::fabs(mMid - 50.0f) < 0.1f);

    // Submerged in water
    float mWet = SoilEstimator::calculateMoisture(1200, dry, wet);
    assert(std::fabs(mWet - 100.0f) < 0.1f);

    std::cout << "  -> Passed capacitive calibration tests!\n";
}

void testAgronomicEstimationBounds() {
    std::cout << "[TEST] Running Agronomic Estimation Bounds Test...\n";
    float moistures[] = {0.0f, 15.0f, 40.0f, 55.0f, 75.0f, 95.0f, 100.0f};

    for (float m : moistures) {
        SoilNutrientData data = SoilEstimator::estimate(m, 0.0f);

        // Moisture preserved
        assert(data.moisture == m);

        // EC bounds: [150, 2200]
        assert(data.ec >= 150.0f && data.ec <= 2200.0f);

        // Nutrients positive & physiologically sound
        assert(data.nitrogen >= 10.0f);
        assert(data.phosphorus >= 5.0f);
        assert(data.potassium >= 15.0f);

        // pH bounds: [4.5, 8.5]
        assert(data.ph >= 4.5f && data.ph <= 8.5f);
    }
    std::cout << "  -> Passed agronomic bounds tests!\n";
}

int main() {
    std::cout << "========================================\n";
    std::cout << " RUNNING C++ SOIL ESTIMATOR UNIT TESTS\n";
    std::cout << "========================================\n";

    testCalibrationStandardSensor();
    testCalibrationCapacitiveSensor();
    testAgronomicEstimationBounds();

    std::cout << "\n✅ ALL C++ ESTIMATOR UNIT TESTS PASSED!\n";
    return 0;
}
