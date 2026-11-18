import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

// Web is a lightweight preview. Native apps keep the library in SQLite.
class ContentStore {
  late SharedPreferences _prefs;
  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<int> version() async {
    final text = _prefs.getString('content-pack');
    return text == null ? 0 : ContentPack.parse(text).version;
  }

  Future<List<Guide>> guides() async {
    final text = _prefs.getString('content-pack');
    return text == null ? [] : ContentPack.parse(text).guides;
  }

  Future<void> install(String text) async {
    final pack = ContentPack.parse(text);
    if (pack.version <= await version())
      throw const FormatException('Eski veya aynı paket yüklenemez');
    if (!await _prefs.setString('content-pack', text))
      throw StateError('İçerik kaydedilemedi');
  }
}
