#!/usr/bin/env node
/*
 * Tính số cho báo cáo từ tệp CSV xuất ở trang web đánh giá, dùng chính các hàm trong web/metrics.js
 * để số trong báo cáo khớp với số trang web hiện.
 *
 *   node scripts/report_stats.js noise docs/thuc-nghiem/nhieu-dat-vuon.csv
 *   node scripts/report_stats.js samples docs/thuc-nghiem/mau-dat.csv
 *
 * In ra bảng Markdown để chép vào báo cáo.
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const M = require(path.join(__dirname, '..', 'web', 'metrics.js'));

const SOIL_LABELS = { potting: 'Đất đóng bao', garden: 'Đất vườn', barren: 'Đất bạc màu' };

const fmt = (value, digits) => (value === null || value === undefined ? '–' : value.toFixed(digits));

function readCsvRows(file) {
  const text = fs.readFileSync(file, 'utf8').replace(/^﻿/, '');
  const lines = text.split(/\r?\n/).filter((line) => line.trim() !== '');
  const header = lines[0].split(',');
  return lines.slice(1).map((line) => {
    const cells = line.split(',');
    return Object.fromEntries(header.map((name, i) => [name, cells[i]]));
  });
}

/** Tệp nhiễu (cột adc_raw, adc_noise, adc_dry, adc_wet) đổi lại thành bản tin để dùng noiseSummary */
function noise(file) {
  const num = (text) => (text === undefined || text === '' ? null : Number(text));
  const messages = readCsvRows(file).map((row) => ({
    soil_type: row.soil_type,
    adc: { raw: num(row.adc_raw), noise: num(row.adc_noise), dry: num(row.adc_dry), wet: num(row.adc_wet) },
  }));
  const s = M.noiseSummary(messages);
  const soil = messages.length ? SOIL_LABELS[messages[0].soil_type] || messages[0].soil_type : '';
  console.log(`Tệp: ${path.basename(file)} | ${soil} | mốc khô ${s.dry}, mốc ướt ${s.wet}`);
  console.log('| Số bản tin | ADC trung bình | Không lọc (trung bình adc.noise) | Có lọc (SD của adc.raw) | Giảm nhiễu |');
  console.log('|---|---|---|---|---|');
  console.log(`| ${s.m} | ${fmt(s.adcMean, 1)} | ${fmt(s.rawNoiseMean, 2)} (±${fmt(s.rawNoisePct, 2)}%) | `
    + `${fmt(s.filteredSd, 2)} (±${fmt(s.filteredSdPct, 2)}%) | ${fmt(s.reductionPercent, 1)}% |`);
}

/** Tệp mẫu đất (định dạng Xuất CSV của trang web): sai số N, P, K theo loại đất */
function samples(file) {
  const all = M.fromCsv(fs.readFileSync(file, 'utf8'));
  const soils = [...new Set(all.map((s) => s.soil_type))];
  console.log(`Tệp: ${path.basename(file)} | ${all.length} mẫu`);
  console.log('| Loại đất | Chất | n | MAE (mg/kg) | RMSE (mg/kg) | MAPE (%) |');
  console.log('|---|---|---|---|---|---|');
  for (const soil of [...soils, '']) {
    for (const row of M.summarize(all, soil).filter((r) => ['n', 'p', 'k'].includes(r.key))) {
      const label = soil ? SOIL_LABELS[soil] || soil : 'Chung';
      console.log(`| ${label} | ${row.label} | ${row.n} | ${fmt(row.mae, 2)} | ${fmt(row.rmse, 2)} | ${fmt(row.mape, 1)} |`);
    }
  }
}

const [command, file] = process.argv.slice(2);
if (!file || !['noise', 'samples'].includes(command)) {
  console.error('Cách dùng: node scripts/report_stats.js noise|samples <tệp CSV>');
  process.exit(2);
}
if (command === 'noise') noise(file);
else samples(file);
