import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';
import '../widgets/shared_widgets.dart';
import 'plant_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BackendApi _api = BackendApi();
  late Future<_DashboardSnapshot> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<String> _fetchLidStatus() async {
    // TODO: replace with actual API call that returns lid status ('Open' or 'Closed')
    // Example: return await _api.getLidStatus();
    // For now, return a default value or simulate based on some logic
    return 'Closed';
  }

  Future<_DashboardSnapshot> _loadDashboard() async {
    try {
      final backendPlants = await _api.fetchPlants();
      final details = await Future.wait(
        backendPlants.map((plant) async {
          try {
            return await _api.fetchPlantDetail(plant.plantId);
          } catch (_) {
            return null;
          }
        }),
      );

      final plants = <PlantModel>[];
      final logEntries = <_LogEntry>[];
      for (var i = 0; i < backendPlants.length; i++) {
        final backendPlant = backendPlants[i];
        final detail = details[i];
        final plant = _toPlantModel(backendPlant, detail, i);
        plants.add(plant);
        logEntries.addAll(_logEntriesForPlant(plant, detail));
      }

      logEntries.sort((a, b) => b.weight.compareTo(a.weight));

      final avgHealth =
          plants.isEmpty
              ? 0
              : (plants.fold<int>(0, (sum, plant) => sum + plant.health) /
                      plants.length)
                  .round();
      final avgWaterTank =
          plants.isEmpty
              ? 0
              : (plants.fold<int>(0, (sum, plant) => sum + plant.waterTank) /
                      plants.length)
                  .round();

      final lidStatus = await _fetchLidStatus();

      return _DashboardSnapshot(
        plants: plants,
        avgHealth: avgHealth,
        waterTank: avgWaterTank,
        lidStatus: lidStatus,
        logEntries:
            logEntries.isEmpty
                ? [
                  const _LogEntry(
                    time: 'now',
                    event: 'No backend plant data yet',
                    color: AppTheme.textMuted,
                    weight: 0,
                  ),
                ]
                : logEntries.take(4).toList(),
      );
    } catch (_) {
      // Fallback with default lid status
      return _DashboardSnapshot(
        plants: myPlants,
        avgHealth:
            myPlants.isEmpty
                ? 0
                : (myPlants.fold<int>(0, (sum, plant) => sum + plant.health) /
                        myPlants.length)
                    .round(),
        waterTank:
            myPlants.isEmpty
                ? 0
                : (myPlants.fold<int>(
                          0,
                          (sum, plant) => sum + plant.waterTank,
                        ) /
                        myPlants.length)
                    .round(),
        lidStatus: 'Closed',
        logEntries: const [
          _LogEntry(
            time: 'now',
            event: 'Dashboard loaded from local fallback data',
            color: AppTheme.textMuted,
            weight: 0,
          ),
        ],
      );
    }
  }

  PlantModel _toPlantModel(
    BackendPlant backendPlant,
    BackendPlantDetail? detail,
    int index,
  ) {
    final stats = detail?.stats;
    final status = _statusFromString(stats?.status);
    final palette = _paletteForIndex(index);
    final addedWeeks = stats?.addedWeeks ?? 0;
    final health =
        stats?.health.round() ?? _fallbackHealth(backendPlant, index);
    return PlantModel(
      id: index + 1,
      name: backendPlant.label,
      species: backendPlant.species,
      type: backendPlant.typeLabel,
      status: status,
      moisture: stats?.moisture.round() ?? backendPlant.optimalMoisture.round(),
      humidity:
          stats?.humidity.round() ?? backendPlant.preferredHumidityPct.round(),
      light: stats?.light.round() ?? backendPlant.lightValue.round(),
      temp: stats?.temp.round() ?? backendPlant.optimalTempC.round(),
      waterTank: stats?.waterTank.round() ?? 68,
      fertilizer: stats?.fertilizer.round() ?? 40,
      nextWateringMinutes: stats?.nextWateringMinutes.round() ?? 60,
      lastWatered: stats?.lastWatered ?? 'Unknown',
      addedWeeks: addedWeeks > 0 ? addedWeeks : index + 1,
      health: health,
      description:
          backendPlant.notes?.trim().isNotEmpty == true
              ? backendPlant.notes!.trim()
              : 'Live backend snapshot for ${backendPlant.label}.',
      idealConditions: {
        'Moisture':
            '${backendPlant.moistureMin.round()}–${backendPlant.moistureMax.round()}%',
        'Humidity':
            '${backendPlant.humidityMin.round()}–${backendPlant.humidityMax.round()}%',
        'Light': 'Ellenberg ${backendPlant.lightValue.toStringAsFixed(1)}',
        'Temperature':
            '${backendPlant.tempMinC.round()}–${backendPlant.tempMaxC.round()}°C',
        'Watering': '${stats?.nextWateringMinutes.round() ?? 60} min',
      },
      color: palette.$1,
      lightColor: palette.$2,
      svgType: backendPlant.svgType,
    );
  }

  int _fallbackHealth(BackendPlant plant, int index) {
    final score = 70 + (plant.optimalMoisture / 5).round() - index * 2;
    return score.clamp(55, 96);
  }

  PlantStatus _statusFromString(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'thriving':
        return PlantStatus.thriving;
      case 'attention':
        return PlantStatus.attention;
      default:
        return PlantStatus.resting;
    }
  }

  (Color, Color) _paletteForIndex(int index) {
    const palettes = [
      (Color(0xFF2D5A27), Color(0xFFE8F5E3)),
      (Color(0xFF1A6B3A), Color(0xFFE0F4EA)),
      (Color(0xFF3D6B1A), Color(0xFFEBF5E0)),
      (Color(0xFF2A5C3F), Color(0xFFE2F0EB)),
      (Color(0xFF8B5E34), Color(0xFFF8EDE3)),
    ];
    return palettes[index % palettes.length];
  }

  List<_LogEntry> _logEntriesForPlant(
    PlantModel plant,
    BackendPlantDetail? detail,
  ) {
    final stats = detail?.stats;
    final entries = <_LogEntry>[];
    if (stats != null) {
      entries.add(
        _LogEntry(
          time: 'now',
          event:
              '${plant.name} synced: ${stats.health.round()}% health, ${stats.moisture.round()}% moisture',
          color: stats.health < 70 ? AppTheme.warning : AppTheme.success,
          weight: stats.health,
        ),
      );
      if (stats.waterTank < 20) {
        entries.add(
          _LogEntry(
            time: 'now',
            event:
                '${plant.name} water tank low — ${stats.waterTank.round()}% remaining',
            color: AppTheme.danger,
            weight: 100 - stats.waterTank,
          ),
        );
      }
      return entries;
    }

    entries.add(
      _LogEntry(
        time: 'now',
        event: '${plant.name} loaded from backend profile',
        color: AppTheme.primaryGreen,
        weight: plant.health.toDouble(),
      ),
    );
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardSnapshot>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _DashboardSnapshot.fallback();
        final loading = snapshot.connectionState != ConnectionState.done;

        return SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (loading)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              SliverToBoxAdapter(child: _buildHeader(data)),
              SliverToBoxAdapter(child: _buildResourceAllocation(data)),
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
                    child: _PlantStatCard(plant: data.plants[i]),
                  ),
                  childCount: data.plants.length,
                ),
              ),
              SliverToBoxAdapter(child: _buildAgentLog(data)),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(_DashboardSnapshot data) {
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
              _DarkStat(val: '${data.avgHealth}%', label: 'Avg Health'),
              const SizedBox(width: 8),
              _DarkStat(val: '${data.plants.length}', label: 'Plants'),
              const SizedBox(width: 8),
              _DarkStat(val: '${data.waterTank}%', label: 'Water Tank'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResourceAllocation(_DashboardSnapshot data) {
    final plantNames =
        data.plants.isEmpty
            ? ['No plants']
            : data.plants.map((plant) => plant.name).toList();
    final lidStatus = data.lidStatus;
    final lidColor = lidStatus == 'Open' ? Color(0xFF4ADE80) : Color(0xFFEF4444);
    final lidIcon = lidStatus == 'Open' ? Icons.door_front_door_outlined : Icons.door_back_door_outlined;

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
                // Water distribution bar (unchanged)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Water Distribution',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${data.plants.length} paths active',
                      style: const TextStyle(
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
                      data.plants.isEmpty
                          ? [
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.border,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ]
                          : data.plants
                              .map(
                                (p) => Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: p.color.withValues(alpha: 0.75),
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
                      plantNames
                          .map(
                            (name) => Expanded(
                              child: Text(
                                name.length > 3 ? name.substring(0, 3) : name,
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

                // Lid Status section (replaces LED position)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lid Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: lidColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(lidIcon, size: 14, color: lidColor),
                          const SizedBox(width: 4),
                          Text(
                            lidStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: lidColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Simple status indicator (no slider, just a visual cue)
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: lidColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: lidStatus == 'Open'
                      ? FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Container(
                            decoration: BoxDecoration(
                              color: lidColor,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        )
                      : FractionallySizedBox(
                          widthFactor: 0.2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: lidColor,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Closed',
                      style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                    ),
                    Text(
                      'Open',
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

  Widget _buildAgentLog(_DashboardSnapshot data) {
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
                  data.logEntries.asMap().entries.map((e) {
                    return Column(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    e.value.time,
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
                        if (e.key < data.logEntries.length - 1)
                          const Divider(color: Color(0xFFE5E7EB), height: 20),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
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
          color: Colors.white.withValues(alpha: 0.08),
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
                color: Colors.white.withValues(alpha: 0.5),
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
  final double weight;
  const _LogEntry({
    required this.time,
    required this.event,
    required this.color,
    required this.weight,
  });
}

class _DashboardSnapshot {
  final List<PlantModel> plants;
  final int avgHealth;
  final int waterTank;
  final String lidStatus;
  final List<_LogEntry> logEntries;

  const _DashboardSnapshot({
    required this.plants,
    required this.avgHealth,
    required this.waterTank,
    required this.lidStatus,
    required this.logEntries,
  });

  factory _DashboardSnapshot.fallback() {
    return _DashboardSnapshot(
      plants: myPlants,
      avgHealth:
          myPlants.isEmpty
              ? 0
              : (myPlants.fold<int>(0, (sum, plant) => sum + plant.health) /
                      myPlants.length)
                  .round(),
      waterTank:
          myPlants.isEmpty
              ? 0
              : (myPlants.fold<int>(0, (sum, plant) => sum + plant.waterTank) /
                      myPlants.length)
                  .round(),
      lidStatus: 'Closed',
      logEntries: const [
        _LogEntry(
          time: 'now',
          event: 'Using local fallback dashboard data',
          color: AppTheme.textMuted,
          weight: 0,
        ),
      ],
    );
  }
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