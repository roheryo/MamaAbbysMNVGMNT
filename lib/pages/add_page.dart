import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_applicationtest/database_helper.dart';
import 'inventory_page.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPage();
}

class _AddPage extends State<AddPage> {
  String selectedCategory = 'Pork';
  List<String> categories = [];
  String? selectedProductName;
  List<String> productOptions = [];

  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();

  final DatabaseHelper dbHelper = DatabaseHelper();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Pick Image
  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Save Product
  Future<void> _saveProduct() async {
    String? productName = selectedProductName;
    String quantity = quantityController.text.trim();
    String unitPrice = unitPriceController.text.trim();

    if (productName == null || productName.isEmpty || quantity.isEmpty || unitPrice.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    await dbHelper.insertOrAccumulateProduct(
      productName: productName,
      category: selectedCategory,
      quantity: int.parse(quantity),
      unitPrice: double.parse(unitPrice),
      imagePath: _selectedImage?.path,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Product added successfully!")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const InventoryPage()),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Ensure categories are initialized once (guard if hot-reload)
    if (categories.isEmpty) {
      categories = dbHelper.catalogCategories;
      if (categories.isNotEmpty && !categories.contains(selectedCategory)) {
        selectedCategory = categories.first;
      }
      productOptions = dbHelper.getProductsForCategory(selectedCategory);
      if (productOptions.isNotEmpty) {
        selectedProductName ??= productOptions.first;
      }
    }
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InventoryPage()),
                    );
                  },
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.black,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),
                const Text(
                  "Add Product",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===== Form Container =====
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown for category
                    const Text("Select Product Category",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedCategory,
                      isExpanded: true,
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
                            productOptions = dbHelper.getProductsForCategory(selectedCategory);
                            selectedProductName = productOptions.isNotEmpty ? productOptions.first : null;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Product Name (dependent dropdown)
                    const Text("Product Name",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedProductName,
                      isExpanded: true,
                      hint: const Text("Select product"),
                      items: productOptions.map((String product) {
                        return DropdownMenuItem<String>(
                          value: product,
                          child: Text(product),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedProductName = newValue;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Product Image Picker
                    const Text("Product Image",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade500),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? const Center(
                                child: Icon(Icons.image,
                                    size: 50, color: Colors.grey),
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quantity
                    const Text("Quantity",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter quantity",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Unit Price
                    const Text("Unit Price",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Enter unit price",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Add Product Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProduct,
                        child: const Text("Add Product"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
