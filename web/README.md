# Trang web đánh giá sai số

`evaluation.html` nhận bản tin của trạm qua MQTT và tính sai số của N, P, K ước lượng so với mức chuẩn nhóm đặt cho loại đất đang đo (`npk_normal` trong bản tin). Nhóm không có bộ dụng cụ thử đất, nên đây là độ lệch so với mức chuẩn, không phải độ chính xác so với số đo thật. Sai số chỉ hiện trên trang này, không hiện trên OLED. Trang chỉ đăng ký nhận bản tin, không gửi lệnh nào tới trạm.

## Mở trang

Bấm đúp vào `web/evaluation.html` để mở bằng Chrome, Edge hoặc Firefox. Không cần cài gì, nhưng máy phải có Internet: trang tải thư viện MQTT (Paho) từ cdnjs và nối tới broker.

Mặc định trang nối `broker.emqx.io` qua WebSocket có TLS, cổng 8084, đường dẫn `/mqtt`. Đây là cùng broker mà trạm gửi lên ở cổng 8883. Topic mặc định là `soil_station/1/telemetry` và `soil_station/1/status`.

## Các phần trên trang

1. **Kết nối broker**: đổi broker hoặc topic nếu cần. Mất kết nối thì trang tự thử lại sau 5 giây.
2. **Số đo trực tiếp**:
   - Bản tin mới nhất: độ ẩm, EC, N, P, K, pH; mức N, P, K so với mức chuẩn của loại đất; khối `adc`.
   - Trạng thái trạm lấy từ topic status: online, hoặc offline khi broker đăng LWT sau khoảng 20 giây trạm mất kết nối.
   - Số giây kể từ bản tin cuối.
   - Độ lệch giữa giờ máy tính và `timestamp` của trạm (dùng cho Bảng 4.2). Con số này gồm cả độ trễ mạng; `timestamp` của trạm chỉ chính xác tới giây.
3. **Mẫu đất**: xem mục Lấy một mẫu bên dưới.
4. **Sai số theo từng chỉ số**:
   - Bảng n, MAE, RMSE, MAPE cho từng chỉ số, lọc được theo loại đất.
   - Biểu đồ ước lượng – tham chiếu có đường y = x (dùng cho Hình 4.7). Rê chuột hoặc dùng phím Tab lên một điểm để xem số.
5. **Đo nhiễu bộ lọc**: gom M bản tin liên tiếp (mặc định 100, khoảng 7 phút) trên một cốc đất đứng yên (dùng cho Bảng 4.6 và 4.7).

## Lấy một mẫu

1. Cắm đầu dò vào mẫu đất, chờ số đo đứng yên khoảng 1 phút.
2. Chọn mức ẩm, kiểm tra mã mẫu (trang tự đề xuất M01, M02...), bấm **Lấy mẫu**.
3. Trang lấy trung bình 5 bản tin kế tiếp (khoảng 20 giây) làm giá trị ước lượng. Loại đất lấy theo trạm đang đo. Nếu loại đất đổi giữa chừng thì mẫu bị bỏ.
4. Cột **Tham chiếu** của N, P, K được điền sẵn bằng mức chuẩn của loại đất trong bản tin cuối. Các chỉ số khác để trống vì chưa có giá trị để so. Ô nào cũng sửa được, gõ `6,5` hay `6.5` đều được.

Dữ liệu được lưu trong trình duyệt đang dùng. Bấm **Xuất CSV** sau mỗi buổi đo và lưu tệp vào `docs/thuc-nghiem/`. **Nhập CSV** để mở lại.

## Cách tính

Sai số của một mẫu là `e = ước lượng − tham chiếu`. Mỗi chỉ số tính riêng theo đơn vị của nó, không gộp các chỉ số khác đơn vị:

- MAE = trung bình |e|
- RMSE = căn bậc hai của trung bình e²
- MAPE = 100 × trung bình |e / tham chiếu|, bỏ qua mẫu có tham chiếu bằng 0 (cột "n MAPE" là số mẫu dùng được)

Phần đo nhiễu:

- **Không lọc**: trung bình `adc.noise`, tức độ lệch chuẩn của 21 mẫu thô trong một lần đo (firmware chia cho 21).
- **Có lọc**: độ lệch chuẩn mẫu (chia M − 1) của `adc.raw`, giá trị sau lọc cắt tỉa, giữa M bản tin.
- Hai số được đổi sang % độ ẩm bằng `SD × 100 / |mốc khô − mốc ướt|`.
- Nếu nhiễu sau lọc lớn hơn trước lọc thì độ ẩm đã trôi trong lúc đo; để cốc đứng yên rồi đo lại.

Các hàm tính nằm trong `metrics.js`. Kiểm thử bằng:

```
node --test "web/*.test.js"
```

## Cột của tệp CSV

| Cột | Ý nghĩa |
|---|---|
| `sample_id` | Mã mẫu |
| `soil_type` | `potting` (đóng bao), `garden` (đất vườn), `barren` (bạc màu) |
| `moisture_level` | Khô kiệt / Ẩm thấp / Ẩm tối ưu / Bão hòa |
| `captured_at` | Thời điểm lấy mẫu (ISO 8601, UTC) |
| `est_moisture`, `est_ec`, `est_n`, `est_p`, `est_k`, `est_ph` | Ước lượng của trạm (trung bình các bản tin) |
| `ref_moisture`, `ref_ec`, `ref_n`, `ref_p`, `ref_k`, `ref_ph` | Giá trị tham chiếu, ô trống là không đo |
| `note` | Ghi chú |

Tệp dùng UTF-8 có BOM, ngăn cột bằng dấu phẩy, số dùng dấu chấm. Tệp đã mở và lưu lại bằng Excel cài đặt kiểu Việt Nam (ngăn cột bằng dấu chấm phẩy, số dùng dấu phẩy) vẫn nhập lại được.

Tệp xuất từ phần đo nhiễu có các cột `received_at, timestamp, soil_type, adc_raw, adc_noise, adc_dry, adc_wet, moisture`.

## Đọc sai số so với mức chuẩn

- N, P, K tính từ EC, EC tính từ độ ẩm (`firmware/src/soil_estimator.h`), nên tỉ số ước lượng / mức chuẩn tỉ lệ thuận với độ ẩm. Hệ số được chọn để ở độ ẩm 60% mỗi loại đất cho gần đúng mức chuẩn của nó. Mẫu khô hay ướt hơn sẽ lệch nhiều, đó là do độ ẩm của mẫu chứ không phải phép đo sai.
- Với hệ số hiện tại, một chất ở mức bình thường (lệch không quá ±20%) khi độ ẩm nằm từ khoảng 48 – 50% tới 71 – 75% tùy chất và loại đất. Riêng K của đất bạc màu là 55 – 82%, và ở độ ẩm 60% vẫn thấp hơn mức chuẩn 12%.
- Muốn biết độ chính xác thật thì phải có số đo độc lập (bộ kit thử đất hoặc phòng thí nghiệm). Khi có số đo đó, gõ đè vào cột Tham chiếu. Lưu ý độ ẩm của trạm là chỉ số tương đối theo hai mốc khô, ướt, không phải độ ẩm khối lượng; bút đo EC thường đo dịch chiết đất:nước (1:2 hoặc 1:5), không phải EC của đất ở độ ẩm đang đo.
