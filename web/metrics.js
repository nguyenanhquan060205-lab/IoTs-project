/*
 * Hàm tính sai số và độ nhiễu cho trang web đánh giá (web/evaluation.html).
 * Viết dạng script thường (không phải ES module) vì trang được mở thẳng bằng file://,
 * Chrome chặn import module từ file://. Chạy trong Node thì xuất qua module.exports để kiểm thử.
 */
(function (root) {
  'use strict';

  // Các chỉ số đánh giá: key dùng trong mẫu, field là tên trường trong bản tin telemetry của trạm
  const INDICATORS = [
    { key: 'moisture', field: 'moisture', label: 'Độ ẩm', unit: '%' },
    { key: 'ec', field: 'ec', label: 'EC', unit: 'µS/cm' },
    { key: 'n', field: 'nitrogen', label: 'N', unit: 'mg/kg' },
    { key: 'p', field: 'phosphorus', label: 'P', unit: 'mg/kg' },
    { key: 'k', field: 'potassium', label: 'K', unit: 'mg/kg' },
    { key: 'ph', field: 'ph', label: 'pH', unit: '' },
  ];

  const SAMPLE_COLUMNS = ['sample_id', 'soil_type', 'moisture_level', 'captured_at'];
  const CSV_COLUMNS = SAMPLE_COLUMNS
    .concat(INDICATORS.map((ind) => 'est_' + ind.key))
    .concat(INDICATORS.map((ind) => 'ref_' + ind.key))
    .concat(['note']);

  function isNum(value) {
    return typeof value === 'number' && Number.isFinite(value);
  }

  function mean(values) {
    if (values.length === 0) return null;
    let sum = 0;
    for (const v of values) sum += v;
    return sum / values.length;
  }

  /**
   * Sai số giữa giá trị ước lượng và giá trị tham chiếu.
   * pairs: [{estimate, reference}]. Cặp nào thiếu số thì bỏ qua.
   * MAPE chỉ tính trên các cặp có reference khác 0, mapeN là số cặp dùng được.
   */
  function errorStats(pairs) {
    const valid = (pairs || []).filter((p) => p && isNum(p.estimate) && isNum(p.reference));
    const n = valid.length;
    if (n === 0) return { n: 0, mae: null, rmse: null, mape: null, mapeN: 0 };

    let absSum = 0;
    let sqSum = 0;
    let pctSum = 0;
    let mapeN = 0;
    for (const p of valid) {
      const e = p.estimate - p.reference;
      absSum += Math.abs(e);
      sqSum += e * e;
      if (p.reference !== 0) {
        pctSum += Math.abs(e / p.reference);
        mapeN++;
      }
    }
    return {
      n,
      mae: absSum / n,
      rmse: Math.sqrt(sqSum / n),
      mape: mapeN > 0 ? (100 * pctSum) / mapeN : null,
      mapeN,
    };
  }

  /** Độ lệch chuẩn mẫu (chia m - 1), dùng cho các lần đo lặp. Dưới 2 giá trị thì trả về null. */
  function sampleSd(values) {
    const valid = (values || []).filter(isNum);
    const m = valid.length;
    if (m < 2) return null;
    const avg = mean(valid);
    let sq = 0;
    for (const v of valid) sq += (v - avg) * (v - avg);
    return Math.sqrt(sq / (m - 1));
  }

  /** Đổi một độ lệch tính bằng đơn vị ADC sang % độ ẩm theo 2 mốc hiệu chuẩn khô/ướt. */
  function adcToMoisturePercent(adcSd, dry, wet) {
    if (!isNum(adcSd) || !isNum(dry) || !isNum(wet) || dry === wet) return null;
    return (adcSd * 100) / Math.abs(dry - wet);
  }

  function hasAdc(msg) {
    return msg && msg.adc && isNum(msg.adc.raw) && isNum(msg.adc.noise);
  }

  /**
   * Nhiễu của M bản tin liên tiếp trên cùng một cốc đất đứng yên.
   * - rawNoiseMean: trung bình adc.noise, tức độ lệch chuẩn của 21 mẫu thô trong một lần đo (khi không lọc)
   * - filteredSd: độ lệch chuẩn của adc.raw (giá trị sau lọc cắt tỉa) giữa các bản tin (khi có lọc)
   */
  function noiseSummary(messages) {
    const valid = (messages || []).filter(hasAdc);
    const m = valid.length;
    if (m === 0) {
      return {
        m: 0, adcMean: null, rawNoiseMean: null, filteredSd: null, reductionPercent: null,
        dry: null, wet: null, rawNoisePct: null, filteredSdPct: null,
      };
    }
    const rawNoiseMean = mean(valid.map((msg) => msg.adc.noise));
    const filteredSd = sampleSd(valid.map((msg) => msg.adc.raw));
    const last = valid[m - 1].adc;
    const dry = isNum(last.dry) ? last.dry : null;
    const wet = isNum(last.wet) ? last.wet : null;
    return {
      m,
      adcMean: mean(valid.map((msg) => msg.adc.raw)),
      rawNoiseMean,
      filteredSd,
      reductionPercent: filteredSd !== null && rawNoiseMean > 0
        ? 100 * (1 - filteredSd / rawNoiseMean)
        : null,
      dry,
      wet,
      rawNoisePct: adcToMoisturePercent(rawNoiseMean, dry, wet),
      filteredSdPct: adcToMoisturePercent(filteredSd, dry, wet),
    };
  }

  /**
   * Trung bình từng chỉ số của các bản tin, dùng làm giá trị ước lượng của một mẫu đất.
   * Trả về {moisture, ec, n, p, k, ph}; chỉ số nào không có bản tin hợp lệ thì là null.
   */
  function averageTelemetry(messages) {
    const result = {};
    for (const ind of INDICATORS) {
      const values = (messages || [])
        .map((msg) => (msg && msg.telemetry ? msg.telemetry[ind.field] : undefined))
        .filter(isNum);
      result[ind.key] = mean(values);
    }
    return result;
  }

  /** Sai số theo từng chỉ số. soilType rỗng thì tính trên mọi mẫu. */
  function summarize(samples, soilType) {
    const chosen = (samples || []).filter((s) => !soilType || s.soil_type === soilType);
    return INDICATORS.map((ind) => Object.assign(
      { key: ind.key, label: ind.label, unit: ind.unit },
      errorStats(chosen.map((s) => ({ estimate: s.est[ind.key], reference: s.ref[ind.key] }))),
    ));
  }

  /** Đọc một số do người dùng gõ: nhận cả dấu phẩy và dấu chấm thập phân. Ô trống thì là null. */
  function parseNumber(text) {
    if (text === null || text === undefined) return null;
    const trimmed = String(text).trim().replace(',', '.');
    if (trimmed === '') return null;
    const value = Number(trimmed);
    return Number.isFinite(value) ? value : null;
  }

  // ---------------- CSV ----------------

  function csvCell(value, sep) {
    if (value === null || value === undefined) return '';
    const text = String(value);
    if (text.includes(sep) || text.includes('"') || text.includes('\n') || text.includes('\r')) {
      return '"' + text.replace(/"/g, '""') + '"';
    }
    return text;
  }

  function toRows(text, sep) {
    const rows = [];
    let row = [];
    let cell = '';
    let quoted = false;
    for (let i = 0; i < text.length; i++) {
      const ch = text[i];
      if (quoted) {
        if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
        else if (ch === '"') quoted = false;
        else cell += ch;
      } else if (ch === '"') {
        quoted = true;
      } else if (ch === sep) {
        row.push(cell); cell = '';
      } else if (ch === '\n' || ch === '\r') {
        if (ch === '\r' && text[i + 1] === '\n') i++;
        row.push(cell); cell = '';
        if (row.length > 1 || row[0] !== '') rows.push(row);
        row = [];
      } else {
        cell += ch;
      }
    }
    row.push(cell);
    if (row.length > 1 || row[0] !== '') rows.push(row);
    return rows;
  }

  /** Bảng mẫu đất ra CSV: UTF-8 có BOM để Excel đọc đúng dấu tiếng Việt, số dùng dấu chấm. */
  function toCsv(samples) {
    const lines = [CSV_COLUMNS.join(',')];
    for (const s of samples || []) {
      const cells = SAMPLE_COLUMNS.map((col) => s[col])
        .concat(INDICATORS.map((ind) => s.est[ind.key]))
        .concat(INDICATORS.map((ind) => s.ref[ind.key]))
        .concat([s.note]);
      lines.push(cells.map((v) => csvCell(v, ',')).join(','));
    }
    return '﻿' + lines.join('\r\n') + '\r\n';
  }

  /**
   * Đọc lại CSV của toCsv. Nhận cả tệp đã lưu lại từ Excel cài đặt kiểu Việt Nam
   * (ngăn cột bằng dấu chấm phẩy, số dùng dấu phẩy thập phân). Cột nhận theo tên ở dòng đầu.
   */
  function fromCsv(text) {
    const clean = String(text || '').replace(/^﻿/, '');
    const firstLine = clean.split(/\r?\n/, 1)[0];
    const sep = firstLine.includes(';') && !firstLine.includes(',') ? ';' : ',';
    const rows = toRows(clean, sep);
    if (rows.length === 0) return [];
    const header = rows[0].map((h) => h.trim());
    const index = (name) => header.indexOf(name);
    if (index('sample_id') < 0) throw new Error('Tệp CSV thiếu cột sample_id');

    return rows.slice(1).map((cells) => {
      const get = (name) => (index(name) >= 0 && cells[index(name)] !== undefined ? cells[index(name)] : '');
      const sample = {};
      for (const col of SAMPLE_COLUMNS) sample[col] = get(col);
      sample.est = {};
      sample.ref = {};
      for (const ind of INDICATORS) {
        sample.est[ind.key] = parseNumber(get('est_' + ind.key));
        sample.ref[ind.key] = parseNumber(get('ref_' + ind.key));
      }
      sample.note = get('note');
      return sample;
    });
  }

  const api = {
    INDICATORS,
    CSV_COLUMNS,
    errorStats,
    sampleSd,
    adcToMoisturePercent,
    noiseSummary,
    averageTelemetry,
    summarize,
    parseNumber,
    toCsv,
    fromCsv,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.SoilMetrics = api;
  }
})(typeof window !== 'undefined' ? window : this);
