import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/soil_telemetry.dart';
import '../models/soil_type.dart';

/// Một điểm trên biểu đồ lịch sử: trung bình các số đo trong một khoảng thời gian
class HistoryPoint {
  final DateTime time;
  final double moisture;
  final double ec;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double ph;

  const HistoryPoint({
    required this.time,
    required this.moisture,
    required this.ec,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
  });
}

/// Trung bình số đo trong một ngày của một loại đất
class DailySummary {
  final DateTime day;
  final SoilType? soilType;
  final int count;
  final double moisture;
  final double ec;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double ph;

  const DailySummary({
    required this.day,
    required this.soilType,
    required this.count,
    required this.moisture,
    required this.ec,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.ph,
  });
}

/// Lưu số đo vào SQLite trên điện thoại để xem đất thay đổi theo ngày.
/// Trạm gửi 4 giây một lần nhưng chỉ lưu 1 bản ghi mỗi phút và giữ 30 ngày gần nhất (~1.400 dòng/ngày).
class HistoryRepository {
  static const Duration sampleInterval = Duration(minutes: 1);
  static const Duration retention = Duration(days: 30);

  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database?>? _opening;
  DateTime? _lastSavedAt;

  /// Tăng 1 mỗi khi lưu xong một số đo, để trang Lịch sử đang mở tự tải lại
  final ValueNotifier<int> savedCount = ValueNotifier(0);

  HistoryRepository({this._factory, this._path});

  Future<Database?> _database() => _opening ??= _open();

  Future<Database?> _open() async {
    try {
      final factory = _factory ?? databaseFactory;
      final path = _path ?? p.join(await factory.getDatabasesPath(), 'soil_history.db');
      final db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE readings (
                ts INTEGER NOT NULL,
                soil_type TEXT,
                moisture REAL NOT NULL,
                ec REAL NOT NULL,
                nitrogen REAL NOT NULL,
                phosphorus REAL NOT NULL,
                potassium REAL NOT NULL,
                ph REAL NOT NULL
              )''');
            await db.execute('CREATE INDEX idx_readings_ts ON readings(ts)');
          },
        ),
      );
      final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
      await db.delete('readings', where: 'ts < ?', whereArgs: [cutoff]);
      return db;
    } catch (e) {
      // Ví dụ chạy widget test không có plugin sqflite: App vẫn chạy, chỉ không lưu lịch sử
      debugPrint('[HISTORY] Không mở được CSDL lịch sử: $e');
      return null;
    }
  }

  /// Lưu số đo nếu đã cách lần lưu trước ít nhất [sampleInterval]. Trả về true nếu đã lưu.
  Future<bool> save(SoilTelemetry telemetry) async {
    final last = _lastSavedAt;
    if (last != null && telemetry.timestamp.difference(last).abs() < sampleInterval) {
      return false;
    }
    // Ghi nhận trước khi chờ CSDL để bản tin 4 giây sau không lọt qua trong lúc đang ghi
    _lastSavedAt = telemetry.timestamp;

    final db = await _database();
    if (db == null) return false;
    try {
      await db.insert('readings', {
        'ts': telemetry.timestamp.millisecondsSinceEpoch,
        'soil_type': telemetry.soilType?.code,
        'moisture': telemetry.moisture,
        'ec': telemetry.ec,
        'nitrogen': telemetry.nitrogen,
        'phosphorus': telemetry.phosphorus,
        'potassium': telemetry.potassium,
        'ph': telemetry.ph,
      });
    } catch (e) {
      // Provider gọi save() mà không chờ kết quả, nên phải tự bắt lỗi ở đây
      debugPrint('[HISTORY] Không lưu được số đo: $e');
      return false;
    }
    savedCount.value++;
    return true;
  }

  /// Số đo từ [from] tới nay, gom trung bình theo từng khoảng [bucket] để biểu đồ không quá dày
  Future<List<HistoryPoint>> loadSeries({required DateTime from, required Duration bucket}) async {
    final db = await _database();
    if (db == null) return [];

    final size = bucket.inMilliseconds;
    final rows = await db.rawQuery('''
      SELECT (ts / ?) * ? AS bucket,
             AVG(moisture) AS moisture, AVG(ec) AS ec, AVG(nitrogen) AS nitrogen,
             AVG(phosphorus) AS phosphorus, AVG(potassium) AS potassium, AVG(ph) AS ph
      FROM readings
      WHERE ts >= ?
      GROUP BY bucket
      ORDER BY bucket''', [size, size, from.millisecondsSinceEpoch]);

    return rows
        .map((row) => HistoryPoint(
              time: DateTime.fromMillisecondsSinceEpoch(row['bucket'] as int),
              moisture: row['moisture'] as double,
              ec: row['ec'] as double,
              nitrogen: row['nitrogen'] as double,
              phosphorus: row['phosphorus'] as double,
              potassium: row['potassium'] as double,
              ph: row['ph'] as double,
            ))
        .toList();
  }

  /// Trung bình theo ngày (giờ địa phương) từ [from] tới nay, ngày mới nhất đứng đầu
  Future<List<DailySummary>> loadDailySummaries({required DateTime from}) async {
    final db = await _database();
    if (db == null) return [];

    final rows = await db.rawQuery('''
      SELECT date(ts / 1000, 'unixepoch', 'localtime') AS day, soil_type, COUNT(*) AS count,
             AVG(moisture) AS moisture, AVG(ec) AS ec, AVG(nitrogen) AS nitrogen,
             AVG(phosphorus) AS phosphorus, AVG(potassium) AS potassium, AVG(ph) AS ph
      FROM readings
      WHERE ts >= ?
      GROUP BY day, soil_type
      ORDER BY day DESC, soil_type''', [from.millisecondsSinceEpoch]);

    return rows
        .map((row) => DailySummary(
              day: DateTime.parse(row['day'] as String),
              soilType: SoilType.fromCode(row['soil_type'] as String?),
              count: row['count'] as int,
              moisture: row['moisture'] as double,
              ec: row['ec'] as double,
              nitrogen: row['nitrogen'] as double,
              phosphorus: row['phosphorus'] as double,
              potassium: row['potassium'] as double,
              ph: row['ph'] as double,
            ))
        .toList();
  }

  Future<void> close() async {
    final db = await _opening;
    _opening = null;
    await db?.close();
  }
}
