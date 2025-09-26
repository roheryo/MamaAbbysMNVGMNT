import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), "app.db");
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
        }
      },
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // Optional test user
    await db.insert('users', {
      'username': 'admin',
      'email': 'admin@example.com',
      'password': '1234', // store hashed passwords in real apps
    });
  }

  // Get user by username and password
  Future<Map<String, dynamic>?> getUser(
    String username,
    String password,
  ) async {
    final db = await database;
    var res = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return res.isNotEmpty ? res.first : null;
  }

  // Check if username or email exists
  Future<bool> checkUserExists({String? username, String? email}) async {
    final db = await database;
    String where = '';
    List<String> args = [];
    if (username != null) {
      where = 'username = ?';
      args.add(username);
    } else if (email != null) {
      where = 'email = ?';
      args.add(email);
    }
    var res = await db.query('users', where: where, whereArgs: args);
    return res.isNotEmpty;
  }

  // Insert a new user
  Future<int> insertUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final db = await database;
    return await db.insert('users', {
      'username': username,
      'email': email,
      'password': password,
    });
  }
}
