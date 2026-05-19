import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/plant_card.dart';
import '../widgets/shared_widgets.dart';
import 'dashboard_screen.dart';
import 'plant_detail_screen.dart';
import 'scan_screen.dart';
import 'explore_screen.dart';
import 'add_plant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  bool _showNotification = true;
  final BackendApi _api = BackendApi();
  Future<List<PlantModel>>? _homePlantsFuture;

  @override
  void initState() {
    super.initState();
    _homePlantsFuture = _loadHomePlants();
  }

  Future<List<PlantModel>> get _plantsFuture =>
      _homePlantsFuture ??= _loadHomePlants();

  Future<List<PlantModel>> _loadHomePlants() async {
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

      return List<PlantModel>.generate(backendPlants.length, (index) {
        return _toPlantModel(backendPlants[index], details[index], index);
      });
    } catch (_) {
      return myPlants;
    }
  }

  Future<void> _refreshHomePlants() async {
    if (!mounted) return;
    setState(() {
      _homePlantsFuture = _loadHomePlants();
    });
  }

  PlantModel _toPlantModel(
    BackendPlant backendPlant,
    BackendPlantDetail? detail,
    int index,
  ) {
    final stats = detail?.stats;
    final palette = _paletteForIndex(index);
    final status = _statusFromString(stats?.status);
    final addedWeeks = stats?.addedWeeks ?? 0;
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
      health: stats?.health.round() ?? 76,
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

  PlantStatus _statusFromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
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

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    setState(() => _navIndex = index);
  }

  Widget _buildBody() {
    switch (_navIndex) {
      case 1:
        return const DashboardScreen();
      case 2:
        return const ScanScreen();
      case 3:
        return ExploreScreen(onPlantAdded: _refreshHomePlants);
      default:
        return FutureBuilder<List<PlantModel>>(
          future: _plantsFuture,
          builder: (context, snapshot) {
            final plants = snapshot.data ?? myPlants;
            return _HomeBody(
              showNotification: _showNotification,
              plants: plants,
              onDismissNotification:
                  () => setState(() => _showNotification = false),
              onNavigateDashboard: () => setState(() => _navIndex = 1),
              onNavigatePlant: (plant) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, a, b) => PlantDetailScreen(plant: plant),
                    transitionsBuilder:
                        (_, a, b, child) => SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: a,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                    transitionDuration: const Duration(milliseconds: 320),
                  ),
                );
              },
              onNavigateScan: () => setState(() => _navIndex = 2),
              onNavigateAdd: () async {
                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, a, b) => const AddPlantScreen(),
                    transitionsBuilder:
                        (_, a, b, child) => SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: a,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                    transitionDuration: const Duration(milliseconds: 320),
                  ),
                );
                await _refreshHomePlants();
              },
            );
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder:
            (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(_navIndex), child: _buildBody()),
      ),
      bottomNavigationBar: SymbiosisBottomNav(
        currentIndex: _navIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final bool showNotification;
  final List<PlantModel> plants;
  final VoidCallback onDismissNotification;
  final VoidCallback onNavigateDashboard;
  final Function(PlantModel) onNavigatePlant;
  final VoidCallback onNavigateScan;
  final VoidCallback onNavigateAdd;

  const _HomeBody({
    required this.showNotification,
    required this.plants,
    required this.onDismissNotification,
    required this.onNavigateDashboard,
    required this.onNavigatePlant,
    required this.onNavigateScan,
    required this.onNavigateAdd,
  });

  int get _attentionCount =>
      plants.where((p) => p.status == PlantStatus.attention).length;

  int get _thrivingCount =>
      plants.where((p) => p.status == PlantStatus.thriving).length;

  int get _averageWaterTank =>
      plants.isEmpty
          ? 0
          : (plants.fold<int>(0, (sum, plant) => sum + plant.waterTank) /
                  plants.length)
              .round();

  PlantModel? get _nextWateringPlant {
    if (plants.isEmpty) return null;
    final sorted = [...plants]
      ..sort((a, b) => a.nextWateringMinutes.compareTo(b.nextWateringMinutes));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (showNotification) SliverToBoxAdapter(child: _buildNotification()),
          SliverToBoxAdapter(child: _buildSummaryPills()),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'My Plants',
              action: 'See stats',
              onAction: onNavigateDashboard,
            ),
          ),
          SliverToBoxAdapter(child: _buildPlantCards()),
          SliverToBoxAdapter(child: _buildSystemStatus()),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildQuickActions()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Good morning',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'My Garden',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: onNavigateAdd,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  if (_attentionCount > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '$_attentionCount',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotification() {
    final nextWatering = _nextWateringPlant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.water_drop_outlined,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nextWatering == null
                    ? 'No plants connected yet — add your first plant'
                    : '${nextWatering.name} needs water soon — ${nextWatering.nextWateringMinutes} min',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismissNotification,
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPills() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _Pill(
            label: '${plants.length} Plants',
            bg: AppTheme.lightGreen,
            text: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 8),
          _Pill(
            label: '$_thrivingCount Thriving',
            bg: AppTheme.lightGreen,
            text: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          _Pill(
            label: '$_attentionCount Attention',
            bg: const Color(0xFFFFF3E0),
            text: const Color(0xFFD97706),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCards() {
    final visiblePlants = plants.isEmpty ? myPlants : plants;
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        itemCount: visiblePlants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder:
            (_, i) => PlantCard(
              plant: visiblePlants[i],
              onTap: () => onNavigatePlant(visiblePlants[i]),
              index: i,
            ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.deepGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SYMBIOSIS',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'System Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x264ADE80),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4ADE80),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
              children: [
                DarkStatCard(
                  label: 'Water Tank',
                  value: '$_averageWaterTank%',
                  icon: Icons.water_drop_outlined,
                  iconColor: Color(0xFF60A5FA),
                ),
                DarkStatCard(
                  label: 'LED Light',
                  value:
                      plants.isNotEmpty
                          ? 'Pos. ${plants.first.name.substring(0, 1)}'
                          : 'Pos. A',
                  icon: Icons.wb_sunny_outlined,
                  iconColor: Color(0xFFFCD34D),
                ),
                DarkStatCard(
                  label: 'Agents',
                  value: '${plants.isNotEmpty ? 2 : 0} / 2',
                  icon: Icons.memory_outlined,
                  iconColor: Color(0xFFA78BFA),
                ),
                DarkStatCard(
                  label: 'Optimizer',
                  value: 'Running',
                  icon: Icons.auto_graph_outlined,
                  iconColor: Color(0xFF34D399),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        label: 'Scan Plant',
        sub: 'Check for diseases',
        icon: Icons.qr_code_scanner_outlined,
        bg: AppTheme.lightGreen,
        iconColor: AppTheme.primaryGreen,
        onTap: onNavigateScan,
      ),
      _QuickAction(
        label: 'Add Plant',
        sub: 'Register a new plant',
        icon: Icons.add_circle_outline,
        bg: const Color(0xFFEDE9FE),
        iconColor: const Color(0xFF7C3AED),
        onTap: onNavigateAdd,
      ),
      _QuickAction(
        label: 'Water All',
        sub: 'Trigger irrigation',
        icon: Icons.water_drop_outlined,
        bg: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0369A1),
        onTap: () {},
      ),
      _QuickAction(
        label: 'Move Light',
        sub: 'Reposition LED',
        icon: Icons.wb_sunny_outlined,
        bg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        onTap: () {},
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children:
            actions
                .map(
                  (a) => GestureDetector(
                    onTap: a.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: a.bg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(a.icon, size: 18, color: a.iconColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            a.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.sub,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color text;
  const _Pill({required this.label, required this.bg, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final String sub;
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;
  const _QuickAction({
    required this.label,
    required this.sub,
    required this.icon,
    required this.bg,
    required this.iconColor,
    required this.onTap,
  });
}
