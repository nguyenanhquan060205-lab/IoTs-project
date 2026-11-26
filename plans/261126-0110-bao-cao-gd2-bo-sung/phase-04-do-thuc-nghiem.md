---
phase: 4
title: "Đo thực nghiệm trên mạch thật"
status: pending
priority: P1
effort: "7h30m"
dependencies: [1, 2]
---

# Phase 4: Đo thực nghiệm trên mạch thật

## Goal

Lấy đủ số đo thật và ảnh cho Chương 4 (cùng Hình 3.2, 3.5, 3.7), lưu tệp gốc vào repo để con số nào trong báo cáo cũng truy lại được. Phần 4A Claude tự chạy qua COM7 và MQTT, phần 4B làm cùng nhóm, phần 4C là ảnh Claude dựng từ số đo thật.

## Bối cảnh

- Trạm cắm ở COM7 (chip CP210x), đã nạp firmware ngày 2026-11-26, vào được Wi-Fi và `broker.emqx.io:8883`. Hai lần khởi động đã thấy: NTP 15349 và 15412 ms, kết nối MQTT 1533 và 2503 ms, bộ nhớ trống 167056 và 167076 byte. Mốc hiệu chuẩn vẫn là số mặc định 200 / 3000.
- Script đặt lại được trạm qua chân RTS của cổng Serial (nối vào EN), đã thử ngày 2026-11-26. Giữ RTS ở mức tích cực thì ESP32 đứng yên ở trạng thái reset, Wi-Fi tắt, broker không nhận gói DISCONNECT: về phía broker giống rút nguồn.
- Trạm chỉ nhận lệnh qua MQTT, topic `soil_station/1/command`: `SET_SOIL_TYPE` và `CALIBRATE` (`dry` / `wet`).
- Trong `firmware/src/main.cpp`: `configTzTime("ICT-7", "pool.ntp.org", "time.google.com")` gọi sau `setupWiFi()`; `useTls = WiFi.SSID() != WOKWI_SSID`; `ROOT_CA_BUNDLE` gồm DigiCert Global Root G2 (dùng cho broker.emqx.io) và ISRG Root X1.
- Máy có Python 3.14, Node 24, Chrome, Word, openssl (Git Bash). Chưa có paho-mqtt, Wireshark, MQTTX, adb. `scripts/.venv/` đã nằm trong `.gitignore`.
- Mức chuẩn để so là `npk_normal` trong bản tin. Tỉ số ước lượng / mức chuẩn = hằng số × độ ẩm. Khoảng độ ẩm cho mức bình thường (±20%), tính từ hệ số trong `soil_estimator.h`:

  | Loại đất | N | P | K | Lệch ở độ ẩm 60% (N / P / K) |
  |---|---|---|---|---|
  | Đất đóng bao | 47,5 – 71,3% | 50,0 – 75,0% | 49,1 – 73,6% | +1,1% / −4,0% / −2,2% |
  | Đất vườn | 48,1 – 72,2% | 48,9 – 73,3% | 48,5 – 72,7% | −0,3% / −1,8% / −1,0% |
  | Đất bạc màu | 50,0 – 75,0% | 50,0 – 75,0% | 54,5 – 81,8% | −4,0% / −4,0% / −12,0% |

  Số đo thật ở bước 4B.4 phải khớp bảng này (sai khác chỉ do độ ẩm đo được). Không khớp thì dừng lại kiểm tra trước khi điền báo cáo.

## Quy tắc

- Bản nạp tạm build từ bản sao của `firmware/` (bỏ thư mục `.pio`) trong scratchpad, bằng `pio run -d <bản sao> -t upload --upload-port COM7`. Không sửa `firmware/src`.
- Log đưa vào repo phải che tên Wi-Fi thành `<wifi>` và bỏ địa chỉ IP.
- Mỗi phép đo ghi một dòng vào `docs/thuc-nghiem/README.md`: ngày giờ, người làm, cách làm, tên tệp.
- Không sửa cột "Kết quả mong đợi" trong báo cáo sau khi đã thấy kết quả.

## Files to Create / Modify

- Create: `scripts/report_measure.py`: đo qua Serial và MQTT (các lệnh ở bước 4.0.2)
- Create: `scripts/test_report_measure.py`: kiểm thử các hàm thuần của script trên
- Create: `scripts/report_stats.js`: tính số cho báo cáo bằng chính các hàm trong `web/metrics.js`
- Modify: `web/metrics.js`, `web/metrics.test.js`: thêm `referenceFromNormal()`
- Modify: `web/evaluation.html`, `web/README.md`: tự điền mức chuẩn làm giá trị tham chiếu, bỏ chữ "bộ kit"
- Modify: `docs/hinh/ve_hinh.py`: thêm Hình 3.2
- Create: `docs/thuc-nghiem/README.md`, `docs/thuc-nghiem/*.csv`, `docs/thuc-nghiem/log/*.txt`
- Create: `docs/hinh/*.png`, `docs/hinh/*.jpg`: ảnh chụp và ảnh dựng

## Tasks & Steps

### 4.0 Công cụ

1. Tạo môi trường: `python -m venv scripts/.venv`, rồi `scripts/.venv/Scripts/python -m pip install paho-mqtt pyserial`.
2. `scripts/report_measure.py` (argparse). Mỗi lệnh ghi log thô kèm giờ máy tính và in bảng tóm tắt:
   - `boot --count N`: mỗi lần đặt lại trạm qua RTS, đọc Serial tới khi thấy dòng `[NTP]` (chờ tối đa 60 giây). Ghi ms NTP, ms kết nối MQTT, bộ nhớ trống, dòng `That bai` nếu có. In nhỏ nhất, trung vị, trung bình, lớn nhất.
   - `offset --count N`: hỏi giờ máy chủ NTP bằng một gói SNTP qua UDP (thư viện chuẩn, không cần cài) để biết đồng hồ máy tính lệch bao nhiêu. Đăng ký topic telemetry, so `timestamp` với giờ nhận đã bù độ lệch đó. Ghi kích thước bản tin (byte).
   - `soil-types`: gửi `SET_SOIL_TYPE` lần lượt potting, garden, barren. Với mỗi loại, chờ bản tin có `soil_type` mới rồi ghi 3 bản tin. Cuối cùng trả lại loại đất ban đầu.
   - `calibrate --point dry|wet`: gửi `CALIBRATE`, ghi khối `adc` của bản tin xác nhận và dòng Serial `DA LUU MOC` hoặc `Bo qua`.
   - `offline --hold 60 --count N`: giữ RTS tích cực, theo dõi topic status, ghi số giây tới khi thấy `offline`. Nhả RTS, ghi số giây tới `online` và tới bản tin telemetry đầu tiên.
   - `serial-log --minutes N`: chép Serial kèm giờ máy tính, dùng khi tắt router và khi chạy bản nạp tạm.
   - Hàm thuần (đọc dòng log, thống kê, giải mã gói SNTP, che tên Wi-Fi) đặt riêng, không import paho hay pyserial ở đầu tệp, để kiểm thử chạy được mà không cần cài gì.
3. `scripts/test_report_measure.py` (unittest), chạy bằng `cd scripts && python -m unittest test_report_measure`:
   - Đọc đúng `[NTP] Da co gio sau 15349 ms ke tu khi co WiFi: 2026-11-26 10:29:49 (ICT)` → 15349.
   - Đọc đúng `Thanh cong! (1533 ms, heap trong 167056 byte)` → 1533 và 167056; `That bai sau 812 ms, rc=-2` → 812 và −2.
   - Thống kê [15349, 15412] ra trung vị 15380,5.
   - Giải mã một gói SNTP 48 byte dựng sẵn ra đúng giờ Unix.
   - Che tên Wi-Fi trong dòng `Dang ket noi WiFi "abc"` và dòng `SSID: abc`, bỏ dòng `Dia chi IP`.
4. Trang web tự điền mức chuẩn:
   - `web/metrics.js`: thêm `referenceFromNormal(msg)` trả về `{n, p, k}` lấy từ `msg.npk_normal`, thiếu thì trả về `null` cho từng chất.
   - `web/metrics.test.js`: thêm ca có `npk_normal` và ca thiếu `npk_normal`.
   - `web/evaluation.html`, hàm `onCaptureMessage`: điền `ref.n`, `ref.p`, `ref.k` bằng `referenceFromNormal` của bản tin cuối, các chỉ số khác để trống. Ô vẫn sửa được. Đổi chữ ở gợi ý (dòng có "Ô tham chiếu nào bộ kit không đo") và chú thích bảng mẫu ("giá trị tham chiếu từ bộ kit") thành "mức chuẩn của loại đất". Nhãn trục biểu đồ: "Mức chuẩn" khi chỉ số là N, P, K.
   - `web/README.md`: sửa mục "Lấy một mẫu" và "Lưu ý khi so với bộ kit" theo cách mới.
   - Thử bằng `python scripts/simulate_station.py` (trạm giả có gửi `npk_normal`): lấy 1 mẫu, ô tham chiếu N, P, K tự có số, bảng kết quả có MAE.
5. `scripts/report_stats.js`: `node scripts/report_stats.js noise <csv>` in kết quả `noiseSummary`; `node scripts/report_stats.js samples <csv>` in MAE, RMSE, MAPE theo loại đất và chất (dùng `summarize` và `errorStats`). In ra bảng Markdown để chép vào báo cáo.

### 4A. Claude tự đo (không cần ai)

1. **Khởi động 10 lần** (Bảng 4.2 dòng 1, Bảng 4.3 dòng TLS của ESP32, Hình 4.1): `boot --count 10` → `log/khoi-dong-10-lan.txt`.
2. **Độ lệch giờ và kích thước bản tin** (Bảng 4.2 dòng 2, Chương 3 mục 3.3): `offset --count 5`, cách nhau vài phút → `log/do-lech-timestamp.txt`.
3. **Máy chủ NTP chính sai** (Bảng 4.2 dòng 4): bản nạp tạm đổi `"pool.ntp.org"` thành `"ntp.invalid"`, `boot --count 3` → `log/ntp-may-chu-chinh-sai.txt`. Ghi trạm có lấy được giờ từ time.google.com không và mất bao lâu.
4. **Không có giờ** (Bảng 4.2 dòng 5): bản nạp tạm đặt sai cả hai máy chủ, `serial-log --minutes 3` → `log/khong-co-gio.txt`. Ghi đúng những gì thấy: bản tin có `timestamp` không, TLS kết nối được không.
5. **CA sai** (Bảng 4.3 dòng 2): bản nạp tạm chỉ giữ ISRG Root X1 trong `ROOT_CA_BUNDLE`, `serial-log --minutes 1` → `log/ca-sai.txt`. Mong đợi `That bai sau ... ms, rc=-2` lặp lại 5 giây một lần.
6. **Không TLS** (Bảng 4.3 dòng Chi phí của TLS): bản nạp tạm đặt `useTls = false` (cổng 1883), `boot --count 5` → `log/khong-tls.txt`. So thời gian kết nối và bộ nhớ trống với bước 1.
7. Nạp lại firmware chính: `powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -Port COM7 -NoMonitor`. Kiểm tra `git diff --stat firmware/src` trống, rồi `boot --count 1` thấy đủ dòng NTP và MQTT.
8. **Mất nguồn và bật lại** (Bảng 4.4 dòng 1 và 3): `offline --hold 60 --count 3` → `log/mat-nguon.txt`.
9. **Chứng chỉ còn hạn** (Phụ lục dòng 3): tách 2 chứng chỉ trong `firmware/src/root_ca.h`, đọc ngày hết hạn bằng `openssl x509 -noout -subject -enddate` → `log/chung-chi.txt`.
10. **Không lộ thông tin cấu hình** (Phụ lục dòng 7): `git ls-files` chỉ có `secrets.example.h` và `mqtt_config.example.json`; `git log --all --oneline -- firmware/src/secrets.h mobile/mqtt_config.json` trống → `log/kiem-tra-bi-mat.txt`.

### 4B. Đo cùng nhóm (một buổi khoảng 2 giờ)

Nhóm chuẩn bị: 3 loại đất, 12 cốc mẫu ở 4 mức ẩm, một cốc đất vườn khoảng 50% và một cốc đất bạc màu khoảng 30% (đo nhiễu), cốc nước, khăn lau. Claude chạy script và trang web, nhóm làm phần cần tay và chụp ảnh.

1. **Hiệu chuẩn 3 lần** (Bảng 4.6): mỗi lần nhóm lau khô đầu dò, Claude chạy `calibrate --point dry`; nhóm nhúng đầu dò vào nước, Claude chạy `calibrate --point wet`. Ghi `adc.dry`, `adc.wet`, `adc.noise` lúc khô và lúc ướt → `log/hieu-chuan.txt`. Mốc của lần 3 là mốc trạm giữ trong NVS. Phải hiệu chuẩn xong mới làm các bước sau, vì độ ẩm tính theo 2 mốc này.
2. **Chọn loại đất** (Bảng 4.5 cột đo thật, Hình 4.4): đầu dò cắm yên trong cốc đất vườn khoảng 50%, Claude chạy `soil-types` → `log/chon-loai-dat.txt`. Ở mỗi loại đất, nhóm chụp màn hình app (ghi điểm trên app) và chụp OLED.
3. **Nhiễu bộ lọc** (Bảng 4.7): cốc đất vườn khoảng 50% (trạm đặt loại đất vườn), rồi cốc đất bạc màu khoảng 30% (trạm đặt loại đất bạc màu). Mỗi cốc chạy Đo nhiễu M = 100 trên trang web (khoảng 7 phút, không chạm vào), xuất `nhieu-dat-vuon.csv` và `nhieu-bac-mau.csv`.
4. **12 mẫu so với mức chuẩn** (Bảng 4.8, 4.9, Hình 4.6): với mỗi cốc, đặt loại đất của cốc, cắm đầu dò, chờ số đứng yên khoảng 1 phút, bấm Lấy mẫu trên trang web (mức chuẩn tự điền). Xong 12 mẫu thì xuất `mau-dat.csv`. Đối chiếu từng mẫu với bảng ở mục Bối cảnh.
5. **Mất Wi-Fi** (Bảng 4.4 dòng 2, Bảng 4.2 dòng 3): Claude chạy `serial-log`. Nhóm tắt router 1 phút rồi bật lại: OLED báo `NO WIFI`, trạm vẫn đo, ghi số giây tới khi gửi lại được. Lần 2 tắt 5 phút, so giờ trên OLED và `timestamp` bản tin đầu tiên với giờ máy tính → `log/mat-wifi.txt`.
6. **Rút USB thật 1 lần** để đối chiếu với bước 4A.8: Claude theo dõi topic status, ghi số giây tới `offline` → thêm vào `log/mat-nguon.txt`.
7. **App mất mạng** (Bảng 4.4 dòng 4): nhóm tắt Wi-Fi điện thoại 1 phút rồi bật lại, ghi app tự kết nối lại sau bao lâu. Nếu thử được 4G thì ghi app kết nối TLS và nhận số trên 4G (Phụ lục dòng 2).
8. **Ảnh nhóm chụp**, lưu vào `docs/hinh/`:
   - `hinh-3-5-chon-loai-dat.png`: màn Mẫu đất trên app
   - `hinh-4-3-app-thoi-gian-thuc.png`: app hiện "Cập nhật lúc" và trạng thái kết nối
   - `hinh-4-4-app-<loai-dat>.png` và `hinh-4-4-oled-<loai-dat>.jpg`: app và OLED ở 3 loại đất (lấy ở bước 2)
   - `hinh-4-5-mach-va-mau-dat.jpg`: mạch thật và các cốc mẫu
   - Đời máy điện thoại để điền Bảng 4.1

### 4C. Ảnh Claude dựng từ số đo thật

1. **Hình 3.2, sơ đồ nối chân**: thêm vào `docs/hinh/ve_hinh.py` theo Bảng 3.3 sau khi bỏ rơ-le (GPIO34, 21, 22, 32, 19, 33, 25) → `hinh-3-2-so-do-noi-chan.png`. Đối chiếu chân với `firmware/src/main.cpp` và `HARDWARE_CHECKLIST.md`.
2. **Hình 3.7, trang web**: chụp `web/evaluation.html` khi đang nhận bản tin thật, bằng Chrome chạy ẩn điều khiển qua DevTools Protocol (Node 24 có sẵn WebSocket, không cần cài gói) → `hinh-3-7-trang-web.png`.
3. **Hình 4.1, nhật ký Serial**: dựng ảnh dạng cửa sổ terminal từ log thật của bước 4A.1 (đã che tên Wi-Fi), xuất bằng Chrome chạy ẩn → `hinh-4-1-serial-ntp.png`.
4. **Hình 4.2, bản tin có timestamp**: chụp phần Trực tiếp của trang web (thấy `timestamp` và độ lệch giờ) → `hinh-4-2-ban-tin-timestamp.png`.
5. **Hình 4.4**: ghép 3 ảnh app (và OLED nếu có) của bước 4B.2 thành một ảnh → `hinh-4-4-ba-loai-dat.png`.
6. **Hình 4.6, biểu đồ ước lượng – mức chuẩn**: nhập `mau-dat.csv` vào trang web, chụp biểu đồ N, P, K rồi ghép thành một ảnh → `hinh-4-6-uoc-luong-muc-chuan.png`.

## Todo

- [x] 4.0: môi trường, `report_measure.py` và kiểm thử (13 ca qua), trang web tự điền mức chuẩn (14 kiểm thử qua, thử với trạm giả: ô tham chiếu tự điền 65 / 33 / 90), `report_stats.js`
- [x] 4A.1 – 4A.6: khởi động 10 lần, độ lệch giờ, 4 bản nạp tạm (số tóm tắt trong `docs/thuc-nghiem/so-lieu-bao-cao.md` mục 3)
- [x] 4A.7: nạp lại firmware chính, `git diff --stat firmware/src` trống, khởi động thấy TLS 8883 và dòng `[NTP]`
- [x] 4A.8: mất nguồn và bật lại, 3 lần: offline sau 28.0 – 32.6 s, online lại sau 12.1 – 12.5 s
- [x] 4A.9 – 4A.10: chứng chỉ (DigiCert Global Root G2 hết hạn 15/01/2038, ISRG Root X1 hết hạn 04/06/2035), thông tin cấu hình (`secrets.h` chưa từng commit)
- [ ] 4B.1: hiệu chuẩn 3 lần
- [ ] 4B.2 – 4B.4: chọn loại đất, nhiễu 2 cốc, 12 mẫu
- [ ] 4B.5 – 4B.7: mất Wi-Fi, rút USB, app mất mạng
- [ ] 4B.8: ảnh nhóm chụp và đời máy điện thoại
- [x] 4C.1: Hình 3.2 (`docs/hinh/hinh-3-2-so-do-noi-chan.png`); công cụ chụp trang web `docs/hinh/chup_trang_web.js` đã chạy được
- [x] 4C.2 – 4C.5: Hình 3.7, 4.1, 4.2, 4.4 với số thật; thêm Hình 3.5 và 4.3 chụp từ app bản Windows (nhóm chỉ còn chụp OLED và mạch). Bảng 4.5 cột đo thật đã có (mốc mặc định)
- [ ] 4C.6: Hình 4.6 (cần 12 mẫu ở 4B.4)
- [ ] `docs/thuc-nghiem/README.md` có một dòng cho mỗi phép đo

## Tiến độ

- 2026-11-26 12:43: lần chạy `boot --count 10` đầu tiên không mở được COM7, board đã được rút khỏi máy (broker giữ status `offline`). Phần 4A.1 – 4A.8 chờ cắm lại board.

## Verification

- `cd scripts && python -m unittest test_report_measure` và `node --test "web/*.test.js"` đều qua.
- `git diff --stat firmware/src` trống và Serial sau lần nạp cuối in đủ dòng `[NTP]` và `Thanh cong!`.
- `grep -ri "<tên Wi-Fi thật>" docs/thuc-nghiem docs/hinh` không ra kết quả nào, kể cả trong ảnh dựng.
- `mau-dat.csv` có 12 dòng, cột tham chiếu N, P, K bằng `npk_normal` của loại đất. Nhập lại bằng Nhập CSV trên trang web ra cùng số với `node scripts/report_stats.js samples`.
- Tỉ số ước lượng / mức chuẩn của từng mẫu khớp bảng ở mục Bối cảnh theo độ ẩm đo được.
- Mở từng ảnh trong `docs/hinh/`: đọc rõ chữ, không lộ tên Wi-Fi, IP hay mặt người.
