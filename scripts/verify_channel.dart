// Maintainer smoke test: fetch and verify a real public release without installing.
import 'dart:convert';
import 'dart:io';

import 'package:azik/services/updates.dart';
import 'package:azik/data/models.dart';

Future<void> main() async {
  final config = jsonDecode(
    File('config/release.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final service = UpdateService(
    catalogUrl: config['AZIK_CATALOG_URL'] as String,
    publicKey: config['AZIK_PUBLIC_KEY'] as String,
    repository: config['AZIK_REPOSITORY'] as String,
  );
  try {
    final update = await service.check(0);
    if (update == null) throw StateError('No published pack');
    final pack = ContentPack.parse(await service.download(update));
    stdout.writeln(
      'Verified live GitHub catalog signature and release SHA-256: v${pack.version}, ${pack.guides.length} guides.',
    );
  } finally {
    service.close();
  }
}
