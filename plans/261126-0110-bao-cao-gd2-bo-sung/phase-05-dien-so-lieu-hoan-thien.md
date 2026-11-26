---
phase: 5
title: "Điền số liệu, hình và rà soát cuối"
status: pending
priority: P1
effort: "2h"
dependencies: [3, 4]
---

# Phase 5: Điền số liệu, hình và rà soát cuối

## Goal

Thay mọi đánh dấu `[CHỜ SỐ ĐO]` và `[CHỜ ẢNH]` bằng số và ảnh thật từ phase 4, viết kết luận đúng mức dữ liệu cho phép, rồi rà soát cả tài liệu lần cuối trước khi nộp.

## Files to Create / Modify

- Modify: bản Google Tài liệu của báo cáo (bản đã chuyển ở phase 3)
- Read: `docs/thuc-nghiem/README.md`, `docs/thuc-nghiem/*.csv`, `docs/thuc-nghiem/log/*.txt`, `docs/hinh/*`

## Tasks & Steps

1. Đọc tài liệu (lưu JSON ra tệp rồi trích bằng script), liệt kê vị trí còn `[CHỜ SỐ ĐO]` và `[CHỜ ẢNH]`, so với số đếm ở cuối phase 3.
2. Điền bảng từ tệp gốc, không gõ lại số bằng tay khi đã có trong log hay CSV:
   - Bảng 4.1: đời máy điện thoại.
   - Bảng 4.2 từ `khoi-dong-10-lan.txt`, `do-lech-timestamp.txt`, `mat-wifi.txt`, `ntp-may-chu-chinh-sai.txt`, `khong-co-gio.txt`.
   - Bảng 4.3 từ `khoi-dong-10-lan.txt` (TLS), `ca-sai.txt`, `khong-tls.txt`.
   - Bảng 4.4 từ `mat-nguon.txt`, `mat-wifi.txt` và ghi chép của nhóm ở bước 4B.7.
   - Bảng 4.5: thêm cột số đo thật từ `chon-loai-dat.txt` và điểm đọc trên ảnh app.
   - Bảng 4.6 từ `hieu-chuan.txt`.
   - Bảng 4.7 từ `node scripts/report_stats.js noise` cho 2 tệp `nhieu-*.csv`.
   - Bảng 4.8 và 4.9 từ `mau-dat.csv` và `node scripts/report_stats.js samples`.
   - Chương 3 mục 3.3: kích thước bản tin từ `do-lech-timestamp.txt`.
3. Viết lại đoạn kết quả của Chương 4 mục 2, 3, 4, 6.2 và 6.3 theo số thật:
   - Mỗi số ghi kèm đơn vị và n.
   - Cột "Kết quả thực tế" ghi Đạt hoặc Chưa đạt so với cột mong đợi đã có. Ví dụ thời gian có giờ khoảng 15 giây thì ghi Chưa đạt so với "Vài giây". Chỉ ghi nguyên nhân khi đã kiểm chứng.
   - Sai số so với mức chuẩn: nêu khoảng độ ẩm cho mức bình thường, mẫu nào lệch nhiều và vì sao (do độ ẩm của mẫu, do hệ số như K đất bạc màu). Không viết đây là độ chính xác của phép đo.
   - Nếu mức giảm nhiễu lớn hơn khoảng √21 ≈ 4,6 lần thì giải thích bằng nhiễu gai, dựa vào số liệu trong CSV.
   - Không viết câu kết luận rộng hơn dữ liệu.
4. Cập nhật Chương 5 cho khớp số thật: các ý trong Kết quả đạt được, Bảng 5.1, Hạn chế (số mẫu nhỏ, n theo từng chất, chưa có số đo tham chiếu độc lập, thời gian có giờ NTP nếu chưa đạt).
5. Ảnh:
   - Hỏi nhóm có đồng ý đẩy `docs/hinh/` và `docs/thuc-nghiem/` lên GitHub không (repo đang công khai). Chỉ commit và push khi nhóm trả lời đồng ý trong cuộc trò chuyện.
   - Đồng ý: commit, push, rồi chèn từng ảnh bằng `insertInlineImage` với link `https://raw.githubusercontent.com/<owner>/<repo>/<mã commit>/docs/hinh/<tệp>`. Dùng mã commit chứ không dùng `main` để link không đổi. Chèn vào đoạn trống ngay trên chú thích, rộng tối đa 450 pt. Đọc lại để chắc ảnh đã hiện.
   - Không đồng ý: gửi nhóm danh sách tệp ảnh kèm chú thích tương ứng để nhóm tự chèn.
   - Danh sách: Hình 3.1 – 3.7 và 4.1 – 4.6 (13 hình).
6. Phụ lục: ghi kết quả từng dòng theo `docs/thuc-nghiem/README.md`. Lời cam đoan: điền ngày ký nhóm cung cấp.
7. Mục lục, danh mục bảng (thêm Bảng 4.9), danh mục hình (thêm Hình 3.7, bỏ hình Wireshark, đánh lại số Chương 4):
   - Mục lục là mục lục tự động của Google Tài liệu thì nhóm bấm cập nhật (API không cập nhật được).
   - Danh mục là chữ cố định hoặc đã mất khi chuyển đổi thì Claude viết lại bằng chữ.
8. Rà soát cuối:
   - Tìm "…", `[CHỜ`, "rơ-le", "chưa có LWT", "ACL", "HiveMQ", "bộ kit", "bộ dụng cụ", "Wireshark", "MQTTX": không còn chỗ nào sai ngữ cảnh (các chỗ được giữ có ghi ở phần Verification của phase 3).
   - Mọi bảng và hình được nhắc tới trong thân bài.
   - Danh mục viết tắt khớp với chữ viết tắt thật sự xuất hiện.
9. Xuất PDF bằng `download_file_content` với `exportMimeType: application/pdf`, mở bằng công cụ đọc PDF và xem từng trang: bảng không vỡ, công thức hiện đúng, ảnh nằm trên chú thích, số trang khớp mục lục.

## Todo

- [ ] Điền Bảng 4.1 – 4.9 và kích thước bản tin từ tệp gốc
- [ ] Viết lại đoạn kết quả Chương 4 mục 2, 3, 4, 6.2, 6.3 và Chương 5 theo số thật
- [ ] Hỏi nhóm về việc đẩy ảnh, rồi chèn đủ 13 hình (hoặc gửi danh sách cho nhóm)
- [ ] Phụ lục và ngày ký Lời cam đoan
- [ ] Mục lục, danh mục bảng, danh mục hình
- [ ] Rà soát cuối và xuất PDF

## Verification

- Tìm `[CHỜ SỐ ĐO]`, `[CHỜ ẢNH]` và "…" trong tài liệu: 0 kết quả.
- Mỗi số trong Bảng 4.1 – 4.9 tìm được trong một tệp ở `docs/thuc-nghiem/`.
- `read_doc` đếm được 15 ảnh: 2 logo trường cộng 13 hình.
- Bản PDF xuất ra có số trang ở mục lục khớp với trang thật.
