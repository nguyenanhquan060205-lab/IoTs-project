---
phase: 3
title: "Đồng bộ báo cáo với code và gỡ số chưa đo"
status: in-progress
priority: P1
effort: "3h30m"
dependencies: [1]
---

# Phase 3: Đồng bộ báo cáo với code và gỡ số chưa đo

## Goal

Sửa thẳng trong Google Docs mọi đoạn không khớp code hiện tại, gỡ các con số chưa đo, thêm mô tả trang web đánh giá sai số và vẽ 4 hình sơ đồ. Chỗ nào cần số đo thật thì để đánh dấu cho phase 5.

## Quy ước

- Chỗ chờ số đo ghi `[CHỜ SỐ ĐO]`, chỗ chờ ảnh ghi `[CHỜ ẢNH]`, cả hai tô nền vàng để phase 5 tìm lại.
- Không đụng các đoạn về tài khoản và ACL: nhóm tự xóa (danh sách trong `plan.md`).
- Đọc skill `anthropic-skills:google-workspace` và tệp `references/docs.md` của skill trước lần ghi đầu tiên. Mỗi lô sửa gửi kèm `writeControl.requiredRevisionId` từ lần đọc ngay trước đó.

## Files to Create / Modify

- Modify: tài liệu báo cáo trên Google Docs, link do nhóm cung cấp khi chạy phase này (hoặc bản Google Tài liệu mới, xem bước 1)
- Create: `docs/hinh/hinh-3-1-kien-truc.html` và `.png`, `docs/hinh/hinh-3-3-luu-do-khoi-dong.html` và `.png`, `docs/hinh/hinh-3-4-tuan-tu-doi-loai-dat.html` và `.png`, `docs/hinh/hinh-3-6-he-chuyen-gia.html` và `.png`

## Tasks & Steps

### 1. Kiểm tra quyền sửa

1. Nhóm bật connector Google Docs trong phiên làm việc.
2. Gọi `read_doc` trên mã tài liệu lấy từ link nhóm cung cấp. Đọc được và có `revisionId` thì sửa thẳng trên tài liệu đó.
3. Báo lỗi định dạng Office thì dừng lại hỏi nhóm chọn cách A hoặc B (rủi ro số 1 trong `plan.md`). Chưa có quyết định thì không sửa gì.
4. Hỏi nhóm đã xóa xong phần tài khoản và ACL chưa. Chưa xong thì vẫn làm được, nhưng phải đọc lại trước mỗi lô sửa.

### 2. Mô hình N, P, K theo code (`firmware/src/soil_estimator.h`)

- [ ] Chương 1 mục 1, gạch đầu dòng 4: bỏ "Khắc phục nhược điểm càng tưới nước dinh dưỡng càng tăng" (code vẫn cho N, P, K tăng theo độ ẩm). Viết lại thành: N, P, K vẫn tính từ EC nhưng được so với mức bình thường của loại đất đang chọn, lệch quá ±20% thì báo thấp hoặc cao. Xóa chữ "z" thừa ở cuối câu.
- [ ] Bảng 1.1 dòng 6: cột cải tiến ghi N = 0,08 × EC, P = 0,04 × EC, K = 0,11 × EC; so với mức bình thường của loại đất; sai số so với bộ kit được tính trên trang web.
- [ ] Chương 2 mục 2.2, đoạn 2: thay lập luận "tưới thêm nước không làm đất giàu dinh dưỡng hơn" bằng lập luận trong code. Dinh dưỡng phải hòa tan vào nước trong đất thì cây mới hút được, và chính lượng ion hòa tan đó làm EC tăng, nên N, P, K tính từ EC. Hệ số được chọn sao cho ở độ ẩm 60% mỗi loại đất cho đúng mức bình thường của nó. Giữ câu "không phải số đo độc lập, muốn đo thật cần cảm biến NPK".
- [ ] Chương 3 mục 3.5 và Bảng 3.4: đổi tên 3 dòng N, P, K thành `nitrogenNormal / phosphorusNormal / potassiumNormal`, nghĩa là "mức bình thường để so sánh, không phải số đo". Thêm dòng `N_PER_EC / P_PER_EC / K_PER_EC = 0,08 / 0,04 / 0,11` (dùng chung cho mọi loại đất) và `NORMAL_TOLERANCE = 20%`. Thêm 2 câu về `compareNpk()` và `overallLevel()`: có chỉ số thấp thì báo thấp, không có thì xét cao. OLED có thêm dòng `Chuan:65/33/90 OK|THAP|CAO`.
- [ ] Chương 3 mục 6.3: ghi lý do chọn hệ số theo mức ẩm lý tưởng 60%, kèm ví dụ đất vườn: EC = 60 × 13,5 = 810, N = 64,8, P = 32,4, K = 89,1.
- [ ] Bảng 4.5 (số do hàm trong firmware tính ra, không cần đo): thay bằng số dưới đây, thêm cột "Đèn" và "Mức N-P-K trên OLED".

  | Loại đất | ADC | Độ ẩm | EC | N | P | K | pH | Mức trên OLED | Đèn | Điểm trên app |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Đất đóng bao | 1600 | 50,0% | 1000 | 80,0 | 40,0 | 110,0 | 6,2 | OK | Xanh | 100 |
  | Đất vườn | 1600 | 50,0% | 675 | 54,0 | 27,0 | 74,3 | 6,5 | OK | Xanh | 70 (thiếu P, K) |
  | Đất bạc màu | 1600 | 50,0% | 200 | 16,0 | 8,0 | 22,0 | 5,8 | THAP (K) | Đỏ (EC < 300) | 30 |

  Viết lại đoạn trước bảng. Đất vườn được OLED báo OK vì so với mức bình thường của đất vườn, nhưng app trừ còn 70 điểm vì app dùng một bộ ngưỡng chung (P ≥ 30, K ≥ 80). Ở đất bạc màu, N = 16 và P = 8 nằm đúng ngưỡng 80% nên chỉ lệch một chút là đổi mức. Mốc mặc định 200 / 3000 chỉ để minh họa.
- [ ] Chương 5 mục 1, gạch đầu dòng 4: bỏ "N, P, K không còn tăng theo độ ẩm", thay bằng "N, P, K so với mức bình thường của loại đất". Bảng 5.1 dòng Loại đất sửa tương tự.
- [ ] Hạn chế, gạch đầu dòng 2: viết lại thành câu hoàn chỉnh. N, P, K, EC, pH đều suy ra từ độ ẩm theo hệ số của loại đất nên trạm không phân biệt được hai mẫu cùng loại nhưng khác lượng phân. App và OLED đang dùng hai cách so khác nhau (ngưỡng chung và mức bình thường của loại đất). EC chưa bù nhiệt.

### 3. LWT và topic status (code đã có, `firmware/src/main.cpp`)

- [ ] Bảng 1.1 dòng 3: trạm có LWT `{"status":"offline"}` (QoS 1, giữ lại). Bản tin online được giữ lại và gửi lại mỗi 30 giây. App chưa đăng ký topic status.
- [ ] Chương 2 mục 4.3 đoạn 2, Chương 3 mục 3.4, Bảng 3.5 dòng status: sửa "chưa có LWT / không giữ lại" cho đúng code. Nói thêm lý do gửi lại mỗi 30 giây: client ID ngẫu nhiên, nên khi trạm khởi động lại, phiên cũ còn treo khoảng 22 giây (1,5 lần keep-alive 15 giây) rồi broker mới đăng LWT offline của phiên cũ, đè lên online của phiên mới.
- [ ] Chương 4 mục 4: sửa đoạn văn và cột "Kết quả mong đợi" của Bảng 4.4. Rút nguồn trạm thì topic status thành offline sau khoảng 20 – 25 giây (xem trên trang web hoặc MQTTX), app vẫn chỉ thấy "Cập nhật lúc" dừng lại. Cột "Kết quả thực tế" để `[CHỜ SỐ ĐO]`.
- [ ] Chương 5 mục 1 câu "Tính năng LWT... chưa làm kịp", Bảng 5.1 dòng Trạng thái thiết bị, Hạn chế gạch đầu dòng 5, Hướng phát triển gạch đầu dòng LWT: sửa thành "đã có LWT; còn thiếu: app đăng ký topic status để báo trạm online/offline, client ID cố định theo địa chỉ MAC".

### 4. Đã bỏ rơ-le, bơm, van (commit `9e37561`)

- [ ] Chương 2 mục 5: bỏ "rơ-le đóng cắt" khỏi danh sách nguồn nhiễu.
- [ ] Bảng 3.2: xóa dòng 7 (module rơ-le). Chương 3 mục 2.2: xóa câu "Module rơ-le nối GPIO26 (bơm) và GPIO27 (van)...". Bảng 3.3: xóa dòng Rơ-le.
- [ ] Bảng 3.5 dòng command: bỏ "(firmware còn nhận SET_PUMP, SET_VALVE)". Bảng 3.6: xóa dòng `actuators`.
- [ ] Bảng 4.1 dòng Trạm đo mô phỏng: bỏ "rơ-le mô phỏng".

### 5. Các thông số khác lệch với code

- [ ] Chương 3 mục 3.3: bộ đệm 512 byte sửa thành **768 byte** (bản tin khoảng 420 byte, đo trên board ngày 25/11).
- [ ] Chương 3 mục 3.4 và 4.4: mất Wi-Fi thì trạm dò lại 15 giây một lần (mỗi lần dò chặn tối đa khoảng 8 giây); mất broker thì thử lại 5 giây một lần.
- [ ] Bảng 3.6: thêm `npk_normal` (đối tượng, mức N, P, K bình thường của loại đất) và `npk_level` (đối tượng, `low / normal / high` cho từng chất), cột so với giai đoạn 1 ghi "Mới".
- [ ] Chương 3 mục 2.2 (hoặc mục 1.1): thêm quy tắc đèn và còi theo code. Đỏ khi độ ẩm < 35% hoặc > 80%, EC > 1800 hoặc < 300, pH < 5,5. Vàng khi độ ẩm 35 – 49% hoặc 71 – 80%, hoặc N, P, K thấp hơn mức bình thường. Còn lại là xanh. Còi kêu 3 tiếng khi độ ẩm vừa ra ngoài khoảng 35 – 80%, phải về lại khoảng 38 – 77% mới hết báo.
- [ ] Bảng 1.1 dòng 5: mốc giai đoạn 1 là **200 và 3000** (code giai đoạn 1, commit `c46466f`), không phải 100 và 3800.
- [ ] Bảng 2.2 dòng 8084: thêm "trang web đánh giá sai số". Bảng 4.1 dòng Máy chủ MQTT: `broker.emqx.io` (EMQX công cộng), cổng 8883 TLS; WSS 8084 cho trang web. Dòng Ứng dụng: điền đời máy điện thoại, nếu nhóm chưa cung cấp thì ghi `[CHỜ SỐ ĐO]`.

### 6. Gỡ các số chưa đo

- [ ] Chương 4 mục 2: bỏ 1,82 s / 1,15 s / 2,64 s / 0,45 s và câu "khớp 100%". Viết lại thành mô tả cách đo: đọc dòng `[NTP] Da co gio sau ... ms` trên Serial qua ≥ 10 lần khởi động, độ lệch `timestamp` xem trên trang web.
- [ ] Bảng 4.2: cột "Kết quả thực tế" để `[CHỜ SỐ ĐO]` cho mọi dòng. Dòng "Máy chủ chính không phản hồi": mong đợi là chuyển sang `time.google.com`. Dòng "Chưa có giờ": mong đợi giữ nguyên, ghi rõ là tùy chọn, làm được thì mới giữ dòng này.
- [ ] Chương 4 mục 3 đoạn 1: bỏ "TLS 1.2", "1.2 giây", "dưới khoảng 250 ms" (ESP32 bắt tay TLS phiên bản nào thì cần bắt gói tin mới biết).
- [ ] Bảng 4.3 (các dòng còn lại sau khi nhóm xóa dòng tài khoản và ACL): cột "Kết quả thực tế" để `[CHỜ SỐ ĐO]`. Cột này đang lệch một dòng, nên ghi lại từ đầu, không chép kết quả cũ sang.
- [ ] Chương 4 mục 6.2 và Bảng 4.7: bỏ 48,62 / 5,18 / 54,15 / 6,12 / 89,3% / ±1,38%. Viết lại phương pháp: "không lọc" là trung bình `adc.noise` (độ lệch chuẩn của 21 mẫu thô trong một lần đo), "có lọc" là độ lệch chuẩn của `adc.raw` qua 100 bản tin liên tiếp trên cùng một cốc đất đứng yên. Hai số đều đổi sang % độ ẩm theo mốc khô/ướt.
- [ ] Chương 4 mục 6.3: bỏ "−5,5% đến +6,6%", "MAE = 4,4%", "RMSE = 4,9%" và câu kết luận "đủ chính xác để phân lớp độ phì nhiêu... trong sản xuất nông nghiệp". Viết lại phương pháp (xem mục 7).
- [ ] Phụ lục B: cột Kết quả để `[CHỜ SỐ ĐO]` cho mọi dòng. Phase 4 đánh dấu lại khi đã có bằng chứng.

### 7. Thêm phần trang web đánh giá sai số

- [ ] Chương 1 mục 2, gạch đầu dòng 4: "đánh giá sai số MAE, RMSE, MAPE so với bộ dụng cụ thử đất, tính và hiển thị trên trang web (không hiển thị trên OLED)". Trả lời rồi đóng bình luận "?" ở chữ MAE, RMSE (nếu connector đóng bình luận được; không được thì báo nhóm tự đóng).
- [ ] Chương 2 mục 6: thêm 3 ý. Mỗi chỉ số tính MAE, RMSE riêng theo đơn vị của nó, không gộp chỉ số khác đơn vị. MAPE bỏ qua mẫu có giá trị tham chiếu bằng 0. `adc.noise` của trạm chia cho n, còn SD giữa các lần đo chia cho m − 1.
- [ ] Chương 3: thêm tiểu mục **5.5 Trang web đánh giá sai số** sau mục 5.4. Nội dung theo `web/README.md`: kết nối WSS 8084, phần Trực tiếp (gồm trạng thái online/offline), lấy mẫu bằng trung bình 5 bản tin, nhập tham chiếu, bảng MAE/RMSE/MAPE theo chỉ số và loại đất, biểu đồ ước lượng – tham chiếu, đo nhiễu M bản tin, xuất CSV. Thêm **Hình 3.7: Trang web đánh giá sai số** với `[CHỜ ẢNH]`. Cập nhật mục lục và danh mục hình.
- [ ] Bảng 4.1: thêm dòng "Trang web đánh giá sai số | `web/evaluation.html`, trình duyệt | WSS 8084, chỉ nhận bản tin, không gửi lệnh".
- [ ] Chương 4 mục 6.3 viết lại phương pháp:
  - Mẫu: 3 loại đất × 4 mức ẩm = 12 mẫu. Mỗi mẫu đo đủ các chỉ số mà bộ kit đo được.
  - Nguồn tham chiếu cho từng chỉ số: độ ẩm theo khối lượng nước thêm vào hoặc cân sấy; EC và pH bằng bút đo hoặc kit (ghi rõ tỷ lệ đất:nước); N, P, K bằng kit.
  - Nêu rõ hai chỗ khác định nghĩa (rủi ro 3 và 4 trong `plan.md`).
  - Bảng 4.8 đổi cột thành: Mã mẫu | Loại đất | Mức ẩm | Chỉ số | Tham chiếu | Ước lượng | Sai số, tất cả để `[CHỜ SỐ ĐO]`.
  - Thêm **Bảng 4.9: MAE, RMSE, MAPE theo từng chỉ số** (cột: Chỉ số | Đơn vị | n | MAE | RMSE | MAPE), để `[CHỜ SỐ ĐO]`. Cập nhật danh mục bảng.
- [ ] Bảng 5.1 dòng Đánh giá sai số: "So với bộ kit, tính MAE/RMSE/MAPE theo từng chỉ số trên trang web".

### 8. Lỗi câu chữ và hình thức

- [ ] Chương 4 mục 1: "kết nối qua cả Wi-Fi" sửa thành câu hoàn chỉnh (Wi-Fi, hoặc Wi-Fi và 4G nếu đã thử).
- [ ] Hướng phát triển: "tự chỉnh ma trận trọng số" sửa thành "tự chỉnh bộ hệ số". Thêm gạch đầu dòng: dùng broker riêng có tài khoản và ACL.
- [ ] Hạn chế: thêm gạch đầu dòng về broker công cộng có TLS nhưng chưa có tài khoản, ai biết topic vẫn đọc và gửi lệnh được.
- [ ] Tiêu đề "LỜI CÁM ƠN" đổi thành "LỜI CẢM ƠN" (cả mục lục).
- [ ] Danh mục từ viết tắt: xóa BLE, UART, SoC (không dùng trong bài). Thêm MAPE, SD, OLED, I2C, UDP, TCP, RTC, UTC, LED, SQLite. Dòng ACL để nhóm tự quyết cùng phần tài khoản.
- [ ] Thêm trích dẫn trong thân bài theo số thứ tự trong danh sách tài liệu tham khảo:
  - [1], [2], [19]: N-P-K, EC và độ phì (Chương 2 mục 1, mục 2)
  - [3]: độ ẩm đất
  - [4], [11]: cảm biến LM393
  - [7], [8], [9]: ESP32, ADC, GPIO34 thuộc ADC1 (Chương 2 mục 1, Chương 3 mục 2.2)
  - [10]: WiFiMulti
  - [5], [6], [16]: IoT và MQTT
  - [12], [14]: SNTP và NTP
  - [13]: NIST (Bảng 4.2)
  - [15]: TLS
  - [17]: cổng EMQX (Bảng 2.2)
  - [18]: DS18B20 (hướng phát triển)
  - [20]: Wokwi
- [ ] Phụ lục A: nếu nhóm không cung cấp mốc thời gian (câu hỏi mở 3) thì xóa khỏi mục lục và danh mục bảng.

### 9. Vẽ 4 hình sơ đồ

- [x] Viết mỗi hình bằng HTML + SVG trong `docs/hinh/`, lấy đúng thành phần trong code (sinh bằng `python docs/hinh/ve_hinh.py`):
  - Hình 3.1: 3 tầng thiết bị, truyền thông, ứng dụng. Thêm trang web ở tầng ứng dụng, không có rơ-le.
  - Hình 3.3: lưu đồ `setup()` → Wi-Fi → NTP → vòng `loop()` thử MQTT 5 giây.
  - Hình 3.4: tuần tự `SET_SOIL_TYPE` → lưu NVS → gửi ngay telemetry làm xác nhận.
  - Hình 3.6: luồng ngưỡng → trừ điểm → khuyến nghị của `AgronomicEngine`.
- [x] Xuất PNG bằng Chrome chạy ẩn, độ phân giải gấp 2 (`--headless=new --force-device-scale-factor=2 --window-size=<rộng>,<cao>`; kích thước từng hình in ra khi chạy `ve_hinh.py`). Đã xem lại cả 4 ảnh.
- [ ] Báo nhóm chèn 4 PNG vào đúng chỗ chú thích (API chỉ chèn được ảnh có URL công khai).

## Verification

- Đọc lại tài liệu sau mỗi lô sửa và đối chiếu từng ô đã đánh dấu ở trên.
- Tìm trong tài liệu các từ "rơ-le", "SET_PUMP", "actuators", "512 byte", "chưa có LWT", "không còn tăng theo độ ẩm", "4.4%", "1.82": không còn kết quả nào.
- Đếm được các đánh dấu `[CHỜ SỐ ĐO]` và `[CHỜ ẢNH]`, ghi số lượng vào phần ghi chú cuối phase này để phase 5 đối chiếu.
- 4 tệp PNG trong `docs/hinh/` mở được và đọc rõ chữ.

## Tiến độ (2026-11-26)

- Đã xong mục 9: 4 hình trong `docs/hinh/` (`hinh-3-1-kien-truc.png`, `hinh-3-3-luu-do-khoi-dong.png`, `hinh-3-4-tuan-tu-doi-loai-dat.png`, `hinh-3-6-he-chuyen-gia.png`), nội dung đối chiếu với code. Hình 3.4 dùng đúng chữ trên app: "Đang gửi tới trạm..." và "Trạm đã nhận".
- Mục 1 – 8 đang chờ: phiên thực hiện chưa có connector Google Docs (chỉ có Claude Docs, không mở được tài liệu Google). Bật connector Google Docs rồi chạy lại `/ak:cook` cho kế hoạch này.
