import 'dart:async';
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
  bool isLoading = true;
  bool isLoadingMore = false;
  String searchQuery = "";
  String filterType = "nama"; // default filter
  Timer? _debounce;
  int _page = 0;
  final int _limit = 50;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTransactions(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isBusy) {
        _loadTransactions();
      }
    });
  }

  bool get _isBusy => isLoading || isLoadingMore;

  Future<void> _loadTransactions({bool reset = false}) async {
    if (_isBusy) return;

    if (reset) {
      setState(() {
        isLoading = true;
        _page = 0;
        _hasMore = true;
        transactions.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() => isLoadingMore = true);
    }

    List<Map<String, dynamic>> data = [];

    final offset = _page * _limit;

    if (filterType == "nama") {
      data = await DBHelper().searchTransactions(
        nama: searchQuery,
        limit: _limit,
        offset: offset,
      );
    } else if (filterType == "tanggal") {
      data = await DBHelper().searchTransactions(
        tanggal: searchQuery,
        limit: _limit,
        offset: offset,
      );
    } else if (filterType == "lunas") {
      data = await DBHelper().searchTransactions(
        status: "lunas",
        nama: searchQuery,
        limit: _limit,
        offset: offset,
      );
    } else if (filterType == "belum") {
      data = await DBHelper().searchTransactions(
        status: "belum",
        nama: searchQuery,
        limit: _limit,
        offset: offset,
      );
    } else {
      data = await DBHelper().searchTransactions(limit: _limit, offset: offset);
    }

    setState(() {
      _applyOrderNumberBatch(data);
      transactions.addAll(data);
      _hasMore = data.length == _limit;
      _page++;
      isLoading = false;
      isLoadingMore = false;
    });
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      searchQuery = val;
      _loadTransactions(reset: true);
    });
  }

  void _applyOrderNumberBatch(List<Map<String, dynamic>> batch) {
    Map<String, int> dailyCounter = {};

    for (var trx in transactions) {
      final date = DateTime.tryParse(trx['date']);
      if (date == null) continue;
      final key = "${date.year}-${date.month}-${date.day}";
      dailyCounter[key] = (dailyCounter[key] ?? 0) + 1;
      trx['order_number'] = dailyCounter[key];
    }

    for (var trx in batch) {
      final date = DateTime.tryParse(trx['date']);
      if (date == null) continue;
      final key = "${date.year}-${date.month}-${date.day}";
      dailyCounter[key] = (dailyCounter[key] ?? 0) + 1;
      trx['order_number'] = dailyCounter[key];
    }
  }

  Future<void> _deleteTransaction(int id) async {
    await DBHelper().deleteTransaction(id);
    _loadTransactions(reset: true);
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
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
        {"dibayar": newDibayar, "status": newStatus},
        where: "id = ?",
        whereArgs: [trx['id']],
      );

      _loadTransactions(reset: true);
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
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
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
                    });
                    _loadTransactions(reset: true);
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
                    onChanged: _onSearchChanged,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : transactions.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada transaksi ditemukan',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadTransactions(reset: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: transactions.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= transactions.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final trx = transactions[index];
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
