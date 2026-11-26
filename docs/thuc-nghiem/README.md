# Nhật ký thực nghiệm (Chương 4 báo cáo giai đoạn 2)

Mỗi số trong Chương 4 phải truy được về một tệp trong thư mục này. Mỗi phép đo ghi một dòng vào bảng dưới.

- Log Serial và MQTT do `scripts/report_measure.py` ghi, đã che tên Wi-Fi thành `<wifi>` và địa chỉ IP thành `<ip>`.
- Tệp CSV xuất từ trang `web/evaluation.html`. Số cho báo cáo tính lại bằng `node scripts/report_stats.js noise|samples <tệp>`, dùng chung hàm với trang web.
- Bản nạp tạm (NTP sai, CA sai, không TLS) build từ bản sao của `firmware/` ngoài kho mã. Sau đó board được nạp lại firmware chính.

| Ngày giờ | Người làm | Phép đo | Cách làm | Tệp | Dùng cho |
|---|---|---|---|---|---|
| 2026-11-26 12:48 | Claude | Hạn chứng chỉ gốc | Tách 2 chứng chỉ trong `firmware/src/root_ca.h`, đọc bằng `openssl x509`; xem chuỗi chứng chỉ của broker.emqx.io:8883 bằng `openssl s_client` | `log/chung-chi.txt` | Phụ lục dòng 3 |
| 2026-11-26 12:48 | Claude | Thông tin cấu hình không nằm trong kho mã | `git ls-files`, `git log --all -- firmware/src/secrets.h mobile/mqtt_config.json`, `git check-ignore` | `log/kiem-tra-bi-mat.txt` | Phụ lục dòng 7 |
| 2026-11-26 12:57 | Claude | Khởi động 10 lần (firmware chính) | `report_measure.py boot --count 10`: đặt lại trạm qua chân EN, đọc dòng `[NTP]` và `Thanh cong!` | `log/khoi-dong-10-lan.txt` | Bảng 4.2 dòng 1, Bảng 4.3 dòng 1, Phụ lục dòng 1 |
| 2026-11-26 13:02 | Claude | Độ lệch timestamp, kích thước bản tin | `report_measure.py offset --count 5 --interval 60`, giờ máy tính đã bù theo time.google.com | `log/do-lech-timestamp.txt` | Bảng 4.2 dòng 2, Chương 3 mục 3.3 |
| 2026-11-26 13:08 | Claude | Máy chủ NTP chính sai | Bản nạp tạm đổi `pool.ntp.org` thành `ntp.invalid`, `boot --count 3` | `log/ntp-may-chu-chinh-sai.txt` | Bảng 4.2 dòng 4 |
| 2026-11-26 13:11 | Claude | Không có giờ | Bản nạp tạm đặt sai cả hai máy chủ NTP, `serial-log --reset --minutes 3`; cùng lúc đếm bản tin MQTT có `timestamp` (40 bản tin, 0 có `timestamp`) | `log/khong-co-gio.txt` | Bảng 4.2 dòng 5 |
| 2026-11-26 13:15 | Claude | CA sai | Bản nạp tạm chỉ giữ ISRG Root X1 trong `ROOT_CA_BUNDLE`, `serial-log --reset --minutes 1.5` | `log/ca-sai.txt` | Bảng 4.3 dòng 2 |
| 2026-11-26 13:17 | Claude | Không TLS (cổng 1883) | Bản nạp tạm đặt `useTls = false`, `boot --count 5`. Dòng log ghi "mo phong Wokwi" là nhãn có sẵn trong firmware cho nhánh không mã hóa, phép đo chạy trên board thật | `log/khong-tls.txt` | Bảng 4.3 dòng Chi phí của TLS |
| 2026-11-26 13:20 | Claude | Nạp lại firmware chính | `scripts\flash_esp32.ps1 -Port COM7 -NoMonitor`, `git diff --stat firmware/src` trống, khởi động 1 lần thấy TLS 8883 và dòng `[NTP]` | (không lưu) | Kiểm tra sau các bản nạp tạm |
| 2026-11-26 13:40 | Claude | Ảnh app (Hình 3.5, 4.3, 4.4) | App Flutter bản Windows, cửa sổ 412 × 880, đổi loại đất trên màn Mẫu đất rồi chụp màn Tổng quan | `docs/hinh/hinh-3-5-*.png`, `hinh-4-3-*.png`, `hinh-4-4-*.png` | Hình 3.5, 4.3, 4.4 |
| 2026-11-26 13:42 | Claude | Chọn loại đất trên mạch thật | `report_measure.py soil-types` (mốc mặc định 200 / 3000) | `log/chon-loai-dat.txt` | Bảng 4.5 cột đo thật |
| 2026-11-26 13:43 | Claude | Ảnh trang web (Hình 3.7, 4.2) | `node docs/hinh/chup_trang_web.js`, trang nhận bản tin thật | `docs/hinh/hinh-3-7-trang-web.png`, `hinh-4-2-ban-tin-timestamp.png` | Hình 3.7, 4.2 |
| 2026-11-26 13:22 | Claude | Mất nguồn và bật lại | `report_measure.py offline --hold 60 --count 3`. Chỉ lần 1 có kết quả: board bị ngắt USB khoảng 13:24 nên lần 2, 3 không đo được | `log/mat-nguon.txt` | Bảng 4.4 dòng 1 và 3 |
| 2026-11-26 13:44 | Claude | Mất nguồn và bật lại, đo bù 2 lần | `report_measure.py offline --hold 60 --count 2 --gap 45` | `log/mat-nguon-2.txt` | Bảng 4.4 dòng 1 và 3 |
