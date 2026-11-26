---
title: "Bổ sung báo cáo giai đoạn 2: khớp với code, trang web đánh giá sai số và số đo thật"
description: "Sửa báo cáo cho khớp code hiện tại, đo thật trên mạch (phần lớn Claude tự chạy qua COM7), tính sai số N, P, K so với mức chuẩn của từng loại đất, rồi điền số liệu và hình vào báo cáo trên Google Tài liệu."
status: in-progress
priority: P1
effort: "17h"
branch: main
tags: [docs, iot, esp32, mqtt, web, evaluation, report]
blockedBy: []
blocks: []
created: 2026-11-26
---

# Bổ sung báo cáo giai đoạn 2

## Overview

Sửa báo cáo cho khớp code hiện tại, đo thật trên mạch, tính sai số N, P, K so với mức chuẩn của từng loại đất, rồi điền số liệu và hình vào báo cáo.

- Tài liệu: báo cáo giai đoạn 2 trên Drive. Link do nhóm giữ, không ghi vào repo vì repo công khai mà tài liệu có tên và MSSV.
- Ngày 2026-11-26 đọc lại toàn bộ tài liệu lần 2 qua connector Google Docs. Nhóm chưa sửa chỗ nào trong danh sách của phase 3. Tài liệu chỉ có 2 ảnh (logo ở 2 trang bìa), 13 chú thích hình chưa có ảnh.
- Trạm đã nạp firmware mới nhất, đang chạy ở COM7, vào được Wi-Fi và `broker.emqx.io:8883`. Claude tự chạy phần lớn phép đo qua Serial và MQTT. Nhóm chỉ làm việc cần tay: nhúng đầu dò, chuẩn bị cốc đất, tắt router, chụp ảnh mạch và app.

## Quyết định đã chốt

| Câu hỏi | Quyết định | Hệ quả cho kế hoạch |
|---|---|---|
| Cách tính chỉ số | Giữ như code: độ ẩm → EC → N, P, K (`firmware/src/soil_estimator.h`) | Báo cáo bỏ câu "N, P, K lấy theo loại đất, không tăng theo độ ẩm" và viết lại theo code |
| Sai số so với gì (chốt lại 2026-11-26) | Nhóm không có bộ kit thử đất. Sai số là độ lệch của N, P, K ước lượng so với mức chuẩn nhóm đặt cho loại đất đó (`npk_normal` trong bản tin) | Bỏ mọi chỗ nói đo bằng bộ kit. Trang web tự lấy mức chuẩn làm giá trị tham chiếu (phase 4). Báo cáo nói rõ đây không phải độ chính xác so với số đo thật (rủi ro 3) |
| Sai số hiện ở đâu | Trên trang web, không hiện trên OLED | Firmware không thêm gì về sai số |
| Số liệu Chương 4 | NTP 1,82 s, TLS 1,2 s, Bảng 4.7, MAE 4,4%, RMSE 4,9% là số tạm, chưa đo | Gỡ số tạm (phase 3), đo thật (phase 4), điền lại (phase 5) |
| Tài khoản và ACL (đổi lần 2, tối 2026-11-26) | **Làm.** Broker riêng EMQX Serverless `y0601019.ala.asia-southeast1.emqxsl.com` (8883 TLS, 8084 WSS), 3 tài khoản `soil_station`, `soil_app`, `soil_web` và ACL, mọi việc khác bị luật `#` Deny chặn | Phase 3 mục 2 đã xóa phần ACL khỏi tài liệu theo quyết định cũ, giờ viết lại theo EMQX ở phase 3 mục 2b. Bằng chứng: `python scripts/test_broker_acl.py` đạt 22/22 mục |
| Cách sửa tài liệu (đổi 2026-11-26) | Tài liệu là file `.docx` và tài khoản Google nối với Claude chỉ được xem. Nhóm lưu thành Google Tài liệu và cấp quyền sửa, Claude sửa qua API | Link tài liệu đổi. Bản `.docx` giữ làm dự phòng, nhóm ngừng sửa bản đó. Phase 3 bước 1 kiểm tra bản chuyển đổi |
| Bắt gói tin bằng Wireshark (chốt 2026-11-26) | Bỏ | Xóa dòng bắt gói ở Bảng 4.3 và Hình 4.3, đánh lại số hình Chương 4 |
| Ảnh | Claude tự làm ảnh không cần tay (sơ đồ, trang web, nhật ký Serial). Nhóm chụp mạch, OLED, app | API chỉ chèn ảnh có URL công khai. Repo đang công khai: nhóm đồng ý đẩy ảnh lên GitHub thì Claude chèn bằng link raw, không thì nhóm tự chèn (phase 5) |
| Tự chèn hay Claude sửa (2026-11-26, lần 3) | Cấp quyền sửa file `.docx` không đủ: connector Drive vẫn không sửa được, Docs API không ghi vào `.docx`. Nhóm tự chèn số và ảnh | Claude gom số và ảnh vào `docs/thuc-nghiem/so-lieu-bao-cao.md` và cập nhật tệp này mỗi khi có số đo mới. Nhóm lưu thành Google Tài liệu thì Claude quay lại sửa thẳng |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Trang web đánh giá sai số](./phase-01-web-danh-gia-sai-so.md) | Completed: `web/evaluation.html`, 12 kiểm thử qua, chạy thử với trạm giả trên Chrome |
| 2 | [Phase 2: Thêm log đo thời gian trong firmware](./phase-02-firmware-log-do.md) | Completed: nạp vào board ngày 2026-11-26, Serial in đủ dòng NTP và MQTT |
| 3 | [Phase 3: Chuyển sang Google Tài liệu và sửa chữ cho khớp code](./phase-03-dong-bo-bao-cao-voi-code.md) | In progress: xong 4 hình sơ đồ; chờ nhóm lưu thành Google Tài liệu và cấp quyền sửa |
| 4 | [Phase 4: Đo thực nghiệm trên mạch thật](./phase-04-do-thuc-nghiem.md) | Pending: phần tự động (4A) làm được ngay, phần cần tay (4B) làm cùng nhóm |
| 5 | [Phase 5: Điền số liệu, hình và rà soát cuối](./phase-05-dien-so-lieu-hoan-thien.md) | Pending |

Phase 3 và 4 chạy song song. Phần 4A không cần ai. Phase 3 chờ nhóm chuyển tài liệu. Phase 5 cần cả 3 và 4.

```
Phase 1 (web) ──┬──> Phase 3 (chuyển tài liệu, sửa chữ) ───────────┐
Phase 2 (log) ──┴──> Phase 4 (4A tự động, 4B cùng nhóm, 4C ảnh) ───┴──> Phase 5 (điền số, chèn ảnh)
```

## Nhóm cần làm hoặc cung cấp

- [ ] Lưu tài liệu thành Google Tài liệu (Tệp → Lưu dưới dạng Google Tài liệu), cấp quyền Người chỉnh sửa cho tài khoản Google đang nối với Claude, gửi link mới trong cuộc trò chuyện. Việc này chặn phase 3.
- [ ] Một buổi đo khoảng 2 giờ cạnh máy tính (phase 4B): 3 loại đất, 12 cốc mẫu, cốc nước, khăn lau, bình xịt, được tắt router Wi-Fi vài phút.
- [ ] Ảnh chụp bằng điện thoại theo danh sách ở phase 4B.
- [ ] Đời máy điện thoại chạy app, ngày ký Lời cam đoan.
- [ ] Đồng ý hay không việc đẩy ảnh và log lên GitHub (phase 5 bước 5).

## Rủi ro

| # | Rủi ro | Mức | Cách xử lý |
|---|---|:---:|---|
| 1 | Chuyển `.docx` sang Google Tài liệu có thể làm mất số tự động trong chú thích (đang hiện "Bảng 4.:"), mục lục, danh mục bảng và hình, hoặc công thức Chương 2 | Cao | Phase 3 bước 1 kiểm tra từng thứ. Mất số chú thích thì ghi số cố định. Mất danh mục thì viết lại bằng chữ ở phase 5 |
| 2 | Nhóm sửa tài liệu cùng lúc với Claude | Trung bình | Mỗi lô ghi kèm `writeControl.requiredRevisionId` từ lần đọc ngay trước. Bị từ chối thì đọc lại rồi làm lại |
| 3 | Sai số so với mức chuẩn gần như chỉ phụ thuộc độ ẩm: tỉ số ước lượng / mức chuẩn = hằng số × độ ẩm. Ở độ ẩm 60% lệch không quá 4%, riêng K đất bạc màu lệch −12%. Đất khô kiệt hay bão hòa lệch rất lớn | Cao | Báo cáo trình bày đây là kiểm tra hệ số có cho đúng mức chuẩn quanh độ ẩm lý tưởng không, và khoảng độ ẩm cho mức "bình thường". Không gọi là độ chính xác. Hạn chế ghi rõ chưa có số đo tham chiếu độc lập |
| 4 | Bản nạp tạm (NTP sai, CA sai, không TLS) bị để lại trên board hoặc lẫn vào `firmware/src` | Trung bình | Build từ bản sao của `firmware/` trong scratchpad. Cuối phần 4A nạp lại firmware chính, `git diff firmware/src` trống, Serial in đủ dòng |
| 5 | Thời gian có giờ NTP đo thật khoảng 15 s (2 lần: 15,3 và 15,4 s), khác xa số tạm 1,82 s và cột mong đợi "Vài giây" | Trung bình | Ghi số thật và kết luận đúng là chưa đạt nếu vậy. Chỉ ghi nguyên nhân khi đã kiểm chứng. Sửa firmware để có giờ nhanh hơn nằm ngoài phạm vi |
| 6 | Số mẫu nhỏ: 12 mẫu, mỗi loại đất 4 mẫu | Thấp | Ghi n cạnh mỗi số, kết luận dè dặt, đưa vào Hạn chế |
| 7 | Ảnh và log đẩy lên repo công khai | Thấp | Che tên Wi-Fi, bỏ địa chỉ IP, không đưa ảnh có mặt người hay mật khẩu. Hỏi nhóm trước khi push |
| 8 | Giữ chân EN ở mức thấp để giả mất nguồn có thể khác rút điện thật | Thấp | Về phía broker hai cách như nhau: kết nối TCP đứt, không có gói DISCONNECT. Nhóm rút USB thật 1 lần để đối chiếu |
| 9 | Mật khẩu `soil_app` nằm trong file APK, ai mở APK ra là đọc được | Thấp (demo) | ACL chỉ cho `soil_app` nhận số đo và gửi lệnh, không gửi được số đo giả. Mật khẩu chỉ nằm trong `secrets.h` và `mqtt_config.json` (đã `.gitignore`), trang web không lưu mật khẩu |

## Ngoài phạm vi

- Sửa app để chấm điểm theo mức chuẩn của từng loại đất (câu hỏi mở 1).
- Sửa firmware để có giờ NTP nhanh hơn.
- Bắt gói tin, hiện sai số trên OLED.

## Câu hỏi còn mở

1. Có sửa app để chấm điểm theo mức chuẩn từng loại đất (dùng trường `npk_level` trạm đã gửi) không? Mặc định: không sửa, chỉ ghi vào Hạn chế.
2. Đẩy `docs/hinh/` và `docs/thuc-nghiem/` lên GitHub để Claude tự chèn ảnh không? Hỏi ở phase 5 bước 5.

## Success Criteria

- [ ] `node --test "web/*.test.js"` và `python -m unittest test_report_measure` (chạy trong `scripts/`) đều qua
- [ ] Sau các bản nạp tạm, board chạy lại firmware chính, `git diff firmware/src` trống, Serial in đủ dòng NTP và MQTT
- [ ] Báo cáo không còn chỗ mâu thuẫn với code: N, P, K theo EC, đã có LWT, không còn rơ-le, bộ đệm 768 byte, Bảng 3.6 có `npk_normal` và `npk_level`, phần tài khoản và ACL khớp broker riêng EMQX, không còn bộ kit (trừ Hạn chế và Hướng phát triển)
- [ ] Mọi số trong Chương 4 có tệp gốc trong `docs/thuc-nghiem/`
- [ ] Tài liệu không còn `[CHỜ SỐ ĐO]`, `[CHỜ ẢNH]` hay ô "…", và đủ 13 hình có ảnh (3.1 – 3.7, 4.1 – 4.6 sau khi bỏ hình Wireshark)

<!-- slug: bao-cao-gd2-bo-sung -->
