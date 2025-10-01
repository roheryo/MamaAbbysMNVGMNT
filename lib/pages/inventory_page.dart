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
  bool hasUnread = false;

  final List<String> categories = [
    'All',
    'Pork',
    'Virginia Products',
    'Purefoods Products',
    'Big Shot Products',
    'Chicken',
    'Beefies Products',
    'Siomai',
    'Nuggets',
    'Squidballs',
    'Tj Products',
    'Beef',
    'Champion Products',
    'Tocino',
    'Longganisa',
    'Others',
  ];

  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _refreshUnread();
  }

  void _sortProducts(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final qtyA = a['quantity'] as int;
      final qtyB = b['quantity'] as int;
      final aLow = qtyA < 7;
      final bLow = qtyB < 7;

      if (aLow && !bLow) return -1;
      if (!aLow && bLow) return 1;
      return 0;
    });
  }

  Future<void> _loadProducts() async {
    final db = DatabaseHelper();
    await db.checkLowStockProducts();
    final data = await db.fetchProducts();

    setState(() {
      allProducts = data;
      products = List.from(allProducts);
      _sortProducts(products);
    });

    final unread = await db.fetchNotifications(onlyUnread: true);
    if (unread.isNotEmpty && mounted) {
      final latest = unread.first;
      final message = latest['message']?.toString() ?? 'New notification';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              ).then((_) => _refreshUnread());
            },
          ),
        ),
      );
      final id = latest['id'];
      if (id is int) {
        await db.markNotificationsReadByIds([id]);
      }
      await _refreshUnread();
    }
  }

  Future<void> _refreshUnread() async {
    final db = DatabaseHelper();
    final v = await db.hasUnreadNotifications();
    if (!mounted) return;
    setState(() => hasUnread = v);
  }

  Future<void> _deleteSelected() async {
    if (selectedProducts.isEmpty) return;

    final db = DatabaseHelper();
    List<int> idsToDelete =
        selectedProducts.map((i) => products[i]['id'] as int).toList();

    for (var id in idsToDelete) {
      await db.deleteProduct(id);
    }

    await _loadProducts();

    setState(() {
      selectedProducts.clear();
      isSelectionMode = false;
    });
  }

  Future<void> _showSellModal(Map<String, dynamic> product) async {
    final TextEditingController quantityController = TextEditingController();
    final int currentStock = product['quantity'] as int;
    final double unitPrice = (product['unitPrice'] as num).toDouble();
    final String productName = product['productName'] as String;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int quantity = 1;
            double totalAmount = unitPrice;

            void updateQuantity(int newQuantity) {
              if (newQuantity >= 1 && newQuantity <= currentStock) {
                setModalState(() {
                  quantity = newQuantity;
                  totalAmount = unitPrice * quantity;
                });
                quantityController.text = quantity.toString();
              }
            }

            return AlertDialog(
              title: Text('Sell $productName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Stock: $currentStock'),
                  Text('Unit Price: ₱${unitPrice.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Quantity: '),
                      IconButton(
                        onPressed: () => updateQuantity(quantity - 1),
                        icon: const Icon(Icons.remove),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (value) {
                            final newQuantity = int.tryParse(value) ?? 1;
                            if (newQuantity >= 1 && newQuantity <= currentStock) {
                              setModalState(() {
                                quantity = newQuantity;
                                totalAmount = unitPrice * quantity;
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () => updateQuantity(quantity + 1),
                        icon: const Icon(Icons.add),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Amount: ₱${totalAmount.toStringAsFixed(2)}'),
                        Text('Remaining Stock: ${currentStock - quantity}'),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirm Sale'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final quantityToSell = int.tryParse(quantityController.text) ?? 1;
      await _processSale(product, quantityToSell);
    }
  }

  Future<void> _processSale(Map<String, dynamic> product, int quantityToSell) async {
    try {
      final db = DatabaseHelper();
      final productId = product['id'] as int;
      
      // Process the sale
      await db.sellProduct(
        productId: productId,
        quantityToSell: quantityToSell,
      );
      
      // Refresh the products list
      await _loadProducts();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully sold $quantityToSell ${product['productName']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      _sortProducts(products);
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
      _sortProducts(products);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
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
                    Stack(
                      clipBehavior: Clip.none,
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
                            ).then((_) => _refreshUnread());
                          },
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
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
                    _loadProducts();
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
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _deleteSelected,
                    child: const Text("Delete"),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: products.isEmpty
                  ? const Center(child: Text("No products found."))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final qty = product['quantity'] as int;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                          color: qty < 7 ? Colors.red.shade100 : Colors.white,
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
                                    border:
                                        Border.all(color: Colors.grey.shade500),
                                  ),
                                  child: const Center(
                                    child:
                                        Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['productName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
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
                                    _showSellModal(product);
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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
