import 'package:flutter/material.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/plant_painter.dart';

class PlantLibraryDetailScreen extends StatefulWidget {
  final BackendPlant plant;
  final bool isInCollection;
  final Future<void> Function(BackendPlant plant)? onAddRequested;

  const PlantLibraryDetailScreen({
    super.key,
    required this.plant,
    required this.isInCollection,
    this.onAddRequested,
  });

  @override
  State<PlantLibraryDetailScreen> createState() =>
      _PlantLibraryDetailScreenState();
}

class _PlantLibraryDetailScreenState extends State<PlantLibraryDetailScreen> {
  bool _adding = false;

  Color get _accentColor {
    switch (widget.plant.difficulty) {
      case PlantDisplayDifficulty.easy:
        return const Color(0xFF16A34A);
      case PlantDisplayDifficulty.medium:
        return const Color(0xFFD97706);
      case PlantDisplayDifficulty.hard:
        return AppTheme.danger;
    }
  }

  Color get _lightAccent {
    switch (widget.plant.difficulty) {
      case PlantDisplayDifficulty.easy:
        return const Color(0xFFE8F5E3);
      case PlantDisplayDifficulty.medium:
        return const Color(0xFFFEF3C7);
      case PlantDisplayDifficulty.hard:
        return const Color(0xFFFEE2E2);
    }
  }

  Future<void> _confirmAdd() async {
    if (widget.isInCollection || widget.onAddRequested == null || _adding) {
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add to collection?'),
          content: Text(
            'Are you sure you want to add ${widget.plant.label} to your collection?',
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

    if (shouldAdd != true || !mounted) {
      return;
    }

    setState(() {
      _adding = true;
    });

    try {
      await widget.onAddRequested!(widget.plant);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.plant.label} added to your collection'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _lightAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: _accentColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _lightAccent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        widget.isInCollection
                            ? 'In Collection'
                            : widget.plant.typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _lightAccent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      PlantWidget(
                        type: widget.plant.svgType,
                        color: _accentColor,
                        size: 120,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.plant.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.plant.species,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Tag(
                            label: widget.plant.typeLabel,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            label:
                                widget.plant.difficulty.name[0].toUpperCase() +
                                widget.plant.difficulty.name.substring(1),
                            color: _accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Text(
                  'Care Guide',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.mintBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ConditionRow(
                        label: 'Moisture',
                        value:
                            '${widget.plant.moistureMin.round()}–${widget.plant.moistureMax.round()}%',
                      ),
                      _ConditionRow(
                        label: 'Humidity',
                        value:
                            '${widget.plant.humidityMin.round()}–${widget.plant.humidityMax.round()}%',
                      ),
                      _ConditionRow(
                        label: 'Light',
                        value:
                            'Ellenberg ${widget.plant.lightValue.toStringAsFixed(1)}',
                      ),
                      _ConditionRow(
                        label: 'Temperature',
                        value:
                            '${widget.plant.tempMinC.round()}–${widget.plant.tempMaxC.round()}°C',
                      ),
                      _ConditionRow(
                        label: 'DLI',
                        value: widget.plant.dliRequirement.toStringAsFixed(1),
                      ),
                      _ConditionRow(
                        label: 'Watering',
                        value:
                            widget.plant.difficulty ==
                                    PlantDisplayDifficulty.easy
                                ? 'Every 1–2 weeks'
                                : widget.plant.difficulty ==
                                    PlantDisplayDifficulty.medium
                                ? 'Weekly check'
                                : 'Frequent monitoring',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'This plant is ${widget.plant.difficulty.name} to care for. The values above come from the backend plant profile and can be used to match light, moisture, humidity, and temperature to its ideal growing conditions.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: widget.isInCollection || _adding ? null : _confirmAdd,
              icon: Icon(
                widget.isInCollection ? Icons.check_circle_outline : Icons.add,
              ),
              label: Text(
                widget.isInCollection
                    ? 'Already in Collection'
                    : _adding
                    ? 'Adding...'
                    : 'Add to Collection',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConditionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
