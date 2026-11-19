// Local store. Nothing leaves the phone. Minutes and check-ins are kept 60 days.
// The phone app uses SqfliteStore (sqflite_store.dart); the web demo and the tests
// use MemoryStore (open_store.dart picks one per platform).
import 'dart:convert';

import 'models.dart';

const kRetentionDays = 60;

abstract class Store {
  Future<void> saveMinutes(List<MinuteRec> recs);
  Future<List<MinuteRec>> minutesFrom(int fromMinute);
  Future<void> saveCheckin(Checkin c);
  Future<void> saveCheckins(List<Checkin> cs);
  Future<List<Checkin>> checkinsFrom(int fromMinute);
  Future<Map<String, dynamic>?> getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> value);
  Future<void> removeKey(String key);

  /// Deletes minutes and check-ins older than 60 days.
  Future<void> prune(int nowMinute);

  /// "Delete my data": everything, including profile and plan.
  Future<void> deleteAll();

  /// Band minutes, band check-ins and the sync cursor (used when switching
  /// between the demo band and a real one, so the two never mix).
  Future<void> deleteBandData();

  Future<int> syncCursor() async => (await getJson('cursor'))?['minute'] as int? ?? 0;
  Future<void> setSyncCursor(int minute) => setJson('cursor', {'minute': minute});
}

/// In-memory store: tests and the web demo (nothing is kept after the page closes).
class MemoryStore extends Store {
  final minutes = <int, MinuteRec>{};
  final checkins = <int, Checkin>{};
  final kv = <String, String>{};

  @override
  Future<void> saveMinutes(List<MinuteRec> recs) async {
    for (final r in recs) {
      minutes[r.minute] = r;
    }
  }

  @override
  Future<List<MinuteRec>> minutesFrom(int fromMinute) async =>
      (minutes.values.where((r) => r.minute >= fromMinute).toList()
        ..sort((a, b) => a.minute.compareTo(b.minute)));

  @override
  Future<void> saveCheckin(Checkin c) async => checkins[c.minute] = c;

  @override
  Future<void> saveCheckins(List<Checkin> cs) async {
    for (final c in cs) {
      checkins[c.minute] = c;
    }
  }

  @override
  Future<List<Checkin>> checkinsFrom(int fromMinute) async =>
      (checkins.values.where((c) => c.minute >= fromMinute).toList()
        ..sort((a, b) => a.minute.compareTo(b.minute)));

  @override
  Future<Map<String, dynamic>?> getJson(String key) async =>
      kv[key] == null ? null : jsonDecode(kv[key]!) as Map<String, dynamic>;

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      kv[key] = jsonEncode(value);

  @override
  Future<void> removeKey(String key) async => kv.remove(key);

  @override
  Future<void> prune(int nowMinute) async {
    final cut = nowMinute - kRetentionDays * 1440;
    minutes.removeWhere((k, _) => k < cut);
    checkins.removeWhere((k, _) => k < cut);
  }

  @override
  Future<void> deleteBandData() async {
    minutes.clear();
    checkins.removeWhere((_, c) => c.source == DataSource.watch);
    kv.remove('cursor');
  }

  @override
  Future<void> deleteAll() async {
    minutes.clear();
    checkins.clear();
    kv.clear();
  }
}
