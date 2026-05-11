import 'package:flutter/material.dart';
import '../shared/widgets.dart';

class ManualControlPage extends StatefulWidget {
  const ManualControlPage({super.key});

  @override
  State<ManualControlPage> createState() => _ManualControlPageState();
}

class _ManualControlPageState extends State<ManualControlPage> {
  bool _autoPilot = true;
  bool _pumpArmed = false;
  double _servoPosition = 0.62;
  double _pumpStrength = 0.42;

  @override
  Widget build(BuildContext context) {
    final accent =
        _autoPilot ? const Color(0xFF2F8F5B) : const Color(0xFFC98A1D);
    final background =
        _autoPilot ? const Color(0xFFF6F8F4) : const Color(0xFFFCF8EF);

    return Container(
      color: background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color:
                    _autoPilot
                        ? const Color(0xFFE2ECE4)
                        : const Color(0xFFF0DFC0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Control',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ModeBadge(autoPilot: _autoPilot),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _autoPilot
                      ? 'The system is in autonomous mode. Switch to manual only when you need direct hardware control.'
                      : 'Manual mode active. Controls are live and will override the coordinator until auto-pilot is restored.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6E8577),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                MasterSwitch(
                  value: _autoPilot,
                  accent: accent,
                  onChanged: (value) => setState(() => _autoPilot = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ControlPanel(
            title: 'LED arm position',
            subtitle: 'Servo travel for the light zone',
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    inactiveTrackColor: accent.withOpacity(0.18),
                    thumbColor: accent,
                    overlayColor: accent.withOpacity(0.08),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _servoPosition,
                    onChanged:
                        (value) => setState(() => _servoPosition = value),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Retract',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6E8577),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(_servoPosition * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Extend',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6E8577),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ControlPanel(
            title: 'Water pump',
            subtitle: 'Hold to confirm irrigation',
            child: Column(
              children: [
                HoldToConfirmButton(
                  activeColor: accent,
                  confirmLabel: 'Hold to dispense 50 ml',
                  onConfirmed: () {
                    setState(() => _pumpArmed = !_pumpArmed);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ValueTile(
                        label: 'Pump status',
                        value: _pumpArmed ? 'Armed' : 'Ready',
                        accent: accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueTile(
                        label: 'Flow rate',
                        value: '${(_pumpStrength * 100).round()} ml/s',
                        accent: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    inactiveTrackColor: accent.withOpacity(0.14),
                    thumbColor: accent,
                    overlayColor: accent.withOpacity(0.08),
                    trackHeight: 5,
                  ),
                  child: Slider(
                    value: _pumpStrength,
                    onChanged: (value) => setState(() => _pumpStrength = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ControlPanel(
            title: 'System toggles',
            subtitle: 'Small switches with explicit state',
            child: Column(
              children: [
                ToggleRow(
                  title: 'Soil sensor override',
                  value: _pumpArmed,
                  accent: accent,
                  onChanged: (value) => setState(() => _pumpArmed = value),
                ),
                const SizedBox(height: 10),
                ToggleRow(
                  title: 'Manual light lock',
                  value: !_autoPilot,
                  accent: accent,
                  onChanged: (value) => setState(() => _autoPilot = !value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModeBadge extends StatelessWidget {
  const ModeBadge({required this.autoPilot});

  final bool autoPilot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: autoPilot ? const Color(0xFFEAF6EE) : const Color(0xFFF5EFE0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        autoPilot ? 'Auto' : 'Manual',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: autoPilot ? const Color(0xFF2F8F5B) : const Color(0xFFC98A1D),
        ),
      ),
    );
  }
}

class MasterSwitch extends StatelessWidget {
  const MasterSwitch({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(value ? Icons.hub_rounded : Icons.pan_tool_rounded, color: accent),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Auto-pilot mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        Switch(value: value, activeColor: accent, onChanged: onChanged),
      ],
    );
  }
}

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E8577),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class ValueTile extends StatelessWidget {
  const ValueTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6E8577),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.title,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final Color accent;
  final Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        Switch(value: value, activeColor: accent, onChanged: onChanged),
      ],
    );
  }
}
