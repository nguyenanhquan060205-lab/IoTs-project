---
title: Sửa kế hoạch báo cáo GĐ2 sau khi đọc lại tài liệu
date: 2026-11-26
summary: Tài liệu là .docx chỉ được xem; không có bộ kit nên sai số so với mức chuẩn npk_normal; phase 4 chia phần tự động qua COM7 và phần làm cùng nhóm
---

# Sửa kế hoạch báo cáo GĐ2 sau khi đọc lại tài liệu

## What happened

- Đọc lại toàn bộ báo cáo GĐ2 qua connector Google Docs (499 đoạn và bảng, 2 ảnh logo, 13 chú thích hình chưa có ảnh). Nhóm chưa sửa chỗ nào trong danh sách của phase 3.
- `get_file_metadata` cho thấy tài liệu là `.docx` (`mimeType` Word), `canEdit: false` với tài khoản đang nối. Docs API đọc được nhưng không ghi được.
- Phase 2 xong: nạp firmware qua COM7, Serial in `[NTP] Da co gio sau 15349 ms` và `Thanh cong! (1533 ms, heap trong 167056 byte)`. Lần nạp thứ hai: 15412 ms, 2503 ms. Số NTP thật khoảng 15 s, khác xa số tạm 1,82 s trong báo cáo.
- Máy có Python 3.14, Node 24, Chrome, Word, openssl; chưa có paho-mqtt, Wireshark, MQTTX, adb. Repo GitHub công khai (API trả 200).

## Decision

- Nhóm lưu tài liệu thành Google Tài liệu và cấp quyền sửa; Claude sửa qua API.
- Không có bộ kit: sai số là độ lệch N, P, K so với `npk_normal` của loại đất. Với hệ số hiện tại, tỉ số ước lượng / mức chuẩn = hằng số × độ ẩm, nên sai số này đo độ lệch khỏi mức chuẩn theo độ ẩm, không đo độ chính xác. K đất bạc màu lệch −12% ngay ở độ ẩm 60% (khoảng bình thường 54,5 – 81,8%). Báo cáo phải nói rõ.
- Claude xóa luôn phần tài khoản và ACL. Bỏ phép thử Wireshark và Hình 4.3, đánh lại số hình Chương 4.
- Phase 4 chia 4A (Claude tự đo qua Serial và MQTT, đặt lại trạm qua RTS, bản nạp tạm build từ bản sao `firmware/` trong scratchpad), 4B (làm cùng nhóm), 4C (ảnh dựng từ số đo thật).
- Ảnh chèn bằng link raw GitHub theo mã commit nếu nhóm đồng ý push; không thì nhóm tự chèn.

## Next steps

- Nhóm: lưu thành Google Tài liệu, cấp quyền sửa, gửi link mới.
- Claude: chạy phase 4.0 và 4A ngay (không cần ai), rồi phase 3 khi có link.
- Hẹn buổi đo 4B khoảng 2 giờ.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
