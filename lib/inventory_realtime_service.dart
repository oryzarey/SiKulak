import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'notification_service.dart';

class InventoryRealtimeService {
  static final InventoryRealtimeService _instance = InventoryRealtimeService._internal();
  factory InventoryRealtimeService() => _instance;
  InventoryRealtimeService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _debounce;
  String? _activeUserId;

  void start() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    if (_activeUserId == userId && _channel != null) return;

    stop();
    _activeUserId = userId;

    _channel = _client
        .channel('inventories-changes-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _scheduleLowStockCheck(),
        )
        .subscribe();
  }

  void stop() {
    _debounce?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    _channel = null;
    _activeUserId = null;
  }

  void _scheduleLowStockCheck() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _checkLowStockRealtime();
    });
  }

  Future<bool> _shouldInsertNotification({
    required String userId,
    required InventoryItem item,
    required String notifType,
  }) async {
    final lastNotif = await _client
        .from('notifications')
        .select('type, created_at')
        .eq('user_id', userId)
        .eq('related_inventory_id', item.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (lastNotif == null) return true;

    final lastType = lastNotif['type']?.toString();
    final lastCreatedAt = DateTime.tryParse(lastNotif['created_at']?.toString() ?? '');

    if (lastType != notifType) return true;

    if (item.updatedAt != null && lastCreatedAt != null) {
      return item.updatedAt!.isAfter(lastCreatedAt);
    }

    return false;
  }

  Future<void> _checkLowStockRealtime() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _client
          .from('inventories')
          .select()
          .eq('user_id', userId)
          .lte('qty_available', 10)
          .order('qty_available', ascending: true);

      final items = (data as List)
          .map((j) => InventoryItem.fromJson(j))
          .toList();

      if (items.isEmpty) return;

      final List<InventoryItem> notifiedItems = [];
      try {
        for (final item in items) {
          final notifTitle = item.qtyAvailable == 0
              ? 'Stock ${item.name} Habis'
              : 'Stock ${item.name} Rendah';
          final notifBody = item.qtyAvailable == 0
              ? 'Segera tambah stock ${item.name} (stok habis)'
              : 'Segera tambah stock ${item.name}';
          final notifType = item.qtyAvailable == 0 ? 'out_of_stock' : 'low_stock';

          final shouldInsert = await _shouldInsertNotification(
            userId: userId,
            item: item,
            notifType: notifType,
          );
          if (!shouldInsert) continue;

          await _client.from('notifications').insert({
            'user_id': userId,
            'title': notifTitle,
            'body': notifBody,
            'type': notifType,
            'related_inventory_id': item.id,
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
          notifiedItems.add(item);
        }
      } catch (_) {}

      if (notifiedItems.isNotEmpty) {
        for (final item in notifiedItems) {
          NotificationService().showLowStockNotification(
            itemName: item.name,
            qty: item.qtyAvailable,
          );
        }
      }
    } catch (_) {}
  }
}
