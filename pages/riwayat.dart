import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../widgets/drawer.dart';

class Riwayat extends StatefulWidget {
  const Riwayat({super.key});

  @override
  State<Riwayat> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<Riwayat> {
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> filteredTransactions = [];
  bool isLoading = true;
  String searchQuery = "";
  String filterType = "nama"; // default filter

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => isLoading = true);
    final data = await DBHelper().getTransactionsWithItems();
    setState(() {
      transactions = data;
      _applyOrderNumber(); // 🔹 beri nomor urut
      _applyFilter();
      isLoading = false;
    });
  }

  /// Hitung nomor pesanan per hari (reset setiap jam 00:00)
  void _applyOrderNumber() {
    Map<String, int> dailyCounter = {};

    // Urutkan ASC (lama -> baru) agar nomor #1 selalu pesanan terlama
    transactions.sort((a, b) {
      final dateA = DateTime.tryParse(a['date']) ?? DateTime.now();
      final dateB = DateTime.tryParse(b['date']) ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    for (var trx in transactions) {
      final date = DateTime.tryParse(trx['date']);
      if (date == null) continue;

      final key = "${date.year}-${date.month}-${date.day}";

      dailyCounter[key] = (dailyCounter[key] ?? 0) + 1;
      trx['order_number'] = dailyCounter[key];
    }

    // Balik lagi ke DESC supaya transaksi terbaru tampil di atas
    transactions = transactions.reversed.toList();
  }

  void _applyFilter() {
    setState(() {
      List<Map<String, dynamic>> result = [];

      if (filterType == "nama") {
        result = transactions.where((trx) {
          final buyer = (trx['buyer_name'] ?? '').toString().toLowerCase();
          return buyer.contains(searchQuery.toLowerCase());
        }).toList();
      } else if (filterType == "tanggal") {
        result = transactions.where((trx) {
          final date = (trx['date'] ?? '').toString().toLowerCase();
          return date.contains(searchQuery.toLowerCase());
        }).toList();
      } else if (filterType == "lunas") {
        result = transactions.where((trx) => trx['status'] == "lunas").toList();
      } else if (filterType == "belum") {
        result = transactions.where((trx) => trx['status'] != "lunas").toList();
      } else {
        result = transactions;
      }

      if ((filterType == "lunas" || filterType == "belum") &&
          searchQuery.isNotEmpty) {
        result = result.where((trx) {
          final buyer = (trx['buyer_name'] ?? '').toString().toLowerCase();
          return buyer.contains(searchQuery.toLowerCase());
        }).toList();
      }

      filteredTransactions = result;
    });
  }

  Future<void> _deleteTransaction(int id) async {
    await DBHelper().deleteTransaction(id);
    await _loadTransactions();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _updatePayment(Map<String, dynamic> trx) async {
    final total = trx['total'] ?? 0;
    final dibayar = trx['dibayar'] ?? 0;
    final sisa = total - dibayar;

    final controller = TextEditingController();

    final tambahan = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pembayaran"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Total: ${_formatCurrency(total)}"),
            Text("Dibayar: ${_formatCurrency(dibayar)}"),
            Text("Sisa: ${_formatCurrency(sisa)}"),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Jumlah Tambahan Bayar",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              if (val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Masukkan jumlah yang valid")),
                );
                return;
              }
              if (val > sisa) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Jumlah tidak boleh melebihi sisa")),
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );

    if (tambahan != null && tambahan > 0) {
      final newDibayar = dibayar + tambahan;
      final newStatus = newDibayar >= total ? "lunas" : "belum";

      final db = await DBHelper().database;
      await db.update(
        "transactions",
        {
          "dibayar": newDibayar,
          "status": newStatus,
        },
        where: "id = ?",
        whereArgs: [trx['id']],
      );

      await _loadTransactions();
      if (mounted) Navigator.pop(context);
    }
  }

  String _formatCurrency(int amount) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  String _formatDate(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return "${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: filterType,
                  items: const [
                    DropdownMenuItem(value: "nama", child: Text("Nama")),
                    DropdownMenuItem(value: "tanggal", child: Text("Tanggal")),
                    DropdownMenuItem(value: "lunas", child: Text("Lunas")),
                    DropdownMenuItem(value: "belum", child: Text("Belum Lunas")),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      filterType = val;
                      searchQuery = "";
                      _applyFilter();
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: filterType == "nama"
                          ? "Cari nama pembeli..."
                          : filterType == "tanggal"
                              ? "Cari tanggal (YYYY-MM-DD)..."
                              : "Filter status aktif",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    enabled: filterType == "nama" ||
                        filterType == "tanggal" ||
                        filterType == "lunas" ||
                        filterType == "belum",
                    onChanged: (val) {
                      searchQuery = val;
                      _applyFilter();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTransactions.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada transaksi ditemukan',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final trx = filteredTransactions[index];
                            final items = trx['items'] as List<Map<String, dynamic>>;
                            final status = trx['status'] ?? 'lunas';
                            final dibayar = trx['dibayar'] ?? 0;
                            final total = trx['total'] ?? 0;
                            final sisa = total - dibayar;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.receipt, color: Colors.brown),
                                title: Text(
                                  "#${trx['order_number'] ?? '-'} ${trx['buyer_name'] ?? 'Tanpa Nama'}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_formatDate(trx['date'])),
                                    Text("${items.length} item • ${_formatCurrency(total)}"),
                                    if (status != "lunas") ...[
                                      Text("Dibayar: ${_formatCurrency(dibayar)}"),
                                      Text("Sisa: ${_formatCurrency(sisa)}",
                                          style: const TextStyle(color: Colors.orange)),
                                      const Text("Status: Belum Lunas",
                                          style: TextStyle(color: Colors.red)),
                                    ] else
                                      const Text("Status: Lunas",
                                          style: TextStyle(color: Colors.green)),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Center(
    child: Text(
      "#${trx['order_number'] ?? '-'}",
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
  ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDate(trx['date']),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Pemesan: ${trx['buyer_name'] ?? '-'}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Row(
                                              children: [
                                                const Text("Total: ",
                                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                                Text(
                                                  _formatCurrency(total),
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.brown),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (status == "lunas")
                                              const Text("Lunas",
                                                  style: TextStyle(color: Colors.green))
                                            else
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Belum Lunas",
                                                      style: TextStyle(color: Colors.red)),
                                                  Text("Dibayar: ${_formatCurrency(dibayar)}"),
                                                  Text("Sisa: ${_formatCurrency(sisa)}"),
                                                ],
                                              ),
                                            const Divider(),
                                            ...items.map((item) {
                                              final itemTotal =
                                                  (item['price'] as int) * (item['qty'] as int);
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text("${item['name']} (${item['qty']})"),
                                                    Text(_formatCurrency(itemTotal)),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Tutup"),
                                        ),
                                        TextButton(
                                          onPressed: () => _updatePayment(trx),
                                          child: const Text("Edit",
                                              style: TextStyle(color: Colors.blue)),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("Hapus Transaksi"),
                                                content: const Text(
                                                    "Apakah Anda yakin ingin menghapus transaksi ini?"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text("Batal"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text("Hapus",
                                                        style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              await _deleteTransaction(trx['id']);
                                            }
                                          },
                                          child: const Text("Hapus",
                                              style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
