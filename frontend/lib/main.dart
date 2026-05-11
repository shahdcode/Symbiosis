import 'dart:ui';

import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/plant_details_page.dart';
import 'pages/coordinator_log_page.dart';
import 'pages/manual_control_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const greenSeed = Color(0xFF2F8F5B);
    const canvas = Color(0xFFF6F8F4);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Symbiosis Garden',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: greenSeed,
          brightness: Brightness.light,
          surface: Colors.white,
        ).copyWith(
          primary: greenSeed,
          secondary: const Color(0xFF86C88A),
          tertiary: const Color(0xFFB7E2BE),
          surfaceContainerHighest: Colors.white,
        ),
        scaffoldBackgroundColor: canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          margin: EdgeInsets.zero,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF18321F),
          displayColor: const Color(0xFF18321F),
          fontFamily: null,
        ),
      ),
      home: const GardenShell(),
    );
  }
}

class GardenShell extends StatefulWidget {
  const GardenShell({super.key});

  @override
  State<GardenShell> createState() => _GardenShellState();
}

class _GardenShellState extends State<GardenShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const PlantDetailsPage(),
      const CoordinatorLogPage(),
      const ManualControlPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFDAE8DD)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final selected = index == _selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selected
                                  ? const Color(0xFFEAF6EE)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color:
                                  selected
                                      ? const Color(0xFF2F8F5B)
                                      : const Color(0xFF88A293),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color:
                                    selected
                                        ? const Color(0xFF2F8F5B)
                                        : const Color(0xFF88A293),
                              ),
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _navItems = <_NavItem>[
  _NavItem(label: 'Overview', icon: Icons.spa_rounded),
  _NavItem(label: 'Plants', icon: Icons.eco_rounded),
  _NavItem(label: 'Log', icon: Icons.timeline_rounded),
  _NavItem(label: 'Manual', icon: Icons.tune_rounded),
];

class _NavItem {
  const _NavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
