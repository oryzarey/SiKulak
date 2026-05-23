import 'package:flutter/material.dart';
import 'models.dart';
import 'main.dart';
import 'cart_manager.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final CartManager _cart = CartManager();
  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _loadSupplierData();
  }

  Future<void> _loadSupplierData() async {
    try {
      final response = await supabase
          .from('supplier_products')
          .select('*, suppliers(*)')
          .eq('product_id', widget.product.id);

      final list = response as List? ?? [];
      
      if (mounted) {
        setState(() {
          if (list.isNotEmpty) {
            // Sort database list by price ascending (cheapest first)
            list.sort((a, b) {
              final pa = (a['price'] as num?)?.toDouble() ?? 0.0;
              final pb = (b['price'] as num?)?.toDouble() ?? 0.0;
              return pa.compareTo(pb);
            });

            // Map and assign ABC grade dynamically based on price ranking
            _suppliers = List.generate(list.length, (index) {
              final item = list[index];
              final s = item['suppliers'] as Map<String, dynamic>?;
              final price = (item['price'] as num?)?.toDouble() ?? widget.product.price;

              String computedGrade = 'B';
              if (index == 0) {
                computedGrade = 'A'; // Cheapest is A
              } else if (index == list.length - 1 && list.length > 2) {
                computedGrade = 'C'; // Most expensive is C
              } else {
                computedGrade = 'B'; // Middle prices are B
              }

              return {
                'name': s?['name'] ?? 'Pemasok Grosir',
                'description': s?['description'] ?? 'Grosir Kulakan Murah',
                'rating': (s?['rating'] as num?)?.toDouble() ?? 4.5,
                'price': price,
                'grade': computedGrade,
                'last_update': item['updated_at'] != null 
                    ? _formatDate(item['updated_at'].toString())
                    : '03/04/2026',
              };
            });
          } else {
            // Use fallback mock data relative to the database product price
            final basePrice = widget.product.price > 0 ? widget.product.price : 114720.0;
            _suppliers = [
              {
                'name': 'NUA',
                'description': 'Grosir Kulakan Termurah',
                'rating': 4.5,
                'price': basePrice * 0.95,
                'grade': 'A',
                'last_update': '03/04/2026',
              },
              {
                'name': 'Jaya Grosir',
                'description': 'Murahnya Bikin Balik Lagi',
                'rating': 4.5,
                'price': basePrice * 1.01,
                'grade': 'B',
                'last_update': '02/04/2026',
              },
              {
                'name': 'Lancar Jaya',
                'description': 'Stok Melimpah Ruah',
                'rating': 4.2,
                'price': basePrice * 1.05,
                'grade': 'C',
                'last_update': '01/04/2026',
              }
            ];
          }
          
          // Sort by grade: A -> B -> C
          _suppliers.sort((a, b) {
            final ga = a['grade'].toString();
            final gb = b['grade'].toString();
            return ga.compareTo(gb);
          });
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading supplier data: $e');
      if (mounted) {
        setState(() {
          final basePrice = widget.product.price > 0 ? widget.product.price : 114720.0;
          _suppliers = [
            {
              'name': 'NUA',
              'description': 'Grosir Kulakan Termurah',
              'rating': 4.5,
              'price': basePrice * 0.95,
              'grade': 'A',
              'last_update': '03/04/2026',
            },
            {
              'name': 'Jaya Grosir',
              'description': 'Murahnya Bikin Balik Lagi',
              'rating': 4.5,
              'price': basePrice * 1.01,
              'grade': 'B',
              'last_update': '02/04/2026',
            },
            {
              'name': 'Lancar Jaya',
              'description': 'Stok Melimpah Ruah',
              'rating': 4.2,
              'price': basePrice * 1.05,
              'grade': 'C',
              'last_update': '01/04/2026',
            }
          ];
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Product Image (Curved) ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A8A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2979FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 220,
                      height: 180,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty
                          ? Image.network(widget.product.imageUrl!, fit: BoxFit.cover)
                          : const Center(
                              child: Icon(Icons.shopping_bag_outlined, size: 70, color: Color(0xFFBDD7FF)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Product Basic Info ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '252 Sachet', // packaging specification from design
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Wishlist Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isWishlisted = !_isWishlisted;
                          });
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Market Price (Harga Pasar) Row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Harga Pasar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7), // Light green background
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CartManager.formatPrice(widget.product.price),
                              style: const TextStyle(
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.trending_down,
                              color: Color(0xFF166534),
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            const Text(
                              '1,5%',
                              style: TextStyle(
                                color: Color(0xFF166534),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                ],
              ),
            ),
          ),

          // ── Supplier List ──
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(color: Color(0xFF2979FF)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final sup = _suppliers[index];
                    return _buildSupplierCard(sup);
                  },
                  childCount: _suppliers.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> sup) {
    final String name = sup['name'] as String;
    final String desc = sup['description'] as String;
    final double rating = sup['rating'] as double;
    final double price = sup['price'] as double;
    final String grade = sup['grade'] as String;
    final String lastUpdate = sup['last_update'] as String;

    // UI Configuration based on Grade (A, B, C)
    Color gradeColor;
    Color gradeTextColor;
    String gradeLabel;
    Color cardBorderColor;

    switch (grade) {
      case 'A':
        gradeColor = const Color(0xFFDCFCE7); // green
        gradeTextColor = const Color(0xFF15803D);
        gradeLabel = 'Terbaik';
        cardBorderColor = const Color(0xFF22C55E);
        break;
      case 'C':
        gradeColor = const Color(0xFFFEE2E2); // red
        gradeTextColor = const Color(0xFFB91C1C);
        gradeLabel = 'Hindari';
        cardBorderColor = const Color(0xFFEF4444);
        break;
      case 'B':
      default:
        gradeColor = const Color(0xFFFEF3C7); // amber
        gradeTextColor = const Color(0xFFB45309);
        gradeLabel = 'Opsional';
        cardBorderColor = const Color(0xFFF59E0B);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _addSupplierProductToCart(name, price),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Supplier Logo / Circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.storefront,
                      color: gradeTextColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            rating.toString(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Last Update:$lastUpdate',
                            style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Price and Grade Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CartManager.formatPrice(price),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: gradeTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Per Box',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    
                    // Grade Badge Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Grade Circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: gradeTextColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              grade,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        // Label container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: gradeColor,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                          ),
                          child: Text(
                            gradeLabel,
                            style: TextStyle(
                              color: gradeTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  void _addSupplierProductToCart(String supplierName, double price) {
    _cart.add(
      widget.product.id,
      name: widget.product.name,
      price: price,
      imageUrl: widget.product.imageUrl,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Berhasil menambahkan produk dari $supplierName ke keranjang!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2979FF),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }
}
