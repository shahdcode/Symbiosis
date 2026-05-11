import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

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

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: const [
        _DashboardHeader(),
        SizedBox(height: 16),
        _WaterAndLightRow(),
        SizedBox(height: 16),
        _PlantCardsRow(),
        SizedBox(height: 16),
        _SystemSummaryPanel(),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FCF7), Color(0xFFEAF6EE)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFDDEBDD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2A693D),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Garden Overview',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6E8577),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Garden Harmony',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const _StatusChip(label: 'Live sync', icon: Icons.wifi_rounded),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(flex: 5, child: _HarmonyGauge(value: 0.86)),
              SizedBox(width: 14),
              Expanded(flex: 4, child: _MiniStatStack()),
            ],
          ),
        ],
      ),
    );
  }
}

class _HarmonyGauge extends StatelessWidget {
  const _HarmonyGauge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 196,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDBEADC)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.18, end: value),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, child) {
                      return CustomPaint(
                        painter: _RadialGaugePainter(
                          progress: animatedValue,
                          baseColor: const Color(0xFFE7EFE8),
                          fillColor: const Color(0xFF2F8F5B),
                        ),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '86%',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'system health',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6D8679),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _PulseIndicator(),
        ],
      ),
    );
  }
}

class _MiniStatStack extends StatelessWidget {
  const _MiniStatStack();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _GlassMiniCard(
          label: 'Water tank',
          value: '72%',
          subtitle: 'Liquid reserve',
          fill: 0.72,
          accent: Color(0xFF58B96B),
          icon: Icons.water_drop_rounded,
        ),
        SizedBox(height: 12),
        _GlassMiniCard(
          label: 'LED arm',
          value: 'Plant A',
          subtitle: 'Light zone active',
          fill: 0.84,
          accent: Color(0xFF7CD27E),
          icon: Icons.highlight_rounded,
        ),
      ],
    );
  }
}

class _GlassMiniCard extends StatelessWidget {
  const _GlassMiniCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.fill,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtitle;
  final double fill;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDFECE0)),
      ),
      child: Row(
        children: [
          _VerticalFillMeter(value: fill, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF60786C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7B9585),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalFillMeter extends StatelessWidget {
  const _VerticalFillMeter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.05, end: value),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, fill, _) {
        return Container(
          width: 18,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6F1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fill,
              widthFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [color, color.withOpacity(0.66)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.5 + math.sin(_controller.value * math.pi * 2) * 0.06;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF35A257).withOpacity(pulse),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'fluid balance stabilizing',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6D8679),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaterAndLightRow extends StatelessWidget {
  const _WaterAndLightRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 4, child: _ReservoirCard()),
        SizedBox(width: 14),
        Expanded(flex: 3, child: _LightZoneCard()),
      ],
    );
  }
}

class _ReservoirCard extends StatelessWidget {
  const _ReservoirCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2ECE4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B23402B),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LabelRow(label: 'Water tank', icon: Icons.opacity_rounded),
                Text(
                  '72%',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                  ),
                ),
                Text(
                  'Enough reserve for 4 cycles',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718675),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 44, child: _LiquidMeter(value: 0.72)),
        ],
      ),
    );
  }
}

class _LiquidMeter extends StatelessWidget {
  const _LiquidMeter({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.12, end: value),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeOutCubic,
      builder: (context, fill, _) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F7F1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDCE8DE)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fill,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF3BA85F), Color(0xFF93D9A1)],
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.35,
                      child: CustomPaint(painter: _WavePainter(progress: fill)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LightZoneCard extends StatelessWidget {
  const _LightZoneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9FCF8), Color(0xFFEAF6EE)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFDCE8DE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const _LabelRow(label: 'LED arm', icon: Icons.light_mode_rounded),
          const Spacer(),
          const Text(
            'Plant A',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDFF4E5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Light zone active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D7B49),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5F816F)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF5F816F),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlantCardsRow extends StatelessWidget {
  const _PlantCardsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _PlantMiniCard(
            name: 'Plant A',
            species: 'Pilea',
            health: 0.78,
            lineColor: Color(0xFF2F8F5B),
            sparkline: [0.34, 0.4, 0.48, 0.51, 0.55, 0.62, 0.59, 0.68],
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _PlantMiniCard(
            name: 'Plant B',
            species: 'Monstera',
            health: 0.91,
            lineColor: Color(0xFF4CAF50),
            sparkline: [0.58, 0.56, 0.62, 0.64, 0.7, 0.78, 0.8, 0.86],
          ),
        ),
      ],
    );
  }
}

class _PlantMiniCard extends StatelessWidget {
  const _PlantMiniCard({
    required this.name,
    required this.species,
    required this.health,
    required this.lineColor,
    required this.sparkline,
  });

  final String name;
  final String species;
  final double health;
  final Color lineColor;
  final List<double> sparkline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 214,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: lineColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.eco_rounded, color: lineColor),
              ),
              const Spacer(),
              _HealthPill(value: health),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            species,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A9284),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(
                values: sparkline,
                lineColor: lineColor,
                fillColor: lineColor.withOpacity(0.08),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetricChip(
                label: 'Moisture',
                value: '${(health * 100).round()}%',
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Trend',
                value: health > 0.8 ? 'Rising' : 'Stable',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthPill extends StatelessWidget {
  const _HealthPill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final label = '${(value * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2F8F5B),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7A9284),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemSummaryPanel extends StatelessWidget {
  const _SystemSummaryPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System notes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'Plant B is currently in the light zone while Plant A remains in recovery. The reservoir is stable enough for the next irrigation cycle.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6E8577),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class PlantDetailsPage extends StatelessWidget {
  const PlantDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: const [
        _PlantHero(),
        SizedBox(height: 16),
        _PlantStatsGrid(),
        SizedBox(height: 16),
        _UrgencyGraphCard(),
      ],
    );
  }
}

class _PlantHero extends StatelessWidget {
  const _PlantHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Row(
        children: [
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFFEAF7EE), Color(0xFFD8EFDD)],
              ),
              borderRadius: BorderRadius.circular(32),
            ),
            child: const _BotanicalIllustration(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Individual Profile',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F8F5B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Monstera Deliciosa',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Growth phase: active | Urgency skewing high because of recent leaf expansion.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6E8577),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotanicalIllustration extends StatelessWidget {
  const _BotanicalIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 20,
          child: Container(
            width: 46,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF8E6E4A).withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          child: Container(
            width: 8,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3A7F4D),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 22,
          child: _Leaf(angle: -0.8, width: 42, height: 68),
        ),
        Positioned(
          top: 18,
          right: 20,
          child: _Leaf(angle: 0.6, width: 42, height: 72),
        ),
        Positioned(
          bottom: 36,
          left: 18,
          child: _Leaf(angle: -1.2, width: 32, height: 52),
        ),
        Positioned(
          bottom: 36,
          right: 16,
          child: _Leaf(angle: 1.0, width: 32, height: 52),
        ),
      ],
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.angle, required this.width, required this.height});

  final double angle;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6BBB74), Color(0xFF2F8F5B)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2F8F5B),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantStatsGrid extends StatelessWidget {
  const _PlantStatsGrid();

  @override
  Widget build(BuildContext context) {
    final tiles = <_StatTileData>[
      const _StatTileData(
        title: 'Soil moisture',
        value: '40%',
        subtitle: 'Below target range',
        icon: Icons.water_drop_rounded,
        accent: Color(0xFF4BAE67),
      ),
      const _StatTileData(
        title: 'Light intensity',
        value: '18k lux',
        subtitle: 'Within tolerance',
        icon: Icons.wb_sunny_rounded,
        accent: Color(0xFF6CBF73),
      ),
      const _StatTileData(
        title: 'Humidity',
        value: '62%',
        subtitle: 'Comfortable air',
        icon: Icons.water_damage_rounded,
        accent: Color(0xFF77C17A),
      ),
      const _StatTileData(
        title: 'Temperature',
        value: '24°',
        subtitle: 'Stable growing room',
        icon: Icons.thermostat_rounded,
        accent: Color(0xFF58A968),
      ),
    ];

    return GridView.builder(
      itemCount: tiles.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return _StatTile(data: tile);
      },
    );
  }
}

class _StatTileData {
  const _StatTileData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final _StatTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(data.icon, color: data.accent),
          ),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF698172),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8CA094),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyGraphCard extends StatelessWidget {
  const _UrgencyGraphCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Resource Urgency',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Growth phase',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2F8F5B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Moisture is only 40%, yet urgency is rising faster because the plant is actively expanding.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF768A7D),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: _UrgencyChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class CoordinatorLogPage extends StatelessWidget {
  const CoordinatorLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_DecisionEntry>[
      const _DecisionEntry(
        time: '08:12',
        icon: Icons.water_drop_rounded,
        title: 'Water Plant B - 50 ml',
        reason: 'Plant B reached 85% urgency; Plant A remained stable at 20%.',
        emphasis: 'Execution queued after reservoir check.',
        color: Color(0xFF2F8F5B),
      ),
      const _DecisionEntry(
        time: '08:06',
        icon: Icons.light_mode_rounded,
        title: 'Shift LED arm to Plant A',
        reason: 'Light deficit detected on Plant A after a cooling interval.',
        emphasis: 'Exposure window optimized for recovery.',
        color: Color(0xFF67B86C),
      ),
      const _DecisionEntry(
        time: '07:58',
        icon: Icons.engineering_rounded,
        title: 'System health scan completed',
        reason: 'Pump cycle, tank reserve, and servo travel all within bounds.',
        emphasis: 'No intervention required.',
        color: Color(0xFF8BBF6F),
      ),
      const _DecisionEntry(
        time: '07:41',
        icon: Icons.thermostat_rounded,
        title: 'Humidity correction deferred',
        reason:
            'Ambient humidity was acceptable and stable across the last 15 min.',
        emphasis: 'Avoided unnecessary actuation.',
        color: Color(0xFF86B97B),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFE2ECE4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coordinator Decision Log',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'A transparent feed of what the AI did and why it did it.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6E8577),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DecisionCard(entry: entry),
          ),
        ),
      ],
    );
  }
}

class _DecisionEntry {
  const _DecisionEntry({
    required this.time,
    required this.icon,
    required this.title,
    required this.reason,
    required this.emphasis,
    required this.color,
  });

  final String time;
  final IconData icon;
  final String title;
  final String reason;
  final String emphasis;
  final Color color;
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.entry});

  final _DecisionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: entry.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(entry.icon, color: entry.color),
              ),
              const SizedBox(height: 8),
              Container(
                width: 2,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1ECE3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7B9585),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F8F4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Logged',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5D7567),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF708477),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    entry.emphasis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF274635),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManualControlPage extends StatefulWidget {
  const ManualControlPage({super.key});

  @override
  State<ManualControlPage> createState() => _ManualControlPageState();
}

class _ManualControlPageState extends State<ManualControlPage> {
  bool _autoPilot = true;
  bool _pumpArmed = false;
  double _servoPosition = 0.62;
  double _pumpStrength = 0.42;

  @override
  Widget build(BuildContext context) {
    final accent =
        _autoPilot ? const Color(0xFF2F8F5B) : const Color(0xFFC98A1D);
    final background =
        _autoPilot ? const Color(0xFFF6F8F4) : const Color(0xFFFCF8EF);

    return Container(
      color: background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color:
                    _autoPilot
                        ? const Color(0xFFE2ECE4)
                        : const Color(0xFFF0DFC0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Intervention Hub',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _ModeBadge(autoPilot: _autoPilot),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _autoPilot
                      ? 'The system is in autonomous mode. Switch to manual only when you need direct hardware control.'
                      : 'Manual mode active. Controls are live and will override the coordinator until auto-pilot is restored.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6E8577),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _MasterSwitch(
                  value: _autoPilot,
                  accent: accent,
                  onChanged: (value) => setState(() => _autoPilot = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ControlPanel(
            title: 'LED arm position',
            subtitle: 'Servo travel for the light zone',
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    inactiveTrackColor: accent.withOpacity(0.18),
                    thumbColor: accent,
                    overlayColor: accent.withOpacity(0.08),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _servoPosition,
                    onChanged:
                        (value) => setState(() => _servoPosition = value),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Plant A',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${(_servoPosition * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Plant B',
                      style: TextStyle(
                        color: Color(0xFF7A9284),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ControlPanel(
            title: 'Water pump',
            subtitle: 'Hold to confirm irrigation',
            child: Column(
              children: [
                HoldToConfirmButton(
                  activeColor: accent,
                  confirmLabel: 'Hold to dispense 50 ml',
                  onConfirmed: () {
                    setState(() => _pumpArmed = !_pumpArmed);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ValueTile(
                        label: 'Pump strength',
                        value: '${(_pumpStrength * 100).round()}%',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ValueTile(
                        label: 'Arm state',
                        value: _pumpArmed ? 'Armed' : 'Idle',
                        accent: _pumpArmed ? accent : const Color(0xFF6F8274),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    inactiveTrackColor: accent.withOpacity(0.14),
                    thumbColor: accent,
                    overlayColor: accent.withOpacity(0.08),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: _pumpStrength,
                    onChanged: (value) => setState(() => _pumpStrength = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ControlPanel(
            title: 'System toggles',
            subtitle: 'Small switches with explicit state',
            child: Column(
              children: [
                _ToggleRow(
                  title: 'Soil sensor override',
                  value: _pumpArmed,
                  accent: accent,
                  onChanged: (value) => setState(() => _pumpArmed = value),
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  title: 'Manual light lock',
                  value: !_autoPilot,
                  accent: accent,
                  onChanged: (value) => setState(() => _autoPilot = !value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.autoPilot});

  final bool autoPilot;

  @override
  Widget build(BuildContext context) {
    final color = autoPilot ? const Color(0xFFEAF6EE) : const Color(0xFFF7E7C7);
    final textColor =
        autoPilot ? const Color(0xFF2F8F5B) : const Color(0xFFAC7412);
    final label = autoPilot ? 'Auto' : 'Manual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _MasterSwitch extends StatelessWidget {
  const _MasterSwitch({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0F7F1) : const Color(0xFFF8F1E2),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Master Auto-Pilot',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value
                    ? 'Autonomous behavior is active'
                    : 'Manual intervention is in control',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6E8577),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E8577),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6E8577),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.activeColor,
    required this.confirmLabel,
    required this.onConfirmed,
  });

  final Color activeColor;
  final String confirmLabel;
  final VoidCallback onConfirmed;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    _controller.reverse();
    setState(() => _completed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _completed = false;
        _controller.forward().whenComplete(() {
          if (mounted) {
            setState(() => _completed = true);
          }
        });
      },
      onLongPressEnd: (_) {
        if (_completed) {
          widget.onConfirmed();
        }
        _reset();
      },
      onLongPressCancel: _reset,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final fill = _controller.value;
          return Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAF9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDBE8DD)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.activeColor.withOpacity(0.22),
                            widget.activeColor.withOpacity(0.45),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      _completed ? 'Dispensed' : widget.confirmLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: widget.activeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDEBDD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2F8F5B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F8F5B),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  _RadialGaugePainter({
    required this.progress,
    required this.baseColor,
    required this.fillColor,
  });

  final double progress;
  final Color baseColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final basePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = baseColor;
    final fillPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [fillColor, fillColor.withOpacity(0.5)],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

    const startAngle = -math.pi * 0.8;
    const sweep = math.pi * 1.6;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      basePaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep * progress,
      false,
      fillPaint,
    );

    final dotAngle = startAngle + sweep * progress;
    final dotCenter = Offset(
      center.dx + math.cos(dotAngle) * radius,
      center.dy + math.sin(dotAngle) * radius,
    );
    canvas.drawCircle(dotCenter, 7, Paint()..color = fillColor);
    canvas.drawCircle(dotCenter, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final fillPaint =
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = (size.width / (values.length - 1)) * i;
      final dy = size.height - (values[i] * size.height);
      points.add(Offset(dx, dy));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlPoint1 = Offset((previous.dx + current.dx) / 2, previous.dy);
      final controlPoint2 = Offset((previous.dx + current.dx) / 2, current.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(point, 2.8, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _UrgencyChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final values = [0.18, 0.24, 0.31, 0.42, 0.39, 0.58, 0.69, 0.84, 0.88];
    final backgroundPaint =
        Paint()
          ..color = const Color(0xFFF3F7F3)
          ..style = PaintingStyle.fill;
    final axisPaint =
        Paint()
          ..color = const Color(0xFFDFE8E0)
          ..strokeWidth = 1;
    final linePaint =
        Paint()
          ..color = const Color(0xFF2F8F5B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final fillPaint =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x662F8F5B), Color(0x002F8F5B)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

    final chartRect = Rect.fromLTWH(10, 8, size.width - 20, size.height - 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(20)),
      backgroundPaint,
    );

    const left = 34.0;
    const right = 18.0;
    const top = 22.0;
    const bottom = 28.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;

    for (var i = 0; i < 4; i++) {
      final y = top + height * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        axisPaint,
      );
    }

    final path = Path();
    final area = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = left + (width / (values.length - 1)) * i;
      final dy = top + height - values[i] * height;
      points.add(Offset(dx, dy));
    }

    path.moveTo(points.first.dx, points.first.dy);
    area.moveTo(points.first.dx, top + height);
    area.lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final c1 = Offset((previous.dx + current.dx) / 2, previous.dy);
      final c2 = Offset((previous.dx + current.dx) / 2, current.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
      area.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
    }
    area.lineTo(points.last.dx, top + height);
    area.close();

    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);

    final highlight = points[points.length - 2];
    canvas.drawCircle(
      highlight,
      8,
      Paint()..color = const Color(0xFF2F8F5B).withOpacity(0.15),
    );
    canvas.drawCircle(highlight, 4.5, Paint()..color = const Color(0xFF2F8F5B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..style = PaintingStyle.fill;
    final path = Path();
    final waveHeight = size.height * (1 - progress);
    path.moveTo(0, size.height);
    path.lineTo(0, waveHeight);
    for (var i = 0; i <= 12; i++) {
      final x = size.width * i / 12;
      final y =
          waveHeight +
          math.sin((i / 12) * math.pi * 2 + progress * math.pi * 2) * 4;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
