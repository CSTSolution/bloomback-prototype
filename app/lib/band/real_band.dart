// The real band link per platform: Bluetooth LE on the phone; on the web demo
// there is no Bluetooth code at all (flutter_blue_plus is not compiled in).
export 'real_band_io.dart' if (dart.library.js_interop) 'real_band_web.dart';
