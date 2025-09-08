import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/drawer.dart';
import '../db.dart';

class Kasir extends StatefulWidget {
  const Kasir({super.key});

  @override
  State<Kasir> createState() => _KasirState();
}

class _KasirState extends State<Kasir> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> cartItems = [];
  double total = 0.0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await DBHelper().getItems();
    setState(() {
      items = data;
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      // Cek apakah item sudah ada di keranjang
      final existingItemIndex = cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      
      if (existingItemIndex != -1) {
        // Jika sudah ada, tambah quantity
        cartItems[existingItemIndex]['quantity'] = (cartItems[existingItemIndex]['quantity'] ?? 1) + 1;
      } else {
        // Jika belum ada, tambah item baru dengan quantity 1
        cartItems.add({
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'image': item['image'],
          'quantity': 1
        });
      }
      
      // Hitung ulang total
      _calculateTotal();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (cartItems[index]['quantity'] > 1) {
        // Kurangi quantity jika lebih dari 1
        cartItems[index]['quantity'] -= 1;
      } else {
        // Hapus item jika quantity = 1
        cartItems.removeAt(index);
      }
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    total = 0.0;
    for (var item in cartItems) {
      total += (item['price'] * item['quantity']);
    }
  }

  void _checkout() {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Checkout"),
        content: Text("Total: Rp ${total.toStringAsFixed(0)}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              // Simpan transaksi ke database (bisa ditambahkan later)
              setState(() {
                cartItems.clear();
                total = 0.0;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Transaksi berhasil! Total: Rp ${total.toStringAsFixed(0)}")),
              );
            },
            child: const Text("Bayar"),
          ),
        ],
      ),
    );
  }

  Widget buildMenuItem(Map<String, dynamic> item) {
    final String imagePath = item["image"]?.toString() ?? "";
    final String name = item["name"]?.toString() ?? "Nama Kosong";
    final int price = item["price"] is int ? item["price"] : int.tryParse(item["price"]?.toString() ?? "0") ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _addToCart(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar menu
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.grey[200],
                child: imagePath.isNotEmpty && File(imagePath).existsSync()
                    ? Image.file(
                        File(imagePath),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                        },
                      )
                    : const Icon(Icons.fastfood, size: 40, color: Colors.grey),
              ),
            ),

            // Nama & harga
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                    style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCart() {
    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.brown[50],
      child: Column(
        children: [
          const ListTile(
            title: Text("Keranjang", style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.shopping_cart),
          ),
          const Divider(),
          
          if (cartItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Keranjang kosong", style: TextStyle(color: Colors.grey)),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  final itemTotal = (item['price'] * item['quantity']).toDouble();
                  
                  return ListTile(
                    title: Text(item['name']),
                    subtitle: Text("x${item['quantity']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Rp ${itemTotal.toStringAsFixed(0)}"),
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () => _removeFromCart(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          
          if (cartItems.isNotEmpty) const Divider(),
          if (cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Rp ${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: _checkout,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
              ),
              child: const Text("Checkout"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuGrid() {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("Belum ada menu", style: TextStyle(fontSize: 16)),
            Text("Tambahkan menu terlebih dahulu", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return buildMenuItem(items[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaksi"),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                Expanded(flex: 3, child: buildMenuGrid()),
                Expanded(flex: 1, child: buildCart()),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(flex: 3, child: buildMenuGrid()),
                Expanded(flex: 1, child: buildCart()),
              ],
            );
          }
        },
      ),
    );
  }
}
