import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'package:flutter_applicationtest/database_helper.dart';
import 'package:intl/intl.dart';

import 'inventory_page.dart'; // Create this file for InventoryPage
import 'delivery_page.dart'; // Already created earlier

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // Track selected filter
  String selectedFilter = "Today";
  bool hasUnread = false;

  // Track picked dates
  DateTime? selectedDate; // for Today
  DateTime? selectedWeek; // week start
  DateTime? selectedMonth; // month picker

  // Track sales data
  double totalSales = 0.0;
  bool isLoading = false;
  List<Map<String, dynamic>> transactions = [];
  bool isGenerating = false;
  bool isRecomputing = false;

  Future<void> _pickTodayDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      _fetchSalesData();
    }
  }

  Future<void> _pickWeeklyDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedWeek ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      DateTime startOfWeek = picked.subtract(
        Duration(days: picked.weekday - 1),
      );

      setState(() {
        selectedWeek = startOfWeek;
      });

      _fetchSalesData();
    }
  }

  Future<void> _pickMonthlyDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
      _fetchSalesData();
    }
  }

  Future<void> _refreshUnread() async {
    final v = await DatabaseHelper().hasUnreadNotifications();
    if (!mounted) return;
    setState(() => hasUnread = v);
  }

  Future<void> _fetchSalesData() async {
    setState(() => isLoading = true);
    
    try {
      double sales = 0.0;
      String? startDateStr;
      String? endDateStr;
      
      switch (selectedFilter) {
        case "Today":
          if (selectedDate != null) {
            final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
            sales = await DatabaseHelper().getTotalSales(startDate: dateStr, endDate: dateStr);
            startDateStr = dateStr;
            endDateStr = dateStr;
          } else {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            sales = await DatabaseHelper().getTotalSales(startDate: today, endDate: today);
            startDateStr = today;
            endDateStr = today;
          }
          break;
          
        case "Weekly":
          if (selectedWeek != null) {
            final startDate = DateFormat('yyyy-MM-dd').format(selectedWeek!);
            final endDate = DateFormat('yyyy-MM-dd').format(selectedWeek!.add(const Duration(days: 6)));
            sales = await DatabaseHelper().getTotalSales(startDate: startDate, endDate: endDate);
            startDateStr = startDate;
            endDateStr = endDate;
          }
          break;
          
        case "Monthly":
          if (selectedMonth != null) {
            final startDate = DateFormat('yyyy-MM-dd').format(selectedMonth!);
            final endDate = DateFormat('yyyy-MM-dd').format(
              DateTime(selectedMonth!.year, selectedMonth!.month + 1, 0)
            );
            sales = await DatabaseHelper().getTotalSales(startDate: startDate, endDate: endDate);
            startDateStr = startDate;
            endDateStr = endDate;
          }
          break;
      }
      
      // Fetch detailed transactions for the selected range
      List<Map<String, dynamic>> txns = [];
      if (startDateStr != null && endDateStr != null) {
        txns = await DatabaseHelper().fetchSalesTransactionsWithCategory(
          startDate: startDateStr,
          endDate: endDateStr,
        );
      }

      if (mounted) {
        setState(() {
          totalSales = sales;
          transactions = txns;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          totalSales = 0.0;
          transactions = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _generateDemoSales() async {
    if (isGenerating) return;
    setState(() {
      isGenerating = true;
    });
    try {
      final helper = DatabaseHelper();
      final before = await helper.getSalesTransactionsCount();
      final created = await helper.ensureHistoricalData(minTransactions: 500);
      final after = await helper.getSalesTransactionsCount();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${created > 0 ? created : (after - before)} transactions. Total: $after'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      await _fetchSalesData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate demo sales: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  Future<void> _recomputeDailyTotals() async {
    if (isRecomputing) return;
    setState(() {
      isRecomputing = true;
    });
    try {
      await DatabaseHelper().recomputeAllStoreSales();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recomputed daily totals from sales transactions'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      await _fetchSalesData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recompute failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isRecomputing = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    _fetchSalesData();
  }


  // ===== Helper Widget for Bottom Navigation =====
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
            Icon(icon, size: 30, color: color), // icon keeps its color
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
                        color: Colors.black, // label always black
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // label always black
                    ),
                  ),
          ],
        ),
      ),
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
                              "SALES",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Manage Sales",
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
                          Navigator.pushReplacement(
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

          const SizedBox(height: 12),

          // Filter Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ["Today", "Weekly", "Monthly"].map((filter) {
                final isSelected = selectedFilter == filter;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.blue
                            : Colors.grey.shade200,
                        foregroundColor: isSelected
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        setState(() {
                          selectedFilter = filter;
                        });

                        if (filter == "Today") {
                          await _pickTodayDate(context);
                        } else if (filter == "Weekly") {
                          await _pickWeeklyDate(context);
                        } else if (filter == "Monthly") {
                          await _pickMonthlyDate(context);
                        }
                        
                        // Fetch sales data after filter change
                        _fetchSalesData();
                      },
                      child: Text(
                        filter,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: isRecomputing ? null : _recomputeDailyTotals,
                  icon: isRecomputing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: Text(isRecomputing ? 'Recomputing...' : 'Recompute Daily Totals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : _generateDemoSales,
                  icon: isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.history),
                  label: Text(isGenerating ? 'Generating...' : 'Generate 500+ Demo Sales'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Loading sales data...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      selectedFilter == "Today" && selectedDate != null
                          ? "Sales on ${DateFormat('MMM dd, yyyy').format(selectedDate!)}: ₱${totalSales.toStringAsFixed(2)}"
                          : selectedFilter == "Weekly" && selectedWeek != null
                          ? "Sales for week of ${DateFormat('MMM dd').format(selectedWeek!)}: ₱${totalSales.toStringAsFixed(2)}"
                          : selectedFilter == "Monthly" && selectedMonth != null
                          ? "Sales for ${DateFormat('MMMM yyyy').format(selectedMonth!)}: ₱${totalSales.toStringAsFixed(2)}"
                          : selectedFilter == "Today"
                          ? "Total Daily Sales: ₱${totalSales.toStringAsFixed(2)}"
                          : selectedFilter == "Weekly"
                          ? "Total Weekly Sales: ₱${totalSales.toStringAsFixed(2)}"
                          : "Total Monthly Sales: ₱${totalSales.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Transactions header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedFilter == "Today" && (selectedDate != null)
                    ? "Transactions on ${DateFormat('MMMM dd, yyyy').format(selectedDate!)}"
                    : selectedFilter == "Today"
                    ? "Transactions on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}"
                    : selectedFilter == "Weekly" && selectedWeek != null
                    ? "Transactions for week of ${DateFormat('MMM dd').format(selectedWeek!)}"
                    : selectedFilter == "Monthly" && selectedMonth != null
                    ? "Transactions for ${DateFormat('MMMM yyyy').format(selectedMonth!)}"
                    : "Transactions",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Transactions list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : transactions.isEmpty
                      ? const Center(
                          child: Text(
                            "No transactions found.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      : ListView.separated(
                          itemCount: transactions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            final name = (t['productName'] ?? '').toString();
                            final category = (t['category'] ?? 'Unknown').toString();
                            final qty = (t['quantity'] as num?)?.toInt() ?? 0;
                            final total = (t['totalAmount'] as num?)?.toDouble() ?? 0.0;
                            final saleDateRaw = t['saleDate']?.toString();
                            DateTime? saleDt = DateTime.tryParse(saleDateRaw ?? '');
                            final dateTimeLabel = saleDt != null
                                ? DateFormat('MMM dd, yyyy, hh:mm a').format(saleDt)
                                : '';

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                dateTimeLabel.isNotEmpty
                                    ? "$category • $dateTimeLabel"
                                    : category,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("x$qty"),
                                  Text(
                                    "₱${total.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),

          // ===== Bottom Navigation =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  icon: Icons.inventory,
                  label: "Inventory",
                  isActive: false,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const InventoryPage()),
                    );
                  },
                ),
                _buildNavItem(
                  icon: Icons.bar_chart,
                  label: "Sales",
                  isActive: true,
                  color: Colors.green,
                  onTap: () {},
                ),
                _buildNavItem(
                  icon: Icons.local_shipping,
                  label: "Delivery",
                  isActive: false,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DeliveryPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
