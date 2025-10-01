import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  // ===================== Static Product Catalog =====================
  // Centralized catalog of product names grouped by category
  static const Map<String, List<String>> productCatalog = {
    'Virginia Products': [
      'Virginia Classic 250g',
      'Virginia Chicken Hotdog 250g (Blue)',
      'Virginia Classic 500g',
      'Virginia Chicken Hotdog w/ Cheese (Jumbo)',
      'Virginia Classic 1kilo',
      'Virginia w/ Cheese 1 kilo',
      'Chicken Longganisa',
    ],
    'Big Shot Products': [
      'Big shot ball 500g',
      'Big shot classic 1 kilo',
      'Big shot w/ Cheese 1 kilo',
    ],
    'Beefies Products': [
      'Beefies Classic 250g',
      'Beefies w/ Cheese 250g',
      'Beefies Classic 1 kilo',
      'Beefies w/ Cheese 1 kilo',
    ],
    'Purefoods': [
      'TJ Classic 1 kilo',
      'TJ Cheesedog 1 kilo',
      'TJ Classic 250g',
      'Star Nuggets',
      'Crazy Cut Nuggets',
      'Chicken Breast Nuggets',
      'TJ Hotdog w/ Cheese 250g',
      'TJ Balls 500g',
      'TJ Chicken Jumbo',
      'TJ Cocktail',
      'TJ Cheesedog (Small)',
      'TJ Classic (Small)',
    ],
    'Chicken': [
      'Chicken Roll',
      'Chicken Loaf',
      'Chicken Ham',
      'Chicken Tocino',
      'Champion Chicken Hotdog',
      'Chicken Lumpia',
      'Chicken Chorizo',
    ],
    'Pork': [
      'Pork Chop',
      'Pork Pata',
      'Pork Belly',
      'Hamleg/Square Cut',
      'Pork Longganisa',
      'Pork Tocino',
      'Pork Chorizo',
      'Pork Lumpia',
    ],
    'Others': [
      'Burger Patty',
      'Ganada Sweet Ham',
      'Siomai Dimsum',
      'Beef Chorizo',
      'Squidball Kimsea',
      'Squidball Holiday',
      'Tocino Roll',
      'Orlian',
    ],
  };

  // Expose catalog categories as a list
  List<String> get catalogCategories => productCatalog.keys.toList();

  // Get product names for a specific category
  List<String> getProductsForCategory(String category) {
    return productCatalog[category] ?? const [];
  }

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
      version: 9,
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

    await db.execute('''
      CREATE TABLE store_sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_date DATE NOT NULL UNIQUE,
        day_of_week TEXT NOT NULL,
        month INTEGER NOT NULL,
        holiday_flag INTEGER NOT NULL DEFAULT 0,
        sales REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        totalAmount REAL NOT NULL,
        saleDate TEXT NOT NULL,
        FOREIGN KEY(productId) REFERENCES products(id)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_sale_date ON store_sales(sale_date)');
    await db.execute('CREATE INDEX idx_month ON store_sales(month)');
    await db.execute('CREATE INDEX idx_holiday_flag ON store_sales(holiday_flag)');
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

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS store_sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_date TEXT NOT NULL UNIQUE,
          day_of_week TEXT NOT NULL,
          month INTEGER NOT NULL,
          holiday_flag INTEGER NOT NULL DEFAULT 0,
          sales REAL NOT NULL
        )
      ''');
      
      // Create indexes for better performance
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_date ON store_sales(sale_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_month ON store_sales(month)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_holiday_flag ON store_sales(holiday_flag)');
    }

    if (oldVersion < 8) {
      // Migrate sale_date from TEXT to DATE
      // First, check if store_sales table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='store_sales'");
      if (tables.isNotEmpty) {
        // Create a temporary table with the new schema
        await db.execute('''
          CREATE TABLE store_sales_new(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_date DATE NOT NULL UNIQUE,
            day_of_week TEXT NOT NULL,
            month INTEGER NOT NULL,
            holiday_flag INTEGER NOT NULL DEFAULT 0,
            sales REAL NOT NULL
          )
        ''');
        
        // Copy data from old table to new table
        await db.execute('''
          INSERT INTO store_sales_new (id, sale_date, day_of_week, month, holiday_flag, sales)
          SELECT id, sale_date, day_of_week, month, holiday_flag, sales
          FROM store_sales
        ''');
        
        // Drop the old table
        await db.execute('DROP TABLE store_sales');
        
        // Rename the new table
        await db.execute('ALTER TABLE store_sales_new RENAME TO store_sales');
        
        // Recreate indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_date ON store_sales(sale_date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_month ON store_sales(month)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_holiday_flag ON store_sales(holiday_flag)');
      }
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales_transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productId INTEGER NOT NULL,
          productName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unitPrice REAL NOT NULL,
          totalAmount REAL NOT NULL,
          saleDate TEXT NOT NULL,
          FOREIGN KEY(productId) REFERENCES products(id)
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

  // Insert or accumulate product stock if same name/category/unitPrice exists
  Future<int> insertOrAccumulateProduct({
    required String productName,
    required String category,
    required int quantity,
    required double unitPrice,
    String? imagePath,
  }) async {
    final db = await database;

    // Try to find an existing product with same name, category, and price
    final existing = await db.query(
      'products',
      where: 'productName = ? AND category = ? AND unitPrice = ?',
      whereArgs: [productName, category, unitPrice],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingRow = existing.first;
      final id = (existingRow['id'] as num).toInt();
      final currentQty = (existingRow['quantity'] as num).toInt();
      final newQty = currentQty + quantity;

      // Update quantity and optionally imagePath
      final updateData = <String, Object?>{'quantity': newQty};
      if (imagePath != null && imagePath.isNotEmpty) {
        updateData['imagePath'] = imagePath;
      }

      await db.update('products', updateData, where: 'id = ?', whereArgs: [id]);
      return id;
    }

    // Otherwise insert a new product row
    return await db.insert('products', {
      'productName': productName,
      'category': category,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'imagePath': imagePath,
      'createdAt': DateTime.now().toIso8601String(),
    });
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

  Future<int> markNotificationsReadByIds(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.rawUpdate(
      'UPDATE notifications SET isRead = 1 WHERE id IN ($placeholders)',
      ids.map((e) => e).toList(),
    );
  }

  Future<bool> hasUnreadNotifications() async {
    final db = await database;
    final res = await db.query("notifications", where: "isRead = 0", limit: 1);
    return res.isNotEmpty;
  }

  // ===================== Store Sales Methods =====================
  
  // Helper method to format date for database storage
  String _formatDateForDatabase(String date) {
    try {
      // Try to parse the date and format it as YYYY-MM-DD
      final parsedDate = DateTime.parse(date);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      // If parsing fails, return the original string
      return date;
    }
  }
  Future<int> insertStoreSale({
    required String saleDate,
    required String dayOfWeek,
    required int month,
    required bool holidayFlag,
    required double sales,
  }) async {
    final db = await database;
    // Ensure the date is in proper format (YYYY-MM-DD)
    final formattedDate = _formatDateForDatabase(saleDate);
    return await db.insert('store_sales', {
      'sale_date': formattedDate,
      'day_of_week': dayOfWeek,
      'month': month,
      'holiday_flag': holidayFlag ? 1 : 0,
      'sales': sales,
    });
  }

  Future<List<Map<String, dynamic>>> fetchStoreSales({
    String? startDate,
    String? endDate,
    int? month,
    bool? holidayFlag,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      where = 'sale_date BETWEEN ? AND ?';
      whereArgs.addAll([_formatDateForDatabase(startDate), _formatDateForDatabase(endDate)]);
    } else if (startDate != null) {
      where = 'sale_date >= ?';
      whereArgs.add(_formatDateForDatabase(startDate));
    } else if (endDate != null) {
      where = 'sale_date <= ?';
      whereArgs.add(_formatDateForDatabase(endDate));
    }

    if (month != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'month = ?';
      whereArgs.add(month);
    }

    if (holidayFlag != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'holiday_flag = ?';
      whereArgs.add(holidayFlag ? 1 : 0);
    }

    return await db.query(
      'store_sales',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'sale_date DESC',
    );
  }

  Future<double> getTotalSales({
    String? startDate,
    String? endDate,
    int? month,
    bool? holidayFlag,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      where = 'sale_date BETWEEN ? AND ?';
      whereArgs.addAll([_formatDateForDatabase(startDate), _formatDateForDatabase(endDate)]);
    } else if (startDate != null) {
      where = 'sale_date >= ?';
      whereArgs.add(_formatDateForDatabase(startDate));
    } else if (endDate != null) {
      where = 'sale_date <= ?';
      whereArgs.add(_formatDateForDatabase(endDate));
    }

    if (month != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'month = ?';
      whereArgs.add(month);
    }

    if (holidayFlag != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'holiday_flag = ?';
      whereArgs.add(holidayFlag ? 1 : 0);
    }

    final result = await db.rawQuery(
      'SELECT SUM(sales) as total FROM store_sales${where.isNotEmpty ? ' WHERE $where' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> updateStoreSale(int id, {
    String? saleDate,
    String? dayOfWeek,
    int? month,
    bool? holidayFlag,
    double? sales,
  }) async {
    final db = await database;
    Map<String, dynamic> updateData = {};

    if (saleDate != null) updateData['sale_date'] = _formatDateForDatabase(saleDate);
    if (dayOfWeek != null) updateData['day_of_week'] = dayOfWeek;
    if (month != null) updateData['month'] = month;
    if (holidayFlag != null) updateData['holiday_flag'] = holidayFlag ? 1 : 0;
    if (sales != null) updateData['sales'] = sales;

    return await db.update('store_sales', updateData, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStoreSale(int id) async {
    final db = await database;
    return await db.delete('store_sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getStoreSaleByDate(String date) async {
    final db = await database;
    final formattedDate = _formatDateForDatabase(date);
    var res = await db.query(
      'store_sales',
      where: 'sale_date = ?',
      whereArgs: [formattedDate],
    );
    return res.isNotEmpty ? res.first : null;
  }

  // Helper method to create sample sales data for testing
  Future<void> createSampleSalesData() async {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    // Create sample data for the last 30 days
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayOfWeek = days[date.weekday - 1];
      final month = date.month;
      final holidayFlag = date.weekday == 7 || date.weekday == 1; // Weekend as "holiday"
      final sales = (1000 + (i * 50) + (date.weekday * 100)).toDouble(); // Sample sales amount
      
      // Check if data already exists
      final existing = await getStoreSaleByDate(dateStr);
      if (existing == null) {
        await insertStoreSale(
          saleDate: dateStr,
          dayOfWeek: dayOfWeek,
          month: month,
          holidayFlag: holidayFlag,
          sales: sales,
        );
      }
    }
  }

  // ===================== Low Stock Checker =====================
  Future<void> checkLowStockProducts({int threshold = 7}) async {
    final db = await database;
    final products = await db.query('products');
    for (var p in products) {
      final qty = (p['quantity'] is int)
          ? p['quantity'] as int
          : int.tryParse(p['quantity']?.toString() ?? '0') ?? 0;
      if (qty < threshold) {
        final productName = p['productName']?.toString() ?? 'Unknown Product';
        final message = "$productName stock is low: $qty left ";
        final existing = await db.query(
          'notifications',
          where: 'message = ?',
          whereArgs: [message],
          limit: 1,
        );
        if (existing.isEmpty) {
          await insertNotification('Low Stock', message);
        }
      }
    }
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
            "$message\nLocation: ${d['location']}",
          );
        }
      }
    }
  }

  // ===================== Unified Trigger =====================
  Future<void> triggerAllNotifications() async {
    await checkLowStockProducts();
    await checkOverdueDeliveries(overdueAfter: Duration.zero);
  }

  // ===================== Sales Transactions Methods =====================
  
  Future<int> insertSalesTransaction({
    required int productId,
    required String productName,
    required int quantity,
    required double unitPrice,
    required double totalAmount,
  }) async {
    final db = await database;
    return await db.insert('sales_transactions', {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalAmount': totalAmount,
      'saleDate': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchSalesTransactions({
    String? startDate,
    String? endDate,
    int? productId,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      where = 'saleDate BETWEEN ? AND ?';
      whereArgs.addAll([startDate, endDate]);
    } else if (startDate != null) {
      where = 'saleDate >= ?';
      whereArgs.add(startDate);
    } else if (endDate != null) {
      where = 'saleDate <= ?';
      whereArgs.add(endDate);
    }

    if (productId != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'productId = ?';
      whereArgs.add(productId);
    }

    return await db.query(
      'sales_transactions',
      where: where.isNotEmpty ? where : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'saleDate DESC',
    );
  }

  // Returns sales transactions joined with product category and filtered by inclusive date range.
  // startDate/endDate should be in 'yyyy-MM-dd' format when provided.
  Future<List<Map<String, dynamic>>> fetchSalesTransactionsWithCategory({
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    String where = '';
    List<dynamic> whereArgs = [];

    String? startIso;
    String? endIso;

    if (startDate != null) {
      try {
        final d = DateTime.parse(startDate);
        startIso = DateTime(d.year, d.month, d.day).toIso8601String();
      } catch (_) {
        // Fallback: use raw string if parsing fails
        startIso = startDate;
      }
    }

    if (endDate != null) {
      try {
        final d = DateTime.parse(endDate);
        endIso = DateTime(d.year, d.month, d.day, 23, 59, 59, 999).toIso8601String();
      } catch (_) {
        endIso = endDate;
      }
    }

    if (startIso != null && endIso != null) {
      where = 'st.saleDate BETWEEN ? AND ?';
      whereArgs.addAll([startIso, endIso]);
    } else if (startIso != null) {
      where = 'st.saleDate >= ?';
      whereArgs.add(startIso);
    } else if (endIso != null) {
      where = 'st.saleDate <= ?';
      whereArgs.add(endIso);
    }

    final rows = await db.rawQuery(
      'SELECT st.id, st.productId, st.productName, st.quantity, st.unitPrice, st.totalAmount, st.saleDate, p.category '
      'FROM sales_transactions st '
      'LEFT JOIN products p ON p.id = st.productId'
      '${where.isNotEmpty ? ' WHERE ' + where : ''} '
      'ORDER BY st.saleDate DESC',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return rows;
  }

  Future<double> getTotalSalesAmount({
    String? startDate,
    String? endDate,
    int? productId,
  }) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      where = 'saleDate BETWEEN ? AND ?';
      whereArgs.addAll([startDate, endDate]);
    } else if (startDate != null) {
      where = 'saleDate >= ?';
      whereArgs.add(startDate);
    } else if (endDate != null) {
      where = 'saleDate <= ?';
      whereArgs.add(endDate);
    }

    if (productId != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'productId = ?';
      whereArgs.add(productId);
    }

    final result = await db.rawQuery(
      'SELECT SUM(totalAmount) as total FROM sales_transactions${where.isNotEmpty ? ' WHERE $where' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ===================== Sell Product Method =====================
  
  Future<Map<String, dynamic>> sellProduct({
    required int productId,
    required int quantityToSell,
  }) async {
    final db = await database;
    
    // Start transaction
    await db.transaction((txn) async {
      // Get current product details
      final productResult = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      if (productResult.isEmpty) {
        throw Exception('Product not found');
      }
      
      final product = productResult.first;
      final currentQuantity = product['quantity'] as int;
      final unitPrice = (product['unitPrice'] as num).toDouble();
      final productName = product['productName'] as String;
      
      // Check if there's enough stock
      if (currentQuantity < quantityToSell) {
        throw Exception('Insufficient stock. Available: $currentQuantity, Requested: $quantityToSell');
      }
      
      // Calculate total amount
      final totalAmount = unitPrice * quantityToSell;
      
      // Update product quantity
      final newQuantity = currentQuantity - quantityToSell;
      await txn.update(
        'products',
        {'quantity': newQuantity},
        where: 'id = ?',
        whereArgs: [productId],
      );
      
      // Insert sales transaction
      await txn.insert('sales_transactions', {
        'productId': productId,
        'productName': productName,
        'quantity': quantityToSell,
        'unitPrice': unitPrice,
        'totalAmount': totalAmount,
        'saleDate': DateTime.now().toIso8601String(),
      });
      
      // Update or insert daily sales record
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final dayOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][today.weekday - 1];
      final month = today.month;
      final holidayFlag = today.weekday == 7 || today.weekday == 1; // Weekend as "holiday"
      
      // Check if sales record exists for today
      final existingSales = await txn.query(
        'store_sales',
        where: 'sale_date = ?',
        whereArgs: [todayStr],
      );
      
      if (existingSales.isNotEmpty) {
        // Update existing record
        final currentSales = (existingSales.first['sales'] as num).toDouble();
        await txn.update(
          'store_sales',
          {'sales': currentSales + totalAmount},
          where: 'sale_date = ?',
          whereArgs: [todayStr],
        );
      } else {
        // Insert new record
        await txn.insert('store_sales', {
          'sale_date': todayStr,
          'day_of_week': dayOfWeek,
          'month': month,
          'holiday_flag': holidayFlag ? 1 : 0,
          'sales': totalAmount,
        });
      }
    });
    
    // Return updated product info
    final updatedProduct = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    
    return updatedProduct.first;
  }

  // ===================== Debug Helper =====================
  Future<void> printDbPath() async {
    final path = join(await getDatabasesPath(), "app.db");
    print("Database is stored here: $path");
  }
}
