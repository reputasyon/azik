import 'models.dart';

abstract interface class LibraryStore {
  Future<void> open();
  Future<int> version();
  Future<List<Guide>> guides();
  Future<void> install(String text);
}
