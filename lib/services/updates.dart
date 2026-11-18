import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../data/models.dart';

class UpdateFailure implements Exception {
  final String message;
  const UpdateFailure(this.message);
  @override
  String toString() => message;
}

class PackUpdate {
  final int version, size;
  final String digest;
  final Uri url;
  const PackUpdate(this.version, this.size, this.digest, this.url);
}

class UpdateService {
  final http.Client client;
  final String catalogUrl, publicKey, repository;
  UpdateService({
    http.Client? client,
    this.catalogUrl = const String.fromEnvironment('AZIK_CATALOG_URL'),
    this.publicKey = const String.fromEnvironment('AZIK_PUBLIC_KEY'),
    this.repository = const String.fromEnvironment('AZIK_REPOSITORY'),
  }) : client = client ?? http.Client();
  bool get configured =>
      catalogUrl.isNotEmpty && publicKey.isNotEmpty && repository.isNotEmpty;

  Future<List<int>> _get(Uri uri, int limit) async {
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw const UpdateFailure('Dosya alınamadı. Daha sonra yeniden dene.');
    if ((response.contentLength ?? 0) > limit)
      throw const UpdateFailure('Dosya boyutu sınırı aşıldı.');
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > limit)
        throw const UpdateFailure('Dosya boyutu sınırı aşıldı.');
    }
    return bytes;
  }

  Future<PackUpdate?> check(int installedVersion) async {
    if (!configured)
      throw const UpdateFailure('GitHub yayın kanalı henüz yapılandırılmadı.');
    final catalog = Uri.parse(catalogUrl);
    if (catalog.scheme != 'https' ||
        !catalog.host.endsWith('.github.io') ||
        catalog.hasPort ||
        catalog.userInfo.isNotEmpty) {
      throw const UpdateFailure(
        'Güncelleme kataloğu bir HTTPS GitHub Pages adresi olmalı.',
      );
    }
    final envelope = jsonDecode(
      utf8.decode(await _get(catalog, 128 * 1024)),
    ) as Map<String, dynamic>;
    final payload = base64Decode(envelope['payload'] as String);
    final valid = await Ed25519().verify(
      payload,
      signature: Signature(
        base64Decode(envelope['signature'] as String),
        publicKey: SimplePublicKey(
          base64Decode(publicKey),
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid)
      throw const UpdateFailure(
        'Güncelleme imzası doğrulanamadı. Mevcut içerik korundu.',
      );
    final j = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
    if (j['schema'] != 1 ||
        j['id'] != 'temel' ||
        j['minAppBuild'] is! int ||
        j['minAppBuild'] > 1) {
      throw const UpdateFailure(
        'Bu içerik için uygulamanın yeni sürümü gerekiyor.',
      );
    }
    final v = j['version'], size = j['bytes'], digest = j['sha256'];
    if (v is! int ||
        v < 1 ||
        size is! int ||
        size < 1 ||
        size > 20 * 1024 * 1024 ||
        digest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const UpdateFailure('Güncelleme kataloğu geçersiz.');
    }
    final uri = Uri.parse(j['url'] as String);
    if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository) ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/$repository/releases/download/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const UpdateFailure(
        'Paket adresi bu projenin GitHub sürümlerine ait değil.',
      );
    }
    if (v <= installedVersion) return null;
    return PackUpdate(v, size, digest, uri);
  }

  Future<String> download(PackUpdate update) async {
    final bytes = await _get(update.url, update.size);
    final digest = (await Sha256().hash(bytes)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (bytes.length != update.size || digest != update.digest)
      throw const UpdateFailure(
        'Dosya bütünlüğü doğrulanamadı. Mevcut içerik korundu.',
      );
    final text = utf8.decode(bytes);
    if (ContentPack.parse(text).version != update.version)
      throw const UpdateFailure('Paket sürümü katalogla eşleşmiyor.');
    return text;
  }

  void close() => client.close();
}
