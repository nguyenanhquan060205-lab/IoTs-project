#!/usr/bin/env python3
"""
End-to-End MQTT Pipeline Verification Test
Verifies roundtrip communication with broker.emqx.io:
1. Telemetry publishing on 'soil_station/1/telemetry'
2. Command dispatching and receipt on 'soil_station/1/command'
"""

import unittest
import json
import time
import paho.mqtt.client as mqtt

BROKER = "broker.emqx.io"
PORT = 1883
TELEMETRY_TOPIC = "soil_station/1/telemetry"
COMMAND_TOPIC = "soil_station/1/command"

class TestMqttEndToEnd(unittest.TestCase):
    def test_live_mqtt_roundtrip(self):
        client_id_sub = f"test_e2e_sub_{int(time.time())}"
        client_id_pub = f"test_e2e_pub_{int(time.time())}"

        received_telemetry = []
        received_command = []

        def on_sub_message(client, userdata, msg):
            payload = json.loads(msg.payload.decode('utf-8'))
            if msg.topic == TELEMETRY_TOPIC:
                received_telemetry.append(payload)
            elif msg.topic == COMMAND_TOPIC:
                received_command.append(payload)

        # Subscriber client
        sub_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id_sub)
        sub_client.on_message = on_sub_message
        sub_client.connect(BROKER, PORT, 30)
        sub_client.subscribe([(TELEMETRY_TOPIC, 1), (COMMAND_TOPIC, 1)])
        sub_client.loop_start()

        # Publisher client
        pub_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id_pub)
        pub_client.connect(BROKER, PORT, 30)
        pub_client.loop_start()

        time.sleep(1.0) # Wait for subscription to establish

        # 1. Publish test command
        cmd_payload = {"action": "SET_SOIL_TYPE", "soil_type": "garden", "source": "test_e2e"}
        pub_client.publish(COMMAND_TOPIC, json.dumps(cmd_payload), qos=1)

        # 2. Publish test telemetry
        telemetry_payload = {
            "device_id": "esp32_soil_station_01",
            "timestamp": int(time.time()),
            "telemetry": {
                "nitrogen": 80.0,
                "phosphorus": 45.0,
                "potassium": 110.0,
                "ph": 6.4,
                "ec": 850.0,
                "moisture": 60.0,
                "temperature": 27.5
            }
        }
        pub_client.publish(TELEMETRY_TOPIC, json.dumps(telemetry_payload), qos=1)

        # Wait up to 5 seconds for messages to arrive
        deadline = time.time() + 5.0
        while time.time() < deadline:
            if received_command and received_telemetry:
                break
            time.sleep(0.1)

        sub_client.loop_stop()
        sub_client.disconnect()
        pub_client.loop_stop()
        pub_client.disconnect()

        self.assertGreater(len(received_command), 0, "Did not receive command on COMMAND_TOPIC")
        self.assertEqual(received_command[0].get("action"), "SET_SOIL_TYPE")
        self.assertEqual(received_command[0].get("soil_type"), "garden")

        self.assertGreater(len(received_telemetry), 0, "Did not receive telemetry on TELEMETRY_TOPIC")
        self.assertEqual(received_telemetry[0]["telemetry"]["moisture"], 60.0)
        print("✅ Live MQTT roundtrip verified successfully on broker.emqx.io!")

if __name__ == '__main__':
    unittest.main()
