import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../../core/contracts/errors.dart';
import '../../core/models/enums.dart';
import '../../core/models/model_download_progress.dart';
import 'model_manifest.dart';
import 'network.dart';

/// SHA-256 of the file at [path] as lower-case hex (synchronous; call it from a
/// background isolate for large files).
String sha256OfFileSync(String path) {
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  final file = File(path).openSync();
  try {
    while (true) {
      final chunk = file.readSync(1 << 20);
      if (chunk.isEmpty) break;
      input.add(chunk);
    }
  } finally {
    file.closeSync();
  }
  input.close();
  return sink.value.toString();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Downloads, resumes, verifies and deletes the full-tier files listed in the
/// manifest, and reports [ModelDownloadProgress].
///
/// Files land in [dir] under their manifest base names. While downloading they are
/// `<name>.part` (kept on cancel / failure for resume); after every SHA-256 matches
/// they are renamed and `verified.json` is written, which is what [isComplete] trusts
/// on later launches (re-hashing hundreds of MB at start-up would be too slow).
class FullModelDownloader {
  /// Creates the downloader for [files] (the full tier's manifest entries).
  FullModelDownloader({
    required List<ModelFileEntry> files,
    required this.dir,
    required this._transport,
    required this._network,
    this.hashFile = _hashInBackground,
  }) : files = List.unmodifiable(files);

  /// Files to fetch.
  final List<ModelFileEntry> files;

  /// Destination folder.
  final Directory dir;

  /// Hashes a file (default: SHA-256 in a background isolate).
  final Future<String> Function(String path) hashFile;

  final ModelTransport _transport;
  final NetworkMonitor _network;
  final _controller = StreamController<ModelDownloadProgress>.broadcast();
  ModelDownloadProgress _status = ModelDownloadProgress.idle;
  Future<void>? _running;
  Completer<void>? _cancel;

  static Future<String> _hashInBackground(String path) =>
      Isolate.run(() => sha256OfFileSync(path));

  /// Total bytes of all files.
  int get totalBytes => files.fold(0, (sum, f) => sum + f.size);

  /// Current state.
  ModelDownloadProgress get status => _status;

  /// Every change of [status] (broadcast).
  Stream<ModelDownloadProgress> get progress => _controller.stream;

  /// Final path of [entry].
  File fileFor(ModelFileEntry entry) => File('${dir.path}/${entry.basename}');

  File _partFor(ModelFileEntry entry) =>
      File('${dir.path}/${entry.basename}.part');

  File get _marker => File('${dir.path}/verified.json');

  void _emit(ModelDownloadProgress p) {
    _status = p;
    if (!_controller.isClosed) _controller.add(p);
  }

  /// Whether every file is on disk and was verified against the current manifest.
  Future<bool> isComplete() async {
    if (files.isEmpty || !_marker.existsSync()) return false;
    try {
      final verified =
          jsonDecode(await _marker.readAsString()) as Map<String, dynamic>;
      for (final f in files) {
        final file = fileFor(f);
        if (verified[f.basename] != f.sha256 ||
            !file.existsSync() ||
            file.lengthSync() != f.size) {
          return false;
        }
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Bytes already on disk (finished files plus partial downloads).
  int bytesOnDisk() {
    var total = 0;
    for (final f in files) {
      final done = fileFor(f);
      final part = _partFor(f);
      if (done.existsSync() && done.lengthSync() == f.size) {
        total += f.size;
      } else if (part.existsSync()) {
        total += part.lengthSync().clamp(0, f.size);
      }
    }
    return total;
  }

  /// Sets the initial [status] from what is on disk (call once at start-up).
  Future<void> restore() async {
    if (await isComplete()) {
      _emit(_completed());
    } else {
      final onDisk = bytesOnDisk();
      _emit(
        ModelDownloadProgress(
          state: DownloadState.idle,
          receivedBytes: onDisk,
          totalBytes: totalBytes,
        ),
      );
    }
  }

  ModelDownloadProgress _completed() => ModelDownloadProgress(
    state: DownloadState.completed,
    receivedBytes: totalBytes,
    totalBytes: totalBytes,
  );

  /// Downloads whatever is missing; see `PhonemeRecognizer.downloadFullModel`.
  /// Concurrent calls share one download.
  Future<void> download({bool requireWifi = true}) {
    return _running ??= _download(requireWifi).whenComplete(() {
      _running = null;
      _cancel = null;
    });
  }

  Future<void> _download(bool requireWifi) async {
    if (files.isEmpty) {
      _fail('No full model is listed in the model manifest');
    }
    if (await isComplete()) {
      if (_status.state != DownloadState.completed) _emit(_completed());
      return;
    }
    final cancel = _cancel = Completer<void>();
    await dir.create(recursive: true);
    var received = bytesOnDisk();
    while (true) {
      if (requireWifi && !await _network.isUnmetered()) {
        _emit(
          ModelDownloadProgress(
            state: DownloadState.waitingForWifi,
            receivedBytes: received,
            totalBytes: totalBytes,
          ),
        );
        // If the change stream ends without Wi-Fi, only a cancel can end the wait.
        final wifi = _network.unmeteredChanges
            .firstWhere((u) => u)
            .then<void>((_) {}, onError: (Object _) => cancel.future);
        await Future.any<void>([wifi, cancel.future]);
        if (cancel.isCompleted) _cancelled(received);
        continue; // re-check: the change event may be stale
      }
      _emit(
        ModelDownloadProgress(
          state: DownloadState.downloading,
          receivedBytes: received,
          totalBytes: totalBytes,
        ),
      );
      final lostWifi = Completer<void>();
      StreamSubscription<bool>? watch;
      if (requireWifi) {
        watch = _network.unmeteredChanges.listen((u) {
          if (!u && !lostWifi.isCompleted) lostWifi.complete();
        });
      }
      try {
        for (final f in files) {
          received = await _fetch(f, received, cancel, lostWifi);
        }
      } on _Interrupted catch (i) {
        received = bytesOnDisk();
        if (i.cancelled) _cancelled(received);
        continue; // Wi-Fi lost: wait for it again
      } on Object catch (e) {
        _fail('Download failed: $e', received: bytesOnDisk());
      } finally {
        await watch?.cancel();
      }
      break;
    }
    await _verify(received);
  }

  /// Streams [f] into its `.part` file from where it left off. Returns the new total.
  Future<int> _fetch(
    ModelFileEntry f,
    int received,
    Completer<void> cancel,
    Completer<void> lostWifi,
  ) async {
    final done = fileFor(f);
    if (done.existsSync() && done.lengthSync() == f.size) return received;
    final part = _partFor(f);
    var offset = part.existsSync() ? part.lengthSync() : 0;
    if (offset > f.size) {
      received -= f.size;
      part.deleteSync();
      offset = 0;
    }
    if (offset == f.size) return received;
    final response = await _transport.get(Uri.parse(f.url), offset: offset);
    if (offset > 0 && !response.resumed) {
      received -= offset; // server ignored the range: start this file again
      offset = 0;
    }
    final sink = part.openSync(
      mode: offset == 0 ? FileMode.write : FileMode.append,
    );
    final step = (totalBytes ~/ 200).clamp(64 * 1024, 1 << 30);
    var lastEmit = received;
    final finished = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    var interrupted = false;
    void stop() {
      if (interrupted || finished.isCompleted) return;
      interrupted = true;
      unawaited(sub.cancel());
      finished.complete();
    }

    sub = response.body.listen(
      (chunk) {
        sink.writeFromSync(chunk);
        received += chunk.length;
        if (received - lastEmit >= step) {
          lastEmit = received;
          _emit(
            ModelDownloadProgress(
              state: DownloadState.downloading,
              receivedBytes: received,
              totalBytes: totalBytes,
            ),
          );
        }
      },
      onError: (Object e, StackTrace s) {
        if (!finished.isCompleted) finished.completeError(e, s);
      },
      onDone: () {
        if (!finished.isCompleted) finished.complete();
      },
      cancelOnError: true,
    );
    unawaited(cancel.future.then((_) => stop()));
    unawaited(lostWifi.future.then((_) => stop()));
    try {
      await finished.future;
    } finally {
      sink.closeSync();
    }
    if (interrupted) throw _Interrupted(cancelled: cancel.isCompleted);
    _emit(
      ModelDownloadProgress(
        state: DownloadState.downloading,
        receivedBytes: received,
        totalBytes: totalBytes,
      ),
    );
    final length = part.lengthSync();
    if (length != f.size) {
      throw HttpException('${f.basename}: got $length of ${f.size} bytes');
    }
    return received;
  }

  Future<void> _verify(int received) async {
    _emit(
      ModelDownloadProgress(
        state: DownloadState.verifying,
        receivedBytes: received,
        totalBytes: totalBytes,
      ),
    );
    // Check every file before failing, so one retry re-fetches all bad ones.
    final verified = <String, String>{};
    final bad = <String>[];
    for (final f in files) {
      final done = fileFor(f);
      final part = _partFor(f);
      final source = part.existsSync() ? part : done;
      final actual = await hashFile(source.path);
      if (actual != f.sha256) {
        source.deleteSync();
        bad.add(f.basename);
        continue;
      }
      if (source == part) part.renameSync(done.path);
      verified[f.basename] = f.sha256;
    }
    if (bad.isNotEmpty) {
      _fail('Checksum mismatch for ${bad.join(', ')}', received: bytesOnDisk());
    }
    await _marker.writeAsString(jsonEncode(verified), flush: true);
    _emit(_completed());
  }

  Never _cancelled(int received) {
    _emit(
      ModelDownloadProgress(
        state: DownloadState.cancelled,
        receivedBytes: received,
        totalBytes: totalBytes,
      ),
    );
    throw const ModelDownloadException('Cancelled');
  }

  Never _fail(String message, {int? received}) {
    _emit(
      ModelDownloadProgress(
        state: DownloadState.failed,
        receivedBytes: received ?? _status.receivedBytes,
        totalBytes: totalBytes,
        error: message,
      ),
    );
    throw ModelDownloadException(message);
  }

  /// Cancels a running download (keeps partial files). No-op when idle.
  Future<void> cancel() async {
    final running = _running;
    final c = _cancel;
    if (running == null || c == null) return;
    if (!c.isCompleted) c.complete();
    try {
      await running;
    } on ModelDownloadException {
      // Expected: the download ends with "Cancelled".
    }
  }

  /// Cancels any download and deletes every full-tier file, partial or not.
  Future<void> delete() async {
    await cancel();
    if (dir.existsSync()) await dir.delete(recursive: true);
    _emit(
      ModelDownloadProgress(state: DownloadState.idle, totalBytes: totalBytes),
    );
  }

  /// Closes [progress].
  Future<void> close() async {
    await cancel();
    await _controller.close();
  }
}

class _Interrupted implements Exception {
  const _Interrupted({required this.cancelled});

  final bool cancelled;
}
