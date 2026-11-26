---
title: Đo tự động trên trạm thật và chụp ảnh giao diện cho báo cáo GĐ2
date: 2026-11-26
summary: "Đo NTP, TLS, mất nguồn qua COM7 bằng report_measure.py và 4 bản nạp tạm; chụp app bản Windows và trang web; NTP chậm 15-20 s và TLS không cần giờ là hai phát hiện phải sửa trong báo cáo"
---

# Đo tự động trên trạm thật và chụp ảnh giao diện cho báo cáo GĐ2

## What happened

- Viết `scripts/report_measure.py` (13 kiểm thử) đo qua Serial và MQTT, log tự che tên Wi-Fi và IP. Trang web tự điền `npk_normal` làm tham chiếu N, P, K (14 kiểm thử). `scripts/report_stats.js` tính số bằng chính `web/metrics.js`.
- Board bị ngắt USB 2 lần (12:43 và khoảng 13:24, chip CP210x biến mất khỏi Windows). Lần thứ hai làm hỏng lần đo mất nguồn 2 và 3; đo bù sau khi cắm lại.
- Kết quả trên board thật (ngày 2026-11-26):
  - NTP: 10 lần, 3 lần dưới 4 s, 7 lần 15.3 – 19.6 s. Đặt sai tên máy chủ chính thì có giờ sau 1.9 – 4.6 s, nên 15 s nhiều khả năng là thời gian chờ pool.ntp.org trước khi chuyển sang time.google.com (chưa bắt gói xác nhận).
  - Không có giờ (sai cả hai máy chủ): bản tin thiếu `timestamp` nhưng TLS vẫn kết nối, trái với Chương 2 mục 3.1 của báo cáo.
  - TLS: 10/10 thành công, trung vị 1.68 s. CA sai: 16/16 bị từ chối rc=-2. Không TLS: 0.83 s và thêm khoảng 43.7 KB RAM trống.
  - Mất nguồn (giữ EN thấp): offline sau 28.0 – 32.6 s, online lại sau 12.1 – 12.5 s.
- Connector Drive vẫn `canEdit: false` dù nhóm đã cấp quyền sửa file `.docx`; Docs API không ghi được `.docx`. Nhóm tự chèn từ `docs/thuc-nghiem/so-lieu-bao-cao.md`.
- Ảnh: chạy app Flutter bản Windows (release) trong cửa sổ 412 × 880, điều khiển bằng PowerShell (PrintWindow, click theo tỉ lệ), đổi loại đất trên chính app. Trang web chụp qua Chrome DevTools Protocol bằng Node 24 (`docs/hinh/chup_trang_web.js`). Hình 4.1 dựng từ log thật (`docs/hinh/ve_hinh_serial.py`).

## Decision

- Bản nạp tạm luôn build từ bản sao `firmware/` trong scratchpad; sau đó nạp lại firmware chính và kiểm `git diff firmware/src` trống.
- Ảnh app ghi rõ là bản Windows của cùng app; nhóm chụp lại trên điện thoại nếu cần.

## Next steps

- Nhóm: chụp OLED và mạch (Hình 4.5), buổi đo 4B (hiệu chuẩn, nhiễu, 12 mẫu, tắt router, app trên 4G).
- Sửa chữ trong báo cáo theo phase 3, thêm hai mục mới: NTP chậm và TLS không kiểm tra hạn chứng chỉ khi chưa có giờ.
- Chưa commit.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
