import 'package:flutter/material.dart';
import 'package:safe/screens/emergency_screen.dart';
import 'package:safe/screens/feed_screen.dart';
import 'package:safe/screens/home_screen.dart';
import 'package:safe/screens/location_screen.dart';
import 'package:safe/theme/app_theme.dart';
import 'package:safe/widgets/contacts/contacts_screen.dart';

import 'package:safe/screens/sos_screen.dart';
import 'package:safe/widgets/smart_wake_gesture_detector.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  void _onSmartWakeLDetected() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const AlertMessageScreen(
          initialRecentCallVector: '9109750185',
        ),
      ),
    );
  }

  // Initial App Entry: Route Safety & Source-Destination Finder (Photo 1 & 2 UI/UX)
  final List<Widget> _pages = const [
    LocationScreen(),
    HomeScreen(),
    EmergencyScreen(),
    ContactsScreen(),
    FeedScreen(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(icon: Icons.map_rounded, label: 'Route Safety'),
    _NavItemData(icon: Icons.shield_rounded, label: 'Safety Audit'),
    _NavItemData(icon: Icons.local_police_rounded, label: 'Emergency'),
    _NavItemData(icon: Icons.people_alt_rounded, label: 'Contacts'),
    _NavItemData(icon: Icons.auto_awesome_rounded, label: 'Feed'),
  ];

  void _onTabTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SmartWakeGestureDetector(
        onLPatternDetected: _onSmartWakeLDetected,
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.pageBackgroundGradient,
          ),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final isSelected = _currentIndex == index;
              final item = _navItems[index];

              return GestureDetector(
                onTap: () => _onTabTapped(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFFA855F7),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        size: 24,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1.0 : 0.0,
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
