import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'inventory_page.dart';
import 'sales_page.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  List<Map<String, dynamic>> deliveries = [
    {
      "id": "DEL-001",
      "customer": "Jan Paul",
      "location": "Tagum City, Pagsabangan",
      "contact": "09171234567",
      "product": "2x Chicken Adobo",
      "status": "Pending",
      "date": DateTime(2025, 9, 20, 10, 30),
    },
    {
      "id": "DEL-002",
      "customer": "Van Renzo",
      "location": "Tagum City, Osmena Extension",
      "contact": "09181234567",
      "product": "1x Beef Steak",
      "status": "On the way",
      "date": DateTime(2025, 9, 22, 15, 00),
    },
    {
      "id": "DEL-003",
      "customer": "Roger",
      "location": "Tagum City, Magugpo Poblacion",
      "contact": "09191234567",
      "product": "3x Pork Sinigang",
      "status": "Delivered",
      "date": DateTime(2025, 9, 23, 18, 45),
    },
    {
      "id": "DEL-004",
      "customer": "Mia",
      "location": "Tagum City, Apokon",
      "contact": "09201234567",
      "product": "2x Spaghetti",
      "status": "Overdue",
      "date": DateTime(2025, 9, 19, 9, 15),
    },
  ];

  DateTime? selectedDateTime;

  bool isSelectionMode = false;
  Set<String> selectedDeliveries = {};

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

  Color _getStatusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "On the way":
        return Colors.blue;
      case "Delivered":
        return Colors.green;
      case "Overdue":
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  void _deleteSelected() {
    setState(() {
      deliveries.removeWhere((d) => selectedDeliveries.contains(d["id"]));
      selectedDeliveries.clear();
      isSelectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final filteredDeliveries = selectedDateTime == null
        ? deliveries
        : deliveries.where((delivery) {
            final d = delivery["date"] as DateTime;
            return d.year == selectedDateTime!.year &&
                d.month == selectedDateTime!.month &&
                d.day == selectedDateTime!.day;
          }).toList();

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
                      icon: Icon(
                        Icons.notifications,
                        color: Colors.blue,
                        size: screenWidth * 0.07,
                      ),
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
                      icon: Icon(
                        Icons.settings,
                        color: Colors.blue,
                        size: screenWidth * 0.07,
                      ),
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

          SizedBox(height: screenWidth * 0.03),

          // ===== Filter + Select Row =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Date Filter
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDateTime == null
                            ? "Select Date"
                            : "${selectedDateTime!.year}-${selectedDateTime!.month.toString().padLeft(2, '0')}-${selectedDateTime!.day.toString().padLeft(2, '0')} "
                                  "${selectedDateTime!.hour.toString().padLeft(2, '0')}:${selectedDateTime!.minute.toString().padLeft(2, '0')}",
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

                // Right: Buttons (Select / Delete / Cancel)
                Row(
                  children: [
                    if (isSelectionMode) ...[
                      SizedBox(
                        height: 36, // make smaller height
                        child: ElevatedButton.icon(
                          onPressed: selectedDeliveries.isEmpty
                              ? null
                              : _deleteSelected,
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text("Delete"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(
                              80,
                              36,
                            ), // min width & height
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
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
                            minimumSize: const Size(80, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
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
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text("Select"),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: screenWidth * 0.03),

          // ===== Delivery List =====
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: filteredDeliveries.isEmpty
                  ? const Center(
                      child: Text(
                        "No deliveries found for this date",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredDeliveries.length,
                      itemBuilder: (context, index) {
                        final delivery = filteredDeliveries[index];
                        final isSelected = selectedDeliveries.contains(
                          delivery["id"],
                        );
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: isSelectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedDeliveries.add(
                                            delivery["id"],
                                          );
                                        } else {
                                          selectedDeliveries.remove(
                                            delivery["id"],
                                          );
                                        }
                                      });
                                    },
                                  )
                                : null,
                            title: Text(
                              delivery["id"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Customer: ${delivery['customer']}"),
                                Text(
                                  "Status: ${delivery['status']}",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Date: ${delivery['date'].year}-${delivery['date'].month.toString().padLeft(2, '0')}-${delivery['date'].day.toString().padLeft(2, '0')} "
                                  "${delivery['date'].hour.toString().padLeft(2, '0')}:${delivery['date'].minute.toString().padLeft(2, '0')}",
                                ),
                              ],
                            ),
                            trailing: !isSelectionMode
                                ? ElevatedButton(
                                    onPressed: () =>
                                        _showDeliveryDetails(delivery),
                                    child: const Text("View"),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ),
          //  Bottom Navigation
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
                        SizedBox(height: screenWidth * 0.015),
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
                        SizedBox(height: screenWidth * 0.015),
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
                        SizedBox(height: screenWidth * 0.015),
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                          ),
                          child: const Text(
                            "Delivery",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  void _showDeliveryDetails(Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delivery Details (${delivery['id']})"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${delivery['customer']}"),
            Text("Location: ${delivery['location']}"),
            Text("Contact: ${delivery['contact']}"),
            Text("Product: ${delivery['product']}"),
            Text(
              "Status: ${delivery['status']}",
              style: TextStyle(
                color: _getStatusColor(delivery['status']),
                fontWeight: FontWeight.bold,
              ),
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
}
