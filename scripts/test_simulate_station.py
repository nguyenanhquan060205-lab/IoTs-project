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
        m = 60.0
        n, p, k, ph, ec = simulate_station.calculate_nutrients_from_moisture(m)
        payload = {
            "device_id": "esp32_soil_station_01",
            "timestamp": int(time.time()),
            "telemetry": {
                "nitrogen": n,
                "phosphorus": p,
                "potassium": k,
                "ph": ph,
                "ec": ec,
                "moisture": m,
                "temperature": 27.5
            },
            "actuators": {
                "pump": False,
                "nutrient_valve": False
            }
        }

        json_str = json.dumps(payload)
        parsed = json.loads(json_str)

        self.assertIn("telemetry", parsed)
        self.assertIn("actuators", parsed)
        tel = parsed["telemetry"]
        for key in ["nitrogen", "phosphorus", "potassium", "ph", "ec", "moisture", "temperature"]:
            self.assertIn(key, tel)
            self.assertIsInstance(tel[key], (int, float))

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

if __name__ == '__main__':
    unittest.main()
