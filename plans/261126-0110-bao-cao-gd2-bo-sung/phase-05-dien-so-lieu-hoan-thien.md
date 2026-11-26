---
phase: 5
title: "Điền số liệu, hình và rà soát cuối"
status: pending
priority: P1
effort: "1h30m"
dependencies: [3, 4]
---

# Phase 5: Điền số liệu, hình và rà soát cuối

## Goal

Thay mọi đánh dấu `[CHỜ SỐ ĐO]` và `[CHỜ ẢNH]` bằng số và ảnh thật từ phase 4. Viết kết luận đúng mức dữ liệu cho phép, rồi rà soát cả tài liệu lần cuối trước khi nộp.

## Files to Create / Modify

- Modify: tài liệu Google Docs (bản đã chọn ở phase 3)
- Read: `docs/thuc-nghiem/README.md`, `docs/thuc-nghiem/*.csv`, `docs/thuc-nghiem/log/*.txt`

## Tasks & Steps

1. Đọc tài liệu, liệt kê vị trí còn đánh dấu `[CHỜ SỐ ĐO]` và `[CHỜ ẢNH]`, so với số đếm được ở cuối phase 3.
2. Điền bảng từ tệp gốc, không gõ lại số bằng tay khi đã có trong CSV:
   - Bảng 4.2 từ log NTP và độ lệch `timestamp`.
   - Bảng 4.3 từ log TLS và ảnh Wireshark.
   - Bảng 4.4 từ nhật ký kết nối lại.
   - Bảng 4.6 từ 3 lần hiệu chuẩn.
   - Bảng 4.7 từ `nhieu-*.csv` (tính lại bằng `noiseSummary`).
   - Bảng 4.8 và 4.9 từ `mau-dat.csv` (tính lại bằng `errorStats`).
   - Thêm cột số đo thật cạnh Bảng 4.5.
3. Viết lại đoạn văn kết quả của mục 4.2, 4.3, 4.6.2 và 4.6.3 theo số thật:
   - Mỗi chỉ số nêu MAE, RMSE kèm đơn vị và n.
   - Nói rõ chỉ số nào lệch nhiều và vì sao (khác định nghĩa, ít mẫu, mức bình thường do nhóm tự đặt).
   - Không viết câu kết luận rộng hơn dữ liệu.
   - Nếu mức giảm nhiễu lớn hơn khoảng √21 ≈ 4,6 lần thì giải thích bằng nhiễu gai, dựa vào số liệu CSV.
4. Cập nhật Chương 5 cho khớp số thật: các ý trong Kết quả đạt được, Bảng 5.1, Hạn chế (số mẫu nhỏ, n theo chỉ số).
5. Ảnh: nhóm chèn các tệp trong `docs/hinh/` vào đúng chú thích. Đọc lại tài liệu để chắc mỗi chú thích Hình 3.1 – 3.7 và 4.1 – 4.7 có ảnh ngay trên nó.
6. Phụ lục B: ghi kết quả từng dòng theo `docs/thuc-nghiem/README.md`. Phụ lục A: điền nếu nhóm có mốc thời gian, không có thì đã xóa ở phase 3.
7. Lời cam đoan: nhóm điền ngày ký.
8. Cập nhật mục lục, danh mục bảng (thêm Bảng 4.9) và danh mục hình (thêm Hình 3.7). Mục lục đang là chữ thường thì sửa tay số trang sau khi xuất PDF.
9. Rà soát cuối:
   - Tìm "…", `[CHỜ`, "rơ-le", "chưa có LWT", "ACL", "tài khoản": không còn chỗ nào sai ngữ cảnh.
   - Mọi bảng và hình được nhắc tới trong thân bài.
   - Danh mục viết tắt khớp với chữ viết tắt thật sự xuất hiện.
10. Xuất PDF (Tệp → Tải xuống → PDF), xem từng trang: bảng không vỡ, công thức hiển thị đúng, số trang khớp mục lục.

## Todo

- [ ] Điền Bảng 4.2 – 4.9 từ tệp gốc
- [ ] Viết lại đoạn kết quả mục 4.2, 4.3, 4.6.2, 4.6.3 và Chương 5 theo số thật
- [ ] Đủ ảnh cho Hình 3.1 – 3.7 và 4.1 – 4.7
- [ ] Phụ lục A, B và ngày ký Lời cam đoan
- [ ] Mục lục, danh mục bảng, danh mục hình
- [ ] Rà soát cuối và xuất PDF

## Verification

- Tìm `[CHỜ SỐ ĐO]`, `[CHỜ ẢNH]` và "…" trong tài liệu: 0 kết quả.
- Mỗi số trong Bảng 4.2 – 4.9 tìm được trong một tệp ở `docs/thuc-nghiem/`.
- Đếm ảnh trong tài liệu: 2 logo trường (ở 2 trang bìa) cộng 14 hình (3.1 – 3.7, 4.1 – 4.7).
- Bản PDF xuất ra có số trang ở mục lục khớp với trang thật.
