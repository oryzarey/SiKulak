import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service that manages OS-level push notifications for SiKulak.
class NotificationService {
  // ── Singleton ──────────────────────────────────────────────
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialization ─────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    // Android: use the app's built-in launcher icon
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);

    // Create the notification channel on Android 8+
    const channel = AndroidNotificationChannel(
      'low_stock_alerts',
      'Peringatan Stok Rendah',
      description: 'Notifikasi ketika stok barang Anda rendah atau habis',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  // ── Request permission (Android 13+) ───────────────────────
  Future<void> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  // ── Show low-stock notification ────────────────────────────
  /// Fires an OS notification for a single low-stock item.
  Future<void> showLowStockNotification({
    required String itemName,
    required int qty,
  }) async {
    if (!_initialized) await init();

    final body = qty == 0
        ? '$itemName sudah habis'
        : '$itemName tinggal $qty Sachet';

    const androidDetails = AndroidNotificationDetails(
      'low_stock_alerts',
      'Peringatan Stok Rendah',
      channelDescription:
          'Notifikasi ketika stok barang Anda rendah atau habis',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: DefaultStyleInformation(true, true),
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      itemName.hashCode, // unique id per item
      'Tambah Stock Anda!',
      body,
      details,
    );
  }

  /// Fires notifications for a list of low-stock items.
  Future<void> showLowStockNotifications(
      List<Map<String, dynamic>> items) async {
    for (final item in items) {
      await showLowStockNotification(
        itemName: item['name'] as String,
        qty: item['qty'] as int,
      );
    }
  }
}
