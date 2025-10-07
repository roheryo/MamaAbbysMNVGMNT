import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPage();
}

class _NotificationPage extends State<NotificationPage> {
  final db = DatabaseHelper();
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    notifications = await db.fetchNotifications();
    await _replaceProductIdsWithNames();
    setState(() {});
    await db.markAllNotificationsRead();
  }

  Future<void> _replaceProductIdsWithNames() async {
    final database = await db.database;
    final updatedNotifications = <Map<String, dynamic>>[];

    for (var n in notifications) {
      final message = n["message"]?.toString() ?? "";
      String newMessage = message;

      final regex = RegExp(
          r'Product ID:\s*(\d+)\s*\|\s*Qty:\s*(\d+)',
          caseSensitive: false);
      final match = regex.firstMatch(message);

      if (match != null) {
        final productId = int.tryParse(match.group(1)!);
        final qty = match.group(2)!;

        if (productId != null) {
          final res = await database.query(
            "products",
            where: "id = ?",
            whereArgs: [productId],
            limit: 1,
          );

          if (res.isNotEmpty) {
            final productName = res.first["productName"] ?? "Unknown Product";
            newMessage = message.replaceFirst(
              regex,
              "Product: $productName | Quantity: $qty",
            );
          }
        }
      }

      updatedNotifications.add({
        ...n,
        "message": newMessage,
      });
    }

    notifications = updatedNotifications;
  }

  Future<void> _deleteNotification(int id) async {
    final database = await db.database;
    await database.delete("notifications", where: "id = ?", whereArgs: [id]);
    await _loadNotifications();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Unknown date";
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) return "Invalid date";
      return DateFormat("MMM d, yyyy - h:mm a").format(parsed.toLocal());
    } catch (e) {
      return "Invalid date";
    }
  }

  Future<void> _showDeliveryDetails(String message) async {
    final database = await db.database;

    final regex =
        RegExp(r'Delivery for (.+?) is overdue', caseSensitive: false);
    final match = regex.firstMatch(message);

    Map<String, dynamic>? deliveryDetails;

    if (match != null) {
      final customerName = match.group(1)?.trim();

      if (customerName != null) {
        final res = await database.query(
          "deliveries",
          where: "customerName = ?",
          whereArgs: [customerName],
          orderBy: "createdAt DESC",
          limit: 1,
        );

        if (res.isNotEmpty) {
          deliveryDetails = res.first;
        }
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          if (deliveryDetails == null) {
            return const AlertDialog(
              title: Text("Delivery Details"),
              content: Text("Could not find delivery details in database."),
            );
          }

          return AlertDialog(
            title: const Text("Delivery Details"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Customer: ${deliveryDetails['customerName']}"),
                Text("Contact: ${deliveryDetails['customerContact']}"),
                Text("Address: ${deliveryDetails['location']}"),
                Text("Category: ${deliveryDetails['category']}"),
                Text("Product ID: ${deliveryDetails['productId']}"),
                Text("Quantity: ${deliveryDetails['quantity']}"),
                Text("Status: ${deliveryDetails['status']}"),
                Text("Created: ${_formatDate(deliveryDetails['createdAt'])}"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // <-- Added SafeArea to respect status bar and device edges
        child: Column(
          children: [
            // ===== Header =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.blue, size: 26),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Notifications",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text("No notifications yet"))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        final message = n["message"] ?? "";

                        final isDelivery = message.toLowerCase().contains("delivery for");

                        return Stack(
                          children: [
                            Card(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isDelivery ? Icons.local_shipping : Icons.error,
                                          color: isDelivery ? Colors.blue : Colors.orange,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      isDelivery ? message.split("\n").first : message,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                                    onPressed: () => _deleteNotification(n["id"]),
                                                    splashRadius: 18,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDate(n["createdAt"]),
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isDelivery)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          onPressed: () => _showDeliveryDetails(message),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            minimumSize: const Size(50, 28),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            textStyle: const TextStyle(fontSize: 12),
                                          ),
                                          child: const Text("View"),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
