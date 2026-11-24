#include <Arduino.h>
#include <WiFi.h>
#include <WiFiMulti.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>
#include <time.h>
#include "soil_estimator.h"
#include "adc_filter.h"
#include "root_ca.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
// Chưa tạo secrets.h (ví dụ chạy trên Wokwi): dùng broker công cộng qua TLS, có mã hóa nhưng chưa có tài khoản
#define WIFI_SSID      "iPhone"
#define WIFI_PASSWORD  "password"
#define MQTT_HOST      "broker.emqx.io"
#define MQTT_PORT      8883
#define MQTT_USERNAME  ""
#define MQTT_PASSWORD  ""
#endif

/* ====================================================================
 * CẤU HÌNH HỆ THỐNG GIÁM SÁT DINH DƯỠNG ĐẤT IOT (ESP32)
 * Cấu hình Tối Giản: Chỉ Điện Thoại + ESP32 + Cảm Biến Nước/Độ Ẩm ADC
 * N, P, K, EC, pH ước lượng từ độ ẩm theo loại đất do App chọn
 * Tùy chọn cắm thêm: OLED 0.96" I2C, Relay 5V điều khiển bơm
 * ==================================================================== */

// 1. Cấu hình WiFi (Tự động thử WiFi trong secrets.h và Wokwi-GUEST)
const char* WOKWI_SSID = "Wokwi-GUEST";  // Giả lập Wokwi
WiFiMulti wifiMulti;

// 2. Cấu hình MQTT (Trùng khớp với Mobile App), kết nối TLS và tài khoản lấy từ secrets.h
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

// Module rơ-le 2 kênh có opto và jumper JD-VCC kích ở mức THẤP: LOW = rơ-le đóng, HIGH = rơ-le nhả
#define RELAY_ON   LOW
#define RELAY_OFF  HIGH

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// 4. Hiệu chuẩn ADC cảm biến độ ẩm: giá trị mặc định, đo lại trên đất thật bằng màn Hiệu chuẩn của App
// Module LM393/FC-28 cho ADC giảm khi ướt nên mốc khô sẽ lớn hơn mốc ướt, phép tính độ ẩm tự xử lý cả 2 chiều
const int DEFAULT_ADC_DRY = 200;
const int DEFAULT_ADC_WET = 3000;
const int MIN_CALIBRATION_GAP = 300;  // Hai mốc khô/ướt quá gần nhau thì độ ẩm tính ra không còn ý nghĩa
int adcDry = DEFAULT_ADC_DRY;
int adcWet = DEFAULT_ADC_WET;

WiFiClientSecure secureClient;
PubSubClient mqttClient(secureClient);

// Loại đất và mốc hiệu chuẩn lưu vào flash (NVS) để khởi động lại vẫn giữ
Preferences prefs;
SoilType currentSoilType = SoilType::GARDEN;

// Biến lưu trạng thái hoạt động
bool pumpActive = false;
bool valveActive = false;
bool hasOLED = false;
unsigned long lastTelemetryTime = 0;
unsigned long lastMqttAttempt = 0;
const unsigned long TELEMETRY_INTERVAL = 4000;   // 4 giây gửi 1 lần
const unsigned long MQTT_RETRY_INTERVAL = 5000;  // Mất kết nối broker thì 5 giây thử lại 1 lần
const time_t VALID_EPOCH = 1700000000;           // Đồng hồ chưa qua mốc 11/2023 nghĩa là chưa đồng bộ NTP

float round1(float value) {
    return roundf(value * 10.0f) / 10.0f;
}

// -------------------------------------------------------------
// Hàm hiển thị thông số lên màn hình OLED (Tự động bỏ qua nếu không cắm OLED)
// -------------------------------------------------------------
void updateOLED(const char* soilLabel, const SoilNutrientData& soil) {
    if (!hasOLED) return; // Không cắm OLED thì bỏ qua, không bao giờ bị đơ treo I2C
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);

    // Tiêu đề: Loại đất đang đo + trạng thái WiFi
    display.setCursor(0, 0);
    display.printf("%-9s %s", soilLabel, WiFi.status() == WL_CONNECTED ? "WIFI OK" : "NO WIFI");
    display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

    // Dòng 1: Độ ẩm & EC
    display.setCursor(0, 14);
    display.printf("Am: %.1f%%  EC: %.0f", soil.moisture, soil.ec);

    // Dòng 2: NPK
    display.setCursor(0, 26);
    display.printf("N:%.0f  P:%.0f  K:%.0f", soil.nitrogen, soil.phosphorus, soil.potassium);

    // Dòng 3: pH + nhãn nhắc N-P-K, EC, pH là số ước lượng
    display.setCursor(0, 38);
    display.printf("pH: %.1f  UOC LUONG", soil.ph);

    // Dòng 4: Trạng thái bơm, MQTT và giờ thực lấy từ NTP
    char clock[6] = "--:--";
    time_t epoch = time(nullptr);
    if (epoch > VALID_EPOCH) {
        struct tm timeinfo;
        localtime_r(&epoch, &timeinfo);
        strftime(clock, sizeof(clock), "%H:%M", &timeinfo);
    }
    display.drawLine(0, 50, 127, 50, SSD1306_WHITE);
    display.setCursor(0, 54);
    display.printf("BOM:%-3s  %s  %s", pumpActive ? "ON" : "OFF", mqttClient.connected() ? "MQTT" : "----", clock);

    display.display();
}

// -------------------------------------------------------------
// Đọc ADC 21 mẫu rồi lọc trung bình cắt tỉa (bỏ 5 mẫu thấp nhất và 5 mẫu cao nhất)
// -------------------------------------------------------------
AdcReading readFilteredADC(int pin) {
    const int SAMPLES = 21;
    int samples[SAMPLES];
    for (int i = 0; i < SAMPLES; i++) {
        samples[i] = analogRead(pin);
        delay(3);
    }
    return AdcFilter::filter(samples, SAMPLES, 5);
}

// -------------------------------------------------------------
// Lưu mốc hiệu chuẩn: "dry" khi đầu dò để khô ngoài không khí, "wet" khi nhúng vào cốc nước
// -------------------------------------------------------------
void calibrate(const char* point) {
    bool isDry = point != nullptr && strcmp(point, "dry") == 0;
    bool isWet = point != nullptr && strcmp(point, "wet") == 0;
    if (!isDry && !isWet) {
        Serial.println(F("=> Moc hieu chuan khong hop le (chi nhan dry / wet)"));
        return;
    }

    AdcReading reading = readFilteredADC(PIN_WATER_SENSOR);
    int otherPoint = isDry ? adcWet : adcDry;
    if (abs(reading.value - otherPoint) < MIN_CALIBRATION_GAP) {
        Serial.printf("=> Bo qua: ADC %d qua gan moc con lai (%d)\n", reading.value, otherPoint);
        return;
    }

    if (isDry) {
        adcDry = reading.value;
        prefs.putInt("adc_dry", adcDry);
    } else {
        adcWet = reading.value;
        prefs.putInt("adc_wet", adcWet);
    }
    lastTelemetryTime = 0; // Gửi ngay số liệu theo mốc mới để App xác nhận
    Serial.printf("=> DA LUU MOC %s: ADC %d (nhieu +-%.1f)\n", isDry ? "KHO" : "UOT", reading.value, reading.noise);
}

// -------------------------------------------------------------
// Xử lý Lệnh từ App Mobile gửi về qua MQTT
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
    if (action == nullptr) return;
    bool state = doc["state"];

    if (strcmp(action, "SET_PUMP") == 0) {
        pumpActive = state;
        digitalWrite(PIN_RELAY_PUMP, pumpActive ? RELAY_ON : RELAY_OFF);
        Serial.printf("=> RƠ-LE BƠM NƯỚC: %s\n", pumpActive ? "DA BAT (ON)" : "DA TAT (OFF)");
    } else if (strcmp(action, "SET_VALVE") == 0) {
        valveActive = state;
        digitalWrite(PIN_RELAY_VALVE, valveActive ? RELAY_ON : RELAY_OFF);
        Serial.printf("=> RƠ-LE VAN DINH DƯỠNG: %s\n", valveActive ? "MO" : "DONG");
    } else if (strcmp(action, "SET_SOIL_TYPE") == 0) {
        SoilType newType;
        if (SoilEstimator::parseSoilType(doc["soil_type"], newType)) {
            currentSoilType = newType;
            prefs.putUChar("type", (uint8_t)newType);
            lastTelemetryTime = 0; // Gửi ngay số liệu theo loại đất mới để App xác nhận
            Serial.printf("=> LOAI DAT DANG DO: %s\n", SoilEstimator::profile(newType).label);
        } else {
            Serial.println(F("=> Ma loai dat khong hop le, giu nguyen loai dat cu"));
        }
    } else if (strcmp(action, "CALIBRATE") == 0) {
        calibrate(doc["point"]);
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
    wifiMulti.addAP(WIFI_SSID, WIFI_PASSWORD);

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

// Thử kết nối broker 1 lần, không chặn vòng lặp để OLED và LED vẫn chạy khi broker lỗi
void tryConnectMqtt() {
    Serial.printf("Dang ket noi MQTT %s:%d (TLS)...", MQTT_HOST, MQTT_PORT);
    String clientId = "ESP32_Soil_" + String(random(0xffff), HEX);
    bool connected = strlen(MQTT_USERNAME) > 0
                         ? mqttClient.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD)
                         : mqttClient.connect(clientId.c_str());
    if (!connected) {
        // rc = -2: không mở được kết nối TLS (sai host/cổng, chứng chỉ), rc = 4/5: sai tài khoản
        Serial.printf(" That bai, rc=%d. Thu lai sau %lu giay...\n", mqttClient.state(), MQTT_RETRY_INTERVAL / 1000);
        return;
    }

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
    digitalWrite(PIN_RELAY_PUMP, RELAY_OFF);
    digitalWrite(PIN_RELAY_VALVE, RELAY_OFF);
    digitalWrite(PIN_LED_ALERT, LOW);
    digitalWrite(PIN_LED_WARNING, LOW);
    digitalWrite(PIN_LED_NORMAL, HIGH);

    // Đọc loại đất và mốc hiệu chuẩn đã lưu lần trước
    prefs.begin("soil", false);
    uint8_t savedType = prefs.getUChar("type", (uint8_t)SoilType::GARDEN);
    currentSoilType = savedType <= (uint8_t)SoilType::BARREN ? (SoilType)savedType : SoilType::GARDEN;
    adcDry = prefs.getInt("adc_dry", DEFAULT_ADC_DRY);
    adcWet = prefs.getInt("adc_wet", DEFAULT_ADC_WET);
    Serial.printf("Loai dat dang do: %s | Hieu chuan ADC: kho=%d, uot=%d\n",
                  SoilEstimator::profile(currentSoilType).label, adcDry, adcWet);

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

    // Kết nối mạng, đồng bộ giờ thực Việt Nam (UTC+7) qua NTP, chạy nền và tự thử lại
    setupWiFi();
    configTzTime("ICT-7", "pool.ntp.org", "time.google.com");

    // MQTT qua TLS: xác thực chứng chỉ broker bằng Root CA, chống kết nối nhầm máy chủ giả
    secureClient.setCACert(ROOT_CA_BUNDLE);
    secureClient.setHandshakeTimeout(10);
    mqttClient.setServer(MQTT_HOST, MQTT_PORT);
    mqttClient.setCallback(onMqttMessage);
    // Bộ đệm mặc định 256 byte không đủ chứa topic + JSON telemetry (~350 byte) -> nâng lên 512
    mqttClient.setBufferSize(512);
}

// -------------------------------------------------------------
// VÒNG LẶP CHÍNH (LOOP)
// -------------------------------------------------------------
void loop() {
    // Duy trì kết nối WiFi Multi & MQTT
    if (wifiMulti.run() == WL_CONNECTED) {
        if (!mqttClient.connected() && millis() - lastMqttAttempt >= MQTT_RETRY_INTERVAL) {
            lastMqttAttempt = millis();
            tryConnectMqtt();
        }
        mqttClient.loop();
    }

    unsigned long now = millis();
    if (lastTelemetryTime == 0 || now - lastTelemetryTime >= TELEMETRY_INTERVAL) {
        lastTelemetryTime = now;

        // 1. Đọc cảm biến nước qua bộ lọc trung bình cắt tỉa
        AdcReading adc = readFilteredADC(PIN_WATER_SENSOR);

        // 2. Chuyển đổi ADC -> % Độ ẩm & Ước lượng chỉ số dinh dưỡng theo loại đất đang đo
        float moisture = SoilEstimator::calculateMoisture(adc.value, adcDry, adcWet);
        SoilNutrientData soil = SoilEstimator::estimate(moisture, 0.0f, currentSoilType);
        const SoilProfile soilProfile = SoilEstimator::profile(currentSoilType);

        // Cơ chế bảo vệ nông học tự động: Nếu đất đã úng nước (> 85%) mà bơm đang bật -> tự động ngắt
        if (soil.moisture > 85.0f && pumpActive) {
            pumpActive = false;
            digitalWrite(PIN_RELAY_PUMP, RELAY_OFF);
            Serial.println(F("⚠️ [TỰ ĐỘNG BẢO VỆ NÔNG HỌC] Đất đã úng nước (> 85%) -> Tự động ngắt bơm an toàn!"));
        }

        // Hệ thống Đèn LED 3 Cấp Độ (Đỏ - Vàng - Xanh):
        // 🔴 ĐỎ (Nguy hiểm): Khô cằn < 35%, Ngập úng > 80%, Mặn EC > 1800, Nghèo kiệt EC < 300, Chua pH < 5.5
        // 🟡 VÀNG (Cảnh báo nhẹ / Đang tưới): Hơi khô (35 - 49%), Hơi ẩm (71 - 80%), Thiếu N/P/K hoặc Bơm đang chạy
        // 🟢 XANH (Lý tưởng): Đất màu mỡ, ẩm 50 - 70%, pH, EC và N-P-K cân đối
        bool isDanger = (soil.moisture < 35.0f || soil.moisture > 80.0f ||
                         soil.ec > 1800.0f || soil.ec < 300.0f || soil.ph < 5.5f);
        bool lacksNPK = (soil.nitrogen < 50.0f || soil.phosphorus < 30.0f || soil.potassium < 80.0f);
        bool isWarning = (!isDanger && (soil.moisture < 50.0f || soil.moisture > 70.0f || lacksNPK || pumpActive));
        bool isOptimal = (!isDanger && !isWarning);

        digitalWrite(PIN_LED_ALERT,   isDanger  ? HIGH : LOW);
        digitalWrite(PIN_LED_WARNING, isWarning ? HIGH : LOW);
        digitalWrite(PIN_LED_NORMAL,  isOptimal ? HIGH : LOW);

        // 3. Cập nhật màn hình OLED (Tự động bỏ qua nếu không cắm OLED)
        updateOLED(soilProfile.label, soil);

        // 4. In ra Serial Monitor để kiểm tra và lấy số liệu hiệu chuẩn
        Serial.printf("[SENSOR] Dat: %-8s | ADC: %4d (+-%.1f) | Am: %5.1f%% | EC: %5.0f | N: %4.1f | P: %4.1f | K: %4.1f | pH: %3.1f | Bom: %s\n",
                      soilProfile.label, adc.value, adc.noise, soil.moisture,
                      soil.ec, soil.nitrogen, soil.phosphorus, soil.potassium, soil.ph, pumpActive ? "ON" : "OFF");

        // 5. Đóng gói JSON và gửi MQTT lên Cloud cho Mobile App
        if (mqttClient.connected()) {
            StaticJsonDocument<512> doc;
            doc["device_id"] = "esp32_soil_station_01";
            // Giờ thực từ NTP (Unix epoch). Chưa đồng bộ được thì bỏ trống để App dùng giờ nhận bản tin
            time_t epoch = time(nullptr);
            if (epoch > VALID_EPOCH) doc["timestamp"] = (uint32_t)epoch;
            doc["soil_type"] = soilProfile.code;

            JsonObject telemetry = doc.createNestedObject("telemetry");
            telemetry["nitrogen"]   = round1(soil.nitrogen);
            telemetry["phosphorus"] = round1(soil.phosphorus);
            telemetry["potassium"]  = round1(soil.potassium);
            telemetry["ph"]         = round1(soil.ph);
            telemetry["ec"]         = round1(soil.ec);
            telemetry["moisture"]   = round1(soil.moisture);

            JsonObject adcInfo = doc.createNestedObject("adc");
            adcInfo["raw"]   = adc.value;
            adcInfo["noise"] = round1(adc.noise);
            adcInfo["dry"]   = adcDry;
            adcInfo["wet"]   = adcWet;

            JsonObject actuators = doc.createNestedObject("actuators");
            actuators["pump"]           = pumpActive;
            actuators["nutrient_valve"] = valveActive;

            char jsonBuffer[512];
            serializeJson(doc, jsonBuffer);
            if (mqttClient.publish(TOPIC_TELEMETRY, jsonBuffer)) {
                Serial.println("=> Da gui MQTT thanh cong len topic: " + String(TOPIC_TELEMETRY));
            } else {
                Serial.println(F("=> Gui MQTT that bai (ban tin vuot bo dem hoac mat ket noi)"));
            }
        }
    }
}
