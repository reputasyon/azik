import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'models.dart';
import 'store_base.dart';

class ContentStore implements LibraryStore {
  late Database _db;
  final DatabaseFactory? testFactory;
  final String? testPath;
  ContentStore({this.testFactory, this.testPath});
  @override
  Future<void> open() async {
    final factory =
        testFactory ??
        ((Platform.isWindows || Platform.isLinux)
            ? ffi.databaseFactoryFfi
            : databaseFactory);
    if (Platform.isWindows || Platform.isLinux) ffi.sqfliteFfiInit();
    String dbPath;
    if (testPath != null) {
      dbPath = testPath!;
    } else {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      dbPath = p.join(dir.path, 'azik.db');
    }
    _db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE guides (id TEXT PRIMARY KEY, title TEXT, category TEXT, summary TEXT, body TEXT, updated TEXT, source TEXT, license TEXT)',
          );
          await db.execute(
            'CREATE TABLE metadata (key TEXT PRIMARY KEY, value INTEGER NOT NULL)',
          );
        },
      ),
    );
  }

  Future<void> close() => _db.close();
  @override
  Future<int> version() async {
    final rows = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['version'],
    );
    return rows.isEmpty ? 0 : rows.first['value'] as int;
  }

  @override
  Future<List<Guide>> guides() async => (await _db.query(
    'guides',
    orderBy: 'rowid',
  )).map(Guide.fromJson).toList();
  @override
  Future<void> install(String text) async {
    final pack = ContentPack.parse(text);
    await _db.transaction((tx) async {
      final rows = await tx.query(
        'metadata',
        where: 'key = ?',
        whereArgs: ['version'],
      );
      final current = rows.isEmpty ? 0 : rows.first['value'] as int;
      if (pack.version <= current) {
        throw const FormatException('Eski veya aynı paket yüklenemez');
      }
      await tx.delete('guides');
      for (final g in pack.guides) {
        await tx.insert('guides', g.toJson());
      }
      await tx.insert('metadata', {
        'key': 'version',
        'value': pack.version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
