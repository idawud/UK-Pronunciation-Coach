import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Small key-value store for Coach features (confusions, lost words, chunks, circ and
/// shadow). Each feature owns one namespaced key and stores a JSON object under it.
///
/// Values must be JSON-encodable (maps, lists, strings, numbers, booleans and null).
abstract interface class CoachStore {
  /// The object stored under [key], or null when the key is absent or the store is
  /// missing or corrupt.
  Future<Map<String, Object?>?> read(String key);

  /// Replaces the object under [key] with [value]. Other keys are kept.
  Future<void> write(String key, Map<String, Object?> value);

  /// Removes every key (the "Reset Coach data" action).
  Future<void> clear();
}

/// Default [CoachStore]: one JSON file, `coach_store.json`, in the application
/// documents directory.
///
/// File layout: `{"version": 1, "data": {"<key>": {...}, ...}}`. `data` holds the
/// feature keys so that `version` cannot collide with one.
///
/// Writes go to a temporary file that is then renamed over the real file, so a crash
/// mid-write leaves the previous file intact. Writes are queued, so concurrent
/// read-modify-write calls cannot lose each other's keys. A missing, unreadable,
/// corrupt or unknown-version file is treated as empty; the next write replaces it.
class JsonFileCoachStore implements CoachStore {
  /// Creates the store. [directoryProvider] defaults to path_provider's application
  /// documents directory; tests pass a temporary directory.
  JsonFileCoachStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  /// Schema version written at the top level of the file.
  static const int version = 1;

  /// File name inside the documents directory.
  static const String fileName = 'coach_store.json';

  final Future<Directory> Function() _directoryProvider;

  /// Tail of the write queue; each write waits for the previous one.
  Future<void> _queue = Future<void>.value();

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<Map<String, Object?>?> read(String key) async {
    final data = await _load();
    final value = data[key];
    return value is Map<String, Object?> ? value : null;
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) {
    // Encode before queueing so a non-encodable value fails in the caller.
    final encoded = jsonEncode(value);
    return _enqueue(() async {
      final data = await _load();
      data[key] = jsonDecode(encoded) as Map<String, Object?>;
      await _save(data);
    });
  }

  @override
  Future<void> clear() => _enqueue(() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // Keep the queue alive even when one action fails.
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Reads every key. Any problem with the file yields an empty map.
  Future<Map<String, Object?>> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return <String, Object?>{};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return <String, Object?>{};
      if (decoded['version'] != version) return <String, Object?>{};
      final data = decoded['data'];
      if (data is! Map<String, Object?>) return <String, Object?>{};
      return Map<String, Object?>.of(data);
    } on Object {
      return <String, Object?>{};
    }
  }

  Future<void> _save(Map<String, Object?> data) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    final body = jsonEncode(<String, Object?>{
      'version': version,
      'data': data,
    });
    await temp.writeAsString(body, flush: true);
    await temp.rename(file.path);
  }
}

/// In-memory [CoachStore] for tests and previews. Values are JSON round-tripped so
/// tests see the same type rules as [JsonFileCoachStore].
class InMemoryCoachStore implements CoachStore {
  /// Creates an empty store.
  InMemoryCoachStore();

  final Map<String, Map<String, Object?>> _data = {};

  @override
  Future<Map<String, Object?>?> read(String key) async {
    final value = _data[key];
    if (value == null) return null;
    return jsonDecode(jsonEncode(value)) as Map<String, Object?>;
  }

  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    _data[key] = jsonDecode(jsonEncode(value)) as Map<String, Object?>;
  }

  @override
  Future<void> clear() async => _data.clear();
}

/// The Coach store. Defaults to [JsonFileCoachStore]; tests override it with
/// [InMemoryCoachStore] or a store over a temporary directory.
final coachStoreProvider = Provider<CoachStore>((ref) => JsonFileCoachStore());
