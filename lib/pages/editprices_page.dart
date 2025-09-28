import 'package:flutter/material.dart';
import '../database_helper.dart';

class EditpricesPage extends StatefulWidget {
  const EditpricesPage({super.key});

  @override
  State<EditpricesPage> createState() => _EditPricesPage();
}

class _EditPricesPage extends State<EditpricesPage> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<String> categories = [];
  String? selectedCategory;
  int? selectedProductId;

  List<Map<String, dynamic>> products = [];
  Map<String, dynamic>? selectedProduct;
  final TextEditingController priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    final productList = await dbHelper.fetchProducts();
    final uniqueCategories =
        productList.map((p) => p['category'].toString()).toSet().toList();
    setState(() {
      categories = uniqueCategories;
    });
  }

  Future<void> loadProductsByCategory(String category) async {
    final productList = await dbHelper.fetchProducts(category: category);
    setState(() {
      products = productList;
      selectedProductId = null;
      selectedProduct = null;
      priceController.clear();
    });
  }

  Future<void> updateProductPrice() async {
    if (selectedProductId != null && priceController.text.isNotEmpty) {
      final newPrice = double.tryParse(priceController.text);
      if (newPrice != null) {
        await dbHelper.updateProduct(selectedProductId!, {
          'unitPrice': newPrice,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Price of ${selectedProduct!['productName']} updated to $newPrice"),
          ),
        );
        // Reload products to reflect change
        loadProductsByCategory(selectedCategory!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please enter a valid number for the price."),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a product and enter a price."),
        ),
      );
    }
  }

  @override
  void dispose() {
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            color: Colors.white,
            child: Row(
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
                const SizedBox(width: 16),
                const Text(
                  "Edit Prices",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Category",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    hint: const Text("Choose a category"),
                    items: categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                        loadProductsByCategory(value!);
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Select Product",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: selectedProductId,
                    hint: const Text("Choose a product"),
                    items: products.map((product) {
                      return DropdownMenuItem<int>(
                        value: product['id'],
                        child: Text(product['productName']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProductId = value;
                        selectedProduct =
                            products.firstWhere((p) => p['id'] == value);
                        priceController.text =
                            selectedProduct!['unitPrice'].toString();
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "New Price",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: "Enter new price",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: updateProductPrice,
                      child: const Text("Update Price"),
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
}
