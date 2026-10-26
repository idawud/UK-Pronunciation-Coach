/// "Send feedback" (R1-release, beta): opens an email draft in the user's own mail
/// app. The app sends nothing itself. The user may first save their progress file
/// (the same file as Export progress) and attach it to the draft by choice.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Placeholder used when the build has no `--dart-define=FEEDBACK_EMAIL=...`.
/// `.invalid` can never be delivered (RFC 2606), and the Settings entry is disabled
/// while it is in place.
const String feedbackEmailPlaceholder = 'feedback@example.invalid';

/// The feedback address of this build: `--dart-define=FEEDBACK_EMAIL=<address>`
/// (release.yml passes the `FEEDBACK_EMAIL` repository variable; docs/release.md).
const String feedbackEmailDefine = String.fromEnvironment(
  'FEEDBACK_EMAIL',
  defaultValue: feedbackEmailPlaceholder,
);

/// Returns [address] when it looks like a usable email address, otherwise null
/// (unset, placeholder or malformed).
String? usableFeedbackEmail(String address) {
  final a = address.trim();
  if (a.isEmpty || a == feedbackEmailPlaceholder) return null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(a) ? a : null;
}

/// The feedback address, or null when this build has none. Override in tests.
final feedbackEmailProvider = Provider<String?>(
  (ref) => usableFeedbackEmail(feedbackEmailDefine),
);

/// Opens a `mailto:` link in the mail app. Override in tests.
typedef EmailLauncher = Future<bool> Function(Uri mailto);

/// The platform [EmailLauncher] (url_launcher, BSD-3-Clause).
final emailLauncherProvider = Provider<EmailLauncher>(
  (ref) =>
      (uri) => launcher.launchUrl(
        uri,
        mode: launcher.LaunchMode.externalApplication,
      ),
);

/// Short description of the phone's system, added to the draft so bugs can be
/// reproduced. The user sees it in the draft and can delete it.
String deviceSummary() {
  try {
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  } on Object {
    return 'unknown';
  }
}

/// The `mailto:` link for a feedback draft to [to]. When [attachedFileName] is set
/// the body reminds the user to attach that file.
Uri feedbackMailto({
  required String to,
  String? attachedFileName,
  String? device,
}) {
  final body = StringBuffer()
    ..writeln('What happened, or what would you like to change?')
    ..writeln()
    ..writeln()
    ..writeln();
  if (attachedFileName != null) {
    body
      ..writeln(
        'Progress file: please attach $attachedFileName, which you just '
        'saved (it has your scores and practice dates, no recordings).',
      )
      ..writeln();
  }
  body
    ..writeln('---')
    ..writeln('UK Pronunciation Coach beta')
    ..writeln('Phone: ${device ?? deviceSummary()}')
    ..write('You can delete any of this before sending.');
  String enc(String s) => Uri.encodeComponent(s);
  // Built by hand: Uri(queryParameters:) encodes spaces as "+", which some mail
  // apps show literally.
  return Uri.parse(
    'mailto:$to?subject=${enc('UK Pronunciation Coach feedback')}'
    '&body=${enc(body.toString())}',
  );
}

/// What the user chose in the Send feedback dialog.
enum FeedbackChoice {
  /// Write an email without the progress file.
  emailOnly,

  /// Save the progress file first, then write the email and attach it.
  withProgress,
}

/// Asks whether to include the progress file. Null when cancelled.
Future<FeedbackChoice?> showFeedbackDialog(BuildContext context) =>
    showDialog<FeedbackChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send feedback'),
        content: const Text(
          'This opens an email in your mail app. Nothing is sent until you '
          'press Send there.\n\n'
          'You can also save your progress file and attach it, so we can see '
          'your practice days and scores. It has no recordings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, FeedbackChoice.emailOnly),
            child: const Text('Email only'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, FeedbackChoice.withProgress),
            child: const Text('Save file and email'),
          ),
        ],
      ),
    );
