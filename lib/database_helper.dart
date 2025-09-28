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
    await _ensureDeliveriesQuantityColumn(_db!);
    return _db!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), "app.db");
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

    await db.insert('users', {
      'username': 'admin',
      'email': 'admin@example.com',
      'password': '1234',
    });

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

    await db.execute('''
      CREATE TABLE deliveries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerName TEXT NOT NULL,
        customerContact TEXT NOT NULL,
        location TEXT NOT NULL,
        category TEXT NOT NULL,
        productId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        status TEXT DEFAULT 'Pending',
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isRead INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      var columns = await db.rawQuery("PRAGMA table_info(products)");
      bool hasImagePath = columns.any((col) => col['name'] == 'imagePath');
      if (!hasImagePath) await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deliveries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerName TEXT NOT NULL,
          customerContact TEXT NOT NULL,
          location TEXT NOT NULL,
          category TEXT NOT NULL,
          productId INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          quantity INTEGER,
          status TEXT DEFAULT 'Pending',
          FOREIGN KEY(productId) REFERENCES products(id)
        )
      ''');
      await _ensureDeliveriesQuantityColumn(db);
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          isRead INTEGER DEFAULT 0
        )
      ''');
    }
  }

  Future<void> _ensureDeliveriesQuantityColumn(Database db) async {
    var columns = await db.rawQuery("PRAGMA table_info(deliveries)");
    bool hasQuantity = columns.any((col) => col['name'] == 'quantity');
    if (!hasQuantity) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN quantity INTEGER DEFAULT 0');
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

  // ===================== Products Methods =====================
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert('products', product);
  }

  Future<List<Map<String, dynamic>>> fetchProducts({String? category}) async {
    final db = await database;
    if (category != null) {
      return await db.query(
        'products',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'createdAt DESC',
      );
    }
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

  // ===================== Deliveries Methods =====================
  Future<int> insertDelivery(Map<String, dynamic> delivery) async {
    final db = await database;
    return await db.insert('deliveries', delivery);
  }

  Future<List<Map<String, dynamic>>> fetchDeliveries() async {
    final db = await database;
    return await db.query('deliveries', orderBy: "createdAt DESC");
  }

  Future<int> updateDeliveryStatus(dynamic id, String status) async {
    final db = await database;
    int deliveryId = id is int ? id : int.parse(id.toString());
    return await db.update('deliveries', {'status': status}, where: 'id = ?', whereArgs: [deliveryId]);
  }

  Future<int> deleteDelivery(int id) async {
    final db = await database;
    return await db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== Notifications Methods =====================
  Future<int> insertNotification(String title, String message) async {
    final db = await database;
    return await db.insert('notifications', {
      "title": title,
      "message": message,
      "isRead": 0,
      "createdAt": DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchNotifications({bool onlyUnread = false}) async {
    final db = await database;
    return await db.query(
      "notifications",
      where: onlyUnread ? "isRead = 0" : null,
      orderBy: "createdAt DESC",
    );
  }

  Future<int> markAllNotificationsRead() async {
    final db = await database;
    return await db.update("notifications", {"isRead": 1});
  }

  Future<bool> hasUnreadNotifications() async {
    final db = await database;
    final res = await db.query("notifications", where: "isRead = 0", limit: 1);
    return res.isNotEmpty;
  }

  // ===================== Overdue Deliveries Checker =====================
  DateTime? _parseDynamicDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      try {
        if (value > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(value);
        if (value > 1000000000) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt;
      final num = int.tryParse(value);
      if (num != null) {
        if (num > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(num);
        if (num > 1000000000) return DateTime.fromMillisecondsSinceEpoch(num * 1000);
        return DateTime.fromMillisecondsSinceEpoch(num);
      }
    }
    return null;
  }

  Future<void> checkOverdueDeliveries({Duration overdueAfter = const Duration(days: 1)}) async {
    final db = await database;
    final deliveries = await db.query('deliveries', where: "status = ?", whereArgs: ["Pending"]);

    for (var d in deliveries) {
      final createdAt = _parseDynamicDate(d["createdAt"]);
      if (createdAt == null) continue;

      if (DateTime.now().isAfter(createdAt.add(overdueAfter))) {
        await updateDeliveryStatus(d['id'], 'Overdue');

        final message = "Delivery for ${d['customerName']} is overdue!";
        final existing = await db.query("notifications", where: "message = ?", whereArgs: [message]);
        if (existing.isEmpty) {
          await insertNotification(
            "Overdue Delivery",
            "$message\nLocation: ${d['location']}\nProduct ID: ${d['productId']} | Qty: ${d['quantity']}",
          );
        }
      }
    }
  }

  // ===================== Debug Helper =====================
  Future<void> printDbPath() async {
    final path = join(await getDatabasesPath(), "app.db");
    print("Database is stored here: $path");
  }
}
