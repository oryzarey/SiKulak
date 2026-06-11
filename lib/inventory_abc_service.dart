import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class InventoryABCService {
  static final InventoryABCService _instance = InventoryABCService._internal();
  factory InventoryABCService() => _instance;
  InventoryABCService._internal();

  /// Menghitung klasifikasi ABC berdasarkan omzet 3 bulan terakhir.
  Future<void> calculateABC() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Ambil data penjualan 3 bulan terakhir
      final dateThreshold = DateTime.now().subtract(const Duration(days: 90)).toUtc().toIso8601String();
      
      final salesData = await supabase
          .from('pos_order_items')
          .select('qty, total_price, inventory_id, pos_orders!inner(created_at, user_id)')
          .eq('pos_orders.user_id', userId)
          .gte('pos_orders.created_at', dateThreshold);

      final salesList = salesData as List? ?? [];
      
      // 2. Hitung Total Omzet per SKU
      final Map<String, double> skuRevenue = {};
      double totalStoreRevenue = 0.0;

      for (final row in salesList) {
        final inventoryId = row['inventory_id'].toString();
        final revenue = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        
        skuRevenue[inventoryId] = (skuRevenue[inventoryId] ?? 0.0) + revenue;
        totalStoreRevenue += revenue;
      }

      // Pastikan semua produk di inventory masuk hitungan (meskipun omzet 0)
      final allInventory = await supabase
          .from('inventories')
          .select('id')
          .eq('user_id', userId);
      
      for (final inv in allInventory as List) {
        final id = inv['id'].toString();
        skuRevenue.putIfAbsent(id, () => 0.0);
      }

      if (totalStoreRevenue == 0) {
        // Jika tidak ada penjualan, set semua ke C
        await _updateAllToClassC(userId, skuRevenue.keys.toList());
        return;
      }

      // 3. Urutkan (sort) descending berdasarkan omzet
      final sortedSkus = skuRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 4 & 5. Hitung persentase akumulatif dan kelompokkan
      double cumulativeRevenue = 0.0;
      final List<Map<String, dynamic>> updates = [];

      for (final entry in sortedSkus) {
        cumulativeRevenue += entry.value;
        final cumulativePercentage = (cumulativeRevenue / totalStoreRevenue) * 100;

        String abcClass;
        if (cumulativePercentage <= 80) {
          abcClass = 'A';
        } else if (cumulativePercentage <= 95) {
          abcClass = 'B';
        } else {
          abcClass = 'C';
        }

        updates.add({
          'id': entry.key,
          'abc_class': abcClass,
        });
      }

      // 6. Update status ke database
      for (final update in updates) {
        await supabase
            .from('inventories')
            .update({'abc_class': update['abc_class']})
            .eq('id', update['id']);
      }

      debugPrint('[ABC Service] Calculation completed for $userId');
    } catch (e) {
      debugPrint('[ABC Service] Error calculating ABC: $e');
    }
  }

  Future<void> _updateAllToClassC(String userId, List<String> ids) async {
    for (final id in ids) {
      await supabase
          .from('inventories')
          .update({'abc_class': 'C'})
          .eq('id', id);
    }
  }

  /// Helper untuk mendapatkan label perputaran stok
  static String getTurnoverLabel(String? abcClass) {
    switch (abcClass) {
      case 'A': return 'Paling Laku';
      case 'B': return 'Laku Standar';
      case 'C': return 'Jarang Dicari';
      default: return 'Jarang Dicari';
    }
  }
}
