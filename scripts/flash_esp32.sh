#!/usr/bin/env bash
# ========================================================
# Script Nạp Firmware ESP32 1-Click (Tự Động Nhận Cổng COM)
# Cấu hình tối giản: ESP32 + Cảm biến độ ẩm + Điện thoại
# ========================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
cd "$DIR/firmware"

echo "========================================================"
echo "🌱 HỆ THỐNG DINH DƯỠNG ĐẤT IOT - NẠP FIRMWARE ESP32"
echo "   Cấu hình: ESP32 + Cảm biến nước (GPIO34) + Điện thoại"
echo "========================================================"

echo ""
echo "🔍 Đang kiểm tra cổng USB kết nối ESP32..."
PORTS=$(ls /dev/cu.usb* /dev/cu.SLAB* /dev/cu.wch* 2>/dev/null || true)

if [ -z "$PORTS" ]; then
    echo "⚠️  Chưa phát hiện cổng USB của ESP32!"
    echo "👉 Vui lòng cắm cáp USB nối ESP32 với máy tính."
    echo "💡 Ghi chú:"
    echo "   - Đảm bảo cáp USB là cáp truyền dữ liệu (Data cable), không phải cáp sạc thuần."
    echo "   - Nếu dùng chip CH340 hoặc CP2102 trên macOS, cần cấp quyền trong Security & Privacy."
    echo ""
    echo "Danh sách cổng hiện có:"
    pio device list
    exit 1
fi

echo "✅ Phát hiện cổng ESP32: $PORTS"
echo "🚀 Bắt đầu nạp code vào ESP32..."
pio run --target upload

echo ""
echo "🎉 Nạp code thành công 100%!"
echo "📡 Đang mở Serial Monitor (Baudrate 115200) để xem dữ liệu ADC..."
echo "👉 Bấm Ctrl + C để thoát khỏi Serial Monitor bất cứ lúc nào."
echo "--------------------------------------------------------"
sleep 1
pio device monitor -b 115200
