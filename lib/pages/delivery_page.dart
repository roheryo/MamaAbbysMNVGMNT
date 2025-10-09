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




  void _showAddDeliveryDialog() {
  final customerController = TextEditingController();
  final locationController = TextEditingController();
  final contactController = TextEditingController();
  final quantityController = TextEditingController();
  String? category = categories.isNotEmpty ? categories[0] : null;
  List<Map<String, dynamic>> availableProducts = [];
  Map<String, dynamic>? selectedProduct;
  DateTime? deliveryDate = selectedDateTime ?? DateTime.now();

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
        return AlertDialog(
          title: const Text("Add New Delivery"),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                    selectedProduct == null ||
                    deliveryDate == null ||
                    quantityController.text.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(content: Text("Please fill all fields")),
                    );
                  }
                  return;
                }

                final enteredQty = int.tryParse(quantityController.text);
                if (enteredQty == null || enteredQty <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(content: Text("Enter a valid quantity")),
                    );
                  }
                  return;
                }

                if (enteredQty > selectedProduct!['quantity']) {
                  if (mounted) {
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Available stock is ${selectedProduct!['quantity']}, cannot deliver $enteredQty",
                        ),
                      ),
                    );
                  }
                  return;
                }

                await DatabaseHelper().insertDelivery({
                  "customerName": customerController.text,
                  "customerContact": contactController.text,
                  "location": locationController.text,
                  "category": category,
                  "productId": selectedProduct!['id'],
                  "quantity": enteredQty,
                  "createdAt": deliveryDate!.toString(),
                  "status": "Pending",
                });

                final newQty = (selectedProduct!['quantity'] as int) - enteredQty;
                await DatabaseHelper().updateProduct(
                  selectedProduct!['id'] as int,
                  {"quantity": newQty < 0 ? 0 : newQty},
                );

                await DatabaseHelper().checkLowStockProducts();
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
          if (delivery['status'] != 'Delivered' && delivery['status'] != 'Cancelled')
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog first
                await _cancelDelivery(delivery['id']);
              },
              child: const Text("Cancel Delivery"),
            ),
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
            padding: EdgeInsets.all(screenWidth * 0.03),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Image.asset(
                        "assets/images/mamaabbys.jpg",
                        height: screenWidth * 0.15,
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DELIVERY",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: screenWidth * 0.05,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Manage Deliveries",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: screenWidth * 0.035,
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

          // ===== LIST OF DELIVERIES =====
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: filteredDeliveries.length,
              itemBuilder: (context, index) {
                final delivery = filteredDeliveries[index];
                final isSelected = selectedDeliveries.contains(delivery["id"]);
                final status = (delivery["status"] ?? "").toString().toLowerCase();
                final isDelivered = status == "delivered";
                final isCancelled = status == "cancelled";
                return Card(
                    color: status == "overdue" ? Colors.red.shade100 : null, // Light red for overdue
                    child: ListTile(
                      leading: isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedDeliveries.add(delivery["id"]);
                                  } else {
                                    selectedDeliveries.remove(delivery["id"]);
                                  }
                                });
                              },
                            )
                          : null,
                      title: Text(delivery["customerName"] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Customer: ${delivery['customerName']}"),
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
                              final text = dt != null ? dt.toString() : (delivery['createdAt']?.toString() ?? 'N/A');
                              return Text("Date: $text");
                            },
                          ),
                        ],
                      ),
                      trailing: !isSelectionMode
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _showDeliveryDetails(delivery),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size(50, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                  ),
                                  child: const Text(
                                    "View",
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                if (!isDelivered && !isCancelled) const SizedBox(width: 4),
                                if (!isDelivered && !isCancelled)
                                  ElevatedButton(
                                    onPressed: () => _markAsDone(delivery["id"]),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      minimumSize: const Size(50, 30),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    child: const Text(
                                      "Done",
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                              ],
                            )
                          : null,
                    ),
                  );
              },
            ),
          ),
        ],
      ),
    );
  }
}
