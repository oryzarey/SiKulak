import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key, this.onNotificationsMarkedRead}) : super(key: key);

  final VoidCallback? onNotificationsMarkedRead;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late Future<List<AppNotification>> _notificationsFuture;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<AppNotification>> _loadNotifications() async {
    try {
      await _markAllAsRead();
      widget.onNotificationsMarkedRead?.call();
      return await _fetchNotifications();
    } catch (e) {
      _loadError = e.toString();
      return [];
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<List<AppNotification>> _fetchNotifications() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((j) => AppNotification.fromJson(j))
          .toList();
    } catch (e) {
      _loadError = e.toString();
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            toolbarHeight: 70,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifikasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF2979FF),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            child: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat notifikasi: ${snapshot.error}'));
          }
          final notifications = snapshot.data ?? [];
          if (_loadError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Notifikasi belum bisa dimuat.\n$_loadError',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isLow = notif.type == 'low_stock';
              final isOut = notif.type == 'out_of_stock';
              final iconColor = isOut
                  ? Colors.red[700]
                  : (isLow ? Colors.orange[700] : Colors.blue[700]);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor?.withOpacity(0.15),
                  child: Icon(Icons.shopping_bag, color: iconColor),
                ),
                title: Text(
                  notif.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(notif.body ?? ''),
                trailing: Text(
                  _formatTime(notif.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hari ini, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' ;
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
