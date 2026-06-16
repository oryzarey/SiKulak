import 'package:flutter/foundation.dart';
import 'main.dart';
import 'inventory_demand_service.dart';

class InventoryABCService {
  static final InventoryABCService _instance = InventoryABCService._internal();
  factory InventoryABCService() => _instance;
  InventoryABCService._internal();

  /// Menghitung klasifikasi ABC, safety stock, dan reorder point secara bersamaan
  /// berdasarkan data penjualan 90 hari terakhir.
  Future<void> calculateABC() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Ambil data penjualan 3 bulan terakhir (termasuk created_at per baris)
      final dateThreshold =
          DateTime.now().subtract(const Duration(days: 90)).toUtc().toIso8601String();

      final salesData = await supabase
          .from('pos_order_items')
          .select('qty, total_price, inventory_id, pos_orders!inner(created_at, user_id)')
          .eq('pos_orders.user_id', userId)
          .gte('pos_orders.created_at', dateThreshold);

      final salesList = salesData as List? ?? [];

      // 2. Hitung total omzet per SKU dan kumpulkan baris harian per SKU
      final Map<String, double> skuRevenue = {};
      final Map<String, List<Map<String, dynamic>>> skuDailyRows = {};
      double totalStoreRevenue = 0.0;

      for (final row in salesList) {
        final inventoryId = row['inventory_id'].toString();
        final revenue = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        final qty = (row['qty'] as num?)?.toInt() ?? 0;

        skuRevenue[inventoryId] = (skuRevenue[inventoryId] ?? 0.0) + revenue;
        totalStoreRevenue += revenue;

        final order = row['pos_orders'] as Map<String, dynamic>?;
        final createdAt = order?['created_at']?.toString();
        if (createdAt != null) {
          final dt = DateTime.tryParse(createdAt)?.toLocal();
          skuDailyRows.putIfAbsent(inventoryId, () => []).add({
            'date': dt,
            'qty': qty,
          });
        }
      }

      // 3. Pastikan semua produk di inventory masuk hitungan; ambil juga lead_time
      final allInventory = await supabase
          .from('inventories')
          .select('id, lead_time')
          .eq('user_id', userId);

      final Map<String, int> leadTimes = {};
      for (final inv in allInventory as List) {
        final id = inv['id'].toString();
        skuRevenue.putIfAbsent(id, () => 0.0);
        leadTimes[id] = (inv['lead_time'] as num?)?.toInt() ?? 3;
      }

      if (totalStoreRevenue == 0) {
        await _updateAllToDefault(userId, skuRevenue.keys.toList());
        return;
      }

      // 4. Urutkan descending berdasarkan omzet
      final sortedSkus = skuRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 5. Tentukan ABC class, lalu hitung SS dan ROP dalam satu loop
      final now = DateTime.now();
      double cumulativeRevenue = 0.0;
      final List<Map<String, dynamic>> updates = [];

      for (final entry in sortedSkus) {
        cumulativeRevenue += entry.value;
        final cumulativePercentage = (cumulativeRevenue / totalStoreRevenue) * 100;

        final String abcClass;
        if (cumulativePercentage <= 80) {
          abcClass = 'A';
        } else if (cumulativePercentage <= 95) {
          abcClass = 'B';
        } else {
          abcClass = 'C';
        }

        final rows = skuDailyRows[entry.key] ?? [];
        final demandResult = buildDailyDemand(rows, 90, now);
        final stats = computeDemandStats(demandResult);
        final leadTime = leadTimes[entry.key] ?? 3;
        final ss = computeSafetyStock(stats, leadTime, abcClass);
        final rop = computeReorderPoint(stats, leadTime, ss);

        updates.add({
          'id': entry.key,
          'abc_class': abcClass,
          'safety_stock': ss,
          'reorder_point': rop,
        });
      }

      // 6. Tulis ke database
      for (final update in updates) {
        await supabase
            .from('inventories')
            .update({
              'abc_class': update['abc_class'],
              'safety_stock': update['safety_stock'],
              'reorder_point': update['reorder_point'],
            })
            .eq('id', update['id']);
      }

      debugPrint('[ABC Service] Calculation completed for $userId');
    } catch (e) {
      debugPrint('[ABC Service] Error calculating ABC: $e');
    }
  }

  Future<void> _updateAllToDefault(String userId, List<String> ids) async {
    for (final id in ids) {
      await supabase
          .from('inventories')
          .update({'abc_class': 'C', 'safety_stock': 0, 'reorder_point': 0})
          .eq('id', id);
    }
  }

  /// Helper untuk mendapatkan label perputaran stok
  static String getTurnoverLabel(String? abcClass) {
    switch (abcClass) {
      case 'A':
        return 'Paling Laku';
      case 'B':
        return 'Laku Standar';
      case 'C':
        return 'Jarang Dicari';
      default:
        return 'Jarang Dicari';
    }
  }
}
