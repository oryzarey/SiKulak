import 'dart:ui';
import 'package:flutter/material.dart';
import '../models.dart';
import 'glass_container.dart';

class AppHeader extends StatelessWidget {
  final Stream<UserProfile?> profileStream;
  final String fallbackUserName;
  final VoidCallback onProfileTap;
  final Widget notificationWidget;

  const AppHeader({
    super.key,
    required this.profileStream,
    required this.fallbackUserName,
    required this.onProfileTap,
    required this.notificationWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      toolbarHeight: 140,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: StreamBuilder<UserProfile?>(
        stream: profileStream,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final userName = profile?.fullName ?? fallbackUserName;
          final avatarUrl = profile?.avatarUrl;

          return Container(
            padding: const EdgeInsets.only(
              top: 15,
              left: 20,
              right: 20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: GestureDetector(
                      onTap: onProfileTap,
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                              ),
                              child: avatarUrl != null &&
                                      avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        '$avatarUrl?t=${profile?.updatedAt.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Selamat datang,',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: notificationWidget,
                ),
              ],
            ),
          );
        },
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: Container(
            color: const Color(0xFF2979FF)
                .withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}