import 'package:flutter/material.dart';
import 'models.dart';
import 'main.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _suppliers = [];

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
        // 1. Sort by price ascending (cheapest first)
        list.sort((a, b) {
          final pa = (a['price'] as num?)?.toDouble() ?? 0.0;
          final pb = (b['price'] as num?)?.toDouble() ?? 0.0;
          return pa.compareTo(pb);
        });

        setState(() {
          // 2. Build supplier list with grade based on rank
          _suppliers = List.generate(list.length, (index) {
            final item = list[index];
            final supplier = item['suppliers'] as Map<String, dynamic>?;
            final price = (item['price'] as num?)?.toDouble() ?? widget.product.price;
            final lastUpdated = item['last_updated'] ?? item['updated_at'];

            // Grade logic
            String grade;
            if (list.length == 1) {
              grade = 'A'; // only one supplier – treat as best
            } else if (index == 0) {
              grade = 'A'; // cheapest
            } else if (index == list.length - 1) {
              grade = 'C'; // most expensive
            } else {
              grade = 'B'; // middle prices
            }

            return {
              'name': supplier?['name']?.toString() ?? 'Pemasok Grosir',
              'description': supplier?['description']?.toString() ?? 'Grosir Kulakan Murah',
              'price': price,
              'grade': grade,
              'last_update': lastUpdated != null ? _formatDate(lastUpdated.toString()) : '',
              // rating is optional – not used in UI but keep for consistency
              'rating': (supplier?['rating'] as num?)?.toDouble() ?? 4.5,
            };
          });

          // 3. Sort by grade (A → B → C) to display in that order
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
          _suppliers = [];
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

  String _formatPrice(double price) {
    final formatter = price.toStringAsFixed(0);
    final parts = formatter.split('.');
    final intPart = parts[0];
    final stringBuffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count == 3) {
        stringBuffer.write('.');
        count = 0;
      }
      stringBuffer.write(intPart[i]);
      count++;
    }
    final reversedStr = stringBuffer.toString().split('').reversed.join('');
    return 'Rp. $reversedStr';
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
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatPrice(widget.product.price),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Builder(builder: (context) {
                              final delta = widget.product.price - widget.product.lastPrice;
                              final isRising = delta > 0;
                              final isFalling = delta < 0;
                              final icon = isRising ? Icons.arrow_upward : Icons.arrow_downward;
                              final changeColor = isRising ? Colors.red : (isFalling ? Colors.green : Colors.grey[600]);
                              final changePercent = widget.product.lastPrice > 0
                                  ? (delta / widget.product.lastPrice * 100).abs()
                                  : 0.0;
                              return Row(
                                children: [
                                  Icon(icon, color: changeColor, size: 16),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${changePercent.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: changeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }),
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
          else if (_suppliers.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Tidak ada supplier untuk produk ini',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
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
        border: Border.all(color: cardBorderColor, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Updated: $lastUpdate',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Price and Grade Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrice(price),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: gradeTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                // Grade Badge Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grade Circle
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: gradeTextColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gradeTextColor.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Label container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: gradeColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        gradeLabel,
                        style: TextStyle(
                          color: gradeTextColor,
                          fontSize: 12,
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
    );
  }
}