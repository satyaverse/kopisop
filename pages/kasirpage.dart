import 'package:flutter/material.dart';
import '../widgets/drawer.dart';


class Kasir extends StatelessWidget {
  const Kasir({super.key});

  // Daftar menu (dummy data)
  final List<Map<String, dynamic>> menuList = const [
    {"name": "Kopi Hitam", "price": 20000, "image": "https://picsum.photos/200?1"},
    {"name": "Cappuccino", "price": 30000, "image": "https://picsum.photos/200?2"},
    {"name": "Latte", "price": 25000, "image": "https://picsum.photos/200?3"},
    {"name": "Espresso", "price": 18000, "image": "https://picsum.photos/200?4"},
    {"name": "Mocha", "price": 28000, "image": "https://picsum.photos/200?5"},
    {"name": "Macchiato", "price": 27000, "image": "https://picsum.photos/200?6"},
    {"name": "Americano", "price": 22000, "image": "https://picsum.photos/200?7"},
    {"name": "Flat White", "price": 26000, "image": "https://picsum.photos/200?8"},
    {"name": "Affogato", "price": 32000, "image": "https://picsum.photos/200?9"},
  ];

  Widget buildMenuItem(String name, double price, String imageUrl) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar menu
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Image.network(
              imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Nama & harga
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text("Rp ${price.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.brown)),
              ],
            ),
          ),
          // Tombol tambah
          //Align(
          //  alignment: Alignment.centerRight,
            //child: IconButton(
              //icon: const Icon(Icons.add_shopping_cart, color: Colors.brown),
              //onPressed: () {},
            //),
          //)
        ],
      ),
    );
  }

  Widget buildCart() {
    return Card(
      color: Colors.brown[50],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const ListTile(
            title: Text("Keranjang"),
            trailing: Icon(Icons.shopping_cart),
          ),
          const Divider(),
          const ListTile(
            title: Text("Kopi Hitam"),
            subtitle: Text("x1"),
            trailing: Text("Rp 20.000"),
          ),
          const ListTile(
            title: Text("Green Tea"),
            subtitle: Text("x1"),
            trailing: Text("Rp 20.000"),
          ),
          const ListTile(
            title: Text("Cappuccino"),
            subtitle: Text("x2"),
            trailing: Text("Rp 60.000"),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text("Checkout"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200, // 👉 max lebar 1 card
        childAspectRatio: 0.7,   // tinggi/lebar card
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: menuList.length,
      itemBuilder: (context, index) {
        final item = menuList[index];
        return buildMenuItem(
          item["name"],
          item["price"].toDouble(),
          item["image"],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transaksi")),
      drawer: AppDrawer(),
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            // Landscape → menu grid di kiri, keranjang di kanan
            return Row(
              children: [
                Expanded(flex: 2, child: buildMenuGrid()),
                Expanded(flex: 1, child: buildCart()),
              ],
            );
          } else {
            // Portrait → menu grid di atas, keranjang di bawah
            return Column(
              children: [
                Expanded(flex: 2, child: buildMenuGrid()),
                Expanded(flex: 1, child: buildCart()),
              ],
            );
          }
        },
      ),
    );
  }
}
