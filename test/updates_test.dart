import 'dart:convert';
import 'dart:io';

import 'package:azik/data/models.dart';
import 'package:azik/data/store_native.dart';
import 'package:azik/services/updates.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final seed = File('assets/content/temel.json').readAsStringSync();
  test('Turkish search tolerates dotted letters and plain keyboards', () {
    final pack = ContentPack.parse(seed);
    expect(pack.guides.first.matches('ILETISIM'), isTrue);
    expect(normalize('İIıŞĞÜÖÇ'), 'iiisguoc');
  });
  test('Invalid or duplicate guides never form a pack', () {
    final j = jsonDecode(seed) as Map<String, dynamic>;
    (j['guides'] as List).add((j['guides'] as List).first);
    expect(() => ContentPack.parse(jsonEncode(j)), throwsFormatException);
  });
  test(
    'SQLite preserves the old library on invalid update and rejects rollback',
    () async {
      sqfliteFfiInit();
      final store = ContentStore(
        testFactory: databaseFactoryFfiNoIsolate,
        testPath: inMemoryDatabasePath,
      );
      await store.open();
      addTearDown(store.close);
      await store.install(seed);
      await expectLater(store.install('{"schema":99}'), throwsA(anything));
      expect(await store.version(), 1);
      expect((await store.guides()).length, 6);
      final updated = jsonDecode(seed) as Map<String, dynamic>;
      updated['version'] = 2;
      await store.install(jsonEncode(updated));
      await expectLater(store.install(seed), throwsFormatException);
      expect(await store.version(), 2);
    },
  );
  test('Signed GitHub update installs; tamper, wrong host and old versions are rejected', () async {
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final pub = base64Encode((await pair.extractPublicKey()).bytes);
    final pack = jsonDecode(seed) as Map<String, dynamic>;
    pack['version'] = 2;
    final body = utf8.encode(jsonEncode(pack));
    final hash = (await Sha256().hash(body)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    List<int> assetBody = body;
    final payload = <String, dynamic>{
      'schema': 1,
      'id': 'temel',
      'version': 2,
      'minAppBuild': 1,
      'bytes': body.length,
      'sha256': hash,
      'url': 'https://github.com/reputasyon/azik/releases/download/content-v2/temel.json',
    };
    Future<String> envelope() async {
      final bytes = utf8.encode(jsonEncode(payload));
      final signature = await algorithm.sign(bytes, keyPair: pair);
      return jsonEncode({
        'payload': base64Encode(bytes),
        'signature': base64Encode(signature.bytes),
      });
    }

    var catalog = await envelope();
    final service = UpdateService(
      catalogUrl: 'https://reputasyon.github.io/azik/catalog.json',
      publicKey: pub,
      repository: 'reputasyon/azik',
      client: MockClient(
        (r) async => r.url.host.endsWith('github.io')
            ? http.Response(catalog, 200)
            : http.Response.bytes(assetBody, 200),
      ),
    );
    addTearDown(service.close);
    final update = (await service.check(1))!;
    expect(ContentPack.parse(await service.download(update)).version, 2);
    expect(await service.check(2), isNull);
    assetBody = [...body]..[0] = 32;
    await expectLater(service.download(update), throwsA(isA<UpdateFailure>()));
    payload['url'] =
        'https://github.com/other/project/releases/download/v2/temel.json';
    catalog = await envelope();
    await expectLater(service.check(1), throwsA(isA<UpdateFailure>()));
    final corrupted = jsonDecode(catalog) as Map<String, dynamic>;
    corrupted['payload'] = base64Encode(utf8.encode('{}'));
    catalog = jsonEncode(corrupted);
    await expectLater(service.check(1), throwsA(isA<UpdateFailure>()));
  });
}
