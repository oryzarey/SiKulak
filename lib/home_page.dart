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

            // ── Search Bar ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Hari ini beli apa?',
                          prefixIcon: const Icon(Icons.search, color: Colors.blue),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _showFilterModal,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Colors.blue,
                          size: 24,
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

            // ── Produk Pilihan Title ────────────────────────
            SliverToBoxAdapter(
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Produk Pilihan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            // ── Product Grid ────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.75,
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Center(child: Icon(Icons.image, size: 50, color: Colors.grey[300])),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onWishlistTap,
                    child: Icon(isWishlisted ? Icons.favorite : Icons.favorite_border, color: Colors.red),
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
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    Text(' ${product.rating}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Rp ${product.price}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                if (quantity == 0)
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: onAddToCart,
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Tambah'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: onRemoveFromCart,
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.blue, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        IconButton(
                          onPressed: onAddToCart,
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
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
