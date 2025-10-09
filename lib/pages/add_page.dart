import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_applicationtest/database_helper.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  String selectedCategory = 'Pork';
  List<String> categories = [];
  String? selectedProductName;
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<String> productsForSelectedCategory = [];

  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();


  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Pick image from gallery
  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Save product
  Future<void> _saveProduct() async {
  String? productName = selectedProductName?.trim();
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

    Navigator.pop(context); // <-- Return to InventoryPage inside MainNavigation
  }

  @override
  Widget build(BuildContext context) {
    // Initialize categories and product names once
    if (categories.isEmpty) {
      dbHelper.fetchCategories().then((f) {
        if (!mounted) return;
        setState(() {
          categories = f;
          if (categories.isNotEmpty && !categories.contains(selectedCategory)) selectedCategory = categories.first;
        });
        // load product names for the selected category
        dbHelper.fetchProductNamesForCategory(selectedCategory).then((p) {
          if (!mounted) return;
          setState(() {
            productsForSelectedCategory = p;
            selectedProductName = productsForSelectedCategory.isNotEmpty ? productsForSelectedCategory.first : null;
          });
        });
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                      Navigator.pop(context); 
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
                      // Category Dropdown
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
                              // fetch updated product names for the selected category
                              dbHelper.fetchProductNamesForCategory(selectedCategory).then((p) {
                                if (!mounted) return;
                                setState(() {
                                  productsForSelectedCategory = p;
                                  selectedProductName = productsForSelectedCategory.isNotEmpty ? productsForSelectedCategory.first : null;
                                });
                              });
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // Product Name
                      const Text("Product Name",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final availableProducts = productsForSelectedCategory;
                        // Ensure a default selection exists
                        if (selectedProductName == null && availableProducts.isNotEmpty) {
                          selectedProductName = availableProducts.first;
                        } else if (!availableProducts.contains(selectedProductName)) {
                          // If the current selection isn't in the newly selected category, reset
                          selectedProductName = availableProducts.isNotEmpty ? availableProducts.first : null;
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedProductName,
                              isExpanded: true,
                              hint: const Text('Select product'),
                              items: availableProducts.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedProductName = newValue;
                                });
                              },
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Product Image
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
      ),
    );
  }
}
