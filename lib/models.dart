/// Product from the shared catalog (products + supplier_products + suppliers + categories).
class Product {
  final String id;
  final String? categoryId;
  final String name;
  final int baseWeightGr;
  final String? imageUrl;

  // Joined data
  final String? categoryName;
  final double supplierPrice;
  final String? supplierName;
  final double supplierRating;
  final String? grade;

  const Product({
    required this.id,
    required this.name,
    this.categoryId,
    this.baseWeightGr = 0,
    this.imageUrl,
    this.categoryName,
    this.supplierPrice = 0,
    this.supplierName,
    this.supplierRating = 0,
    this.grade,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Nested join: categories
    final category = json['categories'] as Map<String, dynamic>?;

    // Nested join: supplier_products → suppliers
    double price = 0;
    String? sName;
    double sRating = 0;
    String? sGrade;

    final spList = json['supplier_products'];
    if (spList is List && spList.isNotEmpty) {
      final sp = spList.first as Map<String, dynamic>;
      price = (sp['price'] as num?)?.toDouble() ?? 0;
      sGrade = sp['grade'] as String?;

      final supplier = sp['suppliers'] as Map<String, dynamic>?;
      if (supplier != null) {
        sName = supplier['name'] as String?;
        sRating = (supplier['rating'] as num?)?.toDouble() ?? 0;
      }
    }

    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      name: (json['name'] ?? '') as String,
      baseWeightGr: (json['base_weight_gr'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      categoryName: category?['name'] as String?,
      supplierPrice: price,
      supplierName: sName,
      supplierRating: sRating,
      grade: sGrade,
    );
  }
}

/// User's own inventory item.
class InventoryItem {
  final String id;
  final String name;
  final int qtyAvailable;
  final double capitalPrice;
  final double sellingPrice;
  final DateTime? expDate;

  const InventoryItem({
    required this.id,
    required this.name,
    this.qtyAvailable = 0,
    this.capitalPrice = 0,
    this.sellingPrice = 0,
    this.expDate,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      qtyAvailable: (json['qty_available'] as num?)?.toInt() ?? 0,
      capitalPrice: (json['capital_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
      expDate: json['exp_date'] != null
          ? DateTime.tryParse(json['exp_date'].toString())
          : null,
    );
  }
}

/// Product category from the categories table.
class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
    );
  }
}
