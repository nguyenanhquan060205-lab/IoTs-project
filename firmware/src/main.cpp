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
#include <esp_sntp.h>
#include "soil_estimator.h"
#include "adc_filter.h"
#include "root_ca.h"

#if __has_include("secrets.h")
#include "secrets.h"
#define HAS_SECRETS 1
#else
// Chưa tạo secrets.h (ví dụ chạy trên Wokwi): dùng broker công cộng qua TLS, có mã hóa nhưng chưa có tài khoản.
// Trên mạch thật thì phải tạo secrets.h, nếu không trạm chỉ thử WiFi mẫu "iPhone" / "password" bên dưới.
#warning "Chua co firmware/src/secrets.h: tram se dung WiFi mau 'iPhone'. Chep secrets.example.h thanh secrets.h va dien WiFi that truoc khi nap vao mach that."
#define HAS_SECRETS 0
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
 * EC, pH ước lượng từ độ ẩm theo loại đất do App chọn; N, P, K tính từ EC và so với mức bình thường của loại đất
 * Tùy chọn cắm thêm: OLED 0.96" I2C
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
#define PIN_BUZZER        25   // Còi cảnh báo (chủ động hay thụ động đều kêu vì được phát bằng PWM)
#define PIN_LED_ALERT     32   // LED đỏ (Báo động nguy hiểm: Khô cằn / Ngập úng / Chua phèn / Mặn)
#define PIN_LED_WARNING   19   // LED vàng (Cảnh báo nhẹ / Cần theo dõi)
#define PIN_LED_NORMAL    33   // LED xanh (Đất màu mỡ, dinh dưỡng & độ ẩm chuẩn)

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
// Mốc đã được đo thật (có trong NVS) hay vẫn là số mặc định ở trên
bool dryCalibrated = false;
bool wetCalibrated = false;

// 5. Còi: kêu vài tiếng ngắn khi đất vừa chuyển sang quá khô hoặc ngập úng
const uint32_t BUZZER_FREQ = 2700;  // Hz, gần tần số cộng hưởng của đa số còi nhỏ
const uint8_t BUZZER_CHANNEL = 0;   // Kênh LEDC, chỉ cần cho Arduino-ESP32 bản 2.x
const float DRY_ALARM = 35.0f;      // Dưới ngưỡng này là quá khô (trùng đèn đỏ)
const float WET_ALARM = 80.0f;      // Trên ngưỡng này là ngập úng (trùng đèn đỏ)
const float ALARM_HYSTERESIS = 3.0f; // Phải về trong khoảng 38 - 77% mới hết báo, tránh kêu liên tục quanh ngưỡng
bool moistureAlarm = false;

WiFiClientSecure secureClient;
WiFiClient plainClient;  // Chỉ dùng khi chạy mô phỏng trên Wokwi
PubSubClient mqttClient(secureClient);

// Loại đất và mốc hiệu chuẩn lưu vào flash (NVS) để khởi động lại vẫn giữ
Preferences prefs;
SoilType currentSoilType = SoilType::GARDEN;

// Biến lưu trạng thái hoạt động
bool hasOLED = false;
unsigned long lastTelemetryTime = 0;
unsigned long lastMqttAttempt = 0;
unsigned long lastWifiAttempt = 0;
unsigned long lastStatusPublish = 0;
String mqttClientId;
// Đo thời gian lấy giờ NTP (Bảng 4.2 của báo cáo): mốc lúc WiFi vừa nối, mốc lúc SNTP đặt giờ lần đầu
// (ghi trong callback của SNTP nên không bị lệch khi loop() đang bận bắt tay TLS) và cờ đã in log hay chưa
unsigned long wifiConnectedAt = 0;
bool wifiWasUp = false;
volatile unsigned long ntpSyncedAt = 0;
bool ntpLogged = false;

void onTimeSynced(struct timeval* tv) {
    (void)tv;
    if (ntpSyncedAt == 0) ntpSyncedAt = millis();  // SNTP đồng bộ lại mỗi giờ, chỉ giữ lần đầu
}
const unsigned long TELEMETRY_INTERVAL = 4000;   // 4 giây gửi 1 lần
// Gửi lại "online" (giữ lại trên broker) 30 giây 1 lần. Trạm khởi động lại thì phiên MQTT cũ còn treo trên broker
// khoảng 22 giây (1,5 lần keep-alive 15 giây) rồi broker mới đăng LWT "offline" của phiên cũ, đè lên "online"
// của phiên mới. Gửi lại định kỳ để topic status trở về "online" sau tối đa 30 giây.
const unsigned long STATUS_REFRESH_INTERVAL = 30000;
const unsigned long MQTT_RETRY_INTERVAL = 5000;  // Mất kết nối broker thì 5 giây thử lại 1 lần
// Mất WiFi thì 15 giây mới dò lại 1 lần: mỗi lần dò chặn vài giây, giữa các lần trạm vẫn đo và báo đèn
const unsigned long WIFI_RETRY_INTERVAL = 15000;
const time_t VALID_EPOCH = 1700000000;           // Đồng hồ chưa qua mốc 11/2023 nghĩa là chưa đồng bộ NTP

// Làm tròn 1 chữ số lẻ bằng double: kết quả float như 7.1f khi ghi ra JSON sẽ thành 7.099999905
double round1(float value) {
    return round(value * 10.0) / 10.0;
}

// -------------------------------------------------------------
// Còi phát bằng PWM (LEDC): còi thụ động cần sóng vuông để kêu, còi chủ động cũng kêu được với sóng này
// -------------------------------------------------------------
void buzzerTone(uint32_t freq) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcWriteTone(PIN_BUZZER, freq);
#else
    ledcWriteTone(BUZZER_CHANNEL, freq);
#endif
}

void setupBuzzer() {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcAttach(PIN_BUZZER, BUZZER_FREQ, 10);
#else
    ledcSetup(BUZZER_CHANNEL, BUZZER_FREQ, 10);
    ledcAttachPin(PIN_BUZZER, BUZZER_CHANNEL);
#endif
    buzzerTone(0);  // Tần số 0 = tắt còi
}

// Kêu `count` tiếng ngắn (3 tiếng mất khoảng 0,6 giây)
void beep(int count) {
    for (int i = 0; i < count; i++) {
        buzzerTone(BUZZER_FREQ);
        delay(120);
        buzzerTone(0);
        if (i + 1 < count) delay(100);
    }
}

// -------------------------------------------------------------
// Hàm hiển thị thông số lên màn hình OLED (Tự động bỏ qua nếu không cắm OLED)
// -------------------------------------------------------------
void updateOLED(const SoilProfile& soilProfile, const SoilNutrientData& soil, NutrientLevel npkLevel) {
    if (!hasOLED) return; // Không cắm OLED thì bỏ qua, không bao giờ bị đơ treo I2C
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);

    // Tiêu đề: Loại đất đang đo + trạng thái WiFi
    display.setCursor(0, 0);
    display.printf("%-9s %s", soilProfile.label, WiFi.status() == WL_CONNECTED ? "WIFI OK" : "NO WIFI");
    display.drawLine(0, 10, 127, 10, SSD1306_WHITE);

    // Dòng 1: Độ ẩm & EC
    display.setCursor(0, 13);
    display.printf("Am: %.1f%%  EC: %.0f", soil.moisture, soil.ec);

    // Dòng 2: N, P, K tính từ EC
    display.setCursor(0, 23);
    display.printf("N:%.0f  P:%.0f  K:%.0f", soil.nitrogen, soil.phosphorus, soil.potassium);

    // Dòng 3: Mức N/P/K bình thường của loại đất và N-P-K đang thấp / OK / cao so với mức đó
    display.setCursor(0, 33);
    display.printf("Chuan:%.0f/%.0f/%.0f %s", soilProfile.nitrogenNormal, soilProfile.phosphorusNormal,
                   soilProfile.potassiumNormal, SoilEstimator::levelLabel(npkLevel));

    // Dòng 4: pH + nhãn nhắc N-P-K, EC, pH là số ước lượng
    display.setCursor(0, 43);
    display.printf("pH: %.1f  UOC LUONG", soil.ph);

    // Dòng 5: Trạng thái MQTT và giờ thực lấy từ NTP
    char clock[6] = "--:--";
    time_t epoch = time(nullptr);
    if (epoch > VALID_EPOCH) {
        struct tm timeinfo;
        localtime_r(&epoch, &timeinfo);
        strftime(clock, sizeof(clock), "%H:%M", &timeinfo);
    }
    display.drawLine(0, 52, 127, 52, SSD1306_WHITE);
    display.setCursor(0, 55);
    display.printf("%s  %s", mqttClient.connected() ? "MQTT" : "----", clock);

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
    // Chỉ so với mốc còn lại khi mốc đó đã được đo thật. Mốc mặc định (200 / 3000) chưa phải số đo:
    // so với nó sẽ chặn nhầm đầu dò điện dung có ADC lúc khô khoảng 2800 ngay ở bước đầu tiên.
    bool otherCalibrated = isDry ? wetCalibrated : dryCalibrated;
    int otherPoint = isDry ? adcWet : adcDry;
    if (otherCalibrated && abs(reading.value - otherPoint) < MIN_CALIBRATION_GAP) {
        Serial.printf("=> Bo qua: ADC %d qua gan moc %s da luu (%d). Dau do da %s chua?\n",
                      reading.value, isDry ? "uot" : "kho", otherPoint,
                      isDry ? "duoc lau kho" : "nhung vao nuoc");
        return;
    }

    if (isDry) {
        adcDry = reading.value;
        dryCalibrated = true;
        prefs.putInt("adc_dry", adcDry);
    } else {
        adcWet = reading.value;
        wetCalibrated = true;
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

    if (strcmp(action, "SET_SOIL_TYPE") == 0) {
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

    // Mỗi lần run() dò sóng một lượt rồi chờ kết nối tối đa 8 giây. Chỉ thử 2 lần để sai mật khẩu
    // hay không có mạng cũng chỉ chặn khoảng 25 giây lúc khởi động, sau đó loop() tự dò lại
    Serial.printf("Dang ket noi WiFi \"%s\" (hoac \"%s\" khi mo phong)", WIFI_SSID, WOKWI_SSID);
    for (int attempt = 0; attempt < 2 && wifiMulti.run(8000) != WL_CONNECTED; attempt++) {
        Serial.print(".");
    }

    if (WiFi.status() == WL_CONNECTED) {
        wifiConnectedAt = millis();
        wifiWasUp = true;
        Serial.println("\n✅ WiFi da ket noi!");
        Serial.print("   SSID: ");
        Serial.println(WiFi.SSID());
        Serial.print("   Dia chi IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println(F("\n⚠️ Chua vao duoc WiFi. Kiem tra ten mang, mat khau trong secrets.h va mang phai la 2.4 GHz."));
        Serial.printf("   Tram van do va bao den binh thuong, %lu giay se do tim WiFi lai 1 lan.\n",
                      WIFI_RETRY_INTERVAL / 1000);
    }
    lastWifiAttempt = millis();
}

// Báo Online (giữ lại trên broker để ai đăng ký sau cũng biết trạm đang chạy, đè lên bản tin offline)
void publishOnlineStatus() {
    StaticJsonDocument<128> statusDoc;
    statusDoc["status"] = "online";
    statusDoc["device"] = mqttClientId.c_str();
    char buffer[128];
    serializeJson(statusDoc, buffer);
    mqttClient.publish(TOPIC_STATUS, buffer, true);
    lastStatusPublish = millis();
}

// Thử kết nối broker 1 lần, không chặn vòng lặp để OLED và LED vẫn chạy khi broker lỗi
void tryConnectMqtt() {
    // Mạng ảo Wokwi-GUEST không bắt tay TLS được (thử cả www.google.com:443 cũng bị ngắt),
    // nên khi chạy mô phỏng thì dùng MQTT không mã hóa cổng 1883. Ở mạng thật luôn dùng TLS.
    bool useTls = WiFi.SSID() != WOKWI_SSID;
    uint16_t port = useTls ? MQTT_PORT : 1883;
    mqttClient.setClient(useTls ? static_cast<Client&>(secureClient) : static_cast<Client&>(plainClient));
    mqttClient.setServer(MQTT_HOST, port);
    Serial.printf("Dang ket noi MQTT %s:%u (%s)...", MQTT_HOST, port, useTls ? "TLS" : "khong ma hoa, mo phong Wokwi");
    mqttClientId = "ESP32_Soil_" + String(random(0xffff), HEX);
    // LWT: trạm rút điện hay mất mạng đột ngột thì broker tự đăng "offline" (giữ lại) lên topic status
    bool hasAccount = strlen(MQTT_USERNAME) > 0;
    // Đo thời gian mở kết nối (gồm bắt tay TLS) và gói CONNECT, dùng cho Bảng 4.3 của báo cáo
    unsigned long connectStarted = millis();
    bool connected = mqttClient.connect(mqttClientId.c_str(),
                                        hasAccount ? MQTT_USERNAME : nullptr,
                                        hasAccount ? MQTT_PASSWORD : nullptr,
                                        TOPIC_STATUS, 1, true, "{\"status\":\"offline\"}");
    unsigned long connectMs = millis() - connectStarted;
    if (!connected) {
        // rc = -2: không mở được kết nối (sai host/cổng, chứng chỉ TLS), rc = 4/5: sai tài khoản
        Serial.printf(" That bai sau %lu ms, rc=%d. Thu lai sau %lu giay...\n",
                      connectMs, mqttClient.state(), MQTT_RETRY_INTERVAL / 1000);
        return;
    }

    Serial.printf(" Thanh cong! (%lu ms, heap trong %u byte)\n", connectMs, (unsigned)ESP.getFreeHeap());
    mqttClient.subscribe(TOPIC_COMMAND);
    Serial.printf("Da dang ky lang nghe: %s\n", TOPIC_COMMAND);
    publishOnlineStatus();
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

#if !HAS_SECRETS
    Serial.println(F("[CANH BAO] Chua co secrets.h: dang thu WiFi mau \"iPhone\". Tao secrets.h roi nap lai."));
#endif

    // Cấu hình chân vào/ra (I/O)
    pinMode(PIN_WATER_SENSOR, INPUT);
    setupBuzzer();
    pinMode(PIN_LED_ALERT, OUTPUT);
    pinMode(PIN_LED_WARNING, OUTPUT);
    pinMode(PIN_LED_NORMAL, OUTPUT);

    // Mặc định tắt đèn cảnh báo
    digitalWrite(PIN_LED_ALERT, LOW);
    digitalWrite(PIN_LED_WARNING, LOW);
    digitalWrite(PIN_LED_NORMAL, HIGH);

    // Đọc loại đất và mốc hiệu chuẩn đã lưu lần trước
    prefs.begin("soil", false);
    uint8_t savedType = prefs.getUChar("type", (uint8_t)SoilType::GARDEN);
    currentSoilType = savedType <= (uint8_t)SoilType::BARREN ? (SoilType)savedType : SoilType::GARDEN;
    dryCalibrated = prefs.isKey("adc_dry");
    wetCalibrated = prefs.isKey("adc_wet");
    adcDry = prefs.getInt("adc_dry", DEFAULT_ADC_DRY);
    adcWet = prefs.getInt("adc_wet", DEFAULT_ADC_WET);
    Serial.printf("Loai dat dang do: %s | Hieu chuan ADC: kho=%d%s, uot=%d%s\n",
                  SoilEstimator::profile(currentSoilType).label,
                  adcDry, dryCalibrated ? "" : " (mac dinh)",
                  adcWet, wetCalibrated ? "" : " (mac dinh)");

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
    sntp_set_time_sync_notification_cb(onTimeSynced);
    configTzTime("ICT-7", "pool.ntp.org", "time.google.com");

    // MQTT qua TLS: xác thực chứng chỉ broker bằng Root CA, chống kết nối nhầm máy chủ giả
    secureClient.setCACert(ROOT_CA_BUNDLE);
    secureClient.setHandshakeTimeout(10);
    mqttClient.setCallback(onMqttMessage);
    // Bộ đệm mặc định 256 byte không đủ chứa topic + JSON telemetry (~450 byte) -> nâng lên 768
    mqttClient.setBufferSize(768);
}

// -------------------------------------------------------------
// VÒNG LẶP CHÍNH (LOOP)
// -------------------------------------------------------------
void loop() {
    // Duy trì kết nối WiFi Multi & MQTT. Đang có WiFi thì không gọi wifiMulti.run() (lệnh dò sóng chặn vài giây),
    // mất WiFi thì WIFI_RETRY_INTERVAL mới dò lại 1 lần để vẫn đo, báo đèn và còi đúng nhịp 4 giây
    bool wifiUp = WiFi.status() == WL_CONNECTED;
    if (!wifiUp && millis() - lastWifiAttempt >= WIFI_RETRY_INTERVAL) {
        Serial.println(F("[WIFI] Mat ket noi, dang do tim lai..."));
        wifiUp = wifiMulti.run(8000) == WL_CONNECTED;
        lastWifiAttempt = millis();
        if (wifiUp) Serial.printf("[WIFI] Da ket noi lai \"%s\"\n", WiFi.SSID().c_str());
    }
    // Ghi lại lúc WiFi vừa nối (kể cả khi ESP32 tự nối lại) để đo thời gian lấy giờ NTP
    if (wifiUp && !wifiWasUp) wifiConnectedAt = millis();
    wifiWasUp = wifiUp;

    // In một lần mỗi lần khởi động: sau bao lâu kể từ khi có WiFi thì SNTP đặt được giờ thực
    unsigned long syncedAt = ntpSyncedAt;
    if (!ntpLogged && syncedAt != 0 && wifiConnectedAt != 0 && syncedAt >= wifiConnectedAt) {
        time_t epoch = time(nullptr);
        struct tm timeinfo;
        char when[20];
        localtime_r(&epoch, &timeinfo);
        strftime(when, sizeof(when), "%Y-%m-%d %H:%M:%S", &timeinfo);
        Serial.printf("[NTP] Da co gio sau %lu ms ke tu khi co WiFi: %s (ICT)\n",
                      syncedAt - wifiConnectedAt, when);
        ntpLogged = true;
    }

    if (wifiUp) {
        if (!mqttClient.connected() && millis() - lastMqttAttempt >= MQTT_RETRY_INTERVAL) {
            lastMqttAttempt = millis();
            tryConnectMqtt();
        }
        mqttClient.loop();
        if (mqttClient.connected() && millis() - lastStatusPublish >= STATUS_REFRESH_INTERVAL) {
            publishOnlineStatus();
        }
    }

    unsigned long now = millis();
    if (lastTelemetryTime == 0 || now - lastTelemetryTime >= TELEMETRY_INTERVAL) {
        lastTelemetryTime = now;

        // 1. Đọc cảm biến nước qua bộ lọc trung bình cắt tỉa
        AdcReading adc = readFilteredADC(PIN_WATER_SENSOR);

        // 2. Chuyển đổi ADC -> % Độ ẩm -> EC -> N, P, K, rồi so N, P, K với mức bình thường của loại đất đang đo
        float moisture = SoilEstimator::calculateMoisture(adc.value, adcDry, adcWet);
        SoilNutrientData soil = SoilEstimator::estimate(moisture, 0.0f, currentSoilType);
        const SoilProfile soilProfile = SoilEstimator::profile(currentSoilType);
        const NpkLevels npkLevels = SoilEstimator::compareNpk(soil, currentSoilType);
        const NutrientLevel npkLevel = SoilEstimator::overallLevel(npkLevels);

        // Hệ thống Đèn LED 3 Cấp Độ (Đỏ - Vàng - Xanh):
        // 🔴 ĐỎ (Nguy hiểm): Khô cằn < 35%, Ngập úng > 80%, Mặn EC > 1800, Nghèo kiệt EC < 300, Chua pH < 5.5
        // 🟡 VÀNG (Cảnh báo nhẹ): Hơi khô (35 - 49%), Hơi ẩm (71 - 80%), N/P/K thấp hơn mức bình thường
        //    của loại đất
        // 🟢 XANH (Lý tưởng): Đất màu mỡ, ẩm 50 - 70%, pH, EC và N-P-K cân đối
        bool isDanger = (soil.moisture < 35.0f || soil.moisture > 80.0f ||
                         soil.ec > 1800.0f || soil.ec < 300.0f || soil.ph < 5.5f);
        bool lacksNPK = (npkLevel == NutrientLevel::BELOW);
        bool isWarning = (!isDanger && (soil.moisture < 50.0f || soil.moisture > 70.0f || lacksNPK));
        bool isOptimal = (!isDanger && !isWarning);

        digitalWrite(PIN_LED_ALERT,   isDanger  ? HIGH : LOW);
        digitalWrite(PIN_LED_WARNING, isWarning ? HIGH : LOW);
        digitalWrite(PIN_LED_NORMAL,  isOptimal ? HIGH : LOW);

        // 3. Cập nhật màn hình OLED (Tự động bỏ qua nếu không cắm OLED)
        updateOLED(soilProfile, soil, npkLevel);

        // 4. In ra Serial Monitor để kiểm tra và lấy số liệu hiệu chuẩn
        Serial.printf("[SENSOR] Dat: %-8s | ADC: %4d (+-%.1f) | Am: %5.1f%% | EC: %5.0f | N: %4.1f | P: %4.1f | K: %4.1f"
                      " (chuan %.0f/%.0f/%.0f: %s) | pH: %3.1f\n",
                      soilProfile.label, adc.value, adc.noise, soil.moisture,
                      soil.ec, soil.nitrogen, soil.phosphorus, soil.potassium,
                      soilProfile.nitrogenNormal, soilProfile.phosphorusNormal, soilProfile.potassiumNormal,
                      SoilEstimator::levelLabel(npkLevel), soil.ph);

        // 5. Đóng gói JSON và gửi MQTT lên Cloud cho Mobile App
        if (mqttClient.connected()) {
            StaticJsonDocument<768> doc;
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

            // Mức N, P, K bình thường của loại đất và N, P, K đang thấp / bình thường / cao so với mức đó
            JsonObject npkNormalInfo = doc.createNestedObject("npk_normal");
            npkNormalInfo["nitrogen"]   = soilProfile.nitrogenNormal;
            npkNormalInfo["phosphorus"] = soilProfile.phosphorusNormal;
            npkNormalInfo["potassium"]  = soilProfile.potassiumNormal;

            JsonObject npkLevelInfo = doc.createNestedObject("npk_level");
            npkLevelInfo["nitrogen"]   = SoilEstimator::levelCode(npkLevels.nitrogen);
            npkLevelInfo["phosphorus"] = SoilEstimator::levelCode(npkLevels.phosphorus);
            npkLevelInfo["potassium"]  = SoilEstimator::levelCode(npkLevels.potassium);

            JsonObject adcInfo = doc.createNestedObject("adc");
            adcInfo["raw"]   = adc.value;
            adcInfo["noise"] = round1(adc.noise);
            adcInfo["dry"]   = adcDry;
            adcInfo["wet"]   = adcWet;

            char jsonBuffer[640];
            serializeJson(doc, jsonBuffer, sizeof(jsonBuffer));
            if (doc.overflowed()) {
                Serial.println(F("=> [LOI] Bo nho JSON khong du, ban tin bi thieu truong"));
            }
            if (mqttClient.publish(TOPIC_TELEMETRY, jsonBuffer)) {
                Serial.println("=> Da gui MQTT thanh cong len topic: " + String(TOPIC_TELEMETRY));
            } else {
                Serial.println(F("=> Gui MQTT that bai (ban tin vuot bo dem hoac mat ket noi)"));
            }
        }

        // 6. Còi kêu 3 tiếng khi đất VỪA chuyển sang quá khô hoặc ngập úng (để sau khi gửi MQTT cho số liệu đi đúng giờ).
        // Hết báo khi độ ẩm về hẳn khoảng 38 - 77%, nên độ ẩm dao động quanh ngưỡng không làm còi kêu liên tục
        bool moistureExtreme = soil.moisture < DRY_ALARM || soil.moisture > WET_ALARM;
        bool moistureBackToNormal = soil.moisture >= DRY_ALARM + ALARM_HYSTERESIS &&
                                    soil.moisture <= WET_ALARM - ALARM_HYSTERESIS;
        if (!moistureAlarm && moistureExtreme) {
            moistureAlarm = true;
            Serial.printf("[CANH BAO] Dat %s (%.1f%%) -> coi bao 3 tieng\n",
                          soil.moisture < DRY_ALARM ? "qua kho" : "ngap ung", soil.moisture);
            beep(3);
        } else if (moistureAlarm && moistureBackToNormal) {
            moistureAlarm = false;
        }
    }
}
