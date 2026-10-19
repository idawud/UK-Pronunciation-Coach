import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin adapter over the system "save file" and "open file" dialogs, used to export
/// and import the progress backup. The user chooses where the file goes.
abstract interface class BackupFiles {
  /// Lets the user save [contents] as [fileName]. False when they cancelled.
  Future<bool> save(String fileName, String contents);

  /// Lets the user pick a backup file and returns its text, or null when cancelled.
  Future<String?> pick();
}

/// [BackupFiles] on the platform file dialogs (file_picker's Android and Darwin
/// implementations, MIT).
class PlatformBackupFiles implements BackupFiles {
  /// Creates the adapter; [platform] defaults to the registered implementation.
  PlatformBackupFiles({this._platform});

  final FilePickerPlatform? _platform;

  FilePickerPlatform get _picker => _platform ?? FilePickerPlatform.instance;

  @override
  Future<bool> save(String fileName, String contents) async {
    final uri = await _picker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(contents)),
      mimeType: 'application/json',
      dialogTitle: 'Save your progress',
    );
    return uri != null;
  }

  @override
  Future<String?> pick() async {
    final file = await _picker.pickFile(
      dialogTitle: 'Choose a progress backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }
}

/// The backup file adapter. Override in tests.
final backupFilesProvider = Provider<BackupFiles>(
  (ref) => PlatformBackupFiles(),
);

/// Export file name for [now], e.g. `uk-coach-progress-2026-10-19.json`.
String backupFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'uk-coach-progress-${now.year}-${two(now.month)}-${two(now.day)}.json';
}
