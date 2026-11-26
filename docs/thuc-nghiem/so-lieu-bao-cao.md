# Số liệu và ảnh để chèn vào báo cáo giai đoạn 2

Cập nhật: 2026-11-26. Số thập phân viết bằng dấu chấm cho giống phần còn lại của báo cáo.

- Mục 1 và 2 dùng được ngay: ảnh đã vẽ và số lấy thẳng từ code.
- Mục 3 là số đo thật trên board.
- Mục 4 là các chỗ còn chờ cắm board hoặc buổi đo cùng nhóm. Tệp này sẽ được cập nhật khi có số.

## 1. Ảnh đã có

Chèn mỗi ảnh vào dòng trống ngay trên chú thích, chỉnh cho vừa bề ngang trang.

| Chú thích trong báo cáo | Tệp |
|---|---|
| Hình 3.1: Sơ đồ kiến trúc 3 tầng của hệ thống giai đoạn 2 | `docs/hinh/hinh-3-1-kien-truc.png` |
| Hình 3.2: Sơ đồ đấu nối mạch trạm đo (cảm biến LM393, OLED, LED cảnh báo) | `docs/hinh/hinh-3-2-so-do-noi-chan.png` |
| Hình 3.3: Lưu đồ khởi động: Wi-Fi, đồng bộ NTP, kết nối MQTT qua TLS | `docs/hinh/hinh-3-3-luu-do-khoi-dong.png` |
| Hình 3.4: Sơ đồ tuần tự khi người dùng đổi loại đất trên ứng dụng | `docs/hinh/hinh-3-4-tuan-tu-doi-loai-dat.png` |
| Hình 3.6: Quy trình vận hành của hệ chuyên gia trên ứng dụng | `docs/hinh/hinh-3-6-he-chuyen-gia.png` |
| Hình 3.5: Giao diện chọn loại đất trên ứng dụng | `docs/hinh/hinh-3-5-chon-loai-dat.png` |
| Hình 3.7 (mới, thêm vào mục 5.5): Trang web đánh giá sai số | `docs/hinh/hinh-3-7-trang-web.png` |
| Hình 4.1: Serial Monitor khi ESP32 đồng bộ giờ từ pool.ntp.org | `docs/hinh/hinh-4-1-serial-ntp.png` |
| Hình 4.2: Bản tin có trường timestamp nhận được trên MQTTX. **Sửa chú thích thành** "... nhận được trên trang web đánh giá sai số" | `docs/hinh/hinh-4-2-ban-tin-timestamp.png` |
| Hình 4.3 (bỏ): So sánh gói tin bắt bằng Wireshark | Xóa chú thích này, các hình sau lùi lên một số |
| Ứng dụng hiển thị thời gian thực và trạng thái kết nối (đang là Hình 4.4, thành 4.3) | `docs/hinh/hinh-4-3-app-thoi-gian-thuc.png` |
| Ứng dụng ở ba loại đất khác nhau với cùng độ ẩm (đang là Hình 4.5, thành 4.4) | `docs/hinh/hinh-4-4-ba-loai-dat.png` |

Cách làm các ảnh mới (ngày 2026-11-26, trạm thật đang gửi số):

- Ảnh app chụp từ chính app Flutter của dự án, build bản Windows, cửa sổ cỡ điện thoại (412 × 880). Giao diện giống bản Android. Nếu muốn ảnh từ điện thoại thì chụp lại cùng các màn này.
- Hình 4.4: đổi loại đất ngay trên app (màn Mẫu đất), đầu dò giữ yên, trạm xác nhận rồi mới chụp màn Tổng quan. Đất đóng bao và đất vườn 100 điểm, đất bạc màu 30 điểm.
- Hình 4.1 dựng từ log Serial thật của lần khởi động thứ 6 với broker EMQX riêng, đầu dò cắm trong đất (`log/khoi-dong-broker-rieng.txt`, NTP 16 241 ms, gần trung vị 16 233 ms của 10 lần), bằng `python docs/hinh/ve_hinh_serial.py`. Tên Wi-Fi và IP đã che. Bảng 4.2 và 4.3 vẫn lấy số từ `log/khoi-dong-10-lan.txt` (broker công cộng broker.emqx.io).
- Hình 3.7 và 4.2 chụp trang web bằng `node docs/hinh/chup_trang_web.js`. Hình 3.7 hiện phần mẫu đất và sai số còn trống; chụp lại sau buổi đo 12 mẫu nếu muốn có số.

## 2. Số lấy từ code (đúng với firmware và app hiện tại)

### Bảng 4.5: thay cả bảng

Tính bằng hàm trong firmware với mốc mặc định 200 / 3000 và ADC = 1600 (độ ẩm 50%). Mức trên OLED so với mức chuẩn của loại đất (±20%). Điểm trên app tính theo `mobile/lib/services/agronomic_engine.dart`, dùng một bộ ngưỡng chung cho mọi loại đất.

| Loại đất | ADC | Độ ẩm (%) | EC (µS/cm) | N | P | K | pH | Mức N-P-K trên OLED | Đèn | Điểm trên ứng dụng |
|---|---|---|---|---|---|---|---|---|---|---|
| Đất đóng bao | 1600 | 50.0 | 1000 | 80.0 | 40.0 | 110.0 | 6.2 | OK | Xanh | 100 |
| Đất vườn | 1600 | 50.0 | 675 | 54.0 | 27.0 | 74.3 | 6.5 | OK | Xanh | 70 (thiếu P, K) |
| Đất bạc màu | 1600 | 50.0 | 200 | 16.0 | 8.0 | 22.0 | 5.8 | THAP (K thấp) | Đỏ (EC < 300) | 30 |

Đoạn văn trước bảng cần đổi theo: đất vườn được OLED báo OK vì so với mức chuẩn của đất vườn (65 / 33 / 90), nhưng app trừ còn 70 điểm vì app dùng ngưỡng chung P ≥ 30, K ≥ 80. Đất bạc màu bị trừ 25 điểm do EC < 300 và 15 điểm cho mỗi chất N, P, K thiếu. Ở đất bạc màu, N = 16.0 và P = 8.0 nằm đúng ngưỡng 80% mức chuẩn nên chỉ lệch một chút là đổi mức.

### Bảng 3.4: tham số hồ sơ loại đất

| Tham số | Ý nghĩa | Đóng bao / Đất vườn / Bạc màu |
|---|---|---|
| ecPerMoisture | Mỗi 1% độ ẩm làm EC tăng bao nhiêu µS/cm | 20.0 / 13.5 / 4.0 |
| phBase | pH ở độ ẩm 50%, độ dốc 0.012 dùng chung | 6.2 / 6.5 / 5.8 |
| nitrogenNormal | Mức N chuẩn để so sánh (mg/kg), không phải số đo | 95 / 65 / 20 |
| phosphorusNormal | Mức P chuẩn để so sánh (mg/kg) | 50 / 33 / 10 |
| potassiumNormal | Mức K chuẩn để so sánh (mg/kg) | 135 / 90 / 30 |
| N_PER_EC / P_PER_EC / K_PER_EC | N, P, K trên mỗi 1 µS/cm EC, dùng chung cho mọi loại đất | 0.08 / 0.04 / 0.11 |
| NORMAL_TOLERANCE | Lệch quá mức này so với mức chuẩn thì báo thấp hoặc cao | 20% (dùng chung) |

Ví dụ cho Chương 3 mục 6.3: đất vườn ở độ ẩm 60% có EC = 60 × 13.5 = 810 µS/cm, N = 64.8, P = 32.4, K = 89.1 mg/kg, gần đúng mức chuẩn 65 / 33 / 90.

### Khoảng độ ẩm để N, P, K ở mức bình thường (cho Chương 4 mục 6.3)

Tỉ số ước lượng / mức chuẩn tỉ lệ thuận với độ ẩm, nên sai số so với mức chuẩn do độ ẩm của mẫu quyết định.

| Loại đất | N | P | K | Lệch so với mức chuẩn ở độ ẩm 60% (N / P / K) |
|---|---|---|---|---|
| Đất đóng bao | 47.5 – 71.3% | 50.0 – 75.0% | 49.1 – 73.6% | +1.1% / −4.0% / −2.2% |
| Đất vườn | 48.1 – 72.2% | 48.9 – 73.3% | 48.5 – 72.7% | −0.3% / −1.8% / −1.0% |
| Đất bạc màu | 50.0 – 75.0% | 50.0 – 75.0% | 54.5 – 81.8% | −4.0% / −4.0% / −12.0% |

### Các thông số khác

| Chỗ trong báo cáo | Số đúng theo code | Đang ghi |
|---|---|---|
| Chương 3 mục 3.3, bộ đệm PubSubClient | 768 byte | 512 byte |
| Bảng 1.1 dòng 5, mốc hiệu chuẩn giai đoạn 1 | 200 và 3000 | 100 và 3800 |
| Chương 3 mục 3.4, mất Wi-Fi | Dò lại 15 giây một lần (mỗi lần dò chặn tối đa khoảng 8 giây) | Không ghi |
| Chương 3 mục 3.4, mất broker | Thử lại 5 giây một lần | Đúng |
| LWT (Bảng 1.1 dòng 3, Bảng 3.5) | Có: `{"status":"offline"}`, QoS 1, giữ lại. Bản tin online giữ lại và gửi lại mỗi 30 giây, keep-alive 15 giây | "Chưa có LWT" |
| Đèn đỏ | Độ ẩm < 35% hoặc > 80%, EC > 1800 hoặc < 300 µS/cm, pH < 5.5 | Không ghi |
| Đèn vàng | Không đỏ, và độ ẩm < 50% hoặc > 70%, hoặc có chất N, P, K thấp hơn mức chuẩn | Không ghi |
| Đèn xanh | Không đỏ, không vàng | Không ghi |
| Còi | Kêu 3 tiếng khi độ ẩm vừa xuống dưới 35% hoặc lên trên 80%, phải về lại 38 – 77% mới hết báo, phát bằng PWM 2.7 kHz | Không ghi |
| Bảng 3.6, trường mới | `npk_normal` (mức N, P, K chuẩn của loại đất), `npk_level` (`low / normal / high` cho từng chất). Xóa dòng `actuators` | Thiếu 2 trường, còn `actuators` |

### Phụ lục, bảng nghiệm thu

| Dòng | Kết quả | Bằng chứng |
|---|---|---|
| 3. Thời hạn chứng chỉ số CA | Đạt. DigiCert Global Root G2 hết hạn 15/01/2038, ISRG Root X1 hết hạn 04/06/2035. broker.emqx.io dùng chuỗi chứng chỉ của DigiCert Global Root G2 | `docs/thuc-nghiem/log/chung-chi.txt` |
| 7. Bảo mật thông tin cấu hình | Đạt. `secrets.h` và `mqtt_config.json` bị `.gitignore` bỏ qua và chưa từng được commit, kho mã chỉ có tệp mẫu | `docs/thuc-nghiem/log/kiem-tra-bi-mat.txt` |

## 3. Số đo thật (board thật, `broker.emqx.io:8883`, ngày 2026-11-26)

Tệp gốc nằm trong `docs/thuc-nghiem/log/`, cách đo ghi trong `docs/thuc-nghiem/README.md`. Cột "Kết quả mong đợi" giữ nguyên như báo cáo đang ghi.

### Bảng 4.2: cột "Kết quả thực tế"

| Phép thử | Kết quả thực tế |
|---|---|
| Thời gian có giờ sau khi có IP | Chưa đạt. 10 lần khởi động: nhỏ nhất 0.61 s, trung vị 16.3 s, lớn nhất 19.6 s. 3 lần dưới 4 s, 7 lần từ 15.3 đến 19.6 s |
| Độ lệch so với giờ chuẩn | Đạt. Giờ nhận trừ `timestamp` của trạm là 0.89 – 0.91 s (5 lần), sau khi bù giờ máy tính theo time.google.com. `timestamp` chỉ tới giây, nên số này gồm phần lẻ bị cắt (0 – 1 s) và độ trễ mạng |
| Mất Wi-Fi rồi có lại | Đạt. Tắt sóng Wi-Fi của trạm 5 phút bằng bản nạp tạm: giờ trạm lệch giờ chuẩn trung bình −31 ms trước, −21 ms trong và −14 ms sau lúc mất Wi-Fi (trôi 15 ms trong 5 phút) |
| Máy chủ chính không phản hồi | Đạt. Đặt sai tên máy chủ chính, trạm lấy giờ từ time.google.com sau 1.9 – 4.6 s (3 lần) |
| Chưa có giờ | Một phần. Bản tin không có `timestamp` (40/40 bản tin trong 3 phút), đúng như mong đợi. Nhưng kết nối TLS vẫn thành công (1.72 s): trạm không kiểm tra hạn chứng chỉ khi chưa có giờ |

Đoạn văn Chương 4 mục 2 viết lại theo số trên. Gợi ý giải thích nhóm chậm: khi tên máy chủ chính sai, trạm chuyển ngay sang time.google.com và có giờ sau 2 – 5 s; khi pool.ntp.org đúng tên nhưng không trả lời lần đầu, trạm chờ khoảng 15 s rồi mới hỏi máy chủ dự phòng. Nên ghi là "nhiều khả năng", vì chưa bắt gói để xác nhận.

**Phải sửa thêm Chương 2 mục 3.1**: báo cáo đang viết "nếu đồng hồ của ESP32 bị sai ... việc kiểm tra chứng chỉ sẽ thất bại ngay". Số đo cho thấy chưa có giờ trạm vẫn kết nối TLS được. Sửa thành: thời gian thực cần để gắn mốc giờ cho bản tin; trên firmware hiện tại, trạm chưa có giờ vẫn kết nối TLS được, tức là không kiểm tra hạn chứng chỉ (nêu thêm vào Hạn chế).

### Bảng 4.3: cột "Kết quả thực tế" (sau khi xóa các dòng tài khoản, ACL, bắt gói)

| Phép thử | Kết quả thực tế |
|---|---|
| Kết nối TLS thành công | Đạt (phía ESP32). 10/10 lần kết nối được, thời gian kết nối gồm bắt tay TLS: nhỏ nhất 1.56 s, trung vị 1.68 s, lớn nhất 4.88 s. Phía app: chờ buổi đo cùng nhóm |
| CA sai hoặc không có | Đạt. Chỉ giữ ISRG Root X1 (broker dùng DigiCert G2): 16/16 lần bị từ chối, `rc = -2`, mỗi lần thất bại sau 0.45 – 0.62 s, 5 giây thử lại một lần |
| Chi phí của TLS | Đạt. So với bản nạp tạm cổng 1883 không TLS trên cùng mạch: thời gian kết nối trung vị 1.68 s so với 0.83 s (thêm khoảng 0.85 s); bộ nhớ trống 167.1 KB so với 210.8 KB (TLS dùng thêm khoảng 43.7 KB RAM) |

### Bảng 4.4: dòng 1 và 3 (3 lần, `log/mat-nguon.txt` và `log/mat-nguon-2.txt`)

Trạm được giữ ở trạng thái reset 60 s bằng chân EN (tương đương mất nguồn: Wi-Fi tắt, broker không nhận gói DISCONNECT).

| Phép thử | Kết quả mong đợi (sửa theo code: đã có LWT) | Kết quả thực tế |
|---|---|---|
| Trạm mất nguồn đột ngột | Broker đăng `{"status":"offline"}` (giữ lại) khi hết hạn keep-alive (15 s × 1.5); app vẫn chỉ thấy "Cập nhật lúc" dừng lại vì app chưa đăng ký topic status | Đạt. Status offline sau 32.6 s, 32.6 s và 28.0 s (trung bình 31.1 s), lâu hơn mức 22.5 s tính theo keep-alive |
| Trạm bật lại | Trạm gửi status online, ứng dụng nhận dữ liệu mới | Đạt. Status online và bản tin telemetry đầu tiên sau 12.1 – 12.5 s kể từ lúc cấp lại (gồm khởi động, vào Wi-Fi và bắt tay TLS) |
| Trạm mất Wi-Fi | Trạm vẫn đo, OLED báo NO WIFI, có mạng lại thì tự gửi tiếp | Đạt. Tắt sóng Wi-Fi của trạm 5 phút: trạm vẫn đo (71 lần trong 5 phút); có sóng lại thì nối Wi-Fi sau 7.6 s, MQTT sau 9.2 s, gửi lại bản tin sau 9.3 s. OLED chưa quan sát trực tiếp |

### Bảng 4.5: cột đo thật trên mạch (thêm vào cạnh bảng tính sẵn)

Đầu dò để yên, đổi lần lượt 3 loại đất qua lệnh `SET_SOIL_TYPE`, mỗi loại lấy trung bình 3 bản tin (`log/chon-loai-dat.txt`). Trạm vẫn dùng mốc mặc định 200 / 3000 (chưa hiệu chuẩn) nên độ ẩm 60.0% chỉ là số tính theo mốc mặc định, chưa phải độ ẩm thật của đất. Trạm gửi bản tin xác nhận sau 0.7 – 2.1 s kể từ lúc nhận lệnh.

| Loại đất | ADC | Độ ẩm (%) | EC (µS/cm) | N | P | K | pH | Mức N-P-K trên OLED | Điểm trên ứng dụng |
|---|---|---|---|---|---|---|---|---|---|
| Đất đóng bao | 1881 | 60.0 | 1201 | 96.1 | 48.0 | 132.1 | 6.10 | OK | 100 |
| Đất vườn | 1881 | 60.0 | 811 | 64.8 | 32.4 | 89.2 | 6.40 | OK | 100 |
| Đất bạc màu | 1880 | 60.0 | 240 | 19.2 | 9.6 | 26.4 | 5.70 | OK | 30 |

Đáng ghi vào bài: ở độ ẩm 60%, đất bạc màu được OLED báo OK (N, P, K lệch không quá 20% so với mức chuẩn 20 / 10 / 30) nhưng app chỉ cho 30 điểm và báo thiếu cả N, P, K, vì app dùng ngưỡng chung cho mọi loại đất.

### Số khác

- Kích thước bản tin telemetry: 367 – 372 byte (5 bản tin), vừa bộ đệm 768 byte (Chương 3 mục 3.3).
- Phụ lục dòng 1 (đồng bộ NTP): Đạt về độ đúng giờ (lệch dưới 1 s), nhưng thời gian có giờ có lúc tới 20 s.

## 4. Còn chờ

| Chỗ trong báo cáo | Cần gì |
|---|---|
| Bảng 4.6 (hiệu chuẩn), 4.7 (nhiễu), 4.8 và 4.9 (sai số so với mức chuẩn), Bảng 4.4 dòng 2 và 4, cột đo thật của Bảng 4.5 | Buổi đo cùng nhóm: nhúng đầu dò, 12 cốc đất, tắt router |
| Ảnh OLED và Hình 4.5 (mạch thật và các mẫu đất) | Nhóm chụp bằng điện thoại |
| Hình 4.6 (biểu đồ ước lượng so với mức chuẩn) | Sau buổi đo 12 mẫu, Claude chụp từ trang web |
| Bảng 4.1: đời máy điện thoại; Lời cam đoan: ngày ký | Nhóm cung cấp |
