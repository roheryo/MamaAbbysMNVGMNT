import 'package:flutter/material.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool isHoverInventory = false;
  bool isHoverSales = false;
  bool isHoverDelivery = false;

  // For dropdown filter
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Electronics', 'Food', 'Clothing'];

  // Sample product data
  final List<Map<String, dynamic>> products = [
    {
      'name': 'Product 1',
      'stock': 10,
      'price': 150,
      'image': 'assets/images/product1.jpg',
    },
    {
      'name': 'Product 2',
      'stock': 5,
      'price': 250,
      'image': 'assets/images/product2.jpg',
    },
    {
      'name': 'Product 3',
      'stock': 20,
      'price': 100,
      'image': 'assets/images/product3.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Column(
        children: [
          // Header
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
                              "INVENTORY",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Welcome To Inventory",
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

                // Notification & Settings Icons
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

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                print("Search input: $value");
              },
            ),
          ),

          const SizedBox(height: 16),

          // All Categories and Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "All Categories",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: selectedCategory,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedCategory = newValue;
                        print("Selected Category: $selectedCategory");
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Scrollable products list container
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Left Column with product name, stock, price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "In Stock: ${product['stock']} | Price: \$${product['price']}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          // Placeholder square for product image
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade500),
                            ),
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Sell button
                          ElevatedButton(
                            onPressed: () {
                              print("Sell ${product['name']}");
                            },
                            child: const Text("Sell"),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom Row of clickable icons
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
                              color: isHoverInventory
                                  ? Colors.black
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
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
                              color: isHoverSales ? Colors.black : Colors.black,
                              fontWeight: FontWeight.bold,
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
                              color: isHoverDelivery
                                  ? Colors.black
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
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
