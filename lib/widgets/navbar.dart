import 'package:flutter/material.dart';

class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                icon: Icons.home,
                isSelected: selectedIndex == 0,
                onPressed: () => onItemTapped(0),
              ),
              _NavButton(
                icon: Icons.dashboard_outlined,
                isSelected: selectedIndex == 1,
                onPressed: () => onItemTapped(1),
              ),
              _NavButton(
                icon: Icons.assignment_outlined,
                isSelected: selectedIndex == 2,
                onPressed: () => onItemTapped(2),
              ),
              _NavButton(
                icon: Icons.person_outline,
                isSelected: selectedIndex == 3,
                onPressed: () => onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
          size: 28,
        ),
      ),
    );
  }
}

