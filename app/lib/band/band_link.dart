// What the app needs from a band, whatever carries the lines (BLE or FakeBand).
import 'dart:async';

class FoundBand {
  final String id; // BLE remote id, or "fake"
  final String name; // BloomBack-XXXX
  final int rssi;
  const FoundBand(this.id, this.name, this.rssi);
}

/// A connected band that speaks docs/PROTOCOL.md lines.
abstract class BandTransport {
  /// Complete lines from the band, without '\n'.
  Stream<String> get lines;

  /// Sends one command line (must end in '\n').
  Future<void> send(String line);

  /// Fires when the link drops.
  Future<void> get closed;

  Future<void> close();
}

abstract class BandLink {
  bool get isFake;

  /// Bands nearby whose name starts with BloomBack- and that advertise NUS.
  Stream<List<FoundBand>> scan({Duration timeout = const Duration(seconds: 10)});

  Future<void> stopScan();

  /// Connects, asks for MTU 247 and subscribes to TX. On Android the first
  /// connection triggers the OS pairing dialog; the band shows the 6-digit passkey.
  Future<BandTransport> connect(String id);

  /// Removes the bond on the phone side (Android). iOS needs Settings > Bluetooth.
  /// Returns false if the user has to do it in the OS settings.
  Future<bool> forget(String id);
}
