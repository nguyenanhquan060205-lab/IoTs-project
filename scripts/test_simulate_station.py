#!/usr/bin/env python3
"""
Test suite for Soil Station Simulation (scripts/simulate_station.py)
Tests agronomic estimation formulas, JSON schema compatibility, and command handling.
"""

import unittest
import json
import time
import os
import sys

# Ensure scripts directory is in sys.path
sys.path.insert(0, os.path.dirname(__file__))

import simulate_station

class TestSimulateStation(unittest.TestCase):
    def test_calculate_nutrients_ranges(self):
        """Test agronomic formulas across the entire moisture range (0% to 100%)."""
        test_moistures = [0.0, 20.0, 45.0, 55.0, 75.0, 95.0, 100.0]

        for m in test_moistures:
            n, p, k, ph, ec = simulate_station.calculate_nutrients_from_moisture(m)

            # Check physiological agronomic constraints
            self.assertGreaterEqual(ec, 150.0, f"EC too low for moisture {m}")
            self.assertLessEqual(ec, 2200.0, f"EC too high for moisture {m}")

            self.assertGreaterEqual(n, 10.0, f"Nitrogen below minimal threshold for moisture {m}")
            self.assertGreaterEqual(p, 5.0, f"Phosphorus below minimal threshold for moisture {m}")
            self.assertGreaterEqual(k, 15.0, f"Potassium below minimal threshold for moisture {m}")

            self.assertGreaterEqual(ph, 4.5, f"pH too acidic for moisture {m}")
            self.assertLessEqual(ph, 8.5, f"pH too alkaline for moisture {m}")

    def test_telemetry_json_schema(self):
        """Ensure telemetry payload contains all fields required by Flutter SoilTelemetry.fromJson."""
        payload = simulate_station.build_payload(60.0, "garden")

        json_str = json.dumps(payload)
        parsed = json.loads(json_str)

        self.assertIn("telemetry", parsed)
        self.assertIn("actuators", parsed)
        self.assertEqual(parsed["soil_type"], "garden")
        self.assertGreater(parsed["timestamp"], 1700000000)  # Real Unix time, not seconds since boot
        tel = parsed["telemetry"]
        for key in ["nitrogen", "phosphorus", "potassium", "ph", "ec", "moisture"]:
            self.assertIn(key, tel)
            self.assertIsInstance(tel[key], (int, float))
        # The station has no temperature sensor, so no temperature is sent
        self.assertNotIn("temperature", tel)

        adc = parsed["adc"]
        for key in ["raw", "noise", "dry", "wet"]:
            self.assertIsInstance(adc[key], (int, float))

        act = parsed["actuators"]
        self.assertIn("pump", act)
        self.assertIn("nutrient_valve", act)
        self.assertIsInstance(act["pump"], bool)
        self.assertIsInstance(act["nutrient_valve"], bool)

    def test_command_handling_set_pump(self):
        """Test on_message handler with SET_PUMP action."""
        simulate_station.pump_state = False

        class MockMsg:
            topic = simulate_station.COMMAND_TOPIC
            payload = json.dumps({"action": "SET_PUMP", "state": True}).encode('utf-8')

        simulate_station.on_message(None, None, MockMsg())
        self.assertTrue(simulate_station.pump_state)

        # Toggle off
        MockMsg.payload = json.dumps({"action": "SET_PUMP", "state": False}).encode('utf-8')
        simulate_station.on_message(None, None, MockMsg())
        self.assertFalse(simulate_station.pump_state)

    def test_command_handling_set_valve(self):
        """Test on_message handler with SET_VALVE action."""
        simulate_station.valve_state = False

        class MockMsg:
            topic = simulate_station.COMMAND_TOPIC
            payload = json.dumps({"action": "SET_VALVE", "state": True}).encode('utf-8')

        simulate_station.on_message(None, None, MockMsg())
        self.assertTrue(simulate_station.valve_state)

        # Toggle off
        MockMsg.payload = json.dumps({"action": "SET_VALVE", "state": False}).encode('utf-8')
        simulate_station.on_message(None, None, MockMsg())
        self.assertFalse(simulate_station.valve_state)

    def test_soil_type_orders_nutrients(self):
        """At the same moisture, potting mix > garden soil > barren soil for EC and N, P, K."""
        for m in [45.0, 60.0, 75.0]:
            potting = simulate_station.calculate_nutrients_from_moisture(m, "potting")
            garden = simulate_station.calculate_nutrients_from_moisture(m, "garden")
            barren = simulate_station.calculate_nutrients_from_moisture(m, "barren")

            # Tuple order: n, p, k, ph, ec
            for idx in (0, 1, 2, 4):
                self.assertGreater(potting[idx], garden[idx], f"potting <= garden at index {idx}, moisture {m}")
                self.assertGreater(garden[idx], barren[idx], f"garden <= barren at index {idx}, moisture {m}")

    def test_npk_follows_ec(self):
        """N, P, K are computed from EC (like the firmware), so they rise with moisture."""
        coefficients = (simulate_station.N_PER_EC, simulate_station.P_PER_EC, simulate_station.K_PER_EC)
        for soil in simulate_station.SOIL_PROFILES:
            dry = simulate_station.calculate_nutrients_from_moisture(35.0, soil)
            wet = simulate_station.calculate_nutrients_from_moisture(85.0, soil)
            self.assertGreater(wet[4], dry[4], f"EC should rise with moisture for {soil}")
            for idx, coef in enumerate(coefficients):
                self.assertGreater(wet[idx], dry[idx], f"{soil} index {idx} should rise with moisture")
                # Values are rounded to 1 decimal, EC included
                self.assertAlmostEqual(wet[idx], wet[4] * coef, delta=0.1, msg=f"{soil} index {idx}")

    def test_npk_level_against_soil_normal(self):
        """Each soil type is on its normal N-P-K level at 60% moisture, low when dry and high when very wet."""
        for soil in simulate_station.SOIL_PROFILES:
            for moisture, expected in ((30.0, "low"), (60.0, "normal"), (90.0, "high")):
                n, p, k, _, _ = simulate_station.calculate_nutrients_from_moisture(moisture, soil)
                levels = simulate_station.npk_levels(n, p, k, soil)
                self.assertEqual(set(levels.values()), {expected}, f"{soil} at {moisture}%: {levels}")

        # +-20% band, same as the firmware
        self.assertEqual(simulate_station.compare_to_normal(52.0, 65.0), "normal")
        self.assertEqual(simulate_station.compare_to_normal(78.0, 65.0), "normal")
        self.assertEqual(simulate_station.compare_to_normal(51.0, 65.0), "low")
        self.assertEqual(simulate_station.compare_to_normal(79.0, 65.0), "high")

    def test_payload_reports_soil_normal_npk(self):
        """The payload carries the soil type's normal N-P-K level and how each nutrient compares to it."""
        payload = simulate_station.build_payload(60.0, "potting")
        self.assertEqual(payload["npk_normal"], {"nitrogen": 95.0, "phosphorus": 50.0, "potassium": 135.0})
        self.assertEqual(set(payload["npk_level"]), {"nitrogen", "phosphorus", "potassium"})
        for level in payload["npk_level"].values():
            self.assertIn(level, ("low", "normal", "high"))

    def test_command_handling_calibrate(self):
        """CALIBRATE stores the current ADC as the dry or wet point and rejects points too close together."""
        simulate_station.adc_dry = simulate_station.PROBE_DRY_ADC
        simulate_station.adc_wet = simulate_station.PROBE_WET_ADC
        simulate_station.dry_calibrated = False
        simulate_station.wet_calibrated = False
        simulate_station.current_moisture = 2.0  # Probe almost dry

        class MockMsg:
            topic = simulate_station.COMMAND_TOPIC
            payload = json.dumps({"action": "CALIBRATE", "point": "dry"}).encode('utf-8')

        simulate_station.on_message(None, None, MockMsg())
        self.assertAlmostEqual(simulate_station.adc_dry, 256, delta=10)
        self.assertTrue(simulate_station.dry_calibrated)

        # Saving the wet point while the probe is still dry is rejected
        MockMsg.payload = json.dumps({"action": "CALIBRATE", "point": "wet"}).encode('utf-8')
        simulate_station.on_message(None, None, MockMsg())
        self.assertEqual(simulate_station.adc_wet, simulate_station.PROBE_WET_ADC)
        self.assertFalse(simulate_station.wet_calibrated)

    def test_calibrate_first_point_ignores_default_other_point(self):
        """The first point is never compared with a default value: a capacitive probe reads ~2800 dry, near the default wet 3000."""
        simulate_station.adc_dry = simulate_station.PROBE_DRY_ADC
        simulate_station.adc_wet = simulate_station.PROBE_WET_ADC
        simulate_station.dry_calibrated = False
        simulate_station.wet_calibrated = False
        simulate_station.current_moisture = 93.0  # Virtual probe reads ~2800, within 300 of the default wet point

        class MockMsg:
            topic = simulate_station.COMMAND_TOPIC
            payload = json.dumps({"action": "CALIBRATE", "point": "dry"}).encode('utf-8')

        simulate_station.on_message(None, None, MockMsg())
        self.assertAlmostEqual(simulate_station.adc_dry, 2804, delta=10)
        self.assertTrue(simulate_station.dry_calibrated)

    def test_command_handling_set_soil_type(self):
        """Test on_message handler with SET_SOIL_TYPE action, rejecting unknown codes."""
        simulate_station.soil_type = "garden"

        class MockMsg:
            topic = simulate_station.COMMAND_TOPIC
            payload = json.dumps({"action": "SET_SOIL_TYPE", "soil_type": "barren"}).encode('utf-8')

        simulate_station.on_message(None, None, MockMsg())
        self.assertEqual(simulate_station.soil_type, "barren")

        MockMsg.payload = json.dumps({"action": "SET_SOIL_TYPE", "soil_type": "clay"}).encode('utf-8')
        simulate_station.on_message(None, None, MockMsg())
        self.assertEqual(simulate_station.soil_type, "barren")

if __name__ == '__main__':
    unittest.main()
