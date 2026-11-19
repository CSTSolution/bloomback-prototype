// Real band over Bluetooth LE: Nordic UART Service, MTU 247, OS bonding.
//
// flutter_blue_plus is pinned to 1.36.8, the last release under BSD-3.
// 2.x moved to the "FlutterBluePlus License" (paid for for-profit companies,
// plus a build-time licence ping), see app/README.md.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'band_link.dart';
import 'protocol.dart';

class BleBandLink implements BandLink {
  @override
  bool get isFake => false;

  @override
  Stream<List<FoundBand>> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    if (await FlutterBluePlus.isSupported == false) {
      throw StateError('Bluetooth LE is not supported on this phone');
    }
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 5),
            onTimeout: () => throw StateError('Please turn Bluetooth on'));
    final found = <String, FoundBand>{};
    final out = StreamController<List<FoundBand>>();
    final results = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        if (!name.startsWith(Nus.namePrefix)) continue;
        found[r.device.remoteId.str] = FoundBand(r.device.remoteId.str, name, r.rssi);
      }
      if (!out.isClosed) out.add(found.values.toList());
    });
    // Filter by the NUS service (Android and iOS) and by name prefix (above).
    await FlutterBluePlus.startScan(withServices: [Guid(Nus.service)], timeout: timeout);
    // The scan ends on its timeout or on stopScan(): close the stream then.
    final ended = FlutterBluePlus.isScanning.where((on) => !on).listen((_) async {
      await results.cancel();
      if (!out.isClosed) await out.close();
    });
    try {
      yield* out.stream;
    } finally {
      await ended.cancel();
      await results.cancel();
    }
  }

  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  @override
  Future<BandTransport> connect(String id) async {
    final device = BluetoothDevice.fromId(id);
    // Android: ask for MTU 247 during connect. iOS negotiates the MTU itself.
    await device.connect(mtu: Platform.isAndroid ? Nus.mtu : null, timeout: const Duration(seconds: 20));
    if (Platform.isAndroid) {
      // RX/TX need an encrypted, authenticated link: this shows the OS passkey
      // dialog the first time; the band displays the 6-digit code.
      try {
        await device.createBond(timeout: 90);
      } catch (_) {
        // Already bonded, or the OS will bond on first encrypted access.
      }
    }
    final services = await device.discoverServices();
    final nus = services.where((s) => s.uuid == Guid(Nus.service)).firstOrNull;
    if (nus == null) {
      await device.disconnect();
      throw StateError('This device is not a BloomBack band (no UART service)');
    }
    final rx = nus.characteristics.firstWhere((c) => c.uuid == Guid(Nus.rx));
    final tx = nus.characteristics.firstWhere((c) => c.uuid == Guid(Nus.tx));
    final transport = _BleTransport(device, rx, tx);
    await transport._start();
    return transport;
  }

  @override
  Future<bool> forget(String id) async {
    final device = BluetoothDevice.fromId(id);
    try {
      await device.disconnect();
    } catch (_) {}
    if (Platform.isAndroid) {
      try {
        await device.removeBond();
        return true;
      } catch (_) {
        return false;
      }
    }
    return false; // iOS: Settings > Bluetooth > (i) > Forget This Device
  }
}

class _BleTransport implements BandTransport {
  final BluetoothDevice device;
  final BluetoothCharacteristic rx;
  final BluetoothCharacteristic tx;
  final _lines = StreamController<String>.broadcast();
  final _closed = Completer<void>();
  final _asm = LineAssembler();
  StreamSubscription<List<int>>? _valueSub;
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  _BleTransport(this.device, this.rx, this.tx);

  Future<void> _start() async {
    _valueSub = tx.onValueReceived.listen((chunk) {
      for (final l in _asm.add(chunk)) {
        _lines.add(l);
      }
    });
    device.cancelWhenDisconnected(_valueSub!);
    _stateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && !_closed.isCompleted) {
        _closed.complete();
      }
    });
    await tx.setNotifyValue(true);
  }

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> send(String line) async {
    final bytes = utf8.encode(line);
    final chunk = (device.mtuNow - 3).clamp(20, 244);
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = (i + chunk).clamp(0, bytes.length);
      await rx.write(bytes.sublist(i, end), withoutResponse: false);
    }
  }

  @override
  Future<void> close() async {
    await _valueSub?.cancel();
    await _stateSub?.cancel();
    try {
      await device.disconnect();
    } catch (_) {}
    if (!_closed.isCompleted) _closed.complete();
    await _lines.close();
  }
}
