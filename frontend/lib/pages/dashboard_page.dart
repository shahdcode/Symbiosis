import 'package:flutter/material.dart';
import '../shared/painters.dart';
import '../shared/widgets.dart';

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
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F816F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Garden Harmony',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusChip(label: 'Live sync', icon: Icons.wifi_rounded),
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
                        painter: RadialGaugePainter(
                          progress: animatedValue,
                          baseColor: const Color(0xFFE1ECE3),
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
                      'Harmony',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6E8577),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const PulseIndicator(),
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
          VerticalFillMeter(value: fill, color: accent),
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
                        fontSize: 11,
                        color: Color(0xFF5F816F),
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
                LabelRow(label: 'Water tank', icon: Icons.opacity_rounded),
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
          SizedBox(width: 44, child: LiquidMeter(value: 0.72)),
        ],
      ),
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
          const LabelRow(label: 'LED arm', icon: Icons.light_mode_rounded),
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

class LiquidMeter extends StatelessWidget {
  const LiquidMeter({required this.value});

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
              HealthPill(value: health),
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
              painter: SparklinePainter(
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
              MetricChip(
                label: 'Moisture',
                value: '${(health * 100).round()}%',
              ),
              const SizedBox(width: 8),
              MetricChip(
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
