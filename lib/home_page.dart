import 'package:flutter/material.dart';
import 'main.dart';
import 'models.dart';
import 'search_results_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<int, int> _cartItems = {}; // productId: quantity
  final Set<int> _wishlistItems = {};
  String _selectedCategory = 'Semua Produk';
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
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (query) {
                    if (query.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SearchResultsPage(
                            searchQuery: query,
                            products: _products,
                          ),
                        ),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Hari ini beli apa?',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    suffixIcon: const Icon(Icons.tune, color: Colors.blue),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
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

            // ── Category Chips ──────────────────────────
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
                  (context, index) => _ProductCard(
                    product: _products[index],
                    isWishlisted: _wishlistItems.contains(_products[index].id),
                    quantity: _cartItems[_products[index].id] ?? 0,
                    onWishlistTap: () {
                      setState(() {
                        if (_wishlistItems.contains(_products[index].id)) {
                          _wishlistItems.remove(_products[index].id);
                        } else {
                          _wishlistItems.add(_products[index].id);
                        }
                      });
                    },
                    onAddToCart: () {
                      setState(() {
                        final productId = _products[index].id;
                        _cartItems[productId] = (_cartItems[productId] ?? 0) + 1;
                      });
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang')));
                    },
                    onRemoveFromCart: () {
                      setState(() {
                        final productId = _products[index].id;
                        if ((_cartItems[productId] ?? 0) > 1) {
                          _cartItems[productId] = _cartItems[productId]! - 1;
                        } else {
                          _cartItems.remove(productId);
                        }
                      });
                    },
                  ),
                  childCount: _products.length,
                ),
              ),
            ),

            SliverToBoxAdapter(child: const SizedBox(height: 20)),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF2979FF),
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, color: Colors.white70),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.assignment_outlined, color: Colors.white70),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.white70),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: () {
              _showCartModal(context);
            },
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCartModal(BuildContext context) {
    final totalItems = _cartItems.values.fold(0, (sum, qty) => sum + qty);
    final totalPrice = _cartItems.entries.fold<int>(0, (sum, entry) => sum + (entry.key * entry.value));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Keranjang Belanja',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_cartItems.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('Keranjang kosong', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final productId = _cartItems.keys.toList()[index];
                      final quantity = _cartItems[productId]!;
                      final product = _products.firstWhere((p) => p.id == productId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.image, color: Colors.grey[300]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Rp ${product.price}', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (quantity > 1) {
                                          _cartItems[productId] = quantity - 1;
                                        } else {
                                          _cartItems.remove(productId);
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _cartItems[productId] = quantity + 1;
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total: $totalItems items',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          'Rp ${(totalPrice ~/ 1000).toString()}.000',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Lanjut ke pembayaran')));
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Lanjut'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
