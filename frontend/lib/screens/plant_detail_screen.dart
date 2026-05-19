import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';
import '../widgets/shared_widgets.dart';

class PlantDetailScreen extends StatefulWidget {
  final PlantModel plant;
  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  PlantModel get p => widget.plant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          TabBar(
            controller: _tabCtrl,
            labelColor: p.color,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: p.color,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            tabs: const [
              Tab(text: 'Stats'),
              Tab(text: 'Info'),
              Tab(text: 'Conditions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _StatsTab(plant: p),
                _InfoTab(plant: p),
                _ConditionsTab(plant: p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: p.color,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 18, color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner_outlined,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusDot(color: p.statusColor),
                            const SizedBox(width: 6),
                            Text(
                              p.statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.species,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _HeaderPill(label: p.type),
                            const SizedBox(width: 8),
                            _HeaderPill(label: '${p.addedWeeks} weeks'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PlantWidget(
                    type: p.svgType,
                    color: Colors.white.withOpacity(0.9),
                    size: 110,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              color: Colors.black.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _QuickStat(
                    val: '${p.waterTank}%',
                    label: 'Water Tank',
                    warn: p.waterTank < 20,
                  ),
                  _VertDivider(),
                  _QuickStat(
                    val: '${p.humidity}%',
                    label: 'Humidity',
                  ),
                  _VertDivider(),
                  _QuickStat(
                    val: '${p.nextWateringMinutes}m',
                    label: 'Next Water',
                    warn: p.nextWateringMinutes < 60,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  const _HeaderPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String val;
  final String label;
  final bool warn;
  const _QuickStat(
      {required this.val, required this.label, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: warn ? const Color(0xFFFCD34D) : Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 30,
      color: Colors.white.withOpacity(0.15),
    );
  }
}

// ── Stats Tab ──────────────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final PlantModel plant;
  const _StatsTab({required this.plant});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.mintBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                RadialGauge(
                  value: plant.moisture,
                  label: 'Moisture',
                  unit: '%',
                  warning: plant.moisture < 30,
                ),
                RadialGauge(
                  value: plant.light,
                  label: 'Light',
                  unit: '%',
                ),
                RadialGauge(
                  value: plant.fertilizer,
                  label: 'Fert.',
                  unit: '%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          StatBar(
              value: plant.health,
              color: plant.color,
              label: 'Overall Health'),
          StatBar(
            value: plant.waterTank,
            color: plant.waterTank < 20
                ? AppTheme.danger
                : const Color(0xFF0369A1),
            label: 'Water Tank',
          ),
          StatBar(
              value: plant.humidity,
              color: plant.color,
              label: 'Humidity'),
          StatBar(
            value: plant.temp,
            color: plant.color,
            label: 'Temperature',
            unit: '°C',
          ),
          if (plant.waterTank < 20) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.danger, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Water tank critically low — please refill the reservoir',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Info Tab ───────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final PlantModel plant;
  const _InfoTab({required this.plant});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: plant.lightColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              plant.description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'In your collection',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              InfoCard(label: 'Added', value: '${plant.addedWeeks} weeks ago'),
              InfoCard(label: 'Last watered', value: plant.lastWatered),
              InfoCard(
                  label: 'Next watering',
                  value: '${plant.nextWateringMinutes} min'),
              InfoCard(label: 'Status', value: plant.statusLabel),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Conditions Tab ─────────────────────────────────────────────────────────
class _ConditionsTab extends StatelessWidget {
  final PlantModel plant;
  const _ConditionsTab({required this.plant});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ideal growing conditions for ${plant.name}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          ...plant.idealConditions.entries.map((e) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500)),
                        Text(e.value,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: plant.color)),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.border, height: 0),
                ],
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: plant.lightColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Symbiosis Agent Note',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The ${plant.name} agent has adapted its utility function over ${plant.addedWeeks} weeks. Current watering coefficient: 1.${(plant.moisture * 0.1 + 12).round()}x baseline.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.5,
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
