import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uk_pronunciation_coach/ui/settings/backup_files.dart';
import 'package:uk_pronunciation_coach/ui/settings/reminder_scheduler.dart';

final class _File extends PlatformFile {
  _File(this.text);

  final String text;

  @override
  String get name => 'backup.json';

  @override
  Uri get uri => Uri.file('/tmp/backup.json');

  @override
  XFile get xFile => XFile.fromData(utf8.encode(text));

  @override
  int? lengthSync() => text.length;

  @override
  Future<int?> length() async => text.length;

  @override
  Future<Uint8List> readAsBytes() async => utf8.encode(text);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(utf8.encode(text));
}

class _Picker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  String? savedName;
  String? savedText;
  String? savedMime;
  PlatformFile? toPick;
  bool cancelSave = false;
  List<String>? extensions;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (cancelSave) return null;
    savedName = fileName;
    savedText = utf8.decode(bytes);
    savedMime = mimeType;
    return Uri.file('/saved/$fileName');
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    extensions = allowedExtensions;
    return toPick;
  }
}

void main() {
  test('PlatformBackupFiles saves JSON and reads a picked file', () async {
    final picker = _Picker();
    final files = PlatformBackupFiles(platform: picker);
    expect(await files.save('a.json', '{"x":"é"}'), isTrue);
    expect(picker.savedName, 'a.json');
    expect(picker.savedText, '{"x":"é"}');
    expect(picker.savedMime, 'application/json');

    picker.cancelSave = true;
    expect(await files.save('a.json', '{}'), isFalse);

    expect(await files.pick(), isNull);
    picker.toPick = _File('{"y":1}');
    expect(await files.pick(), '{"y":1}');
    expect(picker.extensions, ['json']);
  });

  test('PlatformBackupFiles defaults to the registered platform', () async {
    final picker = _Picker();
    FilePickerPlatform.instance = picker;
    expect(await PlatformBackupFiles().save('b.json', '{}'), isTrue);
    expect(picker.savedName, 'b.json');
  });

  test('backupFileName pads the date', () {
    expect(
      backupFileName(DateTime(2026, 3, 7)),
      'uk-coach-progress-2026-03-07.json',
    );
  });

  test('UnavailableReminderScheduler does nothing', () async {
    const s = UnavailableReminderScheduler();
    expect(s.isSupported, isFalse);
    expect(await s.requestPermission(), isFalse);
    await s.scheduleDaily(600);
    await s.cancel();
  });
}
