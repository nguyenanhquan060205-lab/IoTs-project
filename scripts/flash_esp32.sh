#!/usr/bin/env bash
# ========================================================
# Nạp firmware ESP32: build, tự tìm cổng USB của ESP32, nạp code, mở Serial Monitor
# Chạy được trên macOS, Linux và Git Bash trên Windows.
# Trên Windows PowerShell dùng scripts/flash_esp32.ps1.
#
#   ./scripts/flash_esp32.sh                    # tự tìm cổng
#   ./scripts/flash_esp32.sh --port COM7        # hoặc /dev/cu.usbserial-0001, /dev/ttyUSB0
#   ./scripts/flash_esp32.sh --build-only       # chỉ build, không cần cắm ESP32
#   ./scripts/flash_esp32.sh --no-monitor       # nạp xong không mở Serial Monitor
#   ./scripts/flash_esp32.sh --list-ports       # chỉ liệt kê cổng
# ========================================================

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
FIRMWARE_DIR="$DIR/firmware"

# Chip USB-UART hay gặp trên board ESP32: CP210x, CH340/CH341, CH9102, FTDI, USB native của Espressif.
# Cổng Bluetooth trên Windows có Hardware ID dạng BTHENUM\... nên không bao giờ bị chọn nhầm.
ESP_USB_IDS='VID:PID=(10C4:EA60|1A86:7523|1A86:7522|1A86:55D4|0403:6001|0403:6010|0403:6015|303A:[0-9A-F][0-9A-F][0-9A-F][0-9A-F])'

PORT=""
BUILD_ONLY=0
NO_MONITOR=0
LIST_PORTS=0
while [ $# -gt 0 ]; do
    case "$1" in
        -p|--port) PORT="${2:-}"; shift 2 ;;
        --build-only) BUILD_ONLY=1; shift ;;
        --no-monitor) NO_MONITOR=1; shift ;;
        --list-ports) LIST_PORTS=1; shift ;;
        -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "Tham số không hợp lệ: $1 (xem --help)"; exit 2 ;;
    esac
done

# Tìm lệnh pio: trong PATH, trong thư mục cài của PlatformIO IDE (VS Code), hoặc gọi qua Python
find_pio() {
    if command -v pio >/dev/null 2>&1; then PIO=(pio); return 0; fi
    for candidate in "$HOME/.platformio/penv/bin/pio" "$HOME/.platformio/penv/Scripts/pio.exe"; do
        if [ -x "$candidate" ]; then PIO=("$candidate"); return 0; fi
    done
    for python in python3 python py; do
        if command -v "$python" >/dev/null 2>&1 && "$python" -c "import platformio" >/dev/null 2>&1; then
            PIO=("$python" -m platformio); return 0
        fi
    done
    return 1
}

# In tên các cổng có Hardware ID khớp chip USB của ESP32 (đọc từ "pio device list --serial")
find_esp_ports() {
    "${PIO[@]}" device list --serial | awk -v ids="$ESP_USB_IDS" '
        { sub(/\r$/, "") }
        /^-+$/ { port = prev; next }
        /^Hardware ID:/ { if (port != "" && toupper($0) ~ ids) print port; port = "" }
        { prev = $0 }'
}

echo "========================================================"
echo "🌱 HỆ THỐNG DINH DƯỠNG ĐẤT IOT - NẠP FIRMWARE ESP32"
echo "   Cảm biến độ ẩm: VCC -> 3V3, GND -> GND, AO -> GPIO34"
echo "========================================================"

if ! find_pio; then
    echo "❌ Chưa cài PlatformIO."
    echo "   Cách 1: cài VS Code, vào Extensions cài 'PlatformIO IDE', khởi động lại VS Code."
    echo "   Cách 2: python3 -m pip install -U platformio"
    exit 1
fi
echo "PlatformIO: ${PIO[*]}"

if [ "$LIST_PORTS" -eq 1 ]; then
    "${PIO[@]}" device list --serial
    exit 0
fi

if [ ! -f "$FIRMWARE_DIR/src/secrets.h" ]; then
    echo "⚠️  Chưa có firmware/src/secrets.h: trạm sẽ thử WiFi mẫu 'iPhone' / 'password' và không vào được mạng."
    echo "   Chép firmware/src/secrets.example.h thành secrets.h, điền WiFi 2.4 GHz rồi chạy lại script."
    echo "   Vẫn tiếp tục nạp để kiểm tra cảm biến qua Serial Monitor (không cần mạng)."
fi

echo ""
echo "🔨 Build firmware (lần đầu PlatformIO tải toolchain ESP32, mất vài phút)..."
"${PIO[@]}" run -d "$FIRMWARE_DIR"
if [ "$BUILD_ONLY" -eq 1 ]; then
    echo ""
    echo "✅ Build xong: firmware/.pio/build/esp32dev/firmware.bin"
    exit 0
fi

echo ""
echo "🔍 Đang tìm cổng USB của ESP32..."
if [ -z "$PORT" ]; then
    ESP_PORTS="$(find_esp_ports || true)"
    if [ -z "$ESP_PORTS" ]; then
        echo "❌ Không thấy ESP32. Các cổng đang có:"
        "${PIO[@]}" device list --serial || true
        echo "💡 Ghi chú:"
        echo "   - Dùng cáp USB truyền dữ liệu (Data cable), không phải cáp chỉ sạc."
        echo "   - Windows: Device Manager > Ports phải thấy CP210x hoặc CH340, không thấy thì cài driver."
        echo "   - macOS: chip CH340 hoặc CP2102 có thể cần cấp quyền trong Privacy & Security."
        echo "   - Biết cổng rồi thì chạy lại với --port <cổng>."
        exit 1
    fi
    PORT="$(echo "$ESP_PORTS" | head -n 1)"
    if [ "$(echo "$ESP_PORTS" | wc -l)" -gt 1 ]; then
        echo "⚠️  Thấy nhiều board ESP32, chọn $PORT. Dùng --port để chọn board khác."
    fi
fi
echo "✅ Cổng ESP32: $PORT"

echo "🚀 Bắt đầu nạp code vào ESP32..."
if ! "${PIO[@]}" run -d "$FIRMWARE_DIR" -t upload --upload-port "$PORT"; then
    echo "❌ Nạp code thất bại."
    echo "   - Báo 'Timed out waiting for packet header': giữ nút BOOT khi thấy 'Connecting....', nhả khi bắt đầu ghi."
    echo "   - Báo 'could not open port' / 'Permission denied': đóng Serial Monitor hoặc Arduino IDE đang mở cổng."
    exit 1
fi

echo ""
echo "🎉 Nạp code thành công!"
if [ "$NO_MONITOR" -eq 1 ]; then exit 0; fi

echo "📡 Đang mở Serial Monitor (Baudrate 115200). Bấm Ctrl + C để thoát, bấm nút EN/RST trên board để xem log từ đầu."
echo "--------------------------------------------------------"
sleep 1
"${PIO[@]}" device monitor -p "$PORT" -b 115200
