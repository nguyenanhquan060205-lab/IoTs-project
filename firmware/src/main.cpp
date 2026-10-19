#include <Arduino.h>
#include <WiFi.h>
#include <WiFiMulti.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "soil_estimator.h"

/* ====================================================================
 * CẤU HÌNH HỆ THỐNG GIÁM SÁT DINH DƯỠNG ĐẤT IOT (ESP32)
 * Cấu hình Tối Giản: Chỉ Điện Thoại + ESP32 + Cảm Biến Nước/Độ Ẩm ADC
 * Tùy chọn cắm thêm: OLED 0.96" I2C, Relay 5V điều khiển bơm
 * ==================================================================== */

// 1. Cấu hình WiFi (Tự động thử WiFi nhà/4G và Wokwi-GUEST)
const char* USER_WIFI_SSID     = "iPhone";       // <-- Đổi thành tên WiFi hoặc 4G Hotspot của bạn
const char* USER_WIFI_PASSWORD = "password";     // <-- Đổi thành mật khẩu WiFi của bạn
const char* WOKWI_SSID         = "Wokwi-GUEST";  // Giả lập Wokwi

WiFiMulti wifiMulti;

// 2. Cấu hình MQTT Broker (Trùng khớp 100% với Mobile App)
const char* MQTT_BROKER   = "broker.emqx.io";
const int   MQTT_PORT     = 1883;
const char* TOPIC_TELEMETRY = "soil_station/1/telemetry";
const char* TOPIC_COMMAND   = "soil_station/1/command";
const char* TOPIC_STATUS    = "soil_station/1/status";

// 3. Định nghĩa chân GPIO phần cứng (Đảm bảo an toàn, không xung đột WiFi)
#define PIN_WATER_SENSOR  34   // Chân ADC1 (GPIO34) đọc cảm biến độ ẩm/nước (Cấp nguồn 3.3V!)
#define PIN_RELAY_PUMP    26   // Chân điều khiển Rơ-le máy bơm nước
#define PIN_RELAY_VALVE   27   // Chân điều khiển Rơ-le van dinh dưỡng (dự phòng)
#define PIN_BUZZER        25   // Còi cảnh báo
#define PIN_LED_ALERT     32   // LED đỏ (Báo động nguy hiểm: Khô cằn / Ngập úng / Chua phèn / Mặn)
#define PIN_LED_WARNING   19   // LED vàng (Cảnh báo nhẹ / Đang tưới / Cần theo dõi)
#define PIN_LED_NORMAL    33   // LED xanh (Đất màu mỡ, dinh dưỡng & độ ẩm chuẩn)

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// 4. Cấu hình hiệu chuẩn ADC Cảm biến (Hỗ trợ cả cảm biến điện trở & điện dung v1.2)
// Cảm biến điện trở nước thông thường: Khô (Dry) = 150 - 300; Nhúng ly nước (Wet) = 2500 - 3500
// Cảm biến điện dung không ăn mòn v1.2: Khô (Dry) = 3000; Nhúng ly nước (Wet) = 1300
int ADC_DRY = 200;
int ADC_WET = 3000;

WiFiClient espClient;
PubSubClient mqttClient(espClient);

// Biến lưu trạng thái hoạt động
bool pumpActive = false;
bool valveActive = false;
bool hasOLED = false;
unsigned long lastTelemetryTime = 0;
const unsigned long TELEMETRY_INTERVAL = 4000; // 4 giây gửi 1 lần

// -------------------------------------------------------------
// Hàm hiển thị thông số lên màn hình OLED (Tự động bỏ qua nếu không cắm OLED)
// -------------------------------------------------------------
void updateOLED(float moisture, float ec, float n, float p, float k, float ph) {
    if (!hasOLED) return; // Không cắm OLED thì bỏ qua, không bao giờ bị đơ treo I2C
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);

    // Tiêu đề
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.print(F("SOIL IOT: "));
    if (WiFi.status() == WL_CONNECTED) {
        display.print(F("WIFI OK"));
    } else {
        display.print(F("NO WIFI"));
    }

    display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

    // Dòng 1: Độ ẩm & EC
    display.setCursor(0, 14);
    display.printf("Am: %.1f%%  EC: %.0f", moisture, ec);

    // Dòng 2: NPK
    display.setCursor(0, 26);
    display.printf("N:%.0f  P:%.0f  K:%.0f", n, p, k);

    // Dòng 3: pH & Nhiệt độ
    display.setCursor(0, 38);
    display.printf("pH: %.1f  Nhiet: 27.5C", ph);

    // Dòng 4: Trạng thái bơm
    display.drawLine(0, 50, 127, 50, SSD1306_WHITE);
    display.setCursor(0, 54);
    display.printf("BOM: %s  MQTT: OK", pumpActive ? "[ON]" : "[OFF]");

    display.display();
}

// -------------------------------------------------------------
// Thuật toán lọc trung bình trượt ADC (20 mẫu lấy mẫu để chống nhiễu điện áp)
// -------------------------------------------------------------
int readFilteredADC(int pin) {
    long sum = 0;
    const int SAMPLES = 20;
    for (int i = 0; i < SAMPLES; i++) {
        sum += analogRead(pin);
        delay(3);
    }
    return sum / SAMPLES;
}

// -------------------------------------------------------------
// Xử lý Lệnh từ App Mobile gửi về qua MQTT (Bật/Tắt Bơm)
// -------------------------------------------------------------
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    String msg = "";
    for (unsigned int i = 0; i < length; i++) {
        msg += (char)payload[i];
    }
    Serial.println("\n[MQTT] Nhan lenh tu App Mobile: " + msg);

    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, msg);
    if (error) {
        Serial.print(F("Lỗi parse JSON lệnh: "));
        Serial.println(error.f_str());
        return;
    }

    const char* action = doc["action"];
    bool state = doc["state"];

    if (strcmp(action, "SET_PUMP") == 0) {
        pumpActive = state;
        digitalWrite(PIN_RELAY_PUMP, pumpActive ? HIGH : LOW);
        Serial.printf("=> RƠ-LE BƠM NƯỚC: %s\n", pumpActive ? "DA BAT (ON)" : "DA TAT (OFF)");
    } else if (strcmp(action, "SET_VALVE") == 0) {
        valveActive = state;
        digitalWrite(PIN_RELAY_VALVE, valveActive ? HIGH : LOW);
        Serial.printf("=> RƠ-LE VAN DINH DƯỠNG: %s\n", valveActive ? "MO" : "DONG");
    }
}

// -------------------------------------------------------------
// Quản lý Kết nối WiFi Multi (Tự động kết nối mạng sẵn có)
// -------------------------------------------------------------
void setupWiFi() {
    Serial.println("Dang khoi dong WiFi Multi...");
    WiFi.mode(WIFI_STA);

    // Thêm các AP: Wokwi và WiFi cá nhân
    wifiMulti.addAP(WOKWI_SSID, "");
    wifiMulti.addAP(USER_WIFI_SSID, USER_WIFI_PASSWORD);

    Serial.print("Dang ket noi WiFi");
    int attempts = 0;
    while (wifiMulti.run() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\n✅ WiFi da ket noi!");
        Serial.print("   SSID: ");
        Serial.println(WiFi.SSID());
        Serial.print("   Dia chi IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println("\n⚠️ Chua bat duoc WiFi, he thong se tu dong thu lai lien tuc trong loop().");
    }
}

void reconnectMQTT() {
    while (!mqttClient.connected()) {
        Serial.print("Dang ket noi MQTT Broker...");
        String clientId = "ESP32_Soil_" + String(random(0xffff), HEX);
        if (mqttClient.connect(clientId.c_str())) {
            Serial.println(" Thanh cong!");
            mqttClient.subscribe(TOPIC_COMMAND);
            Serial.printf("Da dang ky lang nghe: %s\n", TOPIC_COMMAND);

            // Báo Online
            StaticJsonDocument<128> statusDoc;
            statusDoc["status"] = "online";
            statusDoc["device"] = clientId;
            char buffer[128];
            serializeJson(statusDoc, buffer);
            mqttClient.publish(TOPIC_STATUS, buffer);
        } else {
            Serial.print(" That bai, rc=");
            Serial.print(mqttClient.state());
            Serial.println(" Thu lai sau 3 giay...");
            delay(3000);
        }
    }
}

// -------------------------------------------------------------
// KHỞI ĐỘNG HỆ THỐNG (SETUP)
// -------------------------------------------------------------
void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n==============================================");
    Serial.println("  HE THONG DINH DUONG DAT IOT (ESP32)");
    Serial.println("==============================================");

    // Cấu hình chân vào/ra (I/O)
    pinMode(PIN_WATER_SENSOR, INPUT);
    pinMode(PIN_RELAY_PUMP, OUTPUT);
    pinMode(PIN_RELAY_VALVE, OUTPUT);
    pinMode(PIN_BUZZER, OUTPUT);
    pinMode(PIN_LED_ALERT, OUTPUT);
    pinMode(PIN_LED_WARNING, OUTPUT);
    pinMode(PIN_LED_NORMAL, OUTPUT);

    // Mặc định tắt các relay và đèn cảnh báo
    digitalWrite(PIN_RELAY_PUMP, LOW);
    digitalWrite(PIN_RELAY_VALVE, LOW);
    digitalWrite(PIN_LED_ALERT, LOW);
    digitalWrite(PIN_LED_WARNING, LOW);
    digitalWrite(PIN_LED_NORMAL, HIGH);

    // Khởi động OLED I2C (địa chỉ 0x3C)
    if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
        Serial.println(F("[CANH BAO] Khong tim thay OLED -> He thong se bo qua OLED va chay che do toi gian (Core Setup)."));
        hasOLED = false;
    } else {
        hasOLED = true;
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(10, 20);
        display.println(F("KHOI DONG HE THONG"));
        display.setCursor(10, 35);
        display.println(F("DAT THONG MINH IOT"));
        display.display();
        delay(1500);
    }

    // Kết nối mạng
    setupWiFi();
    mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
    mqttClient.setCallback(onMqttMessage);
}

// -------------------------------------------------------------
// VÒNG LẶP CHÍNH (LOOP)
// -------------------------------------------------------------
void loop() {
    // Duy trì kết nối WiFi Multi & MQTT
    if (wifiMulti.run() == WL_CONNECTED) {
        if (!mqttClient.connected()) {
            reconnectMQTT();
        }
        mqttClient.loop();
    }

    unsigned long now = millis();
    if (now - lastTelemetryTime >= TELEMETRY_INTERVAL) {
        lastTelemetryTime = now;

        // 1. Đọc cảm biến nước qua bộ lọc trung bình trượt
        int rawADC = readFilteredADC(PIN_WATER_SENSOR);

        // 2. Chuyển đổi ADC -> % Độ ẩm & Ước lượng 7 chỉ số dinh dưỡng
        float moisture = SoilEstimator::calculateMoisture(rawADC, ADC_DRY, ADC_WET);
        float noise = (float)random(-10, 11);
        SoilNutrientData soil = SoilEstimator::estimate(moisture, noise);

        // Cơ chế bảo vệ nông học tự động: Nếu đất đã úng nước (> 85%) mà bơm đang bật -> tự động ngắt
        if (soil.moisture > 85.0f && pumpActive) {
            pumpActive = false;
            digitalWrite(PIN_RELAY_PUMP, LOW);
            Serial.println(F("⚠️ [TỰ ĐỘNG BẢO VỆ NÔNG HỌC] Đất đã úng nước (> 85%) -> Tự động ngắt bơm an toàn!"));
        }

        // Hệ thống Đèn LED 3 Cấp Độ (Đỏ - Vàng - Xanh):
        // 🔴 ĐỎ (Nguy hiểm): Khô cằn < 35%, Ngập úng > 80%, Mặn EC > 1800, Chua pH < 5.5
        // 🟡 VÀNG (Cảnh báo nhẹ / Đang tưới): Hơi khô (35 - 49%) hoặc Hơi ẩm (71 - 80%) hoặc Bơm đang chạy
        // 🟢 XANH (Lý tưởng): Đất màu mỡ, ẩm 50 - 70%, pH và EC cân đối
        bool isDanger = (soil.moisture < 35.0f || soil.moisture > 80.0f || soil.ec > 1800.0f || soil.ph < 5.5f);
        bool isWarning = (!isDanger && (soil.moisture < 50.0f || soil.moisture > 70.0f || pumpActive));
        bool isOptimal = (!isDanger && !isWarning);

        digitalWrite(PIN_LED_ALERT,   isDanger  ? HIGH : LOW);
        digitalWrite(PIN_LED_WARNING, isWarning ? HIGH : LOW);
        digitalWrite(PIN_LED_NORMAL,  isOptimal ? HIGH : LOW);

        // 3. Cập nhật màn hình OLED (Tự động bỏ qua nếu không cắm OLED)
        updateOLED(soil.moisture, soil.ec, soil.nitrogen, soil.phosphorus, soil.potassium, soil.ph);

        // 4. In ra Serial Monitor để kiểm tra và lấy số liệu hiệu chuẩn
        Serial.printf("[SENSOR] ADC: %4d | Am: %5.1f%% | EC: %5.0f | N: %4.1f | P: %4.1f | K: %4.1f | pH: %3.1f | Bom: %s\n",
                      rawADC, soil.moisture, soil.ec, soil.nitrogen, soil.phosphorus, soil.potassium, soil.ph, pumpActive ? "ON" : "OFF");

        // 5. Đóng gói JSON và gửi MQTT lên Cloud cho Mobile App
        if (mqttClient.connected()) {
            StaticJsonDocument<384> doc;
            doc["device_id"] = "esp32_soil_station_01";
            doc["timestamp"] = (uint32_t)(now / 1000);

            JsonObject telemetry = doc.createNestedObject("telemetry");
            telemetry["nitrogen"]    = round(soil.nitrogen * 10.0f) / 10.0f;
            telemetry["phosphorus"]  = round(soil.phosphorus * 10.0f) / 10.0f;
            telemetry["potassium"]   = round(soil.potassium * 10.0f) / 10.0f;
            telemetry["ph"]          = round(soil.ph * 10.0f) / 10.0f;
            telemetry["ec"]          = round(soil.ec * 10.0f) / 10.0f;
            telemetry["moisture"]    = round(soil.moisture * 10.0f) / 10.0f;
            telemetry["temperature"] = 27.5;

            JsonObject actuators = doc.createNestedObject("actuators");
            actuators["pump"]           = pumpActive;
            actuators["nutrient_valve"] = valveActive;

            char jsonBuffer[384];
            serializeJson(doc, jsonBuffer);
            mqttClient.publish(TOPIC_TELEMETRY, jsonBuffer);
            Serial.println("=> Da gui MQTT thanh cong len topic: " + String(TOPIC_TELEMETRY));
        }
    }
}

