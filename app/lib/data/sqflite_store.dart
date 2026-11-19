// sqflite store for the phone app (Android, iOS). Not compiled into the web demo.
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'store.dart';

class SqfliteStore extends Store {
  final Database db;
  SqfliteStore._(this.db);

  static Future<SqfliteStore> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(p.join(dir, 'bloomback.db'), version: 1,
        onCreate: (db, v) async {
      await db.execute('CREATE TABLE minutes(minute INTEGER PRIMARY KEY, steps INTEGER, '
          'med INTEGER, max INTEGER, flags INTEGER)');
      await db.execute('CREATE TABLE checkins(minute INTEGER PRIMARY KEY, status INTEGER, '
          'source TEXT)');
      await db.execute('CREATE TABLE kv(k TEXT PRIMARY KEY, v TEXT)');
    });
    return SqfliteStore._(db);
  }

  @override
  Future<void> saveMinutes(List<MinuteRec> recs) async {
    for (var i = 0; i < recs.length; i += 2000) {
      final b = db.batch();
      for (final r in recs.skip(i).take(2000)) {
        b.rawInsert('INSERT OR REPLACE INTO minutes VALUES(?,?,?,?,?)',
            [r.minute, r.steps, r.medDiff, r.maxDiff, r.flags]);
      }
      await b.commit(noResult: true);
    }
  }

  @override
  Future<List<MinuteRec>> minutesFrom(int fromMinute) async {
    final rows = await db.rawQuery(
        'SELECT minute, steps, med, max, flags FROM minutes WHERE minute >= ? ORDER BY minute',
        [fromMinute]);
    return [
      for (final r in rows)
        MinuteRec(r['minute'] as int, r['steps'] as int, r['med'] as int, r['max'] as int,
            r['flags'] as int)
    ];
  }

  @override
  Future<void> saveCheckin(Checkin c) => saveCheckins([c]);

  @override
  Future<void> saveCheckins(List<Checkin> cs) async {
    final b = db.batch();
    for (final c in cs) {
      b.rawInsert('INSERT OR REPLACE INTO checkins VALUES(?,?,?)',
          [c.minute, c.status.index, c.source.name]);
    }
    await b.commit(noResult: true);
  }

  @override
  Future<List<Checkin>> checkinsFrom(int fromMinute) async {
    final rows = await db.rawQuery(
        'SELECT minute, status, source FROM checkins WHERE minute >= ? ORDER BY minute',
        [fromMinute]);
    return [
      for (final r in rows)
        Checkin(r['minute'] as int, CheckinStatus.values[r['status'] as int],
            DataSource.values.byName(r['source'] as String))
    ];
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final rows = await db.rawQuery('SELECT v FROM kv WHERE k = ?', [key]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['v'] as String) as Map<String, dynamic>;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      db.rawInsert('INSERT OR REPLACE INTO kv VALUES(?, ?)', [key, jsonEncode(value)]);

  @override
  Future<void> removeKey(String key) => db.rawDelete('DELETE FROM kv WHERE k = ?', [key]);

  @override
  Future<void> prune(int nowMinute) async {
    final cut = nowMinute - kRetentionDays * 1440;
    await db.rawDelete('DELETE FROM minutes WHERE minute < ?', [cut]);
    await db.rawDelete('DELETE FROM checkins WHERE minute < ?', [cut]);
  }

  @override
  Future<void> deleteBandData() async {
    await db.rawDelete('DELETE FROM minutes');
    await db.rawDelete("DELETE FROM checkins WHERE source = 'watch'");
    await removeKey('cursor');
  }

  @override
  Future<void> deleteAll() async {
    await db.rawDelete('DELETE FROM minutes');
    await db.rawDelete('DELETE FROM checkins');
    await db.rawDelete('DELETE FROM kv');
  }
}
