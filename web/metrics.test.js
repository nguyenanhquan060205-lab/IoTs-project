// Kiểm thử hàm tính của trang đánh giá sai số. Chạy: node --test "web/*.test.js"
const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('./metrics.js');

const close = (actual, expected, eps = 1e-9) =>
  assert.ok(Math.abs(actual - expected) < eps, `${actual} khác ${expected}`);

test('errorStats: MAE, RMSE, MAPE tính tay với sai số 1, -1, 2, -2', () => {
  const s = M.errorStats([
    { estimate: 11, reference: 10 },
    { estimate: 9, reference: 10 },
    { estimate: 12, reference: 10 },
    { estimate: 8, reference: 10 },
  ]);
  assert.equal(s.n, 4);
  close(s.mae, 1.5);
  close(s.rmse, Math.sqrt(2.5));
  close(s.mape, 15);
  assert.equal(s.mapeN, 4);
});

test('errorStats: MAPE bỏ qua tham chiếu bằng 0 nhưng MAE vẫn tính đủ', () => {
  const s = M.errorStats([
    { estimate: 1, reference: 0 },
    { estimate: 11, reference: 10 },
  ]);
  assert.equal(s.n, 2);
  close(s.mae, 1);
  assert.equal(s.mapeN, 1);
  close(s.mape, 10);
});

test('errorStats: không có cặp hợp lệ thì trả null, không trả NaN', () => {
  for (const pairs of [[], [{ estimate: 5, reference: null }], [{ estimate: NaN, reference: 3 }]]) {
    assert.deepEqual(M.errorStats(pairs), { n: 0, mae: null, rmse: null, mape: null, mapeN: 0 });
  }
});

test('sampleSd: chia m - 1, dưới 2 giá trị thì null', () => {
  close(M.sampleSd([2, 4, 4, 4, 5, 5, 7, 9]), Math.sqrt(32 / 7));
  assert.equal(M.sampleSd([5]), null);
  assert.equal(M.sampleSd([]), null);
});

test('adcToMoisturePercent: theo khoảng cách 2 mốc, cả 2 chiều tín hiệu', () => {
  close(M.adcToMoisturePercent(35, 3200, 1100), 35 * 100 / 2100);
  close(M.adcToMoisturePercent(35, 1100, 3200), 35 * 100 / 2100);
  assert.equal(M.adcToMoisturePercent(35, 2000, 2000), null);
  assert.equal(M.adcToMoisturePercent(null, 3200, 1100), null);
});

test('noiseSummary: nhiễu không lọc là trung bình adc.noise, có lọc là SD của adc.raw', () => {
  const msg = (raw, noise) => ({ adc: { raw, noise, dry: 3200, wet: 1100 } });
  const s = M.noiseSummary([msg(100, 10), { telemetry: {} }, msg(102, 12), msg(104, 14)]);
  assert.equal(s.m, 3);
  close(s.adcMean, 102);
  close(s.rawNoiseMean, 12);
  close(s.filteredSd, 2);
  close(s.reductionPercent, 100 * (1 - 2 / 12));
  close(s.rawNoisePct, 12 * 100 / 2100);
  close(s.filteredSdPct, 2 * 100 / 2100);
  assert.equal(M.noiseSummary([]).m, 0);
  assert.equal(M.noiseSummary([msg(100, 10)]).filteredSd, null);
});

test('averageTelemetry: trung bình từng chỉ số, bỏ bản tin thiếu số', () => {
  const avg = M.averageTelemetry([
    { telemetry: { moisture: 50, ec: 600, nitrogen: 48, phosphorus: 24, potassium: 66, ph: 6.5 } },
    { telemetry: { moisture: 52, ec: 700, nitrogen: 56, phosphorus: 28, potassium: 77, ph: 6.4 } },
    { telemetry: { moisture: 'x' } },
    null,
  ]);
  close(avg.moisture, 51);
  close(avg.ec, 650);
  close(avg.n, 52);
  close(avg.p, 26);
  close(avg.k, 71.5);
  close(avg.ph, 6.45);
  assert.equal(M.averageTelemetry([]).ec, null);
});

test('referenceFromNormal: lấy mức chuẩn N, P, K của loại đất làm giá trị tham chiếu', () => {
  const msg = { soil_type: 'garden', npk_normal: { nitrogen: 65, phosphorus: 33, potassium: 90 } };
  assert.deepEqual(M.referenceFromNormal(msg), { n: 65, p: 33, k: 90 });
});

test('referenceFromNormal: thiếu npk_normal hoặc thiếu số thì trả null cho chất đó', () => {
  assert.deepEqual(M.referenceFromNormal({ telemetry: {} }), { n: null, p: null, k: null });
  assert.deepEqual(M.referenceFromNormal(null), { n: null, p: null, k: null });
  assert.deepEqual(M.referenceFromNormal({ npk_normal: { nitrogen: 20, phosphorus: 'x' } }),
    { n: 20, p: null, k: null });
});

test('summarize: tính riêng từng chỉ số và lọc được theo loại đất', () => {
  const sample = (soil, estN, refN) => ({
    soil_type: soil,
    est: { moisture: null, ec: null, n: estN, p: null, k: null, ph: null },
    ref: { moisture: null, ec: null, n: refN, p: null, k: null, ph: null },
  });
  const samples = [sample('garden', 54, 60), sample('barren', 16, 14)];
  const all = M.summarize(samples).find((r) => r.key === 'n');
  assert.equal(all.n, 2);
  close(all.mae, 4);
  const garden = M.summarize(samples, 'garden').find((r) => r.key === 'n');
  assert.equal(garden.n, 1);
  close(garden.mae, 6);
  assert.equal(M.summarize(samples).find((r) => r.key === 'ph').n, 0);
});

test('parseNumber: nhận dấu phẩy và dấu chấm, ô trống là null', () => {
  assert.equal(M.parseNumber('54,3'), 54.3);
  assert.equal(M.parseNumber(' 6.5 '), 6.5);
  assert.equal(M.parseNumber(''), null);
  assert.equal(M.parseNumber('abc'), null);
});

test('toCsv rồi fromCsv trả lại đúng dữ liệu, kể cả ô trống và chữ có dấu', () => {
  const samples = [
    {
      sample_id: 'M01', soil_type: 'garden', moisture_level: 'Ẩm tối ưu',
      captured_at: '2026-11-26T08:30:00.000Z',
      est: { moisture: 61.2, ec: 826.2, n: 66.1, p: 33, k: 90.9, ph: 6.4 },
      ref: { moisture: 58, ec: null, n: 70, p: 30, k: null, ph: 6.6 },
      note: 'Đất lấy ở bồn hoa, "ẩm", có rễ',
    },
    {
      sample_id: 'M02', soil_type: 'barren', moisture_level: 'Khô kiệt',
      captured_at: '2026-11-26T08:40:00.000Z',
      est: { moisture: 3.5, ec: 150, n: 12, p: 6, k: 16.5, ph: 6.3 },
      ref: { moisture: null, ec: null, n: null, p: null, k: null, ph: null },
      note: '',
    },
  ];
  const csv = M.toCsv(samples);
  assert.ok(csv.startsWith('﻿'));
  assert.deepEqual(M.fromCsv(csv), samples);
});

test('fromCsv: đọc được tệp Excel kiểu Việt Nam (dấu chấm phẩy, phẩy thập phân)', () => {
  const header = M.CSV_COLUMNS.join(';');
  const row = ['M03', 'potting', 'Bão hòa', '2026-11-26T09:00:00.000Z',
    '90,5', '1810', '144,8', '72,4', '199,1', '5,7',
    '88', '', '', '', '', '5,9', 'ghi chú'].join(';');
  const [s] = M.fromCsv('﻿' + header + '\r\n' + row + '\r\n');
  assert.equal(s.moisture_level, 'Bão hòa');
  assert.equal(s.est.moisture, 90.5);
  assert.equal(s.est.n, 144.8);
  assert.equal(s.ref.ph, 5.9);
  assert.equal(s.ref.ec, null);
});

test('fromCsv: thiếu cột sample_id thì báo lỗi rõ ràng', () => {
  assert.throws(() => M.fromCsv('a,b\n1,2\n'), /sample_id/);
});
