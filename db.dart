import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  initDB() async {
    String path = join(await getDatabasesPath(), "cafe.db");
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // tabel produk/menu
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price INTEGER,
            image TEXT
          )
        ''');

        // tabel transaksi utama
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total INTEGER
          )
        ''');

        // detail transaksi
        await db.execute('''
          CREATE TABLE transaction_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER,
            item_id INTEGER,
            qty INTEGER,
            price INTEGER
          )
        ''');
      },
    );
  }

  // =======================
  // ITEMS
  // =======================
  Future<int> insertItem(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert("items", data);
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    return await db.query("items");
  }

  Future<int> deleteItem(int id) async {
  final db = await database;
  return await db.delete("items", where: "id = ?", whereArgs: [id]);
}


  // =======================
  // TRANSACTIONS
  // =======================
  Future<int> insertTransaction(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert("transactions", data);
  }

  Future<int> insertTransactionItem(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert("transaction_items", data);
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return await db.query("transactions");
  }


  Future<int> clearItems() async {
  final db = await database;
  return await db.delete('items');
}
}
