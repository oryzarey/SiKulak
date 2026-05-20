import 'package:flutter/material.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<int, int> _cartItems = {}; // productId: quantity
  final Set<int> _wishlistItems = {};
  String _selectedCategory = 'Semua Produk';
  String _searchQuery = '';
  final Set<String> _selectedBrands = {};
  final Set<String> _selectedSuppliers = {};
  late TextEditingController _searchController;

  final List<String> _categories = [
    'Semua Produk',
    'Sabun',
    'Shampoo',
    'Detergen',
    'Pelemen',
  ];

  final List<Product> _products = const [
    Product(
      id: 1,
      name: 'Sabun Mandi Lux',
      price: 120000,
      rating: 4.5,
      reviews: 24,
      category: 'Sabun',
      brand: 'Lux',
      supplier: 'PT Unilever',
    ),
    Product(
      id: 2,
      name: 'Sabun Lifebuoy Mild Care',
      price: 105000,
      rating: 4.6,
      reviews: 32,
      category: 'Sabun',
      brand: 'Lifebuoy',
      supplier: 'PT Unilever',
    ),
    Product(
      id: 3,
      name: 'Shampoo Pantene Pro-V',
      price: 150000,
      rating: 4.0,
      reviews: 18,
      category: 'Shampoo',
      brand: 'Pantene',
      supplier: 'PT Procter Gamble',
    ),
    Product(
      id: 4,
      name: 'Detergen Attack Plus',
      price: 95000,
      rating: 4.8,
      reviews: 45,
      category: 'Detergen',
      brand: 'Attack',
      supplier: 'PT Kao',
    ),
    Product(
      id: 5,
      name: 'Shampoo Sunsilk Black Shine',
      price: 125000,
      rating: 4.4,
      reviews: 28,
      category: 'Shampoo',
      brand: 'Sunsilk',
      supplier: 'PT Unilever',
    ),
    Product(
      id: 6,
      name: 'Sabun Dove Gentle',
      price: 135000,
      rating: 4.7,
      reviews: 31,
      category: 'Sabun',
      brand: 'Dove',
      supplier: 'PT Unilever',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchCategory = _selectedCategory == 'Semua Produk' || product.category == _selectedCategory;
      final matchSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.brand.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchBrand = _selectedBrands.isEmpty || _selectedBrands.contains(product.brand);
      final matchSupplier = _selectedSuppliers.isEmpty || _selectedSuppliers.contains(product.supplier);

      return matchCategory && matchSearch && matchBrand && matchSupplier;
    }).toList();
  }

  Set<String> get _allBrands => _products.map((p) => p.brand).toSet();
  Set<String> get _allSuppliers => _products.map((p) => p.supplier).toSet();

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text('Merk', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _allBrands.map((brand) {
                    final isSelected = _selectedBrands.contains(brand);
                    return FilterChip(
                      label: Text(brand),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _selectedBrands.add(brand);
                        } else {
                          _selectedBrands.remove(brand);
                        }
                        setModalState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _allSuppliers.map((supplier) {
                    final isSelected = _selectedSuppliers.contains(supplier);
                    return FilterChip(
                      label: Text(supplier),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _selectedSuppliers.add(supplier);
                        } else {
                          _selectedSuppliers.remove(supplier);
                        }
                        setModalState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        child: const Text('Tutup', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _selectedBrands.clear();
                          _selectedSuppliers.clear();
                          setState(() {});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text('Reset', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final metadata = user?.userMetadata;
    final userName = (metadata?['nama'] ?? metadata?['name'] ?? user?.email ?? 'User')
        .toString()
        .split('@')
        .first;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header Section ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selamat datang,', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                    _HeaderIcon(icon: Icons.shopping_basket_outlined, onTap: () {}),
                    const SizedBox(width: 10),
                    _HeaderIcon(icon: Icons.notifications_none_outlined, onTap: () {}),
                  ],
                ),
              ),
            ),

            // ── Search & Filter Section (Blue Background) ──────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    // Search Bar dengan Back Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Hari ini beli apa?',
                                hintStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(Icons.search, color: Colors.white),
                                filled: true,
                                fillColor: Colors.blue.withOpacity(0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Filter Chips Row
                    Padding(
                      padding: const EdgeInsets.only(top: 10, left: 16, bottom: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Filter',
                              icon: Icons.tune,
                              onTap: _showFilterModal,
                            ),
                            _FilterChip(label: 'Rating', onTap: () {}),
                            _FilterChip(label: 'Harga', onTap: () {}),
                            _FilterChip(label: 'Toko', onTap: () {}),
                            _FilterChip(label: 'Brand', onTap: () {}),
                            _FilterChip(label: 'Jumlah', onTap: () {}),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category Chips ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, left: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories
                        .map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CategoryChip(
                            label: cat,
                            isSelected: _selectedCategory == cat,
                            onTap: () => setState(() => _selectedCategory = cat),
                          ),
                        ))
                        .toList(),
                  ),
                ),
              ),
            ),

            // ── Promo Banner ────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harga Sabun sedang\nturun sebanyak 30%',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tawaran terbatas. Beli sekarang.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      child: const Text('Beli Sekarang'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Product Grid ────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = _filteredProducts[index];
                    return _ProductCard(
                      product: product,
                      isWishlisted: _wishlistItems.contains(product.id),
                      quantity: _cartItems[product.id] ?? 0,
                      onWishlistTap: () {
                        setState(() {
                          if (_wishlistItems.contains(product.id)) {
                            _wishlistItems.remove(product.id);
                          } else {
                            _wishlistItems.add(product.id);
                          }
                        });
                      },
                      onAddToCart: () {
                        setState(() {
                          _cartItems[product.id] = (_cartItems[product.id] ?? 0) + 1;
                        });
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang')));
                      },
                      onRemoveFromCart: () {
                        setState(() {
                          if ((_cartItems[product.id] ?? 0) > 1) {
                            _cartItems[product.id] = _cartItems[product.id]! - 1;
                          } else {
                            _cartItems.remove(product.id);
                          }
                        });
                      },
                    );
                  },
                  childCount: _filteredProducts.length,
                ),
              ),
            ),

            // ── Bottom Cart Section ────────────────────────
            if (_cartItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                            ),
                            child: const Text('Lihat Belanjaan mu'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _cartItems.values.fold(0, (sum, qty) => sum + qty).toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Rp. ${(_cartItems.entries.fold(0, (sum, entry) => sum + (entry.key * entry.value)) ~/ 1000000).toStringAsFixed(1)}jt',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            SliverToBoxAdapter(child: const SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.home_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.dashboard_outlined), onPressed: () {}),
            const SizedBox(width: 40),
            IconButton(icon: const Icon(Icons.assignment_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.person_outline), onPressed: () {}),
          ],
        ),
      ),
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: () {},
            child: const Icon(Icons.shopping_basket_outlined, color: Colors.blue),
          ),
          if (_cartItems.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(
                  _cartItems.values.fold(0, (sum, qty) => sum + qty).toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.category,
    required this.brand,
    required this.supplier,
  });

  final int id;
  final String name;
  final int price;
  final double rating;
  final int reviews;
  final String category;
  final String brand;
  final String supplier;
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: GestureDetector(onTap: onTap, child: Icon(icon, color: Colors.blue)),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.blue, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.quantity,
    required this.onWishlistTap,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  final Product product;
  final bool isWishlisted;
  final int quantity;
  final VoidCallback onWishlistTap;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Image placeholder
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                  ),
                  child: Center(child: Icon(Icons.image, size: 80, color: Colors.grey[400])),
                ),
                // Wishlist heart - top right
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onWishlistTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 5)],
                      ),
                      child: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price badge - blue
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rp ${(product.price ~/ 1000).toString()}.000',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Rating
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${product.rating}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Product name
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                // Add/Remove buttons
                if (quantity == 0)
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onAddToCart,
                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                      label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: onRemoveFromCart,
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        IconButton(
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
