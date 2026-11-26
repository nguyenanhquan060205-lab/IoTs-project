---
title: "Bổ sung báo cáo giai đoạn 2: khớp với code, trang web đánh giá sai số và số đo thật"
description: "Sửa báo cáo Google Docs cho khớp code hiện tại, làm trang web tính MAE/RMSE/MAPE, đo thực nghiệm thật rồi điền số liệu và hình vào báo cáo."
status: in-progress
priority: P1
effort: "13h30m"
branch: main
tags: [docs, iot, esp32, mqtt, web, evaluation, report]
blockedBy: []
blocks: []
created: 2026-11-26
---

# Bổ sung báo cáo giai đoạn 2

## Overview

Sửa báo cáo Google Docs cho khớp code hiện tại, làm trang web tính MAE/RMSE/MAPE, đo thực nghiệm thật rồi điền số liệu và hình vào báo cáo.

- Tài liệu: báo cáo giai đoạn 2 trên Google Docs. Link do nhóm giữ, không ghi vào repo vì repo công khai mà tài liệu có tên và MSSV (đã đọc toàn bộ ngày 2026-11-26).
- Bản rà soát chi tiết nằm trong cuộc trò chuyện ngày 2026-11-26. Các phase dưới đây chuyển từng điểm của bản rà soát thành việc cụ thể.

## Quyết định đã chốt (2026-11-26)

| Câu hỏi | Quyết định | Hệ quả cho kế hoạch |
|---|---|---|
| Cách tính chỉ số | Giữ như code hiện tại: độ ẩm → EC → N, P, K (`firmware/src/soil_estimator.h`) | Báo cáo phải bỏ câu "N, P, K lấy theo loại đất, không tăng theo độ ẩm" và viết lại theo code |
| Sai số hiện ở đâu | Tính và hiện trên **trang web**, không hiện trên OLED | Thêm trang `web/evaluation.html` (phase 1), firmware không thêm gì về sai số |
| Số liệu Chương 4 | **Chưa đo**. Các số NTP 1,82 s, TLS 1,2 s, Bảng 4.7, MAE 4,4%, RMSE 4,9% là số tạm | Gỡ hết số chưa đo (phase 3), đo thật (phase 4), điền lại (phase 5) |
| Broker có tài khoản và ACL | Bỏ. **Nhóm tự xóa phần này trong tài liệu** | Kế hoạch không sửa các đoạn đó, chỉ liệt kê vị trí bên dưới để nhóm không sót. Báo cáo theo đúng broker đang dùng: `broker.emqx.io` cổng 8883, có TLS, không tài khoản |
| Cách sửa tài liệu | Bật connector Google Docs, sửa thẳng vào tài liệu | Phase 3 và 5 bắt đầu bằng bước kiểm tra quyền sửa (xem rủi ro số 1) |

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Mọi mô tả kỹ thuật trong báo cáo khớp code ở commit `9e37561` trở về sau | P1 |
| 2 | Có trang web tính MAE, RMSE, MAPE theo từng chỉ số và đo nhiễu bộ lọc từ bản tin MQTT thật | P1 |
| 3 | Mọi con số trong Chương 4 đều có dữ liệu gốc (CSV, log, ảnh chụp) lưu trong repo | P1 |
| 4 | Báo cáo đủ hình, đủ bảng, không còn ô "…" hay đánh dấu `[CHỜ SỐ ĐO]` khi nộp | P1 |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Trang web đánh giá sai số](./phase-01-web-danh-gia-sai-so.md) | Completed: `web/evaluation.html`, 12 kiểm thử qua, chạy thử với trạm giả trên Chrome |
| 2 | [Phase 2: Thêm log đo thời gian trong firmware](./phase-02-firmware-log-do.md) | In progress: code xong, build không cảnh báo; còn nạp vào board |
| 3 | [Phase 3: Đồng bộ báo cáo với code và gỡ số chưa đo](./phase-03-dong-bo-bao-cao-voi-code.md) | In progress: xong 4 hình sơ đồ; mục 1 – 8 chờ connector Google Docs |
| 4 | [Phase 4: Đo thực nghiệm trên mạch thật (nhóm thực hiện)](./phase-04-do-thuc-nghiem.md) | Pending |
| 5 | [Phase 5: Điền số liệu, hình và rà soát cuối](./phase-05-dien-so-lieu-hoan-thien.md) | Pending |

Thứ tự: phase 1 và 2 là công cụ đo, làm trước. Phase 3 cần phase 1 xong để mô tả đúng trang web, nhưng không cần số đo nên làm song song với phase 4 được. Phase 5 cần cả phase 3 và 4.

```
Phase 1 (web) ──┬──> Phase 3 (sửa chữ trong báo cáo) ──┐
Phase 2 (log) ──┴──> Phase 4 (đo trên mạch thật) ──────┴──> Phase 5 (điền số, hình)
```

## Phần nhóm tự xóa: tài khoản và ACL

Nhóm đã nhận tự bỏ phần này. Các chỗ đang nhắc tới broker riêng, tài khoản hoặc ACL:

- [ ] Danh mục từ viết tắt: dòng ACL
- [ ] Bảng phân công: việc của Quân "Cấu hình broker MQTT riêng hỗ trợ TLS và tài khoản"
- [ ] Chương 1, mục 1: gạch đầu dòng 2 "xác thực tài khoản riêng"; Bảng 1.1 dòng 2 "broker riêng có tài khoản"
- [ ] Chương 2, mục 4.3: đoạn đầu (tài khoản, ACL, `secrets.h`, `mqtt_config.json`)
- [ ] Chương 3, mục 1: "trạm đăng nhập bằng tài khoản"; Bảng 3.1 bước B2 "(có tài khoản nếu khai báo)" và B5 "Kiểm tra tài khoản"
- [ ] Chương 3, mục 3.3: "gửi gói CONNECT kèm tên đăng nhập và mật khẩu", "rc = 4 hoặc 5 khi sai tài khoản"
- [ ] Chương 3, mục 4.1: cả tiểu mục "Broker MQTT có TLS, tài khoản và ACL" (gồm câu về HiveMQ Cloud)
- [ ] Chương 3, mục 5.1: "Địa chỉ broker và tài khoản lấy từ mqtt_config.json"
- [ ] Bảng 4.1 dòng Máy chủ MQTT: "tài khoản và ACL"
- [ ] Chương 4, mục 3: đoạn 2 "Phân quyền ACL cũng được kiểm tra..."; Bảng 4.3 ba dòng Sai mật khẩu, Cổng 1883 trên broker riêng, ACL
- [ ] Chương 5, mục 1: gạch đầu dòng 2 "đăng nhập broker riêng bằng tài khoản"; Bảng 5.1 dòng Kết nối MQTT "tài khoản"

Phase 3 sẽ thêm vào phần Hạn chế một câu: trạm dùng broker công cộng có TLS nhưng chưa có tài khoản, ai biết topic vẫn đọc và gửi lệnh được.

## Rủi ro

| # | Rủi ro | Mức | Cách xử lý |
|---|---|:---:|---|
| 1 | Mã tài liệu dài 33 ký tự và link tải về trả thẳng file `.docx`, nên nhiều khả năng đây là file Word tải lên Drive, mở bằng Google Docs ở chế độ tương thích Office. Google Docs API không sửa được loại file này | Cao | Phase 3 bước 1 kiểm tra bằng `read_doc`. Nếu lỗi: (A) Tệp → Lưu dưới dạng Google Tài liệu, sửa trên bản mới (link mới, giữ bản cũ làm dự phòng); hoặc (B) sửa file `.docx` tại máy rồi dùng Drive "Quản lý phiên bản → Tải phiên bản mới lên" để giữ link. Khuyên dùng A |
| 2 | Nhóm sửa tài liệu cùng lúc với phase 3 (đang xóa phần ACL) | Trung bình | Mỗi lần ghi dùng `writeControl.requiredRevisionId` từ lần đọc ngay trước đó. Bị từ chối thì đọc lại rồi làm lại, không bỏ cơ chế này |
| 3 | Độ ẩm % của trạm là chỉ số tương đối theo 2 mốc khô/ướt, không phải độ ẩm khối lượng. So thẳng với độ ẩm cân sấy sẽ ra sai số lớn do khác định nghĩa | Trung bình | Báo cáo nêu rõ nguồn tham chiếu của từng chỉ số và đánh giá độ ẩm riêng, không gộp với N, P, K |
| 4 | Bút đo EC thường đo dịch chiết đất:nước (1:2 hoặc 1:5), không phải EC của đất ở độ ẩm đang đo | Trung bình | Ghi rõ cách đo EC tham chiếu trong mục 4.6.3. Nếu khác định nghĩa thì nói rõ sai số gồm cả phần chênh do định nghĩa |
| 5 | Bộ kit N, P, K chỉ cho mức (thấp / trung bình / cao) thay vì số | Trung bình | Trang web nhận số. Nếu kit chỉ cho mức thì báo trước phase 1 để thêm cột mức và tỷ lệ xếp đúng (câu hỏi mở số 1) |
| 6 | Số mẫu nhỏ (12 mẫu, mỗi chỉ số n ≤ 12) nên MAE và RMSE dao động nhiều | Thấp | Ghi n cạnh mỗi chỉ số, kết luận dè dặt, đưa vào Hạn chế |
| 7 | Google Docs API chỉ chèn được ảnh từ URL công khai | Thấp | Ảnh lưu trong `docs/hinh/`, nhóm tự chèn vào tài liệu. Phase 5 chỉ kiểm tra chú thích và danh mục hình |
| 8 | Broker công cộng: ai biết topic cũng đọc được số đo | Thấp (demo) | Trang web chỉ đăng ký nhận, không gửi lệnh, không lưu mật khẩu nào vào repo |

## Ngoài phạm vi

- Sửa app cho khớp với firmware khi đánh giá N, P, K. Hiện ở độ ẩm 50%, đất vườn được OLED báo "OK" (so với mức bình thường của đất vườn) nhưng app trừ còn 70 điểm (so với ngưỡng chung). Kế hoạch này chỉ mô tả đúng hiện trạng trong báo cáo và đưa vào Hạn chế (câu hỏi mở số 2).
- Dựng broker riêng có tài khoản và ACL (nhóm đã chọn bỏ).
- Hiện sai số trên OLED.

## Câu hỏi còn mở

1. Bộ kit thử đất cho N, P, K ra số mg/kg hay chỉ ra mức? Mặc định: ra số. Nếu chỉ ra mức thì phase 1 thêm phần so mức.
2. Có sửa app để chấm điểm theo mức bình thường của từng loại đất (dùng trường `npk_level` trạm đã gửi) không? Mặc định: không sửa, chỉ ghi vào Hạn chế.
3. Phụ lục A (kế hoạch và tiến độ) chưa có trong thân bài. Nhóm có mốc thời gian để điền không? Mặc định: nếu không có thì xóa khỏi mục lục và danh mục bảng.

## Success Criteria

- [ ] `node --test "web/*.test.js"` qua và trang `web/evaluation.html` nhận được bản tin thật từ trạm
- [ ] Firmware build không cảnh báo và Serial in thời gian đồng bộ NTP, thời gian bắt tay TLS, bộ nhớ trống
- [ ] Báo cáo không còn chỗ nào mâu thuẫn với code: N, P, K theo EC, LWT đã có, không còn rơ-le, bộ đệm 768 byte, Bảng 3.6 có `npk_normal` và `npk_level`
- [ ] Mọi số trong Chương 4 có tệp gốc trong `docs/thuc-nghiem/`
- [ ] Tìm trong tài liệu không còn `[CHỜ SỐ ĐO]`, `[CHỜ ẢNH]` hay ô "…", và đủ 14 hình (13 hình đang thiếu ảnh cộng Hình 3.7 trang web) đã có ảnh

<!-- slug: bao-cao-gd2-bo-sung -->
