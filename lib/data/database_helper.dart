import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Manages SQLite schema v1 under the backup-excluded application support dir.
class DatabaseHelper {
  DatabaseHelper({
    DatabaseFactory? factory,
    Future<Directory> Function()? supportDirProvider,
  }) : _factory = factory ?? databaseFactory,
       _supportDirProvider =
           supportDirProvider ?? getApplicationSupportDirectory;

  static const int schemaVersion = 1;
  static const String dbFileName = 'cantonese_pronunciation.db';

  final DatabaseFactory _factory;
  final Future<Directory> Function() _supportDirProvider;
  Database? _db;

  Future<String> resolveDbPath() async {
    if (Platform.isAndroid) {
      final defaultDbDir = await _factory.getDatabasesPath();
      return p.join(defaultDbDir, dbFileName);
    }
    final supportDir = await _supportDirProvider();
    if (!supportDir.existsSync()) {
      supportDir.createSync(recursive: true);
    }
    return p.join(supportDir.path, dbFileName);
  }

  Future<Database> open() async {
    if (_db != null && _db!.isOpen) return _db!;
    final dbPath = await resolveDbPath();
    await Directory(p.dirname(dbPath)).create(recursive: true);
    _db = await _factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE syllables (
        syllable TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        initial TEXT NOT NULL,
        nucleus TEXT NOT NULL,
        coda TEXT NOT NULL,
        tone INTEGER NOT NULL,
        initial_group INTEGER NOT NULL,
        priority INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_syllables_priority ON syllables (priority)',
    );
    await db.execute(
      'CREATE INDEX idx_syllables_base ON syllables (initial, nucleus, coda)',
    );
    await db.execute('CREATE INDEX idx_syllables_tone ON syllables (tone)');

    await db.execute('''
      CREATE TABLE confusion_stats (
        component TEXT NOT NULL,
        expected TEXT NOT NULL,
        guessed TEXT NOT NULL,
        count INTEGER NOT NULL,
        PRIMARY KEY (component, expected, guessed)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for schema v2+ migrations.
  }
}
