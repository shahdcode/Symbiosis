import 'package:flutter/material.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';
import '../widgets/shared_widgets.dart';
import 'plant_library_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback? onPlantAdded;

  const ExploreScreen({super.key, this.onPlantAdded});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final BackendApi _api = BackendApi();
  String _query = '';
  String _filter = 'All';
  bool _loading = true;
  String? _error;
  List<BackendPlant> _plants = [];
  Set<String> _collectionPlantIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.fetchPlantLibrary(limit: 12),
        _api.fetchPlants(),
      ]);
      final libraryPlants = results[0] as List<BackendPlant>;
      final collectionPlants = results[1] as List<BackendPlant>;
      if (!mounted) return;
      setState(() {
        _plants = libraryPlants;
        _collectionPlantIds = collectionPlants.map((p) => p.plantId).toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<BackendPlant> get _filtered =>
      _plants.where((p) {
        final matchesFilter = _filter == 'All' || p.typeLabel == _filter;
        final matchesQuery =
            p.label.toLowerCase().contains(_query.toLowerCase()) ||
            p.species.toLowerCase().contains(_query.toLowerCase());
        return matchesFilter && matchesQuery;
      }).toList();

  bool _isAdded(BackendPlant plant) =>
      _collectionPlantIds.contains(plant.plantId);

  Future<void> _addToCollection(BackendPlant plant) async {
    if (_isAdded(plant)) {
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to collection?'),
          content: Text(
            'Are you sure you want to add ${plant.label} to your collection?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (shouldAdd != true) {
      return;
    }

    try {
      await _api.createPlantFromScientificName(plant.species);
      if (!mounted) return;
      await _loadPlants();
      widget.onPlantAdded?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plant.label} added to your collection')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadPlants,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        GreenButton(label: 'Retry', onTap: _loadPlants),
                      ],
                    ),
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No matching plants found',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ExploreCard(
                      plant: _filtered[i],
                      index: i,
                      isAdded: _isAdded(_filtered[i]),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => PlantLibraryDetailScreen(
                                  plant: _filtered[i],
                                  isInCollection: _isAdded(_filtered[i]),
                                  onAddRequested: _addToCollection,
                                ),
                          ),
                        );
                      },
                      onAdd: () => _addToCollection(_filtered[i]),
                    ),
                    childCount: _filtered.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore Plants',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Browse a living plant library from Trefle',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.mintBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.search_outlined,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                ),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search plants...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children:
                ['All', 'Indoor', 'Outdoor']
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _filter == f
                                      ? AppTheme.primaryGreen
                                      : AppTheme.mintBg,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    _filter == f
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _ExploreCard extends StatefulWidget {
  final BackendPlant plant;
  final int index;
  final bool isAdded;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ExploreCard({
    required this.plant,
    required this.index,
    required this.isAdded,
    required this.onTap,
    required this.onAdd,
  });

  @override
  State<_ExploreCard> createState() => _ExploreCardState();
}

class _ExploreCardState extends State<_ExploreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _diffColor {
    switch (widget.plant.difficulty) {
      case PlantDisplayDifficulty.easy:
        return const Color(0xFF16A34A);
      case PlantDisplayDifficulty.medium:
        return const Color(0xFFD97706);
      case PlantDisplayDifficulty.hard:
        return AppTheme.danger;
    }
  }

  Color get _diffBg {
    switch (widget.plant.difficulty) {
      case PlantDisplayDifficulty.easy:
        return const Color(0xFFDCFCE7);
      case PlantDisplayDifficulty.medium:
        return const Color(0xFFFEF3C7);
      case PlantDisplayDifficulty.hard:
        return const Color(0xFFFEE2E2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.mintBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.translucent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: PlantWidget(
                      type: widget.plant.svgType,
                      color: AppTheme.primaryGreen,
                      size: 76,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.plant.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.plant.species,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(
                        label: widget.plant.typeLabel,
                        bg:
                            widget.plant.typeLabel == 'Indoor'
                                ? AppTheme.lightGreen
                                : const Color(0xFFFEF3C7),
                        text:
                            widget.plant.typeLabel == 'Indoor'
                                ? AppTheme.primaryGreen
                                : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      _Badge(
                        label:
                            widget.plant.difficulty.name[0].toUpperCase() +
                            widget.plant.difficulty.name.substring(1),
                        bg: _diffBg,
                        text: _diffColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.isAdded ? null : widget.onAdd,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: widget.isAdded ? AppTheme.lightGreen : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isAdded ? Icons.check : Icons.add,
                    size: 14,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color text;
  const _Badge({required this.label, required this.bg, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
