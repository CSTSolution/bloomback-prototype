import 'sqflite_store.dart';
import 'store.dart';

Future<Store> openStore() async => SqfliteStore.open();
