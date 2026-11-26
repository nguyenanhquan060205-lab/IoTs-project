#!/usr/bin/env python3
"""
Kiểm thử các hàm thuần của report_measure.py (không cần cắm trạm, không cần pyserial hay paho-mqtt).
Chạy: cd scripts && python -m unittest test_report_measure
"""

import os
import struct
import tempfile
import unittest

import report_measure as rm


class TestParseLines(unittest.TestCase):
    def test_ntp_line(self):
        line = "[NTP] Da co gio sau 15349 ms ke tu khi co WiFi: 2026-11-26 10:29:49 (ICT)"
        self.assertEqual(rm.parse_ntp_ms(line), 15349)
        self.assertIsNone(rm.parse_ntp_ms("[SENSOR] Dat: DAT VUON | ADC: 2094"))

    def test_mqtt_success(self):
        line = "Dang ket noi MQTT broker.emqx.io:8883 (TLS)... Thanh cong! (1533 ms, heap trong 167056 byte)"
        self.assertEqual(rm.parse_mqtt_result(line), {"ok": True, "ms": 1533, "heap": 167056})

    def test_mqtt_failure(self):
        line = "Dang ket noi MQTT broker.emqx.io:8883 (TLS)... That bai sau 812 ms, rc=-2. Thu lai sau 5 giay..."
        self.assertEqual(rm.parse_mqtt_result(line), {"ok": False, "ms": 812, "rc": -2})
        self.assertIsNone(rm.parse_mqtt_result("Da dang ky lang nghe: soil_station/1/command"))


class TestStats(unittest.TestCase):
    def test_describe(self):
        stats = rm.describe([15349, 15412, None])
        self.assertEqual(stats["n"], 2)
        self.assertEqual(stats["min"], 15349)
        self.assertEqual(stats["max"], 15412)
        self.assertAlmostEqual(stats["median"], 15380.5)
        self.assertAlmostEqual(stats["mean"], 15380.5)

    def test_describe_empty(self):
        self.assertIsNone(rm.describe([]))
        self.assertIsNone(rm.describe([None]))
        self.assertIn("không có số đo", rm.format_stats("NTP", []))


class TestSntp(unittest.TestCase):
    def test_request_packet(self):
        packet = rm.build_sntp_request()
        self.assertEqual(len(packet), 48)
        self.assertEqual(packet[0], 0x23)  # LI = 0, phiên bản 4, chế độ client

    def test_ntp_to_unix(self):
        # 2026-01-01 00:00:00 UTC = 1767225600 (Unix), cộng nửa giây ở phần lẻ
        self.assertAlmostEqual(rm.ntp_to_unix(1767225600 + rm.NTP_EPOCH_OFFSET, 2 ** 31), 1767225600.5)

    def test_clock_offset(self):
        # Máy tính gửi lúc 1000,0 và nhận lúc 1000,2 (giờ máy tính). Máy chủ nhận lúc 1001,1 và gửi lúc 1001,1
        # (giờ chuẩn): máy tính chậm 1 giây, trễ khứ hồi 0,2 giây
        server = 1001.1 + rm.NTP_EPOCH_OFFSET
        sec = int(server)
        frac = int((server - sec) * 2 ** 32)
        packet = bytes(32) + struct.pack("!IIII", sec, frac, sec, frac)
        offset, delay = rm.clock_offset_from_sntp(packet, 1000.0, 1000.2)
        self.assertAlmostEqual(offset, 1.0, places=3)
        self.assertAlmostEqual(delay, 0.2, places=3)

    def test_short_packet(self):
        with self.assertRaises(ValueError):
            rm.clock_offset_from_sntp(bytes(40), 0, 0)


class TestMasker(unittest.TestCase):
    def test_masks_known_wifi_name_and_ip(self):
        masker = rm.Masker(["abc"])
        self.assertEqual(masker.mask('Dang ket noi WiFi "abc" (hoac "Wokwi-GUEST" khi mo phong)'),
                         'Dang ket noi WiFi "<wifi>" (hoac "Wokwi-GUEST" khi mo phong)')
        self.assertEqual(masker.mask("   Dia chi IP: 192.168.1.137"), "   Dia chi IP: <ip>")

    def test_learns_wifi_name_from_ssid_line(self):
        masker = rm.Masker()
        self.assertEqual(masker.mask("   SSID: Nha Tro 5G"), "   SSID: <wifi>")
        self.assertEqual(masker.mask('[WIFI] Da ket noi lai "Nha Tro 5G"'), '[WIFI] Da ket noi lai "<wifi>"')

    def test_keeps_lines_without_secrets(self):
        line = "Dang ket noi MQTT broker.emqx.io:8883 (TLS)... Thanh cong! (1533 ms, heap trong 167056 byte)"
        self.assertEqual(rm.Masker(["abc"]).mask(line), line)

    def test_read_wifi_name(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "secrets.h")
            with open(path, "w", encoding="utf-8") as f:
                f.write('#define WIFI_SSID      "abc"\n#define WIFI_PASSWORD  "x"\n')
            self.assertEqual(rm.read_wifi_name(path), "abc")
            self.assertIsNone(rm.read_wifi_name(os.path.join(folder, "khong-co.h")))


if __name__ == "__main__":
    unittest.main()
