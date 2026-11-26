---
title: Lập kế hoạch bổ sung báo cáo giai đoạn 2
date: 2026-11-26
summary: "Rà soát báo cáo Google Docs so với code và lập kế hoạch 5 phase: trang web sai số, log firmware, sửa báo cáo, đo thật, điền số liệu"
---

# Lập kế hoạch bổ sung báo cáo giai đoạn 2

## What happened

- Đọc báo cáo giai đoạn 2 trên Google Docs. Không có connector nên tải file `.docx` qua link công khai rồi chuyển thành văn bản để đọc.
- Đối chiếu với code ở commit `9e37561`, thấy báo cáo lệch nhiều chỗ:
  - N, P, K: báo cáo ghi "theo loại đất, không tăng theo độ ẩm", nhưng code tính `N/P/K = EC × 0,08/0,04/0,11` (commit `92fa498`).
  - LWT: báo cáo ghi "chưa có", nhưng code đã có LWT offline giữ lại trên broker và gửi lại online mỗi 30 giây.
  - Rơ-le, bơm, van vẫn còn trong báo cáo dù đã bỏ khỏi code.
  - Bộ đệm MQTT ghi 512 byte, code là 768.
  - Bảng 3.6 thiếu `npk_normal` và `npk_level`.
- Chương 4 có số kết luận nhưng các bảng gốc còn trống: MAE 4,4%, RMSE 4,9%, Bảng 4.7. MAE tính gộp các chỉ số khác đơn vị thành % là sai định nghĩa. Bảng 4.3 bị lệch cột kết quả.
- Báo cáo thiếu ảnh của cả 13 hình, thiếu Phụ lục A và không có trích dẫn nào trong thân bài.
- Tính lại Bảng 4.5 theo code ở độ ẩm 50%: đất vườn được OLED báo OK nhưng app chỉ cho 70 điểm, vì app dùng một bộ ngưỡng chung còn firmware so với mức bình thường của từng loại đất.

## Decision

- Giữ cách tính chỉ số như code hiện tại. Báo cáo sửa theo code.
- MAE, RMSE, MAPE tính và hiện trên một trang web riêng (`web/evaluation.html`, WSS 8084), không hiện trên OLED.
- Số liệu Chương 4 chưa được đo: gỡ hết, đo thật rồi mới điền lại.
- Nhóm tự xóa phần broker có tài khoản và ACL. Báo cáo theo đúng `broker.emqx.io` (có TLS, không có tài khoản).
- Sửa tài liệu qua connector Google Docs. Rủi ro: file có vẻ là `.docx` ở chế độ tương thích Office mà API không sửa được. Phương án dự phòng: lưu thành Google Tài liệu, hoặc sửa file `.docx` rồi tải lên phiên bản mới.

## Next steps

- `/ak:cook plans/261126-0110-bao-cao-gd2-bo-sung/plan.md`: bắt đầu từ phase 1 (trang web) và phase 2 (log NTP/TLS trong firmware).
- Câu hỏi còn mở:
  - Bộ kit N, P, K ra số hay ra mức?
  - Có sửa app để chấm điểm theo `npk_level` không?
  - Nhóm có mốc thời gian để điền Phụ lục A không?

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.
