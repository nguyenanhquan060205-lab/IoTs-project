import 'package:flutter_test/flutter_test.dart';
import 'package:soil_nutrient_app/models/soil_telemetry.dart';
import 'package:soil_nutrient_app/models/soil_type.dart';
import 'package:soil_nutrient_app/services/history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SoilTelemetry reading(DateTime time, {double moisture = 55.0, double nitrogen = 65.0, SoilType? soil = SoilType.garden}) {
  return SoilTelemetry(
    nitrogen: nitrogen,
    phosphorus: 33.0,
    potassium: 90.0,
    ph: 6.4,
    ec: moisture * 13.5,
    moisture: moisture,
    timestamp: time,
    soilType: soil,
  );
}

void main() {
  late HistoryRepository repo;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    repo = HistoryRepository(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });

  tearDown(() => repo.close());

  test('Saves at most one reading per minute', () async {
    final start = DateTime.now().subtract(const Duration(hours: 1));

    expect(await repo.save(reading(start)), isTrue);
    // The station publishes every 4 s, those readings are skipped
    expect(await repo.save(reading(start.add(const Duration(seconds: 4)))), isFalse);
    expect(await repo.save(reading(start.add(const Duration(seconds: 59)))), isFalse);
    expect(await repo.save(reading(start.add(const Duration(minutes: 1)))), isTrue);

    final series = await repo.loadSeries(
      from: start.subtract(const Duration(minutes: 1)),
      bucket: const Duration(seconds: 1),
    );
    expect(series.length, 2);
  });

  test('Notifies listeners only when a reading is actually stored', () async {
    final start = DateTime.now().subtract(const Duration(hours: 1));
    var notified = 0;
    repo.savedCount.addListener(() => notified++);

    await repo.save(reading(start));
    await repo.save(reading(start.add(const Duration(seconds: 4)))); // skipped, same minute
    await repo.save(reading(start.add(const Duration(minutes: 1))));

    expect(notified, 2);
    expect(repo.savedCount.value, 2);
  });

  test('Series averages readings inside each bucket', () async {
    // UTC start keeps 10-minute buckets aligned whatever the machine's time zone is
    final start = DateTime.utc(2026, 11, 24, 1, 0);
    await repo.save(reading(start, moisture: 40.0));
    await repo.save(reading(start.add(const Duration(minutes: 2)), moisture: 60.0));
    await repo.save(reading(start.add(const Duration(minutes: 15)), moisture: 70.0));

    final series = await repo.loadSeries(
      from: start.subtract(const Duration(minutes: 1)),
      bucket: const Duration(minutes: 10),
    );

    expect(series.map((p) => p.moisture), [50.0, 70.0]);
    expect(series.first.time.isAtSameMomentAs(start), isTrue);
  });

  test('Daily summaries are split by day and soil type, newest day first', () async {
    final day1 = DateTime(2026, 11, 23, 9, 0);
    final day2 = DateTime(2026, 11, 24, 9, 0);
    await repo.save(reading(day1, nitrogen: 64.0));
    await repo.save(reading(day1.add(const Duration(minutes: 5)), nitrogen: 66.0));
    await repo.save(reading(day2, nitrogen: 20.0, soil: SoilType.barren));
    await repo.save(reading(day2.add(const Duration(minutes: 5)), nitrogen: 95.0, soil: SoilType.potting));

    final days = await repo.loadDailySummaries(from: DateTime(2026, 11, 1));

    expect(days.length, 3);
    expect(days.first.day, DateTime(2026, 11, 24));
    expect(days.where((d) => d.day == DateTime(2026, 11, 24)).map((d) => d.soilType),
        containsAll([SoilType.barren, SoilType.potting]));
    final garden = days.last;
    expect(garden.day, DateTime(2026, 11, 23));
    expect(garden.soilType, SoilType.garden);
    expect(garden.count, 2);
    expect(garden.nitrogen, 65.0);
  });

  test('Readings older than 30 days are removed when the database opens', () async {
    final path = '${await databaseFactoryFfi.getDatabasesPath()}/history_retention_test.db';
    await databaseFactoryFfi.deleteDatabase(path);

    final first = HistoryRepository(factory: databaseFactoryFfi, path: path);
    await first.save(reading(DateTime.now().subtract(const Duration(days: 31))));
    await first.save(reading(DateTime.now().subtract(const Duration(days: 2))));
    await first.close();

    final reopened = HistoryRepository(factory: databaseFactoryFfi, path: path);
    final series = await reopened.loadSeries(
      from: DateTime.now().subtract(const Duration(days: 60)),
      bucket: const Duration(minutes: 1),
    );
    await reopened.close();
    await databaseFactoryFfi.deleteDatabase(path);

    expect(series.length, 1);
  });
}
