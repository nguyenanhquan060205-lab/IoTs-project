---
phase: 3
title: "Chuyển sang Google Tài liệu và sửa chữ cho khớp code"
status: in-progress
priority: P1
effort: "4h"
dependencies: [1]
---

# Phase 3: Chuyển sang Google Tài liệu và sửa chữ cho khớp code

## Goal

Trên bản Google Tài liệu mới, sửa mọi đoạn không khớp code hiện tại, xóa phần tài khoản và ACL, gỡ các con số chưa đo và viết lại phần sai số theo cách so với mức chuẩn của loại đất. Chỗ nào cần số đo hay ảnh thật thì để đánh dấu cho phase 5.

## Quy ước

- Chỗ chờ số đo ghi `[CHỜ SỐ ĐO]`, chỗ chờ ảnh ghi `[CHỜ ẢNH]`, cả hai tô nền vàng để phase 5 tìm lại. Nếu phase 4 đã có số trước khi sửa tới chỗ đó thì ghi thẳng số thật, không cần đánh dấu.
- Đọc skill `anthropic-skills:google-workspace` và tệp `references/docs.md` của skill trước lần ghi đầu tiên.
- Mỗi lô sửa gửi kèm `writeControl.requiredRevisionId` lấy từ lần đọc ngay trước đó.
- `read_doc` trả về khoảng 800 nghìn ký tự JSON. Lưu ra tệp rồi trích chữ và bảng bằng script (như `extract_doc.py` đã dùng ngày 2026-11-26), không đọc thẳng vào cuộc trò chuyện.
- Vị trí dưới đây ghi theo chương, mục, bảng và dòng của bản đọc ngày 2026-11-26.

## Files to Create / Modify

- Modify: bản Google Tài liệu mới của báo cáo (link nhóm gửi trong cuộc trò chuyện, không ghi vào repo)
- Đã tạo: `docs/hinh/hinh-3-1-kien-truc.png`, `hinh-3-3-luu-do-khoi-dong.png`, `hinh-3-4-tuan-tu-doi-loai-dat.png`, `hinh-3-6-he-chuyen-gia.png` (cùng tệp `.html` nguồn và `docs/hinh/ve_hinh.py`)

## Tasks & Steps

### 1. Chuyển sang Google Tài liệu và kiểm tra

1. Nhóm mở file `.docx` trên Drive, chọn Tệp → Lưu dưới dạng Google Tài liệu. Chia sẻ bản mới với quyền Người chỉnh sửa cho tài khoản Google đang nối với Claude. Gửi link mới trong cuộc trò chuyện. Từ lúc này chỉ sửa trên bản mới.
2. Gọi `get_file_metadata` trên bản mới: `mimeType` phải là `application/vnd.google-apps.document` và `capabilities.canEdit` là `true`. Sai thì dừng lại báo nhóm.
3. Đọc bản mới bằng `read_doc` (kèm `commentsIncluded: true`), lưu `revisionId`. So với bản đọc ngày 2026-11-26 và ghi kết quả vào mục Tiến độ:
   - Số đoạn và số bảng (bản cũ trích ra 499 dòng, 2 ảnh logo).
   - Chú thích còn số không: "Bảng 4.5:" hay chỉ còn "Bảng 4.:".
   - Mục lục, danh mục bảng, danh mục hình còn hay mất.
   - Công thức ở Chương 2 mục 5 và 6 còn không.
   - Bình luận "?" ở chữ MAE, RMSE còn không.
4. Chú thích mất số thì ghi số cố định vào từng chú thích (Hình 3.1 – 3.7, 4.1 – 4.6, Bảng 1.1 – 5.1). Đánh số theo thứ tự sau khi đã bỏ Hình 4.3 ở mục 7.
5. Lô thử: `replaceAllText` "LỜI CÁM ƠN" thành "LỜI CẢM ƠN" kèm `requiredRevisionId`, đọc lại để chắc ghi được.

### 2. Xóa phần tài khoản và ACL

Code firmware và app vẫn nhận tài khoản nếu khai báo, nhưng nhóm chỉ chạy với `broker.emqx.io` không tài khoản. Báo cáo viết theo đúng cách đang chạy.

- [ ] Danh mục từ viết tắt: xóa dòng ACL.
- [ ] Bảng phân công, việc của Quân: "Cấu hình broker MQTT riêng hỗ trợ TLS và tài khoản cho trạm đo, ứng dụng" sửa thành "Cấu hình kết nối MQTT qua TLS (cổng 8883) cho trạm đo và ứng dụng".
- [ ] Chương 1 mục 1, gạch đầu dòng 2: bỏ "và xác thực tài khoản riêng", thay bằng "ESP32 kiểm tra chứng chỉ broker bằng Root CA".
- [ ] Bảng 1.1 dòng 2, cột cải tiến: "MQTT qua TLS cổng 8883, ESP32 kiểm tra chứng chỉ bằng Root CA. Vẫn dùng broker công cộng `broker.emqx.io`, chưa có tài khoản".
- [ ] Bảng 3.1: B2 bỏ "(có tài khoản nếu khai báo)". B5 "Kiểm tra tài khoản, chuyển tiếp tới ứng dụng" sửa thành "Chuyển tiếp bản tin tới ứng dụng".
- [ ] Chương 3 mục 3.1, dòng `secrets.h`: "tên và mật khẩu Wi-Fi, địa chỉ broker; tài khoản MQTT để trống khi dùng broker.emqx.io".
- [ ] Chương 3 mục 3.3: ISRG Root X1 "(dùng cho HiveMQ Cloud và đa số broker riêng)" sửa thành "(dự phòng cho broker dùng chứng chỉ Let's Encrypt)". Bỏ "kèm tên đăng nhập và mật khẩu nếu secrets.h có khai báo", "hoặc tài khoản bị từ chối" và "rc = 4 hoặc 5 khi sai tài khoản".
- [ ] Chương 3 mục 4.1: đổi tiêu đề thành "Broker MQTT có TLS". Viết lại đoạn 1: trạm và app dùng `broker.emqx.io` cổng 8883, có TLS, không tài khoản; địa chỉ broker lấy từ `secrets.h` (ESP32) và `mqtt_config.json` (app), mặc định là broker.emqx.io. Bỏ câu về HiveMQ Cloud. Xóa đoạn 2 (hai tài khoản và ACL).
- [ ] Chương 3 mục 5.1: "Địa chỉ broker và tài khoản lấy từ mqtt_config.json" sửa thành "Địa chỉ broker lấy từ mqtt_config.json lúc biên dịch, mặc định broker.emqx.io".
- [ ] Bảng 4.1 dòng Máy chủ MQTT: "`broker.emqx.io` (EMQX công cộng)" và "Cổng 8883 có TLS, không tài khoản; WSS 8084 cho trang web". Dòng này đang có ô "…".
- [ ] Chương 4 mục 3: xóa cả đoạn 2 (ACL và Wireshark).
- [ ] Bảng 4.3: xóa 3 dòng Sai mật khẩu, Cổng 1883 trên broker riêng, ACL.
- [ ] Chương 5 mục 1, gạch đầu dòng 2: bỏ "và đăng nhập broker riêng bằng tài khoản".
- [ ] Bảng 5.1 dòng Kết nối MQTT: "MQTTS cổng 8883, kiểm tra Root CA, broker công cộng chưa có tài khoản".
- [ ] Giữ nguyên tài liệu tham khảo [17] (tên tài liệu của EMQX).

### 3. Mô hình N, P, K theo code (`firmware/src/soil_estimator.h`)

- [ ] Chương 1 mục 1, gạch đầu dòng 4: bỏ "Khắc phục nhược điểm càng tưới nước dinh dưỡng càng tăng" (code vẫn cho N, P, K tăng theo độ ẩm). Viết lại: N, P, K vẫn tính từ EC nhưng được so với mức chuẩn của loại đất đang chọn, lệch quá ±20% thì báo thấp hoặc cao. Xóa chữ "z" thừa ở cuối câu.
- [ ] Bảng 1.1 dòng 6, cột cải tiến: N = 0,08 × EC, P = 0,04 × EC, K = 0,11 × EC; so với mức chuẩn của loại đất; sai số so với mức chuẩn tính trên trang web.
- [ ] Chương 2 mục 2.2, đoạn 2: thay lập luận "tưới thêm nước không làm đất giàu dinh dưỡng hơn" bằng lập luận trong code. Dinh dưỡng phải hòa tan vào nước trong đất thì cây mới hút được, và chính lượng ion hòa tan đó làm EC tăng, nên N, P, K tính từ EC. Hệ số được chọn để ở độ ẩm 60% mỗi loại đất cho gần đúng mức chuẩn của nó. Giữ câu "không phải số đo độc lập, muốn đo thật cần cảm biến NPK". Đoạn 3: "hàm lượng N, P, K điển hình" sửa thành "mức N, P, K chuẩn để so sánh".
- [ ] Chương 3 mục 3.5 và Bảng 3.4: đổi tên 3 dòng N, P, K thành `nitrogenNormal / phosphorusNormal / potassiumNormal`, nghĩa là "mức chuẩn để so sánh, không phải số đo". Thêm dòng `N_PER_EC / P_PER_EC / K_PER_EC = 0,08 / 0,04 / 0,11` (dùng chung cho mọi loại đất) và `NORMAL_TOLERANCE = 20%`. Thêm 2 câu về `compareNpk()` và `overallLevel()`: có chất thấp thì báo thấp, không có thì xét cao. OLED có thêm dòng `Chuan:65/33/90 OK|THAP|CAO`.
- [ ] Chương 3 mục 6.3: ghi lý do chọn hệ số theo độ ẩm lý tưởng 60%, kèm ví dụ đất vườn: EC = 60 × 13,5 = 810, N = 64,8, P = 32,4, K = 89,1.
- [ ] Bảng 4.5 (số do hàm trong firmware tính ra, không cần đo): thay bằng số dưới đây, thêm cột "Đèn" và "Mức N-P-K trên OLED". Phase 5 thêm cột số đo thật trên mạch.

  | Loại đất | ADC | Độ ẩm | EC | N | P | K | pH | Mức trên OLED | Đèn | Điểm trên app |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Đất đóng bao | 1600 | 50,0% | 1000 | 80,0 | 40,0 | 110,0 | 6,2 | OK | Xanh | 100 |
  | Đất vườn | 1600 | 50,0% | 675 | 54,0 | 27,0 | 74,3 | 6,5 | OK | Xanh | 70 (thiếu P, K) |
  | Đất bạc màu | 1600 | 50,0% | 200 | 16,0 | 8,0 | 22,0 | 5,8 | THAP (K) | Đỏ (EC < 300) | 30 |

  Viết lại đoạn trước bảng. Đất vườn được OLED báo OK vì so với mức chuẩn của đất vườn, nhưng app trừ còn 70 điểm vì app dùng một bộ ngưỡng chung (P ≥ 30, K ≥ 80). Ở đất bạc màu, N = 16 và P = 8 nằm đúng ngưỡng 80% nên chỉ lệch một chút là đổi mức. Mốc mặc định 200 / 3000 chỉ để minh họa.
- [ ] Chương 5 mục 1, gạch đầu dòng 4: bỏ "N, P, K không còn tăng theo độ ẩm", thay bằng "N, P, K so với mức chuẩn của loại đất". Bảng 5.1 dòng Loại đất sửa tương tự.
- [ ] Hạn chế, gạch đầu dòng 2: viết lại thành câu hoàn chỉnh. N, P, K, EC, pH đều suy ra từ độ ẩm theo hệ số của loại đất, nên trạm không phân biệt được hai mẫu cùng loại nhưng khác lượng phân. App và OLED đang dùng hai cách so khác nhau (ngưỡng chung và mức chuẩn của loại đất). EC chưa bù nhiệt.

### 4. LWT và topic status (code đã có, `firmware/src/main.cpp`)

- [ ] Bảng 1.1 dòng 3: trạm có LWT `{"status":"offline"}` (QoS 1, giữ lại). Bản tin online được giữ lại và gửi lại mỗi 30 giây. App chưa đăng ký topic status.
- [ ] Chương 3 mục 3.4 và Bảng 3.5 dòng status: sửa "chưa có LWT / không giữ lại" cho đúng code. Nói thêm lý do gửi lại mỗi 30 giây: client ID ngẫu nhiên, nên khi trạm khởi động lại, phiên cũ còn treo khoảng 22 giây (1,5 lần keep-alive 15 giây) rồi broker mới đăng LWT offline của phiên cũ, đè lên online của phiên mới.
- [ ] Chương 4 mục 4: sửa đoạn văn và cột "Kết quả mong đợi" của Bảng 4.4 dòng 1. Mất nguồn thì broker đăng offline khi hết hạn keep-alive (15 s × 1,5), app vẫn chỉ thấy "Cập nhật lúc" dừng lại. Cột "Kết quả thực tế": đo ngày 2026-11-26 được 28,0 – 32,6 s (`docs/thuc-nghiem/so-lieu-bao-cao.md`).
- [ ] Chương 5 mục 1 câu "Tính năng LWT... chưa làm kịp", Bảng 5.1 dòng Trạng thái thiết bị, Hạn chế gạch đầu dòng 5, Hướng phát triển gạch đầu dòng LWT: sửa thành "đã có LWT; còn thiếu: app đăng ký topic status để báo trạm online hay offline, client ID cố định theo địa chỉ MAC".

### 5. Đã bỏ rơ-le, bơm, van (commit `9e37561`)

- [ ] Chương 2 mục 5: bỏ "hoặc rơ-le đóng cắt" khỏi danh sách nguồn nhiễu.
- [ ] Bảng 3.2: xóa dòng 7 (module rơ-le). Chương 3 mục 2.2: xóa câu "Module rơ-le nối GPIO26 và GPIO27...". Bảng 3.3: xóa dòng Rơ-le.
- [ ] Bảng 3.5 dòng command: bỏ "(firmware còn nhận SET_PUMP, SET_VALVE)". Bảng 3.6: xóa dòng `actuators`.
- [ ] Bảng 4.1 dòng Trạm đo mô phỏng: bỏ "và rơ-le mô phỏng".

### 6. Các thông số khác lệch với code

- [ ] Chương 2 mục 3.1, đoạn 2: bỏ câu "nếu đồng hồ của ESP32 bị sai ... việc kiểm tra chứng chỉ sẽ thất bại ngay". Đo ngày 2026-11-26 (`docs/thuc-nghiem/log/khong-co-gio.txt`): trạm chưa có giờ vẫn kết nối TLS được, tức là firmware hiện tại không kiểm tra hạn chứng chỉ. Viết lại: thời gian thực cần để gắn mốc giờ cho bản tin; việc kiểm tra hạn chứng chỉ khi chưa có giờ đưa vào Hạn chế.
- [ ] Chương 3 mục 3.3: bộ đệm 512 byte sửa thành **768 byte**. Kích thước bản tin để `[CHỜ SỐ ĐO]` (phase 4A bước 2 đo).
- [ ] Chương 3 mục 3.4 và 4.4: mất Wi-Fi thì trạm dò lại 15 giây một lần (mỗi lần dò chặn tối đa khoảng 8 giây); mất broker thì thử lại 5 giây một lần.
- [ ] Bảng 3.6: thêm `npk_normal` (đối tượng, mức N, P, K chuẩn của loại đất) và `npk_level` (đối tượng, `low / normal / high` cho từng chất), cột so với giai đoạn 1 ghi "Mới".
- [ ] Chương 3 mục 2.2: thêm quy tắc đèn và còi theo code. Đỏ khi độ ẩm < 35% hoặc > 80%, EC > 1800 hoặc < 300, pH < 5,5. Vàng khi độ ẩm 35 – 49% hoặc 71 – 80%, hoặc N, P, K thấp hơn mức chuẩn. Còn lại là xanh. Còi kêu 3 tiếng khi độ ẩm vừa ra ngoài khoảng 35 – 80%, phải về lại khoảng 38 – 77% mới hết báo.
- [ ] Bảng 1.1 dòng 5: mốc giai đoạn 1 là **200 và 3000** (code giai đoạn 1, commit `c46466f`), không phải 100 và 3800.
- [ ] Bảng 2.2 dòng 8084: "Trang web đánh giá sai số, MQTTX bản web".
- [ ] Bảng 4.1 dòng Ứng dụng: điền đời máy điện thoại nhóm cung cấp, chưa có thì `[CHỜ SỐ ĐO]`. Dòng Công cụ theo dõi: "Serial Monitor, trang web đánh giá sai số, `scripts/report_measure.py`" (bỏ MQTTX, Wireshark).

### 7. Gỡ các số chưa đo

Không sửa cột "Kết quả mong đợi" cho khớp kết quả. Cột này chỉ đổi khi cách làm thay đổi (ghi rõ bên dưới).

- [ ] Chương 4 mục 2: bỏ 1,82 s / 1,15 s / 2,64 s / 0,45 s và câu "khớp 100%". Viết lại thành mô tả cách đo: khởi động lại trạm 10 lần bằng script (đặt lại qua chân EN), đọc số ms trong dòng `[NTP] Da co gio sau ... ms`; độ lệch `timestamp` so với giờ máy tính, giờ máy tính đã so với máy chủ NTP.
- [ ] Bảng 4.2: cột "Kết quả thực tế" để `[CHỜ SỐ ĐO]` cho mọi dòng. Dòng 1, cột cách làm: "Số ms trong dòng `[NTP] Da co gio sau ... ms` (tính từ lúc có Wi-Fi), 10 lần khởi động". Dòng "Máy chủ chính không phản hồi": cách làm "Nạp bản tạm đặt sai tên máy chủ chính", mong đợi "Lấy giờ từ time.google.com". Dòng "Chưa có giờ": cách làm "Nạp bản tạm đặt sai cả hai máy chủ NTP", giữ cột mong đợi.
- [ ] Chương 4 mục 3 đoạn 1: bỏ "TLS 1.2", "1.2 giây", "dưới khoảng 250ms". Giữ câu CA giả làm kết nối thất bại, kết quả để `[CHỜ SỐ ĐO]`.
- [ ] Bảng 4.3: xóa dòng Bắt gói tin. Còn 3 dòng: Kết nối TLS thành công, CA sai, Chi phí của TLS. Dòng Chi phí của TLS, cách làm: "So thời gian kết nối và bộ nhớ trống với bản nạp tạm dùng cổng 1883 không TLS, trên cùng mạch và cùng mạng". Cột "Kết quả thực tế" ghi lại từ đầu, để `[CHỜ SỐ ĐO]`, không chép kết quả cũ (cột này đang lệch một dòng).
- [ ] Xóa chú thích Hình 4.3 (Wireshark). Đổi số: Hình 4.4 → 4.3, 4.5 → 4.4, 4.6 → 4.5, 4.7 → 4.6. Nếu chú thích còn đánh số tự động thì chỉ cần xóa.
- [ ] Chú thích Hình 4.2: "Bản tin có trường timestamp nhận được trên MQTTX" sửa thành "... nhận được trên trang web đánh giá sai số".
- [ ] Chương 4 mục 6.2 và Bảng 4.7: bỏ 48.62 / 5.18 / 54.15 / 6.12 / 89.3% / ±1.38% / ±0.15%. Viết lại phương pháp: "không lọc" là trung bình `adc.noise` (độ lệch chuẩn của 21 mẫu thô trong một lần đo), "có lọc" là độ lệch chuẩn của `adc.raw` qua 100 bản tin liên tiếp trên cùng một cốc đất đứng yên. Hai số đều đổi sang % độ ẩm theo mốc khô, ướt.
- [ ] Bảng 4.6: giữ khung, ô "…" đổi thành `[CHỜ SỐ ĐO]`.
- [ ] Phụ lục: cột Kết quả để `[CHỜ SỐ ĐO]` cho mọi dòng. Dòng 2: bỏ "và 4G" nếu nhóm không thử app trên 4G ở phase 4B. Dòng 5: "từ ứng dụng và MQTTX" sửa thành "từ ứng dụng và lệnh MQTT gửi từ máy tính".

### 8. Sai số so với mức chuẩn và trang web

- [ ] Chương 1 mục 2, gạch đầu dòng 4: "Đo trên mẫu đất thật, lưu lịch sử đo theo ngày trên điện thoại và tính sai số (MAE, RMSE, MAPE) của N, P, K so với mức chuẩn nhóm đặt cho từng loại đất. Sai số tính và hiển thị trên trang web, không hiện trên OLED." Trả lời rồi đóng bình luận "?" ở chữ MAE, RMSE nếu còn (connector không đóng được thì báo nhóm tự đóng).
- [ ] Chương 1 mục 3, đoạn 2: "đem số liệu so sánh độ lệch với mẫu đối chứng" sửa thành "so sánh với mức chuẩn của từng loại đất".
- [ ] Chương 2 mục 6: thêm 3 ý. Giá trị tham chiếu là mức chuẩn N, P, K của loại đất (`npk_normal`). Mỗi chất tính MAE, RMSE riêng theo đơn vị mg/kg, MAPE dùng để so giữa các loại đất có mức chuẩn khác nhau. `adc.noise` của trạm chia cho n, còn SD giữa các lần đo chia cho m − 1.
- [ ] Chương 3: thêm tiểu mục **5.5 Trang web đánh giá sai số** sau mục 5.4. Nội dung theo `web/README.md` (sau khi phase 4 sửa): kết nối WSS 8084, phần Trực tiếp (gồm trạng thái online, offline), lấy mẫu bằng trung bình 5 bản tin, mức chuẩn tự điền làm giá trị tham chiếu, bảng MAE, RMSE, MAPE theo chất và loại đất, biểu đồ ước lượng – mức chuẩn, đo nhiễu M bản tin, xuất CSV. Thêm **Hình 3.7: Trang web đánh giá sai số** với `[CHỜ ẢNH]`.
- [ ] Chương 3 mục 6.1: đổi tiêu đề thành "Chuẩn bị mẫu và mức chuẩn để so sánh". Bỏ câu "Các mẫu đối chứng được đo độc lập bằng bộ dụng cụ thử dinh dưỡng đất...". Thêm: nhóm không có bộ kit nên giá trị để so là mức N, P, K chuẩn của từng loại đất trong Bảng 3.4.
- [ ] Chương 3 mục 6.3: "Số liệu tham chiếu ở mục 6.1 dùng để kiểm tra sai số của bộ hệ số này... và chỉnh lại nếu lệch nhiều" sửa thành "Sai số so với mức chuẩn (Chương 4, mục 6.3) cho biết bộ hệ số có cho đúng mức chuẩn quanh độ ẩm lý tưởng hay không".
- [ ] Bảng 4.1: thêm dòng "Trang web đánh giá sai số | `web/evaluation.html`, trình duyệt | WSS 8084, chỉ nhận bản tin, không gửi lệnh".
- [ ] Chương 4 mục 6.3, viết lại phương pháp:
  - Mẫu: 3 loại đất × 4 mức ẩm (khô kiệt, ẩm thấp, ẩm tối ưu, bão hòa) = 12 mẫu. Trước mỗi mẫu, trạm được đặt đúng loại đất của cốc.
  - Ước lượng là trung bình 5 bản tin. Tham chiếu là mức chuẩn `npk_normal` của loại đất. Sai số e = ước lượng − mức chuẩn, tính MAE, RMSE, MAPE cho từng chất và từng loại đất.
  - Nói rõ ý nghĩa: N, P, K tính từ EC, EC tính từ độ ẩm, nên tỉ số ước lượng / mức chuẩn tỉ lệ thuận với độ ẩm. Theo hệ số hiện tại, mỗi chất ở mức bình thường (lệch không quá ±20%) khi độ ẩm nằm từ khoảng 48 – 50% tới 71 – 75% tùy chất và loại đất, riêng K của đất bạc màu là 55 – 82% (bảng tính sẵn ở phase 4, mục Bối cảnh). Ở độ ẩm 60%, K đất bạc màu vẫn thấp hơn mức chuẩn 12%. Sai số này cho biết ước lượng lệch khỏi mức chuẩn bao nhiêu ở từng mức ẩm, không cho biết độ chính xác so với lượng dinh dưỡng thật trong đất.
  - Bảng 4.8 đổi cột thành: Mã mẫu | Loại đất | Mức ẩm | Độ ẩm đo (%) | N ước lượng / chuẩn | P ước lượng / chuẩn | K ước lượng / chuẩn | Mức trên OLED. 12 dòng, để `[CHỜ SỐ ĐO]`.
  - Thêm **Bảng 4.9: Sai số N, P, K so với mức chuẩn theo loại đất**, cột: Loại đất | Chất | n | MAE (mg/kg) | RMSE (mg/kg) | MAPE (%). 9 dòng, để `[CHỜ SỐ ĐO]`.
  - Chú thích Hình 4.6: "Biểu đồ so sánh giá trị ước lượng và mức chuẩn N, P, K".
- [ ] Bảng 5.1 dòng Đánh giá sai số: "So với mức chuẩn N, P, K của loại đất, tính MAE, RMSE, MAPE trên trang web".
- [ ] Hạn chế, gạch đầu dòng 3: "Chưa có số đo tham chiếu độc lập (bộ kit hay phòng thí nghiệm). Sai số hiện mới so với mức chuẩn nhóm tự đặt, nên chưa cho biết độ chính xác thật của N, P, K."
- [ ] Bảng phân công, việc của Trang: "Thu thập mẫu đất thực nghiệm và số liệu tham chiếu" sửa thành "Thu thập mẫu đất thực nghiệm" (nhóm xem lại khi đọc bản sửa).

### 9. Lỗi câu chữ và hình thức

- [ ] Chương 4 mục 1: "kết nối qua cả Wi-Fi" sửa thành câu hoàn chỉnh (Wi-Fi, hoặc Wi-Fi và 4G nếu nhóm thử ở phase 4B).
- [ ] Hướng phát triển: "tự chỉnh ma trận trọng số" sửa thành "tự chỉnh bộ hệ số". Thêm 2 gạch đầu dòng: dùng broker riêng có tài khoản và ACL; đo đối chứng bằng bộ kit hoặc gửi mẫu tới phòng thí nghiệm.
- [ ] Hạn chế: thêm gạch đầu dòng về broker công cộng có TLS nhưng chưa có tài khoản, ai biết topic vẫn đọc và gửi lệnh được.
- [ ] Tiêu đề "LỜI CÁM ƠN" đổi thành "LỜI CẢM ƠN" (bước 1.5), sửa cả mục lục nếu mục lục là chữ cố định.
- [ ] Danh mục từ viết tắt: xóa BLE, UART, SoC (không dùng trong bài). Thêm MAPE, SD, OLED, I2C, UDP, TCP, RTC, UTC, LED, SQLite.
- [ ] Phụ lục: "Bảng phụ lục B.1" sửa thành "Bảng phụ lục A.1" (thân bài chỉ có Phụ lục A). Mục lục còn nhắc phụ lục khác thì xóa.
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

### 10. Vẽ 4 hình sơ đồ

- [x] Viết mỗi hình bằng HTML + SVG trong `docs/hinh/`, lấy đúng thành phần trong code (sinh bằng `python docs/hinh/ve_hinh.py`): Hình 3.1 kiến trúc 3 tầng, Hình 3.3 lưu đồ khởi động, Hình 3.4 tuần tự đổi loại đất, Hình 3.6 luồng của `AgronomicEngine`.
- [x] Xuất PNG bằng Chrome chạy ẩn, độ phân giải gấp 2. Đã xem lại cả 4 ảnh.
- Chèn ảnh vào tài liệu chuyển sang phase 5 bước 5.

## Verification

- Đọc lại tài liệu sau mỗi lô sửa và đối chiếu từng ô đã đánh dấu ở trên.
- Tìm trong tài liệu: "rơ-le", "SET_PUMP", "actuators", "512 byte", "chưa có LWT", "LWT chưa làm", "không tăng theo độ ẩm", "không còn tăng", "1.82", "4.4%", "48.62", "ACL", "HiveMQ", "mqtt_config.json" kèm "tài khoản": không còn kết quả nào.
- "bộ dụng cụ", "bộ kit" chỉ còn trong Hạn chế và Hướng phát triển. "Wireshark" chỉ còn ở Chương 2 mục 4.1 (phần lý thuyết). "MQTTX" chỉ còn ở Bảng 2.2 dòng 8084. "tài khoản" chỉ còn ở dòng `secrets.h`, Hạn chế và Hướng phát triển.
- Đếm các đánh dấu `[CHỜ SỐ ĐO]` và `[CHỜ ẢNH]`, ghi số lượng vào mục Tiến độ để phase 5 đối chiếu.

## Tiến độ

- 2026-11-26: xong mục 10 (4 hình sơ đồ, nội dung đối chiếu với code; Hình 3.4 dùng đúng chữ trên app "Đang gửi tới trạm..." và "Trạm đã nhận").
- 2026-11-26 (lần 2): đọc được tài liệu qua connector Google Docs. Không sửa được vì tài liệu là `.docx` và tài khoản nối với Claude chỉ có quyền xem. Nhóm chọn lưu thành Google Tài liệu (mục 1). Danh sách mục 2 – 9 đã đối chiếu lại với bản đọc lần này.
- 2026-11-26 (lần 3): nhóm cấp quyền sửa file `.docx` cho tài khoản nối với Claude (danh sách quyền đã có, kể cả "ai có link đều sửa được"), nhưng connector Drive vẫn trả `canEdit: false` và Docs API không ghi được vào file `.docx`. Nhóm chọn tự chèn số và ảnh từ `docs/thuc-nghiem/so-lieu-bao-cao.md`. Nếu có người lưu tài liệu thành Google Tài liệu và gửi link, Claude vẫn sửa thẳng được theo mục 1.
