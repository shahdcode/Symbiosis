import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';
import '../widgets/shared_widgets.dart';
import 'plant_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  int get _avgHealth =>
      (myPlants.fold(0, (s, p) => s + p.health) / myPlants.length).round();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildResourceAllocation()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: const Text(
                'Individual Stats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: _PlantStatCard(plant: myPlants[i]),
              ),
              childCount: myPlants.length,
            ),
          ),
          SliverToBoxAdapter(child: _buildAgentLog()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.deepGreen,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYMBIOSIS DASHBOARD',
            style: TextStyle(
              fontSize: 11,
              color: Color(0x80FFFFFF),
              letterSpacing: 0.9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Garden Overview',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DarkStat(val: '$_avgHealth%', label: 'Avg Health'),
              const SizedBox(width: 8),
              _DarkStat(val: '${myPlants.length}', label: 'Plants'),
              const SizedBox(width: 8),
              _DarkStat(val: '68%', label: 'Water Tank'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceAllocation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resource Allocation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.mintBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Water Distribution',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '4 paths active',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children:
                      myPlants
                          .map(
                            (p) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                height: 8,
                                decoration: BoxDecoration(
                                  color: p.color.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 3),
                Row(
                  children:
                      myPlants
                          .map(
                            (p) => Expanded(
                              child: Text(
                                p.name.substring(0, 3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const Divider(color: Color(0xFFE5E7EB), height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'LED Position',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Zone A (Monstera)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Positioned(
                      left:
                          ((navigatorKey.currentContext != null)
                                  ? MediaQuery.of(
                                    navigatorKey.currentContext!,
                                  ).size.width
                                  : 375.0) *
                              0.2 -
                          40,
                      top: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCD34D),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFCD34D).withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Zone A',
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                    Text(
                      'Zone B',
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                    Text(
                      'Zone C',
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                    Text(
                      'Zone D',
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentLog() {
    final logs = [
      _LogEntry(
        time: '09:41',
        event: 'Coordinator allocated water to Calathea (urgency: 0.87)',
        color: AppTheme.danger,
      ),
      _LogEntry(
        time: '09:28',
        event: 'LED shifted to Zone B — Fiddle Leaf entered growth phase',
        color: AppTheme.warning,
      ),
      _LogEntry(
        time: '08:55',
        event: 'Peace Lily agent reported stable — no action required',
        color: AppTheme.success,
      ),
      _LogEntry(
        time: '08:12',
        event: 'Adaptive model updated Monstera moisture coefficient',
        color: const Color(0xFF7C3AED),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agent Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.mintBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children:
                  logs
                      .asMap()
                      .entries
                      .map(
                        (e) => Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: e.value.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.value.event,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${e.value.time} AM',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (e.key < logs.length - 1)
                              const Divider(
                                color: Color(0xFFE5E7EB),
                                height: 20,
                              ),
                          ],
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Hack to get a build context for the LED indicator width
// In a real app, use LayoutBuilder instead
final navigatorKey = GlobalKey<NavigatorState>();
final _fakeCtx = navigatorKey.currentContext;

extension on Null {
  get size => const _FakeSize();
}

class _FakeSize {
  double get width => 375;
  const _FakeSize();
}

class _DarkStat extends StatelessWidget {
  final String val;
  final String label;
  const _DarkStat({required this.val, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogEntry {
  final String time;
  final String event;
  final Color color;
  const _LogEntry({
    required this.time,
    required this.event,
    required this.color,
  });
}

class _PlantStatCard extends StatelessWidget {
  final PlantModel plant;
  const _PlantStatCard({required this.plant});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, a, b) => PlantDetailScreen(plant: plant),
              transitionsBuilder:
                  (_, a, b, child) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                    ),
                    child: child,
                  ),
              transitionDuration: const Duration(milliseconds: 320),
            ),
          ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: plant.lightColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: PlantWidget(
                      type: plant.svgType,
                      color: plant.color,
                      size: 38,
                      animate: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plant.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusDot(color: plant.statusColor),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        plant.species,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plant.health}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                            plant.health > 85
                                ? const Color(0xFF16A34A)
                                : plant.health > 70
                                ? const Color(0xFFD97706)
                                : AppTheme.danger,
                      ),
                    ),
                    const Text(
                      'Health',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniStat(
                  label: 'Moisture',
                  value: '${plant.moisture}%',
                  low: plant.moisture < 30,
                ),
                const SizedBox(width: 8),
                _MiniStat(label: 'Light', value: '${plant.light}%'),
                const SizedBox(width: 8),
                _MiniStat(label: 'Humidity', value: '${plant.humidity}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool low;
  const _MiniStat({required this.label, required this.value, this.low = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: low ? const Color(0xFFFEF2F2) : AppTheme.mintBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: low ? AppTheme.danger : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
