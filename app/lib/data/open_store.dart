// Picks the store per platform: sqflite on the phone, in memory on the web demo
// (no sqflite on web; the demo uses synthetic data only).
export 'open_store_io.dart' if (dart.library.js_interop) 'open_store_web.dart';
