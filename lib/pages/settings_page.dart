import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/editprices_page.dart';
import 'package:flutter_applicationtest/database_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseHelper db = DatabaseHelper();
 
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
                _performLogout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  
  void _performLogout() {
    
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (Route<dynamic> route) => false,
    );
  }

  
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
                crossAxisAlignment: CrossAxisAlignment.start, 
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

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Category name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.isNotEmpty) Navigator.of(context).pop(true);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final name = ctrl.text.trim();
      await db.insertCategory(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Category "$name" added')));
    }
  }

  Future<void> _showAddProductNameDialog() async {
    final TextEditingController categoryCtrl = TextEditingController();
    final TextEditingController nameCtrl = TextEditingController();

    // Pre-fill category list by fetching from DB
    final categories = await db.fetchCategories();
    String? selected = categories.isNotEmpty ? categories.first : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Product Name'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (categories.isNotEmpty)
                  DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => selected = v),
                  )
                else
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(hintText: 'Category')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Product name')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if ((selected != null && selected!.trim().isNotEmpty) || categoryCtrl.text.trim().isNotEmpty) {
                    if (nameCtrl.text.trim().isNotEmpty) Navigator.of(context).pop(true);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );

    if (result == true) {
      final category = categories.isNotEmpty ? (selected ?? categoryCtrl.text.trim()) : categoryCtrl.text.trim();
      final name = nameCtrl.text.trim();
      if (category.isNotEmpty && name.isNotEmpty) {
        await db.insertCategory(category);
        await db.insertCustomProductName(category: category, name: name);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product "$name" added to $category')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea( 
        child: Column(
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
                children: [
                 
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); 
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
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

           
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, 
                  children: [
                    _buildOption(
                      title: "Edit Prices",
                      subtitle: "Manage Product Prices",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditpricesPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildOption(
                      title: "Add Category",
                      subtitle: "Add a new product category",
                      onTap: () {
                        _showAddCategoryDialog();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildOption(
                      title: "Add Product Name",
                      subtitle: "Add a new product name under a category",
                      onTap: () {
                        _showAddProductNameDialog();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildOption(
                      title: "Logout",
                      subtitle: "Sign out in your account",
                      onTap: () {
                        _showLogoutDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
