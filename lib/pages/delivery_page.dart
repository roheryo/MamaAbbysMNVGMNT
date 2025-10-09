// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import '../database_helper.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  String? _selectedStatus;
  List<Map<String, dynamic>> deliveries = [];
  DateTime? selectedDateTime;
  bool isSelectionMode = false;
  Set<int> selectedDeliveries = {};
  bool hasUnread = false;

  List<String> categories = [];
  List<Map<String, dynamic>> allProducts = [];

      void _showStatusFilterDialog() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Filter by Status"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["Pending", "Overdue", "Delivered", "Cancelled"]
              .map(
                (status) => InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                      _filterByStatus(status);
                    });
                    Navigator.pop(context); // Close dialog immediately
                  },
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Icon(
                          _selectedStatus == status 
                            ? Icons.radio_button_checked 
                            : Icons.radio_button_unchecked,
                          color: _selectedStatus == status ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(status),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _filterByStatus(null); // Reset filter
              });
              Navigator.pop(context);
            },
            child: const Text("Clear Filter"),
          ),
        ],
      );
    },
  );
}

// ===== Function to filter deliveries by status =====
void _filterByStatus(String? status) {
  final db = DatabaseHelper();
  if (status == null) {
    // No filter, show all
    db.fetchDeliveries().then((value) {
      setState(() {
        deliveries = value;
      });
    });
  } else {
    db.fetchDeliveries().then((value) {
      setState(() {
        deliveries = value
            .where((d) =>
                (d["status"] ?? "").toString().toLowerCase() ==
                status.toLowerCase())
            .toList();
      });
    });
  }
}
    
  @override
  void initState() {
    super.initState();
    _refreshDeliveriesAndCheckOverdue();
    _loadCategoriesAndProducts();
    _refreshUnread();
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      try {
        if (value > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(value);
        if (value > 1000000000) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _refreshDeliveriesAndCheckOverdue() async {
  final db = DatabaseHelper();
  await db.checkOverdueDeliveries(overdueAfter: Duration.zero);
  deliveries = await db.fetchDeliveries();
  if (!mounted) return;
  setState(() {});

  // toast for overdue delivery notifications
  final unread = await db.fetchNotifications(onlyUnread: true);
  if (unread.isNotEmpty && mounted) {
    final latest = unread.first;
    final message = latest['message']?.toString() ?? '';

    // Check if the notification matches the overdue delivery format
    final regex = RegExp(r'Your Delivery For (.+) is overdue!', caseSensitive: false);
    final match = regex.firstMatch(message);

    if (match != null) {
      final customerName = match.group(1);
      if (customerName != null && mounted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Your Delivery For $customerName is overdue!"),
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

        // Mark this notification as read
        final id = latest['id'];
        if (id is int) {
          await db.markNotificationsReadByIds([id]);
        }
        if (!mounted) return;
        await _refreshUnread();
      }
    }
  }
}


  Future<void> _refreshUnread() async {
    final db = DatabaseHelper();
    final v = await db.hasUnreadNotifications();
    if (!mounted) return;
    setState(() => hasUnread = v);
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
            Icon(icon, size: MediaQuery.of(context).size.width * 0.08, color: color),
            const SizedBox(height: 6),
            isActive
                ? Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: color, width: 2),
                      ),
                    ),
                    child: const Text(
                      "Delivery",
                      style: TextStyle(
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

  Future<void> _loadCategoriesAndProducts() async {
    final db = DatabaseHelper();
    allProducts = await db.fetchProducts();
    final uniqueCategories = <String>{};
    for (var p in allProducts) {
      if (p['category'] != null && p['category'].toString().isNotEmpty) {
        uniqueCategories.add(p['category'].toString());
      }
    }
    setState(() {
      categories = uniqueCategories.toList();
    });
  }

  Future<void> _pickDateTime() async {
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: selectedDateTime ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );

  if (pickedDate != null) {
    setState(() {
      // Only store the date, set time to 00:00
      selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }
}

  Future<void> _deleteSelected() async {
  if (selectedDeliveries.isEmpty) return;

  // Show confirmation dialog
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete?'),
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
    ),
  );

  if (confirm != true) return; 

  final db = DatabaseHelper();
  for (var id in selectedDeliveries) {
    await db.deleteDelivery(id);
  }
  await _refreshDeliveriesAndCheckOverdue();
  setState(() {
    selectedDeliveries.clear();
    isSelectionMode = false;
  });
}


  Future<void> _markAsDone(int id) async {
    final db = DatabaseHelper();
    await db.updateDeliveryStatus(id, "Delivered");
    await _refreshDeliveriesAndCheckOverdue();
  }

  Future<void> _markGroupAsDone(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = DatabaseHelper();
    for (var id in ids) {
      await db.updateDeliveryStatus(id, 'Delivered');
    }
    await _refreshDeliveriesAndCheckOverdue();
  }

   Future<void> _cancelDelivery(int id) async {
  final db = DatabaseHelper();

  // Get delivery details to restore quantity
  final deliveries = await db.fetchDeliveries();
  final delivery = deliveries.firstWhere((d) => d['id'] == id, orElse: () => {});

  if (delivery.isNotEmpty) {
    final productId = delivery['productId'] as int;
    final quantity = delivery['quantity'] as int;

    // Get current product quantity
    final products = await db.fetchProducts();
    final product = products.firstWhere((p) => p['id'] == productId, orElse: () => {});

    if (product.isNotEmpty) {
      final currentQty = product['quantity'] as int;
      final restoredQty = currentQty + quantity;

      // Restore quantity to product
      await db.updateProduct(productId, {"quantity": restoredQty});
    }
  }
    // Update delivery status to Cancelled
    await db.updateDeliveryStatus(id, "Cancelled");
    await _refreshDeliveriesAndCheckOverdue();
  }
  Future<void> _cancelGroupDeliveries(List<Map<String, dynamic>> deliveriesToCancel) async {
    if (deliveriesToCancel.isEmpty) return;
    final db = DatabaseHelper();

    // For each delivery, restore product qty and set status to Cancelled
    final products = await db.fetchProducts();
    for (var delivery in deliveriesToCancel) {
      final productId = delivery['productId'] as int?;
      final quantity = (delivery['quantity'] is int) ? delivery['quantity'] as int : int.tryParse((delivery['quantity'] ?? '0').toString()) ?? 0;
      if (productId != null) {
        final product = products.firstWhere((p) => p['id'] == productId, orElse: () => {});
        if (product.isNotEmpty) {
          final currentQty = product['quantity'] as int;
          final restoredQty = currentQty + quantity;
          await db.updateProduct(productId, {"quantity": restoredQty});
        }
      }

      final id = delivery['id'];
      if (id is int) {
        await db.updateDeliveryStatus(id, 'Cancelled');
      }
    }

    await _refreshDeliveriesAndCheckOverdue();
  }

  void _showGroupDetails(List<Map<String, dynamic>> deliveries) {
    if (deliveries.isEmpty) return;
    // Use a representative delivery for editable fields
    final representative = deliveries.first;
    DateTime? deliveryDate = _tryParseDate(representative['createdAt']) ?? DateTime.now();

    // Prepare controllers for quantities
    final qtyControllers = <TextEditingController>[];
    for (var d in deliveries) {
      qtyControllers.add(TextEditingController(text: (d['quantity'] ?? '').toString()));
    }

    // Temp storage for adding new product lines to this group
    List<Map<String, dynamic>> newProductLines = [];
    String? addCategory = categories.isNotEmpty ? categories[0] : null;
    List<Map<String, dynamic>> availableProductsForAdd = [];
    Map<String, dynamic>? selectedProductToAdd;
    final addQtyController = TextEditingController();

    void updateAvailableProductsForAdd(String? cat) {
      if (cat == null) return;
      availableProductsForAdd = allProducts.where((p) => p['category'] == cat).toList();
      selectedProductToAdd = null;
      addQtyController.text = '';
    }

    updateAvailableProductsForAdd(addCategory);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Delivery Details (Group)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${representative['customerName'] ?? ''}'),
                  Text('Location: ${representative['location'] ?? ''}'),
                  Text('Contact: ${representative['customerContact'] ?? ''}'),
                  const SizedBox(height: 8),
                  const Text('Products (edit quantities as needed):'),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(deliveries.length, (i) {
                        final d = deliveries[i];
                        final p = allProducts.firstWhere((p) => p['id'] == d['productId'], orElse: () => {});
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Expanded(child: Text(p.isNotEmpty ? (p['productName'] ?? '') : (d['category'] ?? 'Product'))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: qtyControllers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(isDense: true, labelText: 'Qty'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Add Product to Group Section ---
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text('Add Product to this Delivery Group', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: addCategory,
                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      addCategory = v;
                      updateAvailableProductsForAdd(addCategory);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  // Product dropdown
                  ConstrainedBox(
                    constraints: BoxConstraints(minWidth: 200, maxWidth: MediaQuery.of(context).size.width * 0.85),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      isExpanded: true,
                      value: selectedProductToAdd,
                      decoration: const InputDecoration(labelText: 'Product', isDense: true),
                      items: availableProductsForAdd.map((p) => DropdownMenuItem(value: p, child: Text(p['productName'] ?? ''))).toList(),
                      onChanged: (v) {
                        selectedProductToAdd = v;
                        addQtyController.text = '';
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addQtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (selectedProductToAdd == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a product')));
                              return;
                            }
                            final entered = int.tryParse(addQtyController.text) ?? 0;
                            if (entered <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity')));
                              return;
                            }

                            final prodId = selectedProductToAdd!['id'] as int?;
                            final availableStock = (selectedProductToAdd!['quantity'] as int?) ?? 0;

                            // Consider existing quantity in this group and already queued new lines for same product
                            final existingInGroup = deliveries.firstWhere((d) => d['productId'] == prodId, orElse: () => {});
                            final existingQty = existingInGroup.isNotEmpty ? (existingInGroup['quantity'] as int) : 0;
                            final alreadyQueued = newProductLines.where((l) => (l['product']?['id'] ?? -1) == prodId).fold<int>(0, (s, l) => s + ((l['quantity'] as int?) ?? 0));
                            final totalRequested = entered + existingQty + alreadyQueued;

                            if (totalRequested > availableStock) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Available stock is $availableStock; requested total would be $totalRequested')));
                              return;
                            }

                            // If same product already in newProductLines, accumulate
                            final existingIndex = newProductLines.indexWhere((l) => (l['product']?['id'] ?? -1) == prodId);
                            if (existingIndex >= 0) {
                              newProductLines[existingIndex]['quantity'] = (newProductLines[existingIndex]['quantity'] as int) + entered;
                            } else {
                              newProductLines.add({'product': selectedProductToAdd, 'quantity': entered});
                            }

                            // clear selection
                            selectedProductToAdd = null;
                            addQtyController.text = '';
                            setState(() {});
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Product'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (newProductLines.isNotEmpty) ...[
                    const Text('New products to add:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Column(
                      children: newProductLines.map((line) {
                        final p = line['product'] ?? {};
                        final qty = line['quantity'] ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p['productName'] ?? ''),
                          subtitle: Text('Quantity: $qty'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              newProductLines.remove(line);
                              setState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: deliveryDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(deliveryDate ?? DateTime.now()),
                        );
                        if (pickedTime != null) {
                          deliveryDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                          setState(() {});
                        }
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(deliveryDate != null ? deliveryDate.toString() : 'Pick Delivery Date & Time'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton(
                onPressed: () async {
                  final db = DatabaseHelper();

                  // Validate and compute stock deltas for edited quantities
                  final productsFromDb = await db.fetchProducts();
                  final updates = <Map<String, dynamic>>[];

                  for (var i = 0; i < deliveries.length; i++) {
                    final d = deliveries[i];
                    final oldQty = (d['quantity'] is int) ? d['quantity'] as int : int.tryParse((d['quantity'] ?? '0').toString()) ?? 0;
                    final newQty = int.tryParse(qtyControllers[i].text) ?? 0;
                    final prodId = d['productId'] as int?;
                    if (newQty <= 0) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantities')));
                      return;
                    }
                    if (prodId == null) continue;

                    final prod = productsFromDb.firstWhere((p) => p['id'] == prodId, orElse: () => {});
                    final currentStock = prod.isNotEmpty ? (prod['quantity'] as int) : 0;

                    final delta = newQty - oldQty; // positive => need more stock, negative => restore stock
                    if (delta > 0 && delta > currentStock) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough stock for ${prod['productName'] ?? 'product'} (need $delta, have $currentStock)')));
                      return;
                    }

                    updates.add({'id': d['id'], 'productId': prodId, 'oldQty': oldQty, 'newQty': newQty, 'delta': delta});
                  }

                  // Validate new product lines against stock
                  final productsNow = await db.fetchProducts();
                  for (var line in newProductLines) {
                    final p = line['product'] as Map<String, dynamic>;
                    final requested = line['quantity'] as int;
                    final prodFromDb = productsNow.firstWhere((x) => x['id'] == p['id'], orElse: () => {});
                    final available = prodFromDb.isNotEmpty ? (prodFromDb['quantity'] as int) : 0;
                    if (requested > available) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Available stock for ${p['productName']} is $available, cannot add $requested')));
                      return;
                    }
                  }

                  // Apply updates: update deliveries and product quantities
                  for (var u in updates) {
                    final id = u['id'];
                    final prodId = u['productId'] as int;
                    final delta = u['delta'] as int;
                    final newQty = u['newQty'] as int;

                    // Update delivery row
                    if (id is int) await db.updateDelivery(id, {'quantity': newQty});

                    // Update product stock
                    final prodRow = (await db.fetchProducts()).firstWhere((p) => p['id'] == prodId, orElse: () => {});
                    final curStock = prodRow.isNotEmpty ? (prodRow['quantity'] as int) : 0;
                    final updatedStock = curStock - delta; // delta positive reduces stock; negative increases
                    await db.updateProduct(prodId, {'quantity': updatedStock < 0 ? 0 : updatedStock});
                  }

                  // Insert or merge new product lines
                  for (var line in newProductLines) {
                    final p = line['product'] as Map<String, dynamic>;
                    final requested = line['quantity'] as int;

                    // If group already has a delivery for this product, update that delivery instead of inserting a new one
                    final existing = deliveries.firstWhere((d) => d['productId'] == p['id'], orElse: () => {});
                    if (existing.isNotEmpty) {
                      final id = existing['id'];
                      final oldQty = (existing['quantity'] is int) ? existing['quantity'] as int : int.tryParse((existing['quantity'] ?? '0').toString()) ?? 0;
                      final newQty = oldQty + requested;
                      if (id is int) await db.updateDelivery(id, {'quantity': newQty});

                      // decrement stock
                      final prodRow = (await db.fetchProducts()).firstWhere((x) => x['id'] == p['id'], orElse: () => {});
                      final curStock = prodRow.isNotEmpty ? (prodRow['quantity'] as int) : 0;
                      await db.updateProduct(p['id'] as int, {'quantity': (curStock - requested) < 0 ? 0 : (curStock - requested)});
                    } else {
                      // Insert a new delivery row for this group using representative customer info
                      await db.insertDelivery({
                        "customerName": representative['customerName'],
                        "customerContact": representative['customerContact'],
                        "location": representative['location'],
                        "category": p['category'] ?? representative['category'],
                        "productId": p['id'],
                        "quantity": requested,
                        "createdAt": deliveryDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
                        "status": representative['status'] ?? 'Pending',
                      });

                      final prodRow = (await db.fetchProducts()).firstWhere((x) => x['id'] == p['id'], orElse: () => {});
                      final curStock = prodRow.isNotEmpty ? (prodRow['quantity'] as int) : 0;
                      await db.updateProduct(p['id'] as int, {'quantity': (curStock - requested) < 0 ? 0 : (curStock - requested)});
                    }
                  }

                  // Update createdAt if changed
                  if (deliveryDate != null) {
                    for (var d in deliveries) {
                      final id = d['id'];
                      if (id is int) await db.updateDelivery(id, {'createdAt': deliveryDate!.toIso8601String()});
                    }
                    // Also update newly inserted rows (they were created with deliveryDate already)
                  }

                  await db.checkLowStockProducts();
                  await _refreshDeliveriesAndCheckOverdue();
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  

  void _showAddDeliveryDialog() {
  final customerController = TextEditingController();
  final locationController = TextEditingController();
  final contactController = TextEditingController();
  final quantityController = TextEditingController();
  String? category = categories.isNotEmpty ? categories[0] : null;
  List<Map<String, dynamic>> availableProducts = [];
  Map<String, dynamic>? selectedProduct;
  DateTime? deliveryDate = selectedDateTime ?? DateTime.now();

  // Holds the list of product lines the user wants to deliver for this customer
  final List<Map<String, dynamic>> productLines = [];

  void updateProductsByCategory(String? cat) {
    if (cat == null) return;
    availableProducts = allProducts.where((p) => p['category'] == cat).toList();
    selectedProduct = null;
    quantityController.text = '';
  }

  updateProductsByCategory(category);

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        int alreadyRequestedQuantityForProduct(int productId) {
          final existing = productLines.firstWhere(
            (l) => (l['product']?['id'] ?? -1) == productId,
            orElse: () => {},
          );
          if (existing.isEmpty) return 0;
          return (existing['quantity'] as int?) ?? 0;
        }

        return AlertDialog(
          title: const Text("Add New Delivery"),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Customer Name
                  TextField(
                    controller: customerController,
                    decoration: const InputDecoration(
                      labelText: "Customer Name",
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Contact
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: "Contact Number",
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  // Location
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: "Location",
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: "Product Category",
                      isDense: true,
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      category = value;
                      updateProductsByCategory(category);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),

                  // Wrap dropdown in a ConstrainedBox and set isExpanded to avoid overflow
                  ConstrainedBox(
                    constraints: BoxConstraints(minWidth: 200, maxWidth: MediaQuery.of(context).size.width * 0.85),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      isExpanded: true,
                      initialValue: selectedProduct,
                      decoration: const InputDecoration(
                        labelText: "Product",
                        isDense: true,
                      ),
                      items: availableProducts
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Flexible(
                                  child: Text(
                                    p['productName'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        selectedProduct = value;
                        quantityController.text = '';
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Quantity
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: "Quantity",
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  const SizedBox(height: 8),
                  // Add product line button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (selectedProduct == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a product')));
                              return;
                            }
                            final enteredQty = int.tryParse(quantityController.text) ?? 0;
                            if (enteredQty <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid quantity')));
                              return;
                            }

                            final availableStock = (selectedProduct!['quantity'] as int?) ?? 0;
                            final alreadyRequested = alreadyRequestedQuantityForProduct(selectedProduct!['id'] as int);
                            if (enteredQty + alreadyRequested > availableStock) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Available stock is $availableStock, cannot add ${enteredQty + alreadyRequested}')));
                              return;
                            }

                            // If same product already in lines, increment its quantity
                            final existingIndex = productLines.indexWhere((l) => (l['product']?['id'] ?? -1) == (selectedProduct!['id'] as int));
                            if (existingIndex >= 0) {
                              productLines[existingIndex]['quantity'] = (productLines[existingIndex]['quantity'] as int) + enteredQty;
                            } else {
                              productLines.add({
                                'product': selectedProduct,
                                'quantity': enteredQty,
                              });
                            }

                            // Clear selection for next line
                            selectedProduct = null;
                            quantityController.text = '';
                            setState(() {});
                          },
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add Product to Delivery'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  // Show added product lines
                  if (productLines.isNotEmpty) ...[
                    const Align(alignment: Alignment.centerLeft, child: Text('Products to deliver:', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 6),
                    Column(
                      children: productLines.map((line) {
                        final p = line['product'] ?? {};
                        final qty = line['quantity'] ?? 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p['productName'] ?? ''),
                          subtitle: Text('Quantity: $qty'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              productLines.remove(line);
                              setState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Delivery Date Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final currentContext = context;
                        final pickedDate = await showDatePicker(
                          context: currentContext,
                          initialDate: deliveryDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null && mounted) {
                          final pickedTime = await showTimePicker(
                            context: currentContext,
                            initialTime: TimeOfDay.fromDateTime(deliveryDate ?? DateTime.now()),
                          );
                          if (pickedTime != null) {
                            deliveryDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setState(() {});
                          }
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        deliveryDate != null
                            ? "${deliveryDate!.year}-${deliveryDate!.month.toString().padLeft(2, '0')}-${deliveryDate!.day.toString().padLeft(2, '0')} "
                              "${deliveryDate!.hour.toString().padLeft(2, '0')}:${deliveryDate!.minute.toString().padLeft(2, '0')}"
                            : "Pick Delivery Date & Time",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentContext = context;
                if (customerController.text.isEmpty ||
                    contactController.text.isEmpty ||
                    locationController.text.isEmpty ||
                    deliveryDate == null ||
                    productLines.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(content: Text("Please fill customer info and add at least one product")),
                    );
                  }
                  return;
                }

                final db = DatabaseHelper();

                // Final validation: make sure none of the requested quantities exceed current stock
                final products = await db.fetchProducts();
                for (var line in productLines) {
                  final p = line['product'] as Map<String, dynamic>;
                  final requested = line['quantity'] as int;
                  final prodFromDb = products.firstWhere((x) => x['id'] == p['id'], orElse: () => {});
                  final available = prodFromDb.isNotEmpty ? (prodFromDb['quantity'] as int) : 0;
                  if (requested > available) {
                    if (mounted) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(content: Text('Available stock for ${p['productName']} is $available, cannot deliver $requested')),
                      );
                    }
                    return;
                  }
                }

                // Insert one delivery row per product line and decrement stock accordingly
                for (var line in productLines) {
                  final p = line['product'] as Map<String, dynamic>;
                  final requested = line['quantity'] as int;

                  await db.insertDelivery({
                    "customerName": customerController.text,
                    "customerContact": contactController.text,
                    "location": locationController.text,
                    "category": p['category'] ?? category,
                    "productId": p['id'],
                    "quantity": requested,
                    "createdAt": deliveryDate!.toIso8601String(),
                    "status": "Pending",
                  });

                  final newQty = (p['quantity'] as int) - requested;
                  await db.updateProduct(p['id'] as int, {"quantity": newQty < 0 ? 0 : newQty});
                }

                await db.checkLowStockProducts();
                await _refreshDeliveriesAndCheckOverdue();
                if (mounted) Navigator.pop(currentContext);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    ),
  );
}


  void _showDeliveryDetails(Map<String, dynamic> delivery) {
    final product = allProducts.firstWhere(
      (p) => p['id'] == delivery['productId'],
      orElse: () => {},
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("View Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${delivery['customerName']}"),
            Text("Location: ${delivery['location']}"),
            Text("Contact: ${delivery['customerContact']}"),
            Text("Product Category: ${delivery['category'] ?? ''}"),
            Text("Product: ${product['productName'] ?? ''}"),
            Text("Quantity: ${delivery['quantity'] ?? ''}"),
            Text(
              "Status: ${delivery['status'] ?? 'Pending'}",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Builder(
              builder: (_) {
                final dt = _tryParseDate(delivery['createdAt']);
                final dateText = dt != null ? dt.toLocal().toString() : (delivery['createdAt']?.toString() ?? 'N/A');
                return Text("Delivery Date: $dateText");
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          if (delivery['status'] != 'Delivered' && delivery['status'] != 'Cancelled') ...[
            ElevatedButton(
              onPressed: () async {
                // Edit delivery date
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _tryParseDate(delivery['createdAt'])?.toLocal() ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  // Save updated createdAt as ISO string
                  final iso = picked.toIso8601String();
                  await DatabaseHelper().updateDelivery(delivery['id'], {'createdAt': iso});
                  await _refreshDeliveriesAndCheckOverdue();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delivery date updated')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text("Edit Date"),
            ),

            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first
                await _cancelDelivery(delivery['id']);
              },
              child: const Text("Cancel Delivery"),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    List<Map<String, dynamic>> filteredDeliveries;
    if (selectedDateTime == null) {
      filteredDeliveries = List.from(deliveries);
    } else {
      filteredDeliveries = deliveries.where((delivery) {
        final d = _tryParseDate(delivery["createdAt"]);
        if (d == null) return false;
        return d.year == selectedDateTime!.year &&
            d.month == selectedDateTime!.month &&
            d.day == selectedDateTime!.day;
      }).toList();
    }

        filteredDeliveries.sort((a, b) {
    final statusA = (a["status"] ?? "").toString().toLowerCase();
    final statusB = (b["status"] ?? "").toString().toLowerCase();

    //  Push Overdue to the top
    if (statusA == "overdue" && statusB != "overdue") return -1;
    if (statusB == "overdue" && statusA != "overdue") return 1;

    //  Push Delivered and Cancelled to the bottom
    final isDoneA = statusA == "delivered" || statusA == "cancelled";
    final isDoneB = statusB == "delivered" || statusB == "cancelled";

    if (isDoneA && !isDoneB) return 1;
    if (!isDoneA && isDoneB) return -1;

    //  Sort by date (ascending)
    final dateA = _tryParseDate(a["createdAt"]);
    final dateB = _tryParseDate(b["createdAt"]);
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateA.compareTo(dateB);
  });



    return Scaffold(
      body: Column(
        children: [
          // ===== HEADER =====
          Container(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Image.asset(
                        "assets/images/mamaabbys.jpg",
                        height: 60,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DELIVERY",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Manage Deliveries",
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
                    IconButton(
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
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
         // ===== FILTER BAR =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== LEFT COLUMN: Select Date + Add Delivery =====
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Select Date button
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickDateTime,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                selectedDateTime == null
                                    ? "Select Date"
                                    : "${selectedDateTime!.year}-${selectedDateTime!.month.toString().padLeft(2, '0')}-${selectedDateTime!.day.toString().padLeft(2, '0')}",
                              ),
                            ),
                            if (selectedDateTime != null)
                              IconButton(
                                icon: const Icon(Icons.clear, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    selectedDateTime = null;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Add Delivery button right below Select Date
                        ElevatedButton.icon(
                          onPressed: _showAddDeliveryDialog,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text("Add Delivery"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    // ===== RIGHT COLUMN: Filter Status + Select/Delete/Cancel =====
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Filter Status button
                        ElevatedButton(
                          onPressed: _showStatusFilterDialog,
                          child: const Text("Filter Status"),
                        ),
                        const SizedBox(height: 6),

                        // Select / Delete / Cancel buttons
                        Row(
                          children: [
                            if (!isSelectionMode)
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isSelectionMode = true;
                                    selectedDeliveries.clear();
                                  });
                                },
                                child: const Text("Select"),
                              ),
                            if (isSelectionMode) ...[
                              ElevatedButton.icon(
                                onPressed: selectedDeliveries.isEmpty ? null : _deleteSelected,
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text("Delete"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    isSelectionMode = false;
                                    selectedDeliveries.clear();
                                  });
                                },
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text("Cancel"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

          // ===== LIST OF DELIVERIES (grouped by customer+contact+location+createdAt) =====
          Expanded(
            child: Builder(
              builder: (context) {
                // Group deliveries by a composite key so products added together show under one header
                final Map<String, List<Map<String, dynamic>>> groups = {};
                for (var d in filteredDeliveries) {
                  final keyCust = (d['customerName'] ?? '').toString();
                  final keyContact = (d['customerContact'] ?? '').toString();
                  final keyLoc = (d['location'] ?? '').toString();
                  final keyDate = (d['createdAt'] ?? '').toString();
                  final key = '$keyCust|$keyContact|$keyLoc|$keyDate';
                  groups.putIfAbsent(key, () => []).add(d);
                }

                final groupEntries = groups.entries.toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  itemCount: groupEntries.length,
                  itemBuilder: (context, gIndex) {
                    final group = groupEntries[gIndex];
                    final deliveriesInGroup = group.value;

                    // Determine a representative status for the group
                    String groupStatus = 'Pending';
                    if (deliveriesInGroup.any((x) => ((x['status'] ?? '').toString().toLowerCase()) == 'overdue')) {
                      groupStatus = 'Overdue';
                    } else if (deliveriesInGroup.every((x) => ((x['status'] ?? '').toString().toLowerCase()) == 'delivered')) {
                      groupStatus = 'Delivered';
                    } else if (deliveriesInGroup.every((x) => ((x['status'] ?? '').toString().toLowerCase()) == 'cancelled')) {
                      groupStatus = 'Cancelled';
                    }

                    // Parse customer & date details from the composite key
                    final parts = group.key.split('|');
                    final custName = parts.isNotEmpty ? parts[0] : '';
                    final custContact = parts.length > 1 ? parts[1] : '';
                    final custLoc = parts.length > 2 ? parts[2] : '';
                    final createdAtRaw = parts.length > 3 ? parts[3] : '';

                    DateTime? createdAtDt = _tryParseDate(createdAtRaw);
                    final createdAtText = createdAtDt != null ? createdAtDt.toString() : createdAtRaw;

                    // Create a list of delivery ids in this group for group-level actions
                    final groupIds = deliveriesInGroup.map((d) => d['id'] as int).toList();

                    return Card(
                      child: ExpansionTile(
                        key: ValueKey(group.key),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(custName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Location: $custLoc'),
                            Text('Contact: $custContact'),
                          ],
                        ),
                        subtitle: Text('Status: $groupStatus • Date: $createdAtText'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                // Show group details: use the first delivery as representative but allow editing to update all
                                _showGroupDetails(deliveriesInGroup);
                              },
                              child: const Text('View'),
                            ),
                            if (groupStatus.toLowerCase() != 'delivered' && groupStatus.toLowerCase() != 'cancelled')
                              TextButton(
                                onPressed: () => _markGroupAsDone(groupIds),
                                child: const Text('Done'),
                              ),
                            if (groupStatus.toLowerCase() != 'cancelled')
                              TextButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Cancel'),
                                      content: const Text('Cancel all deliveries in this group? This will restore stock.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await _cancelGroupDeliveries(deliveriesInGroup);
                                  }
                                },
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                        children: deliveriesInGroup.map((delivery) {
                          final product = allProducts.firstWhere((p) => p['id'] == delivery['productId'], orElse: () => {});
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            onTap: () => _showDeliveryDetails(delivery),
                            leading: isSelectionMode
                                ? Checkbox(
                                    value: selectedDeliveries.contains(delivery['id']),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedDeliveries.add(delivery['id']);
                                        } else {
                                          selectedDeliveries.remove(delivery['id']);
                                        }
                                      });
                                    },
                                  )
                                : null,
                            title: Text(product.isNotEmpty ? (product['productName'] ?? '') : (delivery['category'] ?? 'Product')),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quantity: ${delivery['quantity'] ?? ''}'),
                                Text('Status: ${delivery['status'] ?? 'Pending'}'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}