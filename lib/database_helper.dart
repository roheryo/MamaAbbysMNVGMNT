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
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    // Users table
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
      'password': '1234',
    });

    // Products table
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productName TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        imagePath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Upgrade logic: only add missing columns/tables
    if (oldVersion < 4) {
      // Add imagePath column if not exists
      var columns = await db.rawQuery("PRAGMA table_info(products)");
      bool hasImagePath = columns.any((col) => col['name'] == 'imagePath');
      if (!hasImagePath) {
        await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT');
      }
    }
  }

  // ===================== Users Methods =====================
  Future<Map<String, dynamic>?> getUser(String username, String password) async {
    final db = await database;
    var res = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return res.isNotEmpty ? res.first : null;
  }

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

  Future<int> insertUser({required String username, required String email, required String password}) async {
    final db = await database;
    return await db.insert('users', {
      'username': username,
      'email': email,
      'password': password,
    });
  }

  // ===================== Products Methods =====================
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert('products', product);
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final db = await database;
    return await db.query('products', orderBy: "createdAt DESC");
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    return await db.update('products', product, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
