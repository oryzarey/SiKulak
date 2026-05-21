import 'package:flutter/material.dart';
import '../dashboard_page.dart';

class FloatingNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onNavItemTapped;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onNavItemTapped,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> with TickerProviderStateMixin {
  late Map<int, AnimationController> _iconScaleControllers;

  @override
  void initState() {
    super.initState();
    _iconScaleControllers = {
      0: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
      1: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
      2: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
      3: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    };
  }

  @override
  void dispose() {
    for (var controller in _iconScaleControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _triggerIconAnimation(int index) {
    _iconScaleControllers[index]?.forward().then((_) {
      _iconScaleControllers[index]?.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (value * 0.2),
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2979FF),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: _AnimatedNavButton(
                  icon: Icons.home,
                  label: 'Beranda',
                  isSelected: widget.selectedIndex == 0,
                  animationController: _iconScaleControllers[0]!,
                  onPressed: () {
                    widget.onNavItemTapped(0);
                    _triggerIconAnimation(0);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              Expanded(
                child: _AnimatedNavButton(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  isSelected: widget.selectedIndex == 1,
                  animationController: _iconScaleControllers[1]!,
                  onPressed: () {
                    widget.onNavItemTapped(1);
                    _triggerIconAnimation(1);
                    if (widget.selectedIndex != 1) {
                      final navContext = context;
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          Navigator.of(navContext).push(
                            PageRouteBuilder(
                              transitionDuration: const Duration(milliseconds: 500),
                              pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
                        }
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: _AnimatedNavButton(
                  icon: Icons.assignment_outlined,
                  label: 'Pesanan',
                  isSelected: widget.selectedIndex == 2,
                  animationController: _iconScaleControllers[2]!,
                  onPressed: () {
                    widget.onNavItemTapped(2);
                    _triggerIconAnimation(2);
                  },
                ),
              ),
              Expanded(
                child: _AnimatedNavButton(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  isSelected: widget.selectedIndex == 3,
                  animationController: _iconScaleControllers[3]!,
                  onPressed: () {
                    widget.onNavItemTapped(3);
                    _triggerIconAnimation(3);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedNavButton extends StatelessWidget {
  const _AnimatedNavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.animationController,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final AnimationController animationController;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: animationController, curve: Curves.elasticOut),
      ),
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedBuilder(
          animation: animationController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
