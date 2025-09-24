import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;
  String? _dbPath;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('Database not initialized. Call init() first.');
    }
    return database;
  }

  String get dbPath {
    final path = _dbPath;
    if (path == null) {
      throw StateError('Database path unknown. Call init() first.');
    }
    return path;
  }

  Future<void> init() async {
    // Initialize FFI for desktop only (not Android/iOS or Web)
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path = await _resolveDbPath();
    _dbPath = path;

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              email TEXT NOT NULL UNIQUE
            )
          ''');
          // Seed sample rows
          await db.insert('users', {
            'name': 'Alice',
            'email': 'alice@example.com',
          });
          await db.insert('users', {'name': 'Bob', 'email': 'bob@example.com'});
        },
      ),
    );
  }

  Future<String> _resolveDbPath() async {
    // On web, SQLite via sqflite is not supported. Avoid Platform.* access entirely.
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite (sqflite) is not supported on Flutter Web. Run on Android, iOS, Windows, macOS, or Linux.',
      );
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final base = await getDatabasesPath();
      return p.join(base, 'app.db');
    }
    // Desktop (Windows/macOS/Linux): create ./data/app.db next to your project
    final Directory cwd = Directory.current;
    final Directory dataDir = Directory(p.join(cwd.path, 'data'));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return p.join(dataDir.path, 'app.db');
  }

  // Simple API
  Future<int> insertUser(String name, String email) {
    return db.insert('users', {'name': name, 'email': email});
  }

  Future<List<Map<String, Object?>>> getUsers() {
    return db.query('users', orderBy: 'id ASC');
  }
}
