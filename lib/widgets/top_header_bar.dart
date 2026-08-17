import 'package:flutter/material.dart';
import 'package:safe/theme/app_theme.dart';

class TopHeaderBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabTapped;

  const TopHeaderBar({
    super.key,
    required this.selectedIndex,
    required this.onTabTapped,
  });

  static const List<_HeaderItemData> _items = [
    _HeaderItemData(icon: Icons.shield_rounded, label: 'Safety Audit'),
    _HeaderItemData(icon: Icons.local_police_rounded, label: 'Emergency'),
    _HeaderItemData(icon: Icons.map_rounded, label: 'Location'),
    _HeaderItemData(icon: Icons.people_alt_rounded, label: 'Contacts'),
    _HeaderItemData(icon: Icons.auto_awesome_rounded, label: 'Feed'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Drawer Menu Button (☰)
          Builder(
            builder: (btnCtx) => InkWell(
              onTap: () => Scaffold.of(btnCtx).openDrawer(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: AppTheme.glassCardDecoration(
                  borderRadius: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: AppTheme.primaryPurple,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Top Feature Shortcuts Row
          Container(
            padding: const EdgeInsets.all(4),
            decoration: AppTheme.glassCardDecoration(
              borderRadius: 20,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            child: Row(
              children: List.generate(_items.length, (idx) {
                final isSelected = selectedIndex == idx;
                final item = _items[idx];

                return GestureDetector(
                  onTap: () => onTabTapped(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 12 : 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.purpleHeroGradient : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: isSelected ? Colors.white : AppTheme.textMuted,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderItemData {
  final IconData icon;
  final String label;

  const _HeaderItemData({required this.icon, required this.label});
}
