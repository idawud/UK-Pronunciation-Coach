import 'dart:io';

/// Deletes recording files for the progress repository.
///
/// [directory] is where the app keeps recordings (A1 / I1 decide); when given,
/// [deleteAll] also empties it so no stray clip survives "delete all my data".
/// Tests pass a temporary directory.
class RecordingStore {
  /// Creates a store; [directory] is optional.
  RecordingStore({this.directory});

  /// Folder holding recordings, if known.
  final Directory? directory;

  /// Deletes the file at [path]. Missing files and file-system errors are ignored
  /// (a later [deleteAll] retries the folder). Returns true when a file was deleted.
  Future<bool> delete(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final f = File(path);
      if (!await f.exists()) return false;
      await f.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Deletes every file in [paths] and everything inside [directory].
  Future<void> deleteAll(Iterable<String?> paths) async {
    for (final p in paths) {
      await delete(p);
    }
    final dir = directory;
    if (dir == null || !await dir.exists()) return;
    await for (final e in dir.list(followLinks: false)) {
      try {
        await e.delete(recursive: true);
      } on FileSystemException {
        // Best effort; nothing else can be done here.
      }
    }
  }
}
