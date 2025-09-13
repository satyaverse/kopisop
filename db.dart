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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price INTEGER,
            image TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total INTEGER,
            buyer_name TEXT,
            status TEXT,
            dibayar INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE transaction_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER,
            item_id INTEGER,
            qty INTEGER,
            price INTEGER,
            FOREIGN KEY (transaction_id) REFERENCES transactions (id),
            FOREIGN KEY (item_id) REFERENCES items (id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE transactions ADD COLUMN buyer_name TEXT");
        }
        if (oldVersion < 3) {
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT 'lunas'");
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN dibayar INTEGER DEFAULT 0");
        }
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

  Future<int> updateItem(Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      "items",
      data,
      where: "id = ?",
      whereArgs: [data["id"]],
    );
  }

  Future<int> clearItems() async {
    final db = await database;
    return await db.delete('items');
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
    return await db.query("transactions", orderBy: "date DESC");
  }

  Future<List<Map<String, dynamic>>> getTransactionsWithItems() async {
    final db = await database;
    final transactions = await db.query("transactions", orderBy: "date DESC");

    final result = <Map<String, dynamic>>[];

    for (var transaction in transactions) {
      final items = await db.rawQuery('''
        SELECT ti.*, i.name 
        FROM transaction_items ti 
        LEFT JOIN items i ON ti.item_id = i.id 
        WHERE ti.transaction_id = ?
      ''', [transaction['id']]);

      result.add({
        'id': transaction['id'],
        'date': transaction['date'],
        'total': transaction['total'],
        'buyer_name': transaction['buyer_name'],
        'status': transaction['status'],
        'dibayar': transaction['dibayar'],
        'items': items,
      });
    }

    return result;
  }

  Future<int> saveCompleteTransaction(
    List<Map<String, dynamic>> cartItems,
    int total, {
    required String buyerName,
    required String status,
    required int dibayar,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      return await db.transaction<int>((txn) async {
        final transactionId = await txn.insert(
          'transactions',
          {
            'date': now,
            'total': total,
            'buyer_name': buyerName,
            'status': status,
            'dibayar': dibayar,
          },
        );

        for (var item in cartItems) {
          await txn.insert(
            'transaction_items',
            {
              'transaction_id': transactionId,
              'item_id': item['id'],
              'qty': item['quantity'],
              'price': item['price'],
            },
          );
        }

        return transactionId;
      });
    } catch (e) {
      throw Exception('Error saving transaction: $e');
    }
  }

  // =======================
  // DELETE TRANSACTION
  // =======================
  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Hapus item transaksi dulu
      await txn.delete("transaction_items",
          where: "transaction_id = ?", whereArgs: [id]);

      // Baru hapus transaksi utama
      await txn.delete("transactions", where: "id = ?", whereArgs: [id]);
    });
  }
}
