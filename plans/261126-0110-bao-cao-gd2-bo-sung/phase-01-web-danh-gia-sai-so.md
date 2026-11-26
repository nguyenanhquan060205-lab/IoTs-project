---
phase: 1
title: "Trang web đánh giá sai số"
status: completed
priority: P1
effort: "3h"
dependencies: []
---

# Phase 1: Trang web đánh giá sai số

## Goal

Một trang web mở thẳng từ máy (không cần máy chủ) nhận bản tin telemetry thật qua MQTT, cho nhập giá trị tham chiếu của từng mẫu đất, rồi tính và hiện MAE, RMSE, MAPE theo từng chỉ số, cùng phép đo nhiễu bộ lọc cho Bảng 4.7.

## Bối cảnh từ code

- Trạm gửi lên `soil_station/1/telemetry` mỗi 4 giây (`firmware/src/main.cpp`):
  `device_id`, `timestamp` (Unix, có thể thiếu nếu chưa có NTP), `soil_type`,
  `telemetry{nitrogen, phosphorus, potassium, ph, ec, moisture}`,
  `npk_normal{nitrogen, phosphorus, potassium}`, `npk_level{...: low|normal|high}`,
  `adc{raw, noise, dry, wet}`.
- `adc.noise` là độ lệch chuẩn của 21 mẫu thô trong một lần đo (chia cho n, `firmware/src/adc_filter.h:33`). `adc.raw` là giá trị sau lọc cắt tỉa.
- Topic `soil_station/1/status`: `{"status":"online","device":"ESP32_Soil_xxxx"}` được giữ lại trên broker và gửi lại mỗi 30 giây. LWT là `{"status":"offline"}`.
- Broker đang dùng: `broker.emqx.io`. Trình duyệt kết nối qua WebSocket có TLS, cổng 8084, đường dẫn `/mqtt`, giống `simulator/index.html` (thư viện Paho `mqttws31.min.js` 1.0.1 từ cdnjs, `useSSL: true`).

## Files to Create / Modify

- Create: `web/metrics.js`: hàm tính toán thuần, không đụng DOM.
- Create: `web/metrics.test.js`: kiểm thử bằng `node:test`.
- Create: `web/evaluation.html`: giao diện, kết nối MQTT, lưu mẫu, bảng, biểu đồ.
- Create: `web/README.md`: cách mở trang, định dạng CSV, cách đo.
- Modify: `README.md`: thêm một dòng trỏ tới `web/README.md`.

## Tasks & Steps

1. **`web/metrics.js` dạng script thường, không dùng ES module.** Mở trang bằng `file://` thì Chrome chặn `import` module do CORS. Bọc trong IIFE: chạy trong Node thì gán `module.exports`, chạy trong trình duyệt thì gán `window.SoilMetrics`. Các hàm:
   - `errorStats(pairs)` với `pairs = [{estimate, reference}]`, bỏ cặp thiếu số. Trả về `{n, mae, rmse, mape, mapeN}`, trong đó `e = estimate − reference`, `mae = mean|e|`, `rmse = sqrt(mean e²)`, `mape = 100 × mean|e / reference|` chỉ tính trên cặp có `reference ≠ 0` (`mapeN` là số cặp dùng được). `n = 0` thì trả về `null` cho từng số.
   - `sampleSd(values)`: độ lệch chuẩn mẫu, chia `m − 1` (đúng công thức SD ở mục 2.6 của báo cáo).
   - `adcToMoisturePercent(adcSd, dry, wet)`: đổi độ lệch ADC sang % độ ẩm, `= adcSd × 100 / |dry − wet|`. `dry = wet` thì trả về `null`.
   - `noiseSummary(messages)`: `{m, rawNoiseMean, filteredSd, reductionPercent, rawNoisePct, filteredSdPct}`. Trong đó `rawNoiseMean` là trung bình `adc.noise` (nhiễu khi không lọc), `filteredSd = sampleSd(adc.raw)` (nhiễu sau lọc), `reductionPercent = 100 × (1 − filteredSd / rawNoiseMean)`. Mốc dry/wet lấy từ bản tin cuối.
   - `averageTelemetry(messages)`: trung bình từng chỉ số của K bản tin gần nhất, dùng làm giá trị ước lượng của một mẫu.
   - `toCsv(samples)` và `fromCsv(text)`: UTF-8, có BOM để Excel đọc đúng dấu tiếng Việt. Cột: `sample_id, soil_type, moisture_level, captured_at, est_moisture, est_ec, est_n, est_p, est_k, est_ph, ref_moisture, ref_ec, ref_n, ref_p, ref_k, ref_ph, note`.
2. **`web/metrics.test.js`** (`node --test "web/*.test.js"`), tính tay để so:
   - `errorStats` với e = [1, −1, 2, −2]: MAE = 1,5, RMSE = √2,5 ≈ 1,5811.
   - MAPE bỏ qua `reference = 0` và trả `mapeN` đúng.
   - `n = 0` trả về `null`, không trả `NaN`.
   - `sampleSd([2, 4, 4, 4, 5, 5, 7, 9])` ≈ 2,138.
   - `adcToMoisturePercent(35, 3200, 1100)` ≈ 1,667, và `null` khi dry = wet.
   - `noiseSummary` với 3 bản tin dựng sẵn ra đúng `reductionPercent`.
   - `fromCsv(toCsv(x))` trả lại đúng `x`, kể cả ô trống và chữ có dấu.
3. **`web/evaluation.html`**: một tệp, CSS viết thẳng trong tệp, chỉ tải Paho từ CDN. Đọc skill `dataviz` trước khi vẽ biểu đồ. Bốn khu vực:
   - **Kết nối**: ô host, cổng, đường dẫn (mặc định `broker.emqx.io`, 8084, `/mqtt`), topic telemetry và status. Nút Kết nối / Ngắt, tự kết nối lại sau 5 giây. Không có ô mật khẩu vì broker công cộng không cần, cũng không lưu thông tin đăng nhập.
   - **Trực tiếp**: số đo mới nhất (độ ẩm, EC, N, P, K, pH, `soil_type`, `npk_level`), khối `adc` (raw, noise, dry, wet), trạng thái trạm từ topic status (online / offline, kèm giờ nhận), tuổi bản tin cuối (giây), và độ lệch `timestamp` so với giờ máy tính (dùng cho Bảng 4.2; ghi chú rằng con số này gồm cả độ trễ mạng).
   - **Mẫu đất**: chọn mức ẩm (khô kiệt / ẩm thấp / ẩm tối ưu / bão hòa), nhập mã mẫu, rồi bấm **Lấy mẫu**. Trang lấy trung bình K = 5 bản tin kế tiếp (khoảng 20 giây) làm giá trị ước lượng, ghi kèm `soil_type` của trạm. Sau đó nhập giá trị tham chiếu cho từng chỉ số; ô nào kit không đo thì để trống. Có bảng mẫu (sửa, xóa được), lưu vào `localStorage`, nút Xuất CSV / Nhập CSV.
   - **Kết quả**: bảng MAE, RMSE, MAPE kèm n cho từng chỉ số (độ ẩm, EC, N, P, K, pH), lọc được theo loại đất. Biểu đồ phân tán "ước lượng – tham chiếu" có đường y = x, chọn chỉ số cần xem (dùng cho Hình 4.7). Mỗi chỉ số hiện đúng đơn vị của nó; trang không gộp các chỉ số khác đơn vị thành một con số.
   - **Đo nhiễu**: nhập M (mặc định 100), bấm Bắt đầu. Trang gom M bản tin kế tiếp (khoảng 6,7 phút) và hiện kết quả `noiseSummary` bằng cả đơn vị ADC lẫn % độ ẩm, có nút Xuất CSV các bản tin thô. Dùng cho Bảng 4.6 và 4.7.
4. **Kiểm tra dữ liệu vào**: bỏ qua bản tin không phải JSON hoặc thiếu `telemetry`, ghi vào khung nhật ký nhỏ, không làm hỏng trang. `timestamp` thiếu thì ghi "trạm chưa có giờ NTP".
5. **`web/README.md`**: cách mở trang (bấm đúp vào tệp, cần Internet), quy trình lấy một mẫu, ý nghĩa từng cột CSV, và cách đọc phần đo nhiễu. Ghi rõ OLED không hiện sai số.

## Todo

- [x] `web/metrics.js` với `errorStats`, `sampleSd`, `adcToMoisturePercent`, `noiseSummary`, `averageTelemetry`, `toCsv`, `fromCsv`
- [x] `web/metrics.test.js` đủ 7 ca ở bước 2
- [x] `web/evaluation.html`: Kết nối, Trực tiếp, Mẫu đất, Kết quả (bảng và biểu đồ), Đo nhiễu
- [x] Xử lý bản tin hỏng và bản tin thiếu `timestamp`
- [x] `web/README.md` và một dòng trong `README.md`

## Verification

- `node --test "web/*.test.js"` qua hết.
- Chạy `python scripts/simulate_station.py` (gửi lên cùng broker), mở `web/evaluation.html`: phần Trực tiếp đổi mỗi vài giây, Lấy mẫu ra trung bình 5 bản tin, nhập tham chiếu thì bảng kết quả cập nhật.
- Đo nhiễu với M = 10 trên giả lập ra số hợp lý, không có `NaN` hay `Infinity`.
- Xuất CSV rồi Nhập lại ra cùng bảng; mở CSV bằng Excel thấy đúng dấu tiếng Việt.
- Trạm thật (sau phase 2): status đổi sang offline khoảng 20 – 25 giây sau khi rút nguồn trạm.
