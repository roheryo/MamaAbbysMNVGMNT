import 'package:flutter/material.dart';
import 'package:flutter_applicationtest/pages/notification_page.dart';
import 'package:flutter_applicationtest/pages/settings_page.dart';
import 'package:flutter_applicationtest/database_helper.dart';
import 'package:intl/intl.dart';


import '../services/forecast_service.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  
  String selectedFilter = "Today";
  bool hasUnread = false;

  
  DateTime? selectedDate; 
  DateTime? selectedWeek; 
  DateTime? selectedMonth; 
 
  double totalSales = 0.0;
  bool isLoading = false;
  List<Map<String, dynamic>> transactions = [];
  
  bool isForecastLoading = false;
  List<DailyForecast> forecasts = [];
  List<Map<String, dynamic>> recentHistory = [];

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

  Future<void> _fetchForecast() async {
    setState(() => isForecastLoading = true);
    try {
      final data = await ForecastService().forecastNext30Days();
      // Also fetch recent historical totals for charting
      final hist = await DatabaseHelper().fetchStoreSales();
      if (!mounted) return;
      setState(() {
        forecasts = data;
        recentHistory = hist;
        isForecastLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        forecasts = [];
        recentHistory = [];
        isForecastLoading = false;
      });
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
                        } else if (filter == "Forecast") {
                          await _fetchForecast();
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
              }).toList()
                ..add(
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedFilter == 'Forecast' ? Colors.blue : Colors.grey.shade200,
                          foregroundColor: selectedFilter == 'Forecast' ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          setState(() {
                            selectedFilter = 'Forecast';
                          });
                          await _fetchForecast();
                        },
                        child: const Text('Forecast', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
            ),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [],
            ),
          ),

          const SizedBox(height: 20),

          // Filter
          if (selectedFilter != 'Forecast') Padding(
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

          if (selectedFilter != 'Forecast') const SizedBox(height: 12),

          // Transactions header
          if (selectedFilter != 'Forecast') Padding(
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

          if (selectedFilter != 'Forecast') const SizedBox(height: 8),

          // Transactions list
          if (selectedFilter != 'Forecast') Expanded(
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

          if (selectedFilter == 'Forecast')
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isForecastLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : forecasts.isEmpty
                        ? const Center(
                            child: Text(
                              'No forecast available. Ensure sales data exists.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue, width: 1),
                                ),
                                child: const Text(
                                  '30-Day Sales Forecast (auto-refreshes daily based on latest sales)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Chart area: show recent history (last 60 days) + 30-day forecast
                              SizedBox(
                                height: 260,
                                child: Card(
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: LineChart(
                                      LineChartData(
                                        gridData: FlGridData(show: true),
                                        titlesData: FlTitlesData(
                                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        lineBarsData: _buildChartSeries(recentHistory, forecasts),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: forecasts.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final f = forecasts[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(DateFormat('MMM dd, yyyy').format(f.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: Text(
                                        '₱${f.predictedSales.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: isForecastLoading ? null : _fetchForecast,
                                  icon: isForecastLoading
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.refresh),
                                  label: Text(isForecastLoading ? 'Refreshing...' : 'Refresh Forecast'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
        ],
      ),
    );
  }

  List<LineChartBarData> _buildChartSeries(List<Map<String, dynamic>> history, List<DailyForecast> forecast) {
    // Convert history rows (descending by default from DB) to ascending date order
    final hist = [...history];
    hist.sort((a, b) => (a['sale_date'] as String).compareTo(a['sale_date'] as String));

    // Only keep last N days for chart clarity
    final int keep = 60;
    final histTrim = hist.length > keep ? hist.sublist(hist.length - keep) : hist;

    final List<FlSpot> histSpots = [];
    double x = 0.0;
    for (final r in histTrim) {
      final s = (r['sales'] as num?)?.toDouble() ?? 0.0;
      histSpots.add(FlSpot(x, s));
      x += 1.0;
    }

    // forecast spots continue the x axis
    final List<FlSpot> foreSpots = [];
    for (int i = 0; i < forecast.length; i++) {
      foreSpots.add(FlSpot(x + i.toDouble(), forecast[i].predictedSales));
    }

    final historyLine = LineChartBarData(
      spots: histSpots,
      isCurved: true,
      color: Colors.blue,
      barWidth: 2,
      dotData: FlDotData(show: false),
    );

    final forecastLine = LineChartBarData(
      spots: foreSpots,
      isCurved: true,
      color: Colors.red,
      barWidth: 2,
      dashArray: [6, 3],
      dotData: FlDotData(show: false),
    );

    return [historyLine, forecastLine];
  }
}
