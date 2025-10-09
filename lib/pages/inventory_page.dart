import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_applicationtest/pages/add_page.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
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
    if (aLow && bLow) return qtyA.compareTo(qtyB);

  
    return qtyA.compareTo(qtyB);
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

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete the selected product(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
               foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirm != true) return; 

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
    final int currentStock = product['quantity'] as int;
    final double unitPrice = (product['unitPrice'] as num).toDouble();
    final String productName = product['productName'] as String;

    // Create controllers and focus node outside StatefulBuilder
    final TextEditingController quantityController = TextEditingController(text: '1');
    final FocusNode focusNode = FocusNode();
    int selectedQuantity = 1;

    final result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( 
          builder: (context, setState) {
            double totalAmount = unitPrice * selectedQuantity;

            return AlertDialog(
              title: Text('Sell $productName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Stock: $currentStock', 
                             style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Unit Price: ₱${unitPrice.toStringAsFixed(2)}',
                             style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Quantity to Sell:', 
                       style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: selectedQuantity > 1 ? () {
                          selectedQuantity--;
                          quantityController.text = selectedQuantity.toString();
                          setState(() {});
                        } : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 32,
                        color: selectedQuantity > 1 ? Colors.red : Colors.grey,
                      ),
                      Container(
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          key: const ValueKey('quantity_field'),
                          controller: quantityController,
                          focusNode: focusNode,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            counterText: '',
                          ),
                          maxLength: 3,
                          onTap: () {
                            focusNode.requestFocus();
                          },
                          onChanged: (value) {
                            // Allow empty field for editing
                            if (value.isEmpty) {
                              selectedQuantity = 0;
                              setState(() {});
                              return;
                            }
                            
                            // Parse the input
                            final newQuantity = int.tryParse(value);
                            
                            // Handle invalid input (non-numeric or negative)
                            if (newQuantity == null || newQuantity < 0) {
                              // Don't update selectedQuantity, let user continue typing
                              return;
                            }
                            
                            // Handle valid numeric input
                            if (newQuantity >= 0 && newQuantity <= currentStock) {
                              selectedQuantity = newQuantity;
                              setState(() {});
                            } else if (newQuantity > currentStock) {
                              // Allow typing but don't update calculations
                              selectedQuantity = newQuantity;
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: selectedQuantity < currentStock ? () {
                          selectedQuantity++;
                          quantityController.text = selectedQuantity.toString();
                          setState(() {});
                        } : null,
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 32,
                        color: selectedQuantity < currentStock ? Colors.green : Colors.grey,
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
                        Text('Total Amount: ₱${totalAmount.toStringAsFixed(2)}',
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Remaining Stock: ${selectedQuantity > 0 ? currentStock - selectedQuantity : currentStock}',
                             style: TextStyle(
                               color: selectedQuantity > 0 && (currentStock - selectedQuantity) < 7 ? Colors.red : Colors.green,
                               fontWeight: FontWeight.bold,
                             )),
                        if (selectedQuantity == 0)
                          const Text('⚠️ Please enter a valid quantity',
                               style: TextStyle(color: Colors.orange, fontSize: 12)),
                        if (selectedQuantity > currentStock)
                          Text('⚠️ Cannot exceed stock limit ($currentStock)',
                               style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedQuantity >= 1 && selectedQuantity <= currentStock) {
                      Navigator.of(context).pop(selectedQuantity);
                    } else {
                      String errorMessage = '';
                      if (selectedQuantity == 0) {
                        errorMessage = 'Please enter a valid quantity';
                      } else if (selectedQuantity < 0) {
                        errorMessage = 'Negative quantities are not allowed';
                      } else if (selectedQuantity > currentStock) {
                        errorMessage = 'Cannot sell more than available stock ($currentStock)';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ $errorMessage'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Sale'),
                ),
              ],
            );
          },
        );
      },
    );

    // Clean up resources
    quantityController.dispose();
    focusNode.dispose();
    
    if (result != null && result > 0) {
      await _processSale(product, result);
    }
  }

  Future<void> _processSale(Map<String, dynamic> product, int quantityToSell) async {
    try {
      final db = DatabaseHelper();
      final productId = product['id'] as int;
      final productName = product['productName'] as String;
      final unitPrice = (product['unitPrice'] as num).toDouble();
      final totalAmount = unitPrice * quantityToSell;
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Processing sale...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Sale Successful!'),
                Text('Sold $quantityToSell $productName'),
                Text('Total: ₱${totalAmount.toStringAsFixed(2)}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ Sale Failed'),
                Text('Error: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
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

String _assetForProduct(String productName) {
  // Normalize and map common product names to asset filenames.
  // The mapping aims to match product names used in the DB to the
  // assets/images/ filenames included in the repository.
  final name = productName.toLowerCase();

  // A small mapping from keywords to file names in assets/images
  final Map<String, String> map = {
    'beef chorizo': 'Beef Chorizo.png',
    'beefies classic 1 kilo': 'Beefies Classic 1 kilo.jpg',
    'beefies classic 250g': 'Beefies Classic 250g.jpg',
    'beefies with cheese 1 kilo': 'Beefies with Cheese 1 kilo.jpg',
    'beefies with cheese 250g': 'Beefies with Cheese 250g.jpg',
    'big shot ball 500g': 'Big shot ball 500g.jpg',
    'big shot classic 1 kilo': 'Big shot classic 1 kilo.jpg',
    'big shot with cheese 1 kilo': 'Big shot with Cheese 1 kilo.jpg',
    'burger patty': 'Burger Patty.png',
    'champion chicken hotdog': 'Champion Chicken Hotdog.png',
    'chicken breast nuggets': 'Chicken Breast Nuggets.jpg',
    'chicken chorizo': 'Chicken Chorizo.png',
    'chicken ham': 'Chicken Ham.png',
    'chicken loaf': 'Chicken Loaf.jpeg',
    'chicken lumpia': 'Chicken Lumpia.png',
    'chicken roll': 'Chicken Roll.jpg',
    'chicken tocino': 'Chicken Tocino.jpg',
    'crazy cut nuggets': 'Crazy Cut Nuggets.png',
    'ganada sweet ham': 'Ganada Sweet Ham.jpg',
    'hamleg square cut': 'Hamleg Square Cut.jpg',
    'mamaabbys': 'mamaabbys.jpg',
    'mama abby': 'mama_abbys.jpg',
    'orlian': 'Orlian.png',
    'pork belly': 'Pork Belly.jpg',
    'pork chop': 'Pork Chop.jpg',
    'pork chorizo': 'Pork Chorizo.jpg',
    'pork longganisa': 'Pork Longganisa.png',
    'pork lumpia': 'Pork Lumpia.png',
    'pork pata': 'Pork Pata.jpg',
    'pork tocino': 'Pork Tocino.png',
    'siomai dimsum': 'Siomai Dimsum.png',
    'squidball holiday': 'Squidball Holiday.png',
    'squidball kimsea': 'Squidball Kimsea.jpg',
    'star nuggets': 'Star Nuggets.png',
    'tj balls 500g': 'TJ Balls 500g.png',
    'tj cheesedog (small)': 'TJ Cheesedog (Small).jpg',
    'tj cheesedog 1 kilo': 'TJ Cheesedog 1 kilo.jpg',
    'tj chicken jumbo': 'TJ Chicken Jumbo.jpg',
    'tj classic (small)': 'TJ Classic (Small).png',
    'tj classic 1 kilo': 'TJ Classic 1 kilo.jpg',
    'tj classic 250g': 'TJ Classic 250g.png',
    'tj cocktail': 'TJ Cocktail.jpg',
    'tj hotdog with cheese 250g': 'TJ Hotdog with Cheese 250g.jpg',
    'tocino roll': 'Tocino Roll.jpeg',
    'virginia chicken hotdog 250g (blue)': 'Virginia Chicken Hotdog 250g (Blue).png',
    'virginia chicken hotdog with cheese (jumbo)': 'Virginia Chicken Hotdog with Cheese (Jumbo).png',
    'virginia classic 1kilo': 'Virginia Classic 1kilo.png',
    'virginia classic 500g': 'Virginia Classic 500g.png',
    'virginia with cheese 1 kilo': 'Virginia with cheese 1 kilo.jpg',
    'viriginia-classic-250g': 'Viriginia-Classic-250g.png',
  };

  // Try to find exact key first
  for (final key in map.keys) {
    if (name.contains(key)) return 'assets/images/${map[key]}';
  }

  // As a fallback try to match by simpler tokens
  if (name.contains('virginia')) return 'assets/images/mamaabbys.jpg';
  if (name.contains('beefies')) return 'assets/images/Beefies Classic 1 kilo.jpg';
  if (name.contains('tj')) return 'assets/images/TJ Classic 1 kilo.jpg';
  if (name.contains('pork')) return 'assets/images/Pork Chop.jpg';
  if (name.contains('chicken')) return 'assets/images/Chicken Roll.jpg';

  // Final default
  return 'assets/images/mamaabbys.jpg';
}

void _viewImage(String imagePath, {bool isAsset = false}) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: isAsset
                    ? Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                      )
                    : Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 30,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    },
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
    body: SafeArea( // ✅ Prevents overlap with status bar
      child: Column(
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
          Expanded(
            child: SingleChildScrollView( 
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
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
                                MaterialPageRoute(
                                    builder: (_) => const AddPage()),
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
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: products.isEmpty
                          ? const Center(child: Text("No products found."))
                          : ListView.builder(
                              physics:
                                  const NeverScrollableScrollPhysics(), 
                              shrinkWrap: true, 
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                final qty = product['quantity'] as int;
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                  color: qty < 7
                                      ? Colors.red.shade100
                                      : Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        if (isSelectionMode)
                                          Checkbox(
                                            value:
                                                selectedProducts.contains(index),
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedProducts.add(index);
                                                } else {
                                                  selectedProducts
                                                      .remove(index);
                                                }
                                              });
                                            },
                                          ),
                                        Builder(builder: (_) {
                                          final String? imagePath =
                                              product['imagePath'] as String?;
                                          final bool hasFileImage = imagePath !=
                                                  null &&
                                              imagePath.isNotEmpty &&
                                              File(imagePath).existsSync();

                                          if (hasFileImage) {
                                            return GestureDetector(
                                              onTap: () => _viewImage(imagePath),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.file(
                                                  File(imagePath),
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      width: 60,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .grey.shade300,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                            color: Colors
                                                                .grey.shade500),
                                                      ),
                                                      child: const Center(
                                                        child: Icon(Icons.image,
                                                            color:
                                                                Colors.grey),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          }

                                          // No file image - try to use asset based on product name
                                          final assetPath = _assetForProduct(
                                              product['productName'].toString());

                                          return GestureDetector(
                                            onTap: () => _viewImage(assetPath,
                                                isAsset: true),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.asset(
                                                assetPath,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (context, error, stackTrace) {
                                                  return Container(
                                                    width: 60,
                                                    height: 60,
                                                    decoration: BoxDecoration(
                                                      color: Colors
                                                          .grey.shade300,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(8),
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade500),
                                                    ),
                                                    child: const Center(
                                                      child: Icon(Icons.image,
                                                          color: Colors.grey),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        }),
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
                                                style: const TextStyle(
                                                    fontSize: 14),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
 }
}
