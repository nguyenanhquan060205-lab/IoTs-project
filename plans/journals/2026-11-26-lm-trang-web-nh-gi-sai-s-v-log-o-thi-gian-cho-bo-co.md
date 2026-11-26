---
title: Làm trang web đánh giá sai số và log đo thời gian cho báo cáo
date: 2026-11-26
summary: "Xong phase 1 (web/evaluation.html), phase 2 xong code (log NTP/TLS), phase 3 xong 4 hình; phần sửa Google Docs chờ connector"
---

# Làm trang web đánh giá sai số và log đo thời gian cho báo cáo

## What happened

- Phase 1:
  - Thêm `web/metrics.js` gồm các hàm tính MAE, RMSE, MAPE theo từng chỉ số, SD mẫu, nhiễu bộ lọc và CSV. 12 kiểm thử `node --test "web/*.test.js"` đều qua.
  - Thêm `web/evaluation.html`: nối broker.emqx.io qua WSS 8084, chỉ nhận bản tin, không gửi lệnh.
  - Chạy thử trên Chrome không giao diện (điều khiển qua CDP) với một trạm giả gửi lên topic thử riêng:
    - Trang kết nối được, hiện số đo trực tiếp, lấy mẫu, nhập tham chiếu, ra bảng sai số, biểu đồ và chú thích.
    - Phần đo nhiễu chạy đúng; dữ liệu còn sau khi tải lại trang; trạng thái online/offline theo LWT đúng.
    - Console không có lỗi.
  - Lỗi tìm thấy khi chạy thử và đã sửa:
    - Đổi topic nhưng trang vẫn hiện trạng thái của topic cũ.
    - Bảng mẫu rộng làm cả trang tràn khung.
    - Nhãn trục bị làm tròn sai với bước 2,5.
    - Chữ `y = x` đè lên đường chéo.
- Phase 2: log `[NTP] Da co gio sau ... ms` và `Thanh cong! (... ms, heap trong ... byte)`.
  - Bản đầu đo NTP bằng `time(nullptr)` trong `loop()`, nên con số sẽ bị cộng thêm thời gian `loop()` bị chặn khi bắt tay TLS. Đã đổi sang `sntp_set_time_sync_notification_cb`.
  - Build `-Wall -Wextra` không có cảnh báo.
- Phase 3: 4 hình sơ đồ trong `docs/hinh/`, sinh bằng `ve_hinh.py` và xuất PNG bằng Chrome. Hình 3.4 dùng đúng chữ trên app ("Đang gửi tới trạm...").

## Decision

- Không tự sửa Google Docs khi chưa có connector Google Docs. Connector Claude Docs không mở được tài liệu Google.
- Không gửi bản tin thử lên topic thật `soil_station/1/*`. Bản tin status giữ lại của trạm giả đã được xóa sau khi chạy thử.

## Next steps

- Cắm ESP32, nạp firmware và xem 2 dòng log mới (việc cuối của phase 2).
- Bật connector Google Docs rồi chạy lại `/ak:cook` để làm mục 1 – 8 của phase 3.
- Nhóm đo thực nghiệm theo phase 4 bằng `web/evaluation.html`.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
