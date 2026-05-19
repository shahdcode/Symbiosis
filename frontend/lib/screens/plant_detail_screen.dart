import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';
import '../widgets/shared_widgets.dart';

class _PlantDetailViewModel {
  final String name;
  final String species;
  final String type;
  final String statusLabel;
  final Color statusColor;
  final Color color;
  final Color lightColor;
  final PlantSvgType svgType;
  final double moisture;
  final double humidity;
  final double light;
  final double temp;
  final double waterTank;
  final double fertilizer;
  final double nextWateringMinutes;
  final String lastWatered;
  final int addedWeeks;
  final double health;
  final String description;
  final Map<String, String> idealConditions;

  const _PlantDetailViewModel({
    required this.name,
    required this.species,
    required this.type,
    required this.statusLabel,
    required this.statusColor,
    required this.color,
    required this.lightColor,
    required this.svgType,
    required this.moisture,
    required this.humidity,
    required this.light,
    required this.temp,
    required this.waterTank,
    required this.fertilizer,
    required this.nextWateringMinutes,
    required this.lastWatered,
    required this.addedWeeks,
    required this.health,
    required this.description,
    required this.idealConditions,
  });

  factory _PlantDetailViewModel.fromLocal(PlantModel plant) {
    return _PlantDetailViewModel(
      name: plant.name,
      species: plant.species,
      type: plant.type,
      statusLabel: plant.statusLabel,
      statusColor: plant.statusColor,
      color: plant.color,
      lightColor: plant.lightColor,
      svgType: plant.svgType,
      moisture: plant.moisture.toDouble(),
      humidity: plant.humidity.toDouble(),
      light: plant.light.toDouble(),
      temp: plant.temp.toDouble(),
      waterTank: plant.waterTank.toDouble(),
      fertilizer: plant.fertilizer.toDouble(),
      nextWateringMinutes: plant.nextWateringMinutes.toDouble(),
      lastWatered: plant.lastWatered,
      addedWeeks: plant.addedWeeks,
      health: plant.health.toDouble(),
      description: plant.description,
      idealConditions: plant.idealConditions,
    );
  }

  factory _PlantDetailViewModel.fromBackend(
    PlantModel fallback,
    BackendPlantDetail detail,
  ) {
    final stats = detail.stats;
    final backendPlant = detail.plant;
    final status = stats.status.toLowerCase();
    final statusColor = switch (status) {
      'thriving' => const Color(0xFF4CAF50),
      'attention' => const Color(0xFFFF9800),
      _ => const Color(0xFF2196F3),
    };
    final color = switch (status) {
      'thriving' => const Color(0xFF2D5A27),
      'attention' => const Color(0xFF9A3412),
      _ => const Color(0xFF2A5C3F),
    };
    final lightColor = switch (status) {
      'thriving' => const Color(0xFFE8F5E3),
      'attention' => const Color(0xFFFFF4E5),
      _ => const Color(0xFFE2F0EB),
    };

    return _PlantDetailViewModel(
      name: backendPlant.label,
      species: backendPlant.species,
      type: backendPlant.typeLabel,
      statusLabel:
          status == 'attention'
              ? 'Attention'
              : status == 'thriving'
              ? 'Thriving'
              : 'Resting',
      statusColor: statusColor,
      color: color,
      lightColor: lightColor,
      svgType: backendPlant.svgType,
      moisture: stats.moisture,
      humidity: stats.humidity,
      light: stats.light,
      temp: stats.temp,
      waterTank: stats.waterTank,
      fertilizer: stats.fertilizer,
      nextWateringMinutes: stats.nextWateringMinutes,
      lastWatered: stats.lastWatered,
      addedWeeks: stats.addedWeeks > 0 ? stats.addedWeeks : fallback.addedWeeks,
      health: stats.health,
      description:
          backendPlant.notes?.trim().isNotEmpty == true
              ? backendPlant.notes!.trim()
              : fallback.description,
      idealConditions: {
        'Moisture':
            '${backendPlant.moistureMin.round()}–${backendPlant.moistureMax.round()}%',
        'Humidity':
            '${backendPlant.humidityMin.round()}–${backendPlant.humidityMax.round()}%',
        'Light': 'Ellenberg ${backendPlant.lightValue.toStringAsFixed(1)}',
        'Temperature':
            '${backendPlant.tempMinC.round()}–${backendPlant.tempMaxC.round()}°C',
        'Watering': '${stats.nextWateringMinutes.round()} min',
      },
    );
  }
}

class PlantDetailScreen extends StatefulWidget {
  final PlantModel plant;
  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late Future<_PlantDetailViewModel> _detailFuture;
  final BackendApi _api = BackendApi();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  PlantModel get p => widget.plant;

  String _normalize(String value) => value.trim().toLowerCase();

  bool _matchesBackendPlant(BackendPlant backendPlant) {
    final localName = _normalize(p.name);
    final localSpecies = _normalize(p.species);
    final backendCommon = _normalize(backendPlant.commonName);
    final backendSpecies = _normalize(backendPlant.species);

    return backendPlant.plantId == _normalize(p.name) ||
        backendCommon == localName ||
        backendSpecies == localSpecies ||
        backendCommon.contains(localName) ||
        localName.contains(backendCommon) ||
        backendSpecies.contains(localSpecies) ||
        localSpecies.contains(backendSpecies);
  }

  Future<_PlantDetailViewModel> _loadDetail() async {
    try {
      final plants = await _api.fetchPlants();
      BackendPlant? match;
      for (final plant in plants) {
        if (_matchesBackendPlant(plant)) {
          match = plant;
          break;
        }
      }

      if (match != null) {
        final detail = await _api.fetchPlantDetail(match.plantId);
        return _PlantDetailViewModel.fromBackend(p, detail);
      }
    } catch (_) {
      // Fall back to the local model below.
    }
    return _PlantDetailViewModel.fromLocal(p);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlantDetailViewModel>(
      future: _detailFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final data = snapshot.data ?? _PlantDetailViewModel.fromLocal(p);

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              if (loading)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              _buildHeader(context, data),
              TabBar(
                controller: _tabCtrl,
                labelColor: data.color,
                unselectedLabelColor: AppTheme.textMuted,
                indicatorColor: data.color,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
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
                    _StatsTab(plant: data),
                    _InfoTab(plant: data),
                    _ConditionsTab(plant: data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, _PlantDetailViewModel plant) {
    return Container(
      color: plant.color,
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
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
                            StatusDot(color: plant.statusColor),
                            const SizedBox(width: 6),
                            Text(
                              plant.statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plant.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plant.species,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _HeaderPill(label: plant.type),
                            const SizedBox(width: 8),
                            _HeaderPill(label: '${plant.addedWeeks} weeks'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PlantWidget(
                    type: plant.svgType,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 110,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _QuickStat(
                    val: '${plant.waterTank.toStringAsFixed(0)}%',
                    label: 'Water Tank',
                    warn: plant.waterTank < 20,
                  ),
                  _VertDivider(),
                  _QuickStat(
                    val: '${plant.humidity.toStringAsFixed(0)}%',
                    label: 'Humidity',
                  ),
                  _VertDivider(),
                  _QuickStat(
                    val: '${plant.nextWateringMinutes.toStringAsFixed(0)}m',
                    label: 'Next Water',
                    warn: plant.nextWateringMinutes < 60,
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String val;
  final String label;
  final bool warn;
  const _QuickStat({required this.val, required this.label, this.warn = false});

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
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
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
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

// ── Stats Tab ──────────────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final _PlantDetailViewModel plant;
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
                  value: plant.moisture.round(),
                  label: 'Moisture',
                  unit: '%',
                  warning: plant.moisture < 30,
                ),
                RadialGauge(
                  value: plant.light.round(),
                  label: 'Light',
                  unit: '%',
                ),
                RadialGauge(
                  value: plant.fertilizer.round(),
                  label: 'Fert.',
                  unit: '%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          StatBar(
            value: plant.health.round(),
            color: plant.color,
            label: 'Overall Health',
          ),
          StatBar(
            value: plant.waterTank.round(),
            color:
                plant.waterTank < 20
                    ? AppTheme.danger
                    : const Color(0xFF0369A1),
            label: 'Water Tank',
          ),
          StatBar(
            value: plant.humidity.round(),
            color: plant.color,
            label: 'Humidity',
          ),
          StatBar(
            value: plant.temp.round(),
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
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.danger,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Water tank critically low — please refill the reservoir',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                      ),
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
  final _PlantDetailViewModel plant;
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
                value: '${plant.nextWateringMinutes.toStringAsFixed(0)} min',
              ),
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
  final _PlantDetailViewModel plant;
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
          ...plant.idealConditions.entries.map(
            (e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: plant.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppTheme.border, height: 0),
              ],
            ),
          ),
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
