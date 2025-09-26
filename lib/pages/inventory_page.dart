import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/add_page.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/sales_page.dart';
import 'package:flutter_applicationtest/pages/delivery_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'package:flutter_applicationtest/database_helper.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String selectedCategory = 'All';
  bool isSelectionMode = false;
  final Set<int> selectedProducts = {};

  final List<String> categories = [
    'All',
    'Pork',
    'Virginia Products',
    'Purefoods',
    'Big Shot Products',
    'Chicken',
    'Beefies Products',
    'Others',
  ];

  List<Map<String, dynamic>> allProducts = []; // master list
  List<Map<String, dynamic>> products = []; // filtered/display list

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final db = DatabaseHelper();
    final data = await db.fetchProducts();
    setState(() {
      allProducts = data;
      products = List.from(allProducts); // display copy
    });
  }

  Future<void> _deleteSelected() async {
    if (selectedProducts.isEmpty) return;

    final db = DatabaseHelper();

    // Collect IDs to delete
    List<int> idsToDelete = selectedProducts
        .map((i) => products[i]['id'] as int)
        .toList();

    for (var id in idsToDelete) {
      await db.deleteProduct(id);
    }

    // Reload products after deletion
    await _loadProducts();

    setState(() {
      selectedProducts.clear();
      isSelectionMode = false;
    });
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 6),
            isActive
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: color, width: 2),
                      ),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _filterProducts(String value) {
    setState(() {
      products = allProducts.where((p) {
        final nameMatch = p['productName']
            .toString()
            .toLowerCase()
            .contains(value.toLowerCase());
        final categoryMatch = selectedCategory == 'All' ||
            p['category'].toString() == selectedCategory;
        return nameMatch && categoryMatch;
      }).toList();
    });
  }

  void _filterByCategory(String? category) {
    if (category == null) return;
    setState(() {
      selectedCategory = category;
      products = allProducts.where((p) {
        return selectedCategory == 'All' ||
            p['category'].toString() == selectedCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
          // ===== Header =====
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: 12,
            ),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Image.asset("assets/images/mamaabbys.jpg", height: 60),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "INVENTORY",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Manage Inventory",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      color: Colors.blue,
                      iconSize: 24,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationPage(),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: const Icon(Icons.settings),
                        color: Colors.blue,
                        iconSize: 24,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== Search Box =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterProducts,
            ),
          ),

          const SizedBox(height: 16),

          // ===== Category Filter =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "All Categories",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: selectedCategory,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: _filterByCategory,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ===== Buttons Row =====
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    children: [
      ElevatedButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPage()),
          );
          _loadProducts(); // refresh after coming back
        },
        child: const Text("Add"),
      ),
      const Spacer(),
      ElevatedButton(
        onPressed: () {
          setState(() {
            isSelectionMode = !isSelectionMode;
            selectedProducts.clear();
          });
        },
        child: Text(isSelectionMode ? "Cancel" : "Select"),
      ),
      const SizedBox(width: 8),
      if (isSelectionMode && selectedProducts.isNotEmpty)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: _deleteSelected,
          child: const Text("Delete"),
        ),
    ],
  ),
),

// Removed SizedBox(height: 8) here

// ===== Products List =====
Expanded(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: products.isEmpty
        ? const Center(child: Text("No products found."))
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8), // tighter top padding
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4), // tighter spacing
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (isSelectionMode)
                        Checkbox(
                          value: selectedProducts.contains(index),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedProducts.add(index);
                              } else {
                                selectedProducts.remove(index);
                              }
                            });
                          },
                        ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade500),
                        ),
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['productName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4), // slightly smaller spacing
                            Text(
                              "Stock: ${product['quantity']} | Price: ₱${product['unitPrice']}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          print("Sell ${product['productName']}");
                        },
                        child: const Text("Sell"),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  ),
),


          // ===== Bottom Navigation =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  icon: Icons.inventory,
                  label: "Inventory",
                  isActive: true,
                  color: Colors.blue,
                  onTap: () {},
                ),
                _buildNavItem(
                  icon: Icons.bar_chart,
                  label: "Sales",
                  isActive: false,
                  color: Colors.green,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SalesPage()),
                    );
                  },
                ),
                _buildNavItem(
                  icon: Icons.local_shipping,
                  label: "Delivery",
                  isActive: false,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DeliveryPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
