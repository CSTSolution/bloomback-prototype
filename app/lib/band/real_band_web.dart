// Web demo: only the demo band works. A real band needs the Android app.
import 'band_link.dart';

const kRealBandOnWeb = 'A real band needs the Android app. This web demo uses the demo band only.';

BandLink createRealBandLink() => const _NoBandLink();

class _NoBandLink implements BandLink {
  const _NoBandLink();

  @override
  bool get isFake => false;

  @override
  Stream<List<FoundBand>> scan({Duration timeout = const Duration(seconds: 10)}) =>
      Stream.error(StateError(kRealBandOnWeb));

  @override
  Future<void> stopScan() async {}

  @override
  Future<BandTransport> connect(String id) => Future.error(StateError(kRealBandOnWeb));

  @override
  Future<bool> forget(String id) async => false;
}
