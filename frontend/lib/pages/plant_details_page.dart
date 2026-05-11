import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../widgets/custom_painters.dart';

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
    final tiles = <StatTileData>[
      const StatTileData(
        title: 'Soil moisture',
        value: '40%',
        subtitle: 'Below target range',
        icon: Icons.water_drop_rounded,
        accent: Color(0xFF4BAE67),
      ),
      const StatTileData(
        title: 'Light intensity',
        value: '18k lux',
        subtitle: 'Within tolerance',
        icon: Icons.wb_sunny_rounded,
        accent: Color(0xFF6CBF73),
      ),
      const StatTileData(
        title: 'Humidity',
        value: '62%',
        subtitle: 'Comfortable air',
        icon: Icons.water_damage_rounded,
        accent: Color(0xFF77C17A),
      ),
      const StatTileData(
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.data});

  final StatTileData data;

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
              painter: UrgencyChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
