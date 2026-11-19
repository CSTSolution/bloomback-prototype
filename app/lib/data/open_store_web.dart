import 'store.dart';

/// Web demo: data lives in memory only and is gone when the page is closed.
Future<Store> openStore() async => MemoryStore();
