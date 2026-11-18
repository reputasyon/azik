import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'store_base.dart';

// Web is a lightweight preview. Native apps keep the library in SQLite.
class ContentStore implements LibraryStore {
  late SharedPreferences _prefs;
  @override
  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<int> version() async {
    final text = _prefs.getString('content-pack');
    return text == null ? 0 : ContentPack.parse(text).version;
  }

  @override
  Future<List<Guide>> guides() async {
    final text = _prefs.getString('content-pack');
    return text == null ? [] : ContentPack.parse(text).guides;
  }

  @override
  Future<void> install(String text) async {
    final pack = ContentPack.parse(text);
    if (pack.version <= await version()) {
      throw const FormatException('Eski veya aynı paket yüklenemez');
    }
    if (!await _prefs.setString('content-pack', text)) {
      throw StateError('İçerik kaydedilemedi');
    }
  }
}
