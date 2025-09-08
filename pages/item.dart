import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/drawer.dart';
import '../widgets/fab.dart';
import '../db.dart';

class Bar extends StatefulWidget {
  const Bar({super.key});

  @override
  State<Bar> createState() => _BarState();
}

class _BarState extends State<Bar> {
  List<Map<String, dynamic>> items = [];

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

  // ==============================
  // Build card item dengan tap hapus
  // ==============================
  Widget buildMenuItem(int id, String name, int price, String imagePath) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final navigator = Navigator.of(context);
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text("Hapus Item"),
                content: Text("Yakin ingin menghapus '$name'?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal"),
                  ),
                  TextButton(
                    onPressed: () async {
                      await DBHelper().deleteItem(id);
                      if (!mounted) return;
                      navigator.pop();
                      _loadItems();
                    },
                    child: const Text("Hapus",
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              child: Image.file(
                File(imagePath),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text("Rp $price", style: const TextStyle(color: Colors.brown)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================
  // Build GridView
  // ==============================
  Widget buildMenuGrid() {
    if (items.isEmpty) {
      return const Center(child: Text("Belum ada data"));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return buildMenuItem(
          item["id"],
          item["name"],
          item["price"],
          item["image"] ?? "",
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bar")),
      drawer: AppDrawer(),
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                Expanded(child: buildMenuGrid()),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(child: buildMenuGrid()),
              ],
            );
          }
        },
      ),
      floatingActionButton: const Fab(),
    );
  }
}
