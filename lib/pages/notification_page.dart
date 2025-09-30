import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; //for date formatting
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

  
    final regex = RegExp(r'Product ID:\s*(\d+)\s*\|\s*Qty:\s*(\d+)', caseSensitive: false);
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
        } else {
          newMessage = message.replaceFirst("Qty:", "Quantity:");
        }
      }
    } else {
      
      if (message.contains("qty")) {
        newMessage = message.replaceAll("qty", "Quantity");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ===== Header =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return Stack(
                        children: [
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.error, color: Colors.orange, size: 30), // ⚠️ Yellow exclamation
                              title: Text(
                                n["message"] ?? "No message",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                _formatDate(n["createdAt"]),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () => _deleteNotification(n["id"]),
                              splashRadius: 18,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
