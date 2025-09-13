import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/drawer.dart';
import '../db.dart';
import '../pages/addbarang.dart';

class ItemPage extends StatefulWidget {
  const ItemPage({super.key});

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filteredItems = [];
  String searchQuery = "";

  //  Controller untuk search
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

  void filterItems(String query) {
    List<Map<String, dynamic>> results = [];
    if (query.isEmpty) {
      results = items;
    } else {
      results = items.where((item) {
        final nameLower = item['name'].toString().toLowerCase();
        final queryLower = query.toLowerCase();
        return nameLower.contains(queryLower);
      }).toList();
    }

    setState(() {
      filteredItems = results;
    });
  }

  Widget buildMenuItem(int id, String name, int price, String? imagePath) {
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
                title: Text(' $name'),
                //content: Text("Apa yang ingin dilakukan pada '$name'?"),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Yakin Hapus ?"),
                            //content: const Text("Yakin ingin Hapus?"),
                            actions: [  
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "Hapus",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Batal"),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm == true) {
                        await DBHelper().deleteItem(id);
                        if (!mounted) return;
                        navigator.pop(); // tutup dialog utama
                        _loadItems();
                      }
                    },
                    child: const Text(
                      "Hapus",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                  TextButton(
                    onPressed: () async {
                      navigator.pop(); // tutup dialog
                      // Navigasi ke halaman edit, misalnya pakai AddBarangPage dengan parameter
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddBarangPage(
                            // Kirim data item untuk di-edit
                            existingItem: {
                              "id": id,
                              "name": name,
                              "price": price,
                              "image": imagePath,
                            },
                          ),
                        ),
                      );
                      _loadItems(); // refresh setelah kembali
                    },
                    child: const Text(
                      "Edit",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Tutup"),
                    
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
              child: (imagePath != null &&
                      imagePath.isNotEmpty &&
                      File(imagePath).existsSync())
                  ? Image.file(
                      File(imagePath),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
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

  Widget buildMenuGrid() {
    if (filteredItems.isEmpty) {
      return const Center(child: Text("Belum ada data"));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return buildMenuItem(
          item["id"],
          item["name"],
          item["price"] ?? 0,
          item["image"],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Produk")),
      drawer: const AppDrawer(),
      body: OrientationBuilder(
        builder: (context, orientation) {
          Widget content = Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Tombol plus di sebelah kiri
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.brown,
                        size: 32,
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddBarangPage()),
                        );
                        _loadItems();
                      },
                    ),
                    // Expanded TextField dengan tombol X
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Cari produk...",
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: searchQuery.isNotEmpty
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            onPressed: searchQuery.isNotEmpty
                                ? () {
                                    _searchController.clear();
                                    filterItems("");
                                  }
                                : null,
                          ),
                        ),
                        onChanged: filterItems,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: buildMenuGrid()),
            ],
          );

          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                Expanded(child: content),
              ],
            );
          } else {
            return content;
          }
        },
      ),
    );
  }
}
