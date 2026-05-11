import 'package:flutter/material.dart';
import '../models/data_models.dart';

class CoordinatorLogPage extends StatelessWidget {
  const CoordinatorLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <DecisionEntry>[
      const DecisionEntry(
        time: '08:12',
        icon: Icons.water_drop_rounded,
        title: 'Water Plant B - 50 ml',
        reason: 'Plant B reached 85% urgency; Plant A remained stable at 20%.',
        emphasis: 'Execution queued after reservoir check.',
        color: Color(0xFF2F8F5B),
      ),
      const DecisionEntry(
        time: '08:06',
        icon: Icons.light_mode_rounded,
        title: 'Shift LED arm to Plant A',
        reason: 'Light deficit detected on Plant A after a cooling interval.',
        emphasis: 'Exposure window optimized for recovery.',
        color: Color(0xFF67B86C),
      ),
      const DecisionEntry(
        time: '07:58',
        icon: Icons.engineering_rounded,
        title: 'System health scan completed',
        reason: 'Pump cycle, tank reserve, and servo travel all within bounds.',
        emphasis: 'No intervention required.',
        color: Color(0xFF8BBF6F),
      ),
      const DecisionEntry(
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

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.entry});

  final DecisionEntry entry;

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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5F816F),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: entry.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: entry.color,
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
                      fontSize: 11,
                      color: Color(0xFF6E8577),
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
