---
phase: 4
title: "Đo thực nghiệm trên mạch thật (nhóm thực hiện)"
status: pending
priority: P1
effort: "5h"
dependencies: [1, 2]
---

# Phase 4: Đo thực nghiệm trên mạch thật (nhóm thực hiện)

## Goal

Lấy đủ số đo thật và ảnh chụp cho Chương 4, lưu tệp gốc vào repo để con số nào trong báo cáo cũng truy lại được.

## Chuẩn bị

- Trạm đã nạp firmware có log của phase 2, đã nối Wi-Fi và `broker.emqx.io:8883`.
- Máy tính mở `web/evaluation.html` (phase 1), đồng hồ máy tính đã đồng bộ Internet (so với time.is).
- Điện thoại chạy app, MQTTX, Wireshark, Serial Monitor (115200).
- 3 loại đất, cốc, cân điện tử, bình xịt, bộ kit thử đất, bút đo pH/EC nếu có.

## Files to Create / Modify

- Create: `docs/thuc-nghiem/README.md`: nhật ký đo (ngày giờ, người đo, điều kiện, tên tệp).
- Create: `docs/thuc-nghiem/*.csv`: tệp xuất từ trang web (mẫu đất, đo nhiễu).
- Create: `docs/thuc-nghiem/log/*.txt`: chép log Serial của từng phép thử.
- Create: `docs/hinh/*.png`: ảnh chụp màn hình và ảnh mạch.

## Tasks & Steps

1. **Hiệu chuẩn, Bảng 4.6.** Lưu mốc khô rồi mốc ướt bằng màn Hiệu chuẩn, làm 3 lần. Mỗi lần ghi `adc.dry`, `adc.wet`, `adc.noise` lúc khô và lúc ướt (đọc trên phần Trực tiếp của trang web). Ghi mốc cuối cùng trạm lưu vào NVS.
2. **Nhiễu bộ lọc, Bảng 4.7.** Cắm đầu dò vào cốc đất vườn khoảng 50% và cốc đất bạc màu khoảng 30%, không chạm vào. Mỗi cốc chạy Đo nhiễu M = 100 (khoảng 7 phút), xuất CSV thành `nhieu-dat-vuon.csv` và `nhieu-bac-mau.csv`, chụp phần kết quả.
3. **NTP, Bảng 4.2 và Hình 4.1, 4.2.**
   - Khởi động lại trạm ít nhất 10 lần, chép số ms trong dòng `[NTP] Da co gio sau ... ms`. Tính trung bình, nhỏ nhất, lớn nhất.
   - Ghi độ lệch `timestamp` trên trang web vào 5 thời điểm khác nhau.
   - Tắt Wi-Fi 5 phút rồi bật lại, so giờ trên OLED và bản tin.
   - Thử máy chủ dự phòng: tạm sửa `"pool.ntp.org"` thành tên sai, nạp, xem trạm vẫn có giờ từ `time.google.com`, rồi **trả lại như cũ**.
   - Khóa cổng UDP 123 chỉ làm khi router cho phép, không làm được thì báo để xóa dòng đó.
   - Chụp Serial (Hình 4.1) và bản tin có `timestamp` trên MQTTX (Hình 4.2).
4. **Bảo mật kết nối, các dòng còn lại của Bảng 4.3 và Hình 4.3.**
   - TLS đúng: chép dòng `Thanh cong! (... ms, heap trong ... byte)` ở 5 lần kết nối.
   - CA sai: tạm thay `setCACert` bằng một chứng chỉ khác, thấy `That bai sau ... ms, rc=-2`, rồi **trả lại như cũ**.
   - Wireshark: bắt gói ở cổng 1883 (chạy `simulator/index.html` hoặc MQTTX ở 1883) và 8883 (trạm thật), chụp hai màn hình đặt cạnh nhau. Ghi phiên bản TLS thấy trong gói Client Hello / Server Hello.
   - Chi phí TLS: so thời gian kết nối và bộ nhớ trống giữa TLS (mạch thật) và không TLS (Wokwi).
5. **Kết nối lại, Bảng 4.4 và Hình 4.4.** Làm 4 phép thử trong bảng, mỗi phép ghi thời điểm và quan sát trên app, OLED, trang web:
   - Rút nguồn: topic status chuyển offline sau bao nhiêu giây.
   - Tắt Wi-Fi 1 phút: OLED báo `NO WIFI`, trạm vẫn đo.
   - Bật lại: status online, app nhận số mới.
   - Điện thoại mất mạng: app tự kết nối lại.
6. **Chọn loại đất, Bảng 4.5 và Hình 4.5.** Giữ đầu dò trong cùng một cốc, đổi 3 loại đất trên app. Chụp app và OLED ở mỗi loại. Ghi lại số đo thật bên cạnh bảng tính sẵn ở phase 3; khác với số tính sẵn là bình thường vì ADC thật khác 1600.
7. **So với bộ kit, Bảng 4.8, 4.9 và Hình 4.7.** Chuẩn bị 12 mẫu (3 loại đất × 4 mức ẩm).
   - Với mỗi mẫu: cắm đầu dò, chờ số đứng yên khoảng 1 phút, bấm Lấy mẫu trên trang web, rồi đo bằng kit và nhập giá trị tham chiếu.
   - Ghi cách đo tham chiếu: độ ẩm theo khối lượng nước thêm vào hay cân sấy; tỷ lệ đất:nước khi đo EC/pH.
   - Xuất `mau-dat.csv`, chụp bảng kết quả và biểu đồ cho từng chỉ số.
8. **Ảnh còn thiếu.** Chụp đủ các ảnh sau rồi lưu vào `docs/hinh/`:
   - Hình 3.2: sơ đồ trên Wokwi
   - Hình 3.5: màn chọn loại đất
   - Hình 3.7: trang web
   - Hình 4.4: app hiện giờ và trạng thái
   - Hình 4.6: ảnh mạch thật và các cốc mẫu
9. **Phụ lục B.** Mỗi dòng ghi Đạt hoặc Chưa đạt, kèm tên tệp làm bằng chứng trong `docs/thuc-nghiem/README.md`.
10. Commit `docs/thuc-nghiem/` và `docs/hinh/`. Không commit `firmware/src/secrets.h` hay ảnh có lộ mật khẩu Wi-Fi.

## Todo

- [ ] Bảng 4.6: hiệu chuẩn 3 lần
- [ ] Bảng 4.7: đo nhiễu 100 bản tin × 2 cốc
- [ ] Bảng 4.2, Hình 4.1, 4.2: NTP
- [ ] Bảng 4.3, Hình 4.3: TLS, CA sai, Wireshark, chi phí TLS
- [ ] Bảng 4.4, Hình 4.4: kết nối lại
- [ ] Bảng 4.5, Hình 4.5: chọn loại đất trên mạch thật
- [ ] Bảng 4.8, 4.9, Hình 4.7: 12 mẫu so với bộ kit
- [ ] Hình 3.2, 3.5, 3.7, 4.6
- [ ] Phụ lục B có bằng chứng cho từng dòng
- [ ] Commit `docs/thuc-nghiem/` và `docs/hinh/`, `git diff firmware/src` trống

## Verification

- `docs/thuc-nghiem/README.md` có một dòng cho mỗi phép thử ở bước 1 – 8, kèm tên tệp.
- `mau-dat.csv` có 12 dòng, cột ước lượng đầy đủ. Mỗi chỉ số dùng để tính sai số có ít nhất 3 giá trị tham chiếu.
- Mở lại `mau-dat.csv` bằng Nhập CSV trên trang web ra đúng bảng MAE/RMSE/MAPE đã chụp.
- Mọi sửa tạm trong firmware (máy chủ NTP sai, CA sai) đã trả lại: `git diff firmware/src` trống.
