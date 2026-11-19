import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const songPickerAvailable = true;

/// Lets the user pick an audio file and copies it into the app's folder. Returns (path, name) or null.
Future<(String, String)?> pickSong({String? replacing}) async {
  // Files, not the Music library: Apple Music songs are not files an app may play.
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'aiff', 'caf', 'flac', 'ogg'],
  );
  final src = f?.path;
  if (src == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final name = p.basename(src);
  final dest = p.join(dir.path, 'after-step-song${p.extension(src).toLowerCase()}');
  if (replacing != null && replacing != dest) await deleteSong(replacing);
  await File(src).copy(dest);
  return (dest, name);
}

Future<void> deleteSong(String? path) async {
  if (path == null) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
