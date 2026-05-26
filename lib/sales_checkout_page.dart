import 'package:flutter/material.dart';

import 'cart_manager.dart';
import 'main.dart';

class SalesCheckoutPage extends StatefulWidget {
  const SalesCheckoutPage({super.key});

  @override
  State<SalesCheckoutPage> createState() => _SalesCheckoutPageState();
}

class _SalesCheckoutPageState extends State<SalesCheckoutPage> {
  final CartManager _cart = CartManager();
  final dynamic _authUser = supabase.auth.currentUser ?? supabase.auth.currentSession?.user;

  String get _userName {
    final user = _authUser;
    if (user == null) return 'Kasir';
    final meta = user.userMetadata;
    final raw = (meta?['full_name'] ?? meta?['nama'] ?? meta?['name'] ?? user.email ?? 'Kasir')
        .toString()
        .split('@')
        .first;
    return raw.isEmpty ? 'Kasir' : raw;
  }

  Future<void> _submitSales() async {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = (_authUser?.id as String?);
      if (userId == null) throw Exception('User tidak terautentikasi');

      final totalPrice = _cart.totalPrice;
      final totalProfit = totalPrice * 0.10;

      final transactionResponse = await supabase.from('transactions').insert({
        'user_id': userId,
        'total_price': totalPrice,
        'total_profit': totalProfit,
        'status': 'completed',
      }).select().single();

      final transactionId = transactionResponse['id'];

      for (final entry in _cart.items.entries) {
        final productId = entry.key;
        final cartItem = entry.value;

        await supabase.from('transaction_items').insert({
          'transaction_id': transactionId,
          'product_id': productId,
          'quantity': cartItem.quantity,
          'price_at_purchase': cartItem.price,
          'profit_at_purchase': cartItem.price * 0.10,
        });

        final inventoryRow = await supabase
            .from('inventories')
            .select('id, qty_available')
            .eq('user_id', userId)
            .or('id.eq.$productId,name.eq.${cartItem.productName}')
            .maybeSingle();

        if (inventoryRow != null) {
          final invId = inventoryRow['id'];
          final currentQty = (inventoryRow['qty_available'] as num?)?.toInt() ?? 0;
          final newQty = (currentQty - cartItem.quantity).clamp(0, 999999);
          await supabase.from('inventories').update({
            'qty_available': newQty,
          }).eq('id', invId);
        }
      }

      _cart.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan penjualan: $e')),
      );
    }
  }

  void _addItem(String productId) {
    final entry = _cart.items[productId];
    if (entry == null) return;
    setState(() {
      _cart.add(
        productId,
        name: entry.productName,
        price: entry.price,
        imageUrl: entry.imageUrl,
      );
    });
  }

  void _removeItem(String productId) {
    if (_cart.quantityOf(productId) == 0) return;
    setState(() => _cart.remove(productId));
  }

  String _formatItemTotal(double price, int quantity) {
    return CartManager.formatPrice(price * quantity);
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A7BF6), Color(0xFF7CB1FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const Text(
                  'Penjualan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 14, backgroundColor: Color(0xFFE5E7EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat datang',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? const Color(0xFF2A7BF6),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      ),
    );
  }

  Widget _buildCartItem(String productId, CartEntry entry) {
    final quantity = entry.quantity;
    final itemTotal = _formatItemTotal(entry.price, quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: (entry.imageUrl ?? '').isNotEmpty
                ? Image.network(
                    entry.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: Colors.grey),
                  )
                : const Icon(Icons.inventory_2_rounded, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  CartManager.formatPrice(entry.price),
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
                Text(
                  itemTotal,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF2A7BF6).withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuantityButton(Icons.remove, () => _removeItem(productId), color: const Color(0xFFCBD5E1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _buildQuantityButton(Icons.add, () => _addItem(productId)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                itemTotal,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  CartManager.formatPrice(_cart.totalPrice),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _cart.isEmpty ? null : _submitSales,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7BF6),
                  disabledBackgroundColor: const Color(0xFF9EC1FA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text(
                  'Catat Penjualan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _cart.items.entries.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: cartItems.isEmpty
                    ? const Center(
                        child: Text(
                          'Keranjang masih kosong',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Pembelian',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.builder(
                              itemCount: cartItems.length,
                              itemBuilder: (context, index) {
                                final entry = cartItems[index];
                                return _buildCartItem(entry.key, entry.value);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }
}