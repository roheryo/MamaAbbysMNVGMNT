import 'package:flutter/material.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  bool isHoverInventory = false;
  bool isHoverSales = false;
  bool isHoverDelivery = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Column(
        children: [
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
                              "Welcome To Sales",
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
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      color: Colors.blue,
                      iconSize: 24,
                      onPressed: () {
                        print("Notifications clicked");
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: const Icon(Icons.settings),
                        color: Colors.blue,
                        iconSize: 24,
                        onPressed: () {
                          print("Settings clicked");
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== YOUR SALES CONTENT HERE =====
          Expanded(
            child: Center(
              child: Text(
                "Sales Content Goes Here",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              ),
            ),
          ),

          // ===== BOTTOM NAVIGATION ICONS =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Inventory
                Expanded(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => isHoverInventory = true),
                    onExit: (_) => setState(() => isHoverInventory = false),
                    child: GestureDetector(
                      onTap: () {
                        print("Inventory clicked");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory,
                            size: 30,
                            color: isHoverInventory
                                ? Colors.blueAccent
                                : Colors.blue,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Inventory",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sales
                Expanded(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => isHoverSales = true),
                    onExit: (_) => setState(() => isHoverSales = false),
                    child: GestureDetector(
                      onTap: () {
                        print("Sales clicked");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 30,
                            color: isHoverSales
                                ? Colors.greenAccent
                                : Colors.green,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Sales",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Delivery
                Expanded(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => isHoverDelivery = true),
                    onExit: (_) => setState(() => isHoverDelivery = false),
                    child: GestureDetector(
                      onTap: () {
                        print("Delivery clicked");
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 30,
                            color: isHoverDelivery
                                ? Colors.orangeAccent
                                : Colors.orange,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Delivery",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
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
