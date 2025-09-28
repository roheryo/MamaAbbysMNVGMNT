import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ for date formatting
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
    setState(() {});
    // Mark as read after loading
    await db.markAllNotificationsRead();
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
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                const Text(
                  "Notifications",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(n["message"] ?? "No message"),
                          subtitle: Text(
                            _formatDate(n["createdAt"]),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
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
