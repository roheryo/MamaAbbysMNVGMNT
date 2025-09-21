import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Helper widget for clickable options
  Widget _buildOption({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setInnerState) {
        return MouseRegion(
          onEnter: (_) => setInnerState(() => isHovered = true),
          onExit: (_) => setInnerState(() => isHovered = false),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isHovered ? Colors.blue.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // align text left
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHovered ? Colors.blue : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
              vertical: 16,
            ),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: const [
                Icon(Icons.settings, color: Colors.blue, size: 28),
                SizedBox(width: 12),
                Text(
                  "SETTINGS",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== Options aligned to the left =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // align children left
                children: [
                  _buildOption(
                    title: "Edit Prices",
                    subtitle: "Manage Product Prices",
                    onTap: () {
                      print("Edit Prices clicked");
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => EditPricesPage()));
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    title: "Logout",
                    subtitle: "Sign out in your account",
                    onTap: () {
                      print("Logout clicked");
                      // Implement logout logic here
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
