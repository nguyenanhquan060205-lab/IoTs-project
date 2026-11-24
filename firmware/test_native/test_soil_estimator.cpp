#include <iostream>
#include <cassert>
#include <cmath>
#include <iomanip>
#include "../src/soil_estimator.h"
#include "../src/adc_filter.h"

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

    std::cout << std::fixed
              << "  " << std::setw(6) << "M(%)" << std::setw(12) << "EC(uS/cm)"
              << std::setw(10) << "N(mg/kg)" << std::setw(10) << "P(mg/kg)"
              << std::setw(10) << "K(mg/kg)" << std::setw(7) << "pH" << "  Check\n";

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

        // Only rows that passed every assert above get printed
        std::cout << "  " << std::setprecision(1) << std::setw(6) << data.moisture
                  << std::setprecision(2) << std::setw(12) << data.ec
                  << std::setw(10) << data.nitrogen << std::setw(10) << data.phosphorus
                  << std::setw(10) << data.potassium << std::setw(7) << data.ph << "  OK\n";
    }
    std::cout << "  -> Passed agronomic bounds tests!\n";
}

void testSoilTypeProfiles() {
    std::cout << "[TEST] Running Soil Type Profile Test...\n";
    const SoilType types[] = {SoilType::POTTING, SoilType::GARDEN, SoilType::BARREN};
    float moistures[] = {0.0f, 15.0f, 40.0f, 55.0f, 75.0f, 95.0f, 100.0f};

    std::cout << std::fixed
              << "  " << std::setw(9) << "Soil" << std::setw(6) << "M(%)" << std::setw(12) << "EC(uS/cm)"
              << std::setw(10) << "N(mg/kg)" << std::setw(10) << "P(mg/kg)"
              << std::setw(10) << "K(mg/kg)" << std::setw(7) << "pH" << "\n";

    for (float m : moistures) {
        // Garden keeps the original coefficients, so the default call must not change
        SoilNutrientData byDefault = SoilEstimator::estimate(m, 0.0f);
        SoilNutrientData garden = SoilEstimator::estimate(m, 0.0f, SoilType::GARDEN);
        assert(byDefault.ec == garden.ec && byDefault.nitrogen == garden.nitrogen && byDefault.ph == garden.ph);

        for (SoilType type : types) {
            SoilNutrientData data = SoilEstimator::estimate(m, 0.0f, type);
            assert(data.ec >= 150.0f && data.ec <= 2200.0f);
            assert(data.nitrogen >= 10.0f && data.phosphorus >= 5.0f && data.potassium >= 15.0f);
            assert(data.ph >= 4.5f && data.ph <= 8.5f);

            if (m == 55.0f || m == 75.0f) {
                std::cout << "  " << std::setw(9) << SoilEstimator::profile(type).label
                          << std::setprecision(1) << std::setw(6) << data.moisture
                          << std::setprecision(2) << std::setw(12) << data.ec
                          << std::setw(10) << data.nitrogen << std::setw(10) << data.phosphorus
                          << std::setw(10) << data.potassium << std::setw(7) << data.ph << "\n";
            }
        }

        // Once the soil is moist enough to dissolve nutrients: potting > garden > barren
        if (m >= 40.0f) {
            SoilNutrientData potting = SoilEstimator::estimate(m, 0.0f, SoilType::POTTING);
            SoilNutrientData barren = SoilEstimator::estimate(m, 0.0f, SoilType::BARREN);
            assert(potting.ec > garden.ec && garden.ec > barren.ec);
            assert(potting.nitrogen > garden.nitrogen && garden.nitrogen > barren.nitrogen);
            assert(potting.phosphorus > garden.phosphorus && garden.phosphorus > barren.phosphorus);
            assert(potting.potassium > garden.potassium && garden.potassium > barren.potassium);
        }
    }

    // Barren soil at a normal moisture stays nutrient-poor (EC < 300, N/P/K below standard)
    SoilNutrientData barren = SoilEstimator::estimate(60.0f, 0.0f, SoilType::BARREN);
    assert(barren.ec < 300.0f && barren.nitrogen < 50.0f && barren.phosphorus < 30.0f && barren.potassium < 80.0f);

    std::cout << "  -> Passed soil type profile tests!\n";
}

void testParseSoilType() {
    std::cout << "[TEST] Running Soil Type Code Parsing Test...\n";
    SoilType type = SoilType::GARDEN;

    assert(SoilEstimator::parseSoilType("potting", type) && type == SoilType::POTTING);
    assert(SoilEstimator::parseSoilType("barren", type) && type == SoilType::BARREN);
    assert(SoilEstimator::parseSoilType("garden", type) && type == SoilType::GARDEN);

    // Invalid codes are rejected and leave the previous type untouched
    assert(!SoilEstimator::parseSoilType("clay", type) && type == SoilType::GARDEN);
    assert(!SoilEstimator::parseSoilType("", type) && type == SoilType::GARDEN);
    assert(!SoilEstimator::parseSoilType(nullptr, type) && type == SoilType::GARDEN);

    std::cout << "  -> Passed soil type parsing tests!\n";
}

void testWateringDoesNotRaiseNPK() {
    std::cout << "[TEST] Running Watering vs N-P-K Test...\n";
    const SoilType types[] = {SoilType::POTTING, SoilType::GARDEN, SoilType::BARREN};

    for (SoilType type : types) {
        SoilNutrientData dry = SoilEstimator::estimate(30.0f, 0.0f, type);
        SoilNutrientData wet = SoilEstimator::estimate(80.0f, 0.0f, type);

        // N, P, K are what the soil sample contains, adding water must not change them
        assert(dry.nitrogen == wet.nitrogen);
        assert(dry.phosphorus == wet.phosphorus);
        assert(dry.potassium == wet.potassium);

        // EC still rises with moisture because water dissolves the salts already in the soil
        assert(wet.ec > dry.ec);
    }
    std::cout << "  -> Passed watering vs N-P-K tests!\n";
}

void testTrimmedMeanFilter() {
    std::cout << "[TEST] Running ADC Trimmed Mean Filter Test...\n";

    // Steady signal around 1500 with 4 spikes (loose wire, relay switching)
    int samples[21] = {1500, 1502, 4095, 1498, 1501, 1499, 0, 1500, 1503, 1497,
                       1500, 4095, 1501, 1499, 1500, 1502, 1498, 0, 1500, 1501, 1499};
    long plainSum = 0;
    for (int v : samples) plainSum += v;
    float plainMean = plainSum / 21.0f;

    AdcReading reading = AdcFilter::filter(samples, 21, 5);
    std::cout << "  plain mean = " << std::setprecision(1) << plainMean
              << ", trimmed mean = " << reading.value << ", noise = " << reading.noise << "\n";
    assert(std::fabs(plainMean - 1500.0f) > 50.0f);  // Spikes drag the plain mean away
    assert(std::abs(reading.value - 1500) <= 1);     // Trimmed mean ignores them
    assert(reading.noise > 100.0f);                  // and the noise figure still reveals the spikes

    // A clean signal reports almost no noise
    int clean[21];
    for (int i = 0; i < 21; i++) clean[i] = 2000 + (i % 3) - 1;
    AdcReading quiet = AdcFilter::filter(clean, 21, 5);
    assert(quiet.value == 2000);
    assert(quiet.noise < 1.0f);

    // Too much trimming falls back to a plain mean instead of dividing by zero
    int few[3] = {10, 20, 30};
    assert(AdcFilter::filter(few, 3, 5).value == 20);
    std::cout << "  -> Passed trimmed mean filter tests!\n";
}

int main() {
    std::cout << "========================================\n";
    std::cout << " RUNNING C++ SOIL ESTIMATOR UNIT TESTS\n";
    std::cout << "========================================\n";

    testCalibrationStandardSensor();
    testCalibrationCapacitiveSensor();
    testAgronomicEstimationBounds();
    testSoilTypeProfiles();
    testParseSoilType();
    testWateringDoesNotRaiseNPK();
    testTrimmedMeanFilter();

    std::cout << "\n✅ ALL C++ ESTIMATOR UNIT TESTS PASSED!\n";
    return 0;
}
