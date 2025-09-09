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
  List<Map<String, dynamic>> filteredItems = [];
  List<Map<String, dynamic>> cartItems = [];
  double total = 0.0;
  String searchQuery = "";

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();

    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final data = await DBHelper().getItems();
    setState(() {
      items = data;
      filteredItems = data;
    });
  }

  void _filterItems(String query) {
    List<Map<String, dynamic>> results = [];
    if (query.isEmpty) {
      results = items;
    } else {
      results = items.where((item) {
        final nameLower = item['name'].toString().toLowerCase();
        return nameLower.contains(query.toLowerCase());
      }).toList();
    }
    setState(() {
      filteredItems = results;
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      final existingItemIndex =
          cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);

      if (existingItemIndex != -1) {
        cartItems[existingItemIndex]['quantity'] =
            (cartItems[existingItemIndex]['quantity'] ?? 1) + 1;
      } else {
        cartItems.add({
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'image': item['image'],
          'quantity': 1
        });
      }

      _calculateTotal();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (cartItems[index]['quantity'] > 1) {
        cartItems[index]['quantity'] -= 1;
      } else {
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
              setState(() {
                cartItems.clear();
                total = 0.0;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Transaksi berhasil!")),
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
    final int price = item["price"] is int
        ? item["price"]
        : int.tryParse(item["price"]?.toString() ?? "0") ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _addToCart(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey[200],
                child: imagePath.isNotEmpty && File(imagePath).existsSync()
                    ? Image.file(
                        File(imagePath),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.fastfood, size: 40, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                    style: const TextStyle(
                        color: Colors.brown, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔧 buildCart: sekarang aman dipanggil di dalam Expanded (landscape)
  /// maupun di dalam ListView (portrait, draggable sheet).
  Widget buildCart({bool isInScrollable = false}) {
    Widget listContent;
    if (cartItems.isEmpty) {
      listContent = const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Keranjang kosong",
            style: TextStyle(color: Colors.grey)),
      );
    } else {
      final listView = ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: isInScrollable, // true kalau dipakai dalam scroll parent
        physics: isInScrollable
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: cartItems.length,
        itemBuilder: (context, index) {
          final item = cartItems[index];
          final itemTotal =
              (item['price'] * item['quantity']).toDouble();
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
      );

      // landscape → pakai Expanded
      // portrait → biarkan biasa (karena parent sudah scrollable)
      listContent = isInScrollable ? listView : Expanded(child: listView);
    }

    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.brown[50],
      child: Column(
        children: [
          const ListTile(
            title: Text("Keranjang",
                style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.shopping_cart),
          ),
          const Divider(),
          listContent,
          if (cartItems.isNotEmpty) const Divider(),
          if (cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Rp ${total.toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
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
    if (filteredItems.isEmpty) {
      return const Center(
        child: Text("Belum ada menu"),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        return buildMenuItem(filteredItems[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuArea = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Cari menu...",
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.clear,
                  color: searchQuery.isNotEmpty ? Colors.red : Colors.grey,
                ),
                onPressed: searchQuery.isNotEmpty
                    ? () {
                        _searchController.clear();
                        _filterItems("");
                      }
                    : null,
              ),
            ),
            onChanged: _filterItems,
          ),
        ),
        Expanded(child: buildMenuGrid()),
      ],
    );

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
                Expanded(flex: 3, child: menuArea),
                Expanded(flex: 1, child: buildCart()), // ⬅️ landscape
              ],
            );
          } else {
            return Stack(
              children: [
                Positioned.fill(child: menuArea),
                DraggableScrollableSheet(
                  initialChildSize: 0.25,
                  minChildSize: 0.1,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              children: [
                                buildCart(isInScrollable: true), // ⬅️ portrait
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
