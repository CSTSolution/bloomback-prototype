import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Web demo: hands the file to the browser (share sheet, or a download where
/// the browser has no file sharing). Nothing is sent anywhere by BloomBack.
Future<void> shareTextFile(String name, String text, {required String subject}) async {
  final file = XFile.fromData(utf8.encode(text), mimeType: 'application/json', name: name);
  await SharePlus.instance.share(ShareParams(files: [file], subject: subject, fileNameOverrides: [name], downloadFallbackEnabled: true));
}
