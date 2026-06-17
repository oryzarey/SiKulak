import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'cart_manager.dart';
import 'product_detail_page.dart';

class ProductSearchPage extends StatefulWidget {
  const ProductSearchPage({super.key});

  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _wishlistItems = {};
  
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  String? _selectedCategoryId; // null = "Semua Kategori"
  String _sortBy = 'name'; // 'name', 'price_asc', 'price_desc', 'rating'
  String? _selectedBrand;
  String? _selectedSupplier;
  List<Map<String, String>> _supplierNames = []; // [{id, name}]
  Map<String, Set<String>> _supplierProductMap = {}; // supplierId -> Set<productId>
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await supabase.from('categories').select().order('sort_order').order('name');
      if (mounted) {
        setState(() {
          _categories = (data as List).map((j) => Category.fromJson(j)).toList();
        });
      }
    } catch (e) {
      debugPrint('[SiKulak] Error loading categories: $e');
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _searchController.text.trim();
      var req = supabase.from('products').select('*, categories(id, name)');
      
      if (query.isNotEmpty) {
        req = req.ilike('name', '%$query%');
      }

      final data = await req;
      if (!mounted) return;

      final list = data as List;
      final parsed = list.map((j) => Product.fromJson(j)).toList();

      // Load supplier data for Toko filter
      try {
        final spData = await supabase
            .from('supplier_products')
            .select('product_id, supplier_id, suppliers(id, name)');
        final spList = (spData as List).cast<Map<String, dynamic>>();
        
        final Map<String, String> supplierIdToName = {};
        final Map<String, Set<String>> supProdMap = {};
        
        for (final sp in spList) {
          final productId = sp['product_id']?.toString() ?? '';
          final supplierObj = sp['suppliers'] as Map<String, dynamic>?;
          final supplierId = supplierObj?['id']?.toString() ?? sp['supplier_id']?.toString() ?? '';
          final supplierName = supplierObj?['name']?.toString() ?? '';
          
          if (supplierId.isEmpty || supplierName.isEmpty) continue;
          supplierIdToName[supplierId] = supplierName;
          supProdMap.putIfAbsent(supplierId, () => {}).add(productId);
        }
        
        if (mounted) {
          _supplierNames = supplierIdToName.entries
              .map((e) => {'id': e.key, 'name': e.value})
              .toList()
            ..sort((a, b) => a['name']!.compareTo(b['name']!));
          _supplierProductMap = supProdMap;
        }
      } catch (e) {
        debugPrint('[SiKulak] Error loading supplier data for filter: $e');
      }

      setState(() {
        _products = parsed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SiKulak] Error loading products: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat produk: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ── FILTERED & SORTED PRODUCTS ────────────────────────────
  List<Product> get _filteredProducts {
    List<Product> result = List.from(_products);

    // 1. Filter by category
    if (_selectedCategoryId != null) {
      // Find the selected category object to get both id and name
      final selectedCat = _categories.cast<Category?>().firstWhere(
        (c) => c!.id == _selectedCategoryId,
        orElse: () => null,
      );
      final catName = selectedCat?.name.toLowerCase() ?? '';
      final catId = _selectedCategoryId!;

      result = result.where((p) {
        if (p.categoryId.isNotEmpty && p.categoryId == catId) return true;
        if (catName.isNotEmpty && p.categoryName.toLowerCase() == catName) return true;
        return false;
      }).toList();
    }

    // 2. Filter by brand
    if (_selectedBrand != null) {
      result = result.where((p) => p.brand.toLowerCase() == _selectedBrand!.toLowerCase()).toList();
    }

    // 3. Filter by supplier/toko
    if (_selectedSupplier != null) {
      final productIdsForSupplier = _supplierProductMap[_selectedSupplier] ?? {};
      result = result.where((p) => productIdsForSupplier.contains(p.id)).toList();
    }

    // 3. Sorting
    if (_sortBy == 'price_asc') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_desc') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'rating') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    } else {
      // Default: sort alphabetically by name
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return result;
  }

  // ── BRAND FILTER DIALOG ────────────────────────────────────
  void _showBrandFilterDialog() {
    final uniqueBrands = _products
        .map((p) => p.brand)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueBrands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada pilihan merk produk.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Brand / Merk'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: uniqueBrands.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text('Semua Brand', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _selectedBrand == null,
                  onTap: () {
                    setState(() => _selectedBrand = null);
                    Navigator.pop(ctx);
                  },
                );
              }
              final brand = uniqueBrands[index - 1];
              return ListTile(
                title: Text(brand),
                selected: _selectedBrand == brand,
                onTap: () {
                  setState(() => _selectedBrand = brand);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ── SUPPLIER / TOKO FILTER DIALOG ──────────────────────────────
  void _showSupplierFilterDialog() {
    if (_supplierNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data toko/supplier.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Toko / Supplier'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _supplierNames.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  title: const Text('Semua Toko', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _selectedSupplier == null,
                  onTap: () {
                    setState(() => _selectedSupplier = null);
                    Navigator.pop(ctx);
                  },
                );
              }
              final supplier = _supplierNames[index - 1];
              return ListTile(
                leading: const Icon(Icons.storefront_rounded, size: 20),
                title: Text(supplier['name'] ?? ''),
                selected: _selectedSupplier == supplier['id'],
                onTap: () {
                  setState(() => _selectedSupplier = supplier['id']);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('shampoo') || name.contains('sampo')) {
      return Icons.shower_rounded;
    }
    if (name.contains('sabun') || name.contains('soap')) {
      return Icons.soap_rounded;
    }
    if (name.contains('perawatan') || name.contains('care') || name.contains('kosmetik')) {
      return Icons.face_retouching_natural_rounded;
    }
    if (name.contains('minuman') || name.contains('drink') || name.contains('jus') || name.contains('kopi')) {
      return Icons.local_drink_rounded;
    }
    if (name.contains('makanan') || name.contains('food') || name.contains('mi ') || name.contains('mie')) {
      return Icons.fastfood_rounded;
    }
    if (name.contains('snack') || name.contains('cemilan') || name.contains('biskuit') || name.contains('roti')) {
      return Icons.cookie_rounded;
    }
    if (name.contains('kebersihan')) {
      return Icons.cleaning_services_rounded;
    }
    if (name.contains('detergen') || name.contains('detergent')) {
      return Icons.local_laundry_service_rounded;
    }
    if (name.contains('bahan pokok') || name.contains('sembako')) {
      return Icons.rice_bowl_rounded;
    }
    return Icons.category_rounded;
  }

  Color _getCategoryColor(String categoryName, bool isSelected) {
    if (isSelected) {
      return const Color(0xFF2979FF);
    }
    final name = categoryName.toLowerCase();
    if (name.contains('shampoo') || name.contains('sampo') || name.contains('sabun') || name.contains('soap')) {
      return const Color(0xFFE0F2FE);
    }
    if (name.contains('perawatan') || name.contains('care') || name.contains('kosmetik')) {
      return const Color(0xFFFCE7F3);
    }
    if (name.contains('minuman') || name.contains('drink') || name.contains('jus') || name.contains('kopi')) {
      return const Color(0xFFFEF3C7);
    }
    if (name.contains('makanan') || name.contains('food') || name.contains('mi ') || name.contains('mie') || name.contains('snack')) {
      return const Color(0xFFD1FAE5);
    }
    if (name.contains('kebersihan')) {
      return const Color(0xFFCCFBF1);
    }
    if (name.contains('detergen') || name.contains('detergent')) {
      return const Color(0xFFE0E7FF);
    }
    if (name.contains('bahan pokok') || name.contains('sembako')) {
      return const Color(0xFFFFEDD5);
    }
    return const Color(0xFFF1F5F9);
  }

  Color _getCategoryIconColor(String categoryName, bool isSelected) {
    if (isSelected) {
      return Colors.white;
    }
    final name = categoryName.toLowerCase();
    if (name.contains('shampoo') || name.contains('sampo') || name.contains('sabun') || name.contains('soap')) {
      return const Color(0xFF0284C7);
    }
    if (name.contains('perawatan') || name.contains('care') || name.contains('kosmetik')) {
      return const Color(0xFFDB2777);
    }
    if (name.contains('minuman') || name.contains('drink') || name.contains('jus') || name.contains('kopi')) {
      return const Color(0xFFD97706);
    }
    if (name.contains('makanan') || name.contains('food') || name.contains('mi ') || name.contains('mie') || name.contains('snack')) {
      return const Color(0xFF059669);
    }
    if (name.contains('kebersihan')) {
      return const Color(0xFF0D9488);
    }
    if (name.contains('detergen') || name.contains('detergent')) {
      return const Color(0xFF4338CA);
    }
    if (name.contains('bahan pokok') || name.contains('sembako')) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─────────── PREMIUM APP BAR WITH SEARCH (Gambar 1) ───────────
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            toolbarHeight: 120,
            automaticallyImplyLeading: false,
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2979FF), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    // Back button in circular background
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Pill-shaped search field
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _loadProducts(),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: 'Hari ini beli apa?',
                                  hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─────────── HORIZONTAL FILTER CHIPS (Gambar 1) ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                     // Filter / Reset button
                    _buildFilterChip(
                      label: 'Filter',
                      icon: Icons.tune,
                      isSelected: _sortBy != 'name' || _selectedBrand != null || _selectedSupplier != null,
                      onTap: () {
                        setState(() {
                          _sortBy = 'name';
                          _selectedBrand = null;
                          _selectedSupplier = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // Rating sort
                    _buildFilterChip(
                      label: 'Rating',
                      icon: Icons.star_rounded,
                      isSelected: _sortBy == 'rating',
                      onTap: () {
                        setState(() => _sortBy = _sortBy == 'rating' ? 'name' : 'rating');
                      },
                    ),
                    const SizedBox(width: 8),
                    // Price sort
                    _buildFilterChip(
                      label: _sortBy == 'price_asc'
                          ? 'Harga (Murah)'
                          : _sortBy == 'price_desc'
                              ? 'Harga (Mahal)'
                              : 'Harga',
                      icon: Icons.swap_vert_rounded,
                      isSelected: _sortBy == 'price_asc' || _sortBy == 'price_desc',
                      onTap: () {
                        setState(() {
                          if (_sortBy == 'price_asc') {
                            _sortBy = 'price_desc';
                          } else if (_sortBy == 'price_desc') {
                            _sortBy = 'name';
                          } else {
                            _sortBy = 'price_asc';
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // Toko / Supplier
                    _buildFilterChip(
                      label: _selectedSupplier != null
                          ? (_supplierNames.firstWhere(
                              (s) => s['id'] == _selectedSupplier,
                              orElse: () => {'name': 'Toko'},
                            )['name'] ?? 'Toko')
                          : 'Toko',
                      icon: Icons.storefront_rounded,
                      isSelected: _selectedSupplier != null,
                      onTap: _showSupplierFilterDialog,
                    ),
                    const SizedBox(width: 8),
                    // Brand / Merk
                    _buildFilterChip(
                      label: _selectedBrand ?? 'Brand',
                      icon: Icons.sell_outlined,
                      isSelected: _selectedBrand != null,
                      onTap: _showBrandFilterDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─────────── HORIZONTAL CATEGORY CIRCLES (Gambar 1) ───────────
          SliverToBoxAdapter(
            child: Container(
              height: 100,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final category = isAll ? null : _categories[index - 1];
                  final isSelected = isAll 
                      ? _selectedCategoryId == null 
                      : _selectedCategoryId == category!.id;

                  final catName = isAll ? 'Semua' : category!.name;
                  final iconData = isAll ? Icons.grid_view_rounded : _getCategoryIcon(catName);
                  final circleBgColor = isAll
                      ? (isSelected ? const Color(0xFF2979FF) : const Color(0xFFE0E7FF))
                      : _getCategoryColor(catName, isSelected);
                  final iconColor = isAll
                      ? (isSelected ? Colors.white : const Color(0xFF4F46E5))
                      : _getCategoryIconColor(catName, isSelected);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = isAll ? null : category!.id;
                      });
                    },
                    child: Container(
                      width: 76,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE8EFFF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2979FF) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: circleBgColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              iconData,
                              color: iconColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isAll ? 'Semua' : category!.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ─────────── PRODUCTS GRID (Gambar 1) ───────────
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(color: Color(0xFF2979FF)),
                ),
              ),
            )
          else if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red[300], size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            )
          else if (filteredList.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(50),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, color: Colors.grey[300], size: 56),
                      const SizedBox(height: 12),
                      Text('Tidak ada produk ditemukan.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = filteredList[index];
                    final isWish = _wishlistItems.contains(product.id);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailPage(product: product),
                            ),
                          ).then((_) => _loadProducts());
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image & Price tag & Heart icon
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Image
                                  Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                        ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                                        : const Center(
                                            child: Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFFCBD5E1)),
                                          ),
                                  ),
                                  // Heart Icon (Top Right)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isWish) {
                                            _wishlistItems.remove(product.id);
                                          } else {
                                            _wishlistItems.add(product.id);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isWish ? Icons.favorite : Icons.favorite_border_rounded,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Price Tag Badge (Bottom Left)
                                  Positioned(
                                    bottom: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2979FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        CartManager.formatPrice(product.price),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Product Details (Star & Name)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
                                      const SizedBox(width: 2),
                                      Text(
                                        product.rating.toString(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filteredList.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2979FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2979FF) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
