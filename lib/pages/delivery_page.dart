import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'inventory_page.dart';
import 'sales_page.dart';
import '../database_helper.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  List<Map<String, dynamic>> deliveries = [];
  DateTime? selectedDateTime;
  bool isSelectionMode = false;
  Set<int> selectedDeliveries = {};

  List<String> categories = [];
  List<Map<String, dynamic>> allProducts = [];

  @override
  void initState() {
    super.initState();
    _refreshDeliveriesAndCheckOverdue();
    _loadCategoriesAndProducts();
  }

  Future<void> _refreshDeliveriesAndCheckOverdue() async {
    final db = DatabaseHelper();
    await db.checkOverdueDeliveries();
    deliveries = await db.fetchDeliveries();
    setState(() {});
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
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _deleteSelected() async {
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

  void _showAddDeliveryDialog() {
    final customerController = TextEditingController();
    final locationController = TextEditingController();
    final contactController = TextEditingController();
    final quantityController = TextEditingController();
    String? category = categories.isNotEmpty ? categories[0] : null;
    List<Map<String, dynamic>> availableProducts = [];
    Map<String, dynamic>? selectedProduct;
    DateTime? deliveryDate;

    deliveryDate = selectedDateTime ?? DateTime.now();

    void updateProductsByCategory(String? cat) {
      if (cat == null) return;
      availableProducts = allProducts
          .where((p) => p['category'] == cat)
          .toList();
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: customerController,
                    decoration: const InputDecoration(
                      labelText: "Customer Name",
                    ),
                  ),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: "Contact Number",
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: "Location"),
                  ),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: "Product Category",
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      category = value;
                      updateProductsByCategory(category);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedProduct,
                    decoration: const InputDecoration(labelText: "Product"),
                    items: availableProducts
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p['productName']),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      selectedProduct = value;
                      quantityController.text = '';
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: "Quantity"),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: deliveryDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            deliveryDate ?? DateTime.now(),
                          ),
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
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (customerController.text.isEmpty ||
                      contactController.text.isEmpty ||
                      locationController.text.isEmpty ||
                      selectedProduct == null ||
                      deliveryDate == null ||
                      quantityController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill all fields")),
                    );
                    return;
                  }

                  final enteredQty = int.tryParse(quantityController.text);
                  if (enteredQty == null || enteredQty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Enter a valid quantity")),
                    );
                    return;
                  }

                  if (enteredQty > selectedProduct!['quantity']) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Available stock is ${selectedProduct!['quantity']}, cannot deliver $enteredQty",
                        ),
                      ),
                    );
                    return;
                  }

                  await DatabaseHelper().insertDelivery({
                    "customerName": customerController.text,
                    "customerContact": contactController.text,
                    "location": locationController.text,
                    "category": category,
                    "productId": selectedProduct!['id'],
                    "quantity": enteredQty,
                    "createdAt": deliveryDate!.toIso8601String(),
                    "status": "Pending",
                  });

                  await _refreshDeliveriesAndCheckOverdue();
                  Navigator.pop(context);
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
            Text(
              "Delivery Date: ${DateTime.parse(delivery['createdAt']).toLocal()}",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
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
        final d = DateTime.parse(delivery["createdAt"]);
        return d.year == selectedDateTime!.year &&
            d.month == selectedDateTime!.month &&
            d.day == selectedDateTime!.day;
      }).toList();
    }

    filteredDeliveries.sort((a, b) {
      if ((a["status"] ?? "") == "Delivered" &&
          (b["status"] ?? "") != "Delivered") {
        return 1;
      } else if ((b["status"] ?? "") == "Delivered" &&
          (a["status"] ?? "") != "Delivered") {
        return -1;
      }
      final dateA = DateTime.parse(a["createdAt"]);
      final dateB = DateTime.parse(b["createdAt"]);
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
              children: [
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
                Row(
                  children: [
                    if (isSelectionMode) ...[
                      ElevatedButton.icon(
                        onPressed: selectedDeliveries.isEmpty
                            ? null
                            : _deleteSelected,
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text("Delete"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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
                    ] else
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isSelectionMode = true;
                            selectedDeliveries.clear();
                          });
                        },
                        child: const Text("Select"),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ===== ADD BUTTON =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _showAddDeliveryDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add Delivery"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
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
                final isDelivered = (delivery["status"] ?? "") == "Delivered";
                return Card(
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
                        Text(
                          "Date: ${DateTime.parse(delivery['createdAt']).toLocal()}",
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
                            if (!isDelivered) const SizedBox(width: 4),
                            if (!isDelivered)
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
          // ===== BOTTOM NAV =====
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenWidth * 0.03,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventoryPage(),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: screenWidth * 0.08,
                          color: Colors.blue,
                        ),
                        const Text(
                          "Inventory",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SalesPage()),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: screenWidth * 0.08,
                          color: Colors.green,
                        ),
                        const Text(
                          "Sales",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          size: screenWidth * 0.08,
                          color: Colors.orange,
                        ),
                        const Text(
                          "Delivery",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
