import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [text] to a temporary file and opens the share sheet.
Future<void> shareTextFile(String name, String text, {required String subject}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsString(text);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: subject));
}
