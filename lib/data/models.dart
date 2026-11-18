import 'dart:convert';

String normalize(String text) => text
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

class Guide {
  final String id, title, category, summary, body, updated, source, license;
  const Guide({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.body,
    required this.updated,
    required this.source,
    required this.license,
  });
  factory Guide.fromJson(Map<String, dynamic> j) {
    String field(String key) {
      final v = j[key];
      if (v is! String || v.trim().isEmpty || v.length > 100000) {
        throw FormatException('Geçersiz rehber alanı: $key');
      }
      return v;
    }

    final id = field('id');
    if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(id))
      throw const FormatException('Geçersiz rehber kimliği');
    return Guide(
      id: id,
      title: field('title'),
      category: field('category'),
      summary: field('summary'),
      body: field('body'),
      updated: field('updated'),
      source: field('source'),
      license: field('license'),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'summary': summary,
    'body': body,
    'updated': updated,
    'source': source,
    'license': license,
  };
  bool matches(String query) =>
      normalize('$title $summary $body $category')
          .contains(normalize(query.trim()));
}

class ContentPack {
  final int version;
  final List<Guide> guides;
  const ContentPack(this.version, this.guides);
  factory ContentPack.parse(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['schema'] != 1 ||
        j['id'] != 'temel' ||
        j['version'] is! int ||
        j['version'] < 1) {
      throw const FormatException('Desteklenmeyen içerik paketi');
    }
    final rows = j['guides'];
    if (rows is! List || rows.isEmpty || rows.length > 10000)
      throw const FormatException('Geçersiz rehber listesi');
    final guides = rows
        .map((r) => Guide.fromJson(r as Map<String, dynamic>))
        .toList();
    if (guides.map((g) => g.id).toSet().length != guides.length)
      throw const FormatException('Yinelenen rehber kimliği');
    return ContentPack(j['version'] as int, guides);
  }
}
