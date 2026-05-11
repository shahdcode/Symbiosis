import 'dart:math' as math;
import 'package:flutter/material.dart';

class VerticalFillMeter extends StatelessWidget {
  const VerticalFillMeter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.05, end: value),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, fill, _) {
        return Container(
          width: 18,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6F1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fill,
              widthFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [color, color.withOpacity(0.66)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PulseIndicator extends StatefulWidget {
  const PulseIndicator();

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.5 + math.sin(_controller.value * math.pi * 2) * 0.06;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF35A257).withOpacity(pulse),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'fluid balance stabilizing',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6D8679),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            const Color(0xFF58B96B),
                            const Color(0xFF58B96B).withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.6,
                      child: CustomPaint(painter: _WavePainter(progress: fill)),
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

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..style = PaintingStyle.fill;
    final path = Path();
    final waveHeight = size.height * (1 - progress);
    path.moveTo(0, size.height);
    path.lineTo(0, waveHeight);
    for (var i = 0; i <= 12; i++) {
      final x = size.width * i / 12;
      final y =
          waveHeight +
          math.sin((i / 12) * math.pi * 2 + progress * math.pi * 2) * 4;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class LabelRow extends StatelessWidget {
  const LabelRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5F816F)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF5F816F),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class HealthPill extends StatelessWidget {
  const HealthPill({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final label = '${(value * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2F8F5B),
        ),
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7A9284),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDEBDD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2F8F5B)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F8F5B),
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
    final color = autoPilot ? const Color(0xFFEAF6EE) : const Color(0xFFF7E7C7);
    final textColor =
        autoPilot ? const Color(0xFF2F8F5B) : const Color(0xFFAC7412);
    final label = autoPilot ? 'Auto' : 'Manual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0F7F1) : const Color(0xFFF8F1E2),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Master Auto-Pilot',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value
                    ? 'Autonomous behavior is active'
                    : 'Manual intervention is in control',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6E8577),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2ECE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E8577),
              height: 1.4,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.09),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6E8577),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.activeColor,
    required this.confirmLabel,
    required this.onConfirmed,
  });

  final Color activeColor;
  final String confirmLabel;
  final VoidCallback onConfirmed;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    _controller.reverse();
    setState(() => _completed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _completed = false;
        _controller.forward().whenComplete(() {
          if (mounted) {
            setState(() => _completed = true);
          }
        });
      },
      onLongPressEnd: (_) {
        if (_completed) {
          widget.onConfirmed();
        }
        _reset();
      },
      onLongPressCancel: _reset,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final fill = _controller.value;
          return Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAF9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDBE8DD)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: fill,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.activeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      widget.confirmLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.activeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
