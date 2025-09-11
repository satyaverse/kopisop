import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => isLoading = true);
    transactions = await DBHelper().getTransactionsWithItems();
    setState(() => isLoading = false);
  }

  Future<void> _deleteTransaction(int id) async {
    await DBHelper().deleteTransaction(id);
    await _loadTransactions();
    if (mounted) Navigator.pop(context); // tutup dialog detail
  }

  String _formatCurrency(int amount) {
    return "Rp ${amount.toString()}";
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada transaksi',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTransactions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final trx = transactions[index];
                      final items = trx['items'] as List<Map<String, dynamic>>;
                      final status = trx['status'] ?? 'lunas';
                      final dibayar = trx['dibayar'] ?? 0;
                      final total = trx['total'] ?? 0;
                      final sisa = total - dibayar;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text("Detail Transaksi"),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatDate(trx['date']),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Pemesan: ${trx['buyer_name'] ?? '-'}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
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
                                          const Text(
                                            "Lunas",
                                            style: TextStyle(color: Colors.green),
                                          )
                                        else
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Belum Lunas",
                                                style: TextStyle(color: Colors.red),
                                              ),
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
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
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
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text("Hapus Transaksi"),
                                            content: const Text(
                                                "Apakah Anda yakin ingin menghapus transaksi ini?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text("Batal"),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text(
                                                  "Hapus",
                                                  style:
                                                      TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await _deleteTransaction(trx['id']);
                                        }
                                      },
                                      child: const Text(
                                        "Hapus",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: ListTile(
                            leading: const Icon(Icons.receipt, color: Colors.brown),
                            title: Text(
                              trx['buyer_name'] ?? 'Tanpa Nama',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatDate(trx['date'])),
                                Text(
                                    "${items.length} item • ${_formatCurrency(total)}"),
                                Text("Dibayar: ${_formatCurrency(dibayar)}"),
                                if (status == "lunas")
                                  const Text("Status: Lunas",
                                      style: TextStyle(color: Colors.green))
                                else
                                  Text("Status: Belum Lunas",
                                      style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
