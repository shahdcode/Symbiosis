import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  _ScanResult? _result;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  void _simulateScan() async {
    setState(() {
      _scanning = true;
      _result = null;
    });
    _spinCtrl.repeat();
    await Future.delayed(const Duration(milliseconds: 2400));
    _spinCtrl.stop();
    _spinCtrl.reset();
    if (mounted) {
      setState(() {
        _scanning = false;
        _result = _ScanResult(
          status: 'healthy',
          confidence: 96,
          plantName: 'Monstera deliciosa',
          tips: [
            'Leaf shine looks great',
            'Moisture level optimal',
            'No signs of pests detected',
          ],
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plant Scanner',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Detect diseases, pests, and health issues',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            _buildScanArea(),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 16),
            if (_result != null) _buildResults(),
            if (_result == null && !_scanning) _buildTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppTheme.mintBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Center(
            child: _scanning
                ? _buildScanning()
                : _result != null
                    ? _buildResultPreview()
                    : _buildPlaceholder(),
          ),
          if (!_scanning && _result == null) ...[
            Positioned(
                top: 16,
                left: 16,
                child: _Corner(top: true, left: true)),
            Positioned(
                top: 16,
                right: 16,
                child: _Corner(top: true, left: false)),
            Positioned(
                bottom: 16,
                left: 16,
                child: _Corner(top: false, left: true)),
            Positioned(
                bottom: 16,
                right: 16,
                child: _Corner(top: false, left: false)),
          ],
        ],
      ),
    );
  }

  Widget _buildScanning() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _spinCtrl,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.lightGreen,
                width: 3,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [
                  Colors.transparent,
                  AppTheme.primaryGreen,
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _PulseText(text: 'Analyzing plant health...'),
      ],
    );
  }

  Widget _buildResultPreview() {
    final healthy = _result!.status == 'healthy';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color:
                healthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            healthy ? Icons.check : Icons.warning_amber_rounded,
            color: healthy ? const Color(0xFF16A34A) : AppTheme.danger,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _result!.plantName,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          healthy ? 'Plant looks healthy' : 'Issues detected',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: healthy ? const Color(0xFF16A34A) : AppTheme.danger,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'Confidence: ${_result!.confidence}%',
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFFA8D5A2),
                width: 2,
                style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.qr_code_scanner_outlined,
              size: 36, color: Color(0xFFA8D5A2)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Scan your plant',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Take a photo or upload an image to analyze',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _simulateScan,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.upload_outlined, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Upload Photo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _result = null),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.mintBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.refresh_outlined,
                  size: 18, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analysis Results',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        ...(_result!.tips.asMap().entries.map((e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 12, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 10),
                      Text(e.value,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF374151))),
                    ],
                  ),
                ),
                if (e.key < _result!.tips.length - 1)
                  const Divider(color: AppTheme.border, height: 0),
              ],
            ))),
      ],
    );
  }

  Widget _buildTips() {
    final tips = [
      'Ensure good lighting — natural light works best',
      'Focus on a specific leaf area if concerned',
      'Capture both top and underside of leaves',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tips for best results',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        ...tips.asMap().entries.map((e) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(e.value,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (e.key < tips.length - 1)
                  const Divider(color: AppTheme.border, height: 0),
              ],
            )),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  final bool top;
  final bool left;
  const _Corner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _CornerPainter(top: top, left: left)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;
  _CornerPainter({required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;

    if (top && left) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    } else if (top && !left) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    } else if (!top && left) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    } else {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _PulseText extends StatefulWidget {
  final String text;
  const _PulseText({required this.text});

  @override
  State<_PulseText> createState() => _PulseTextState();
}

class _PulseTextState extends State<_PulseText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(opacity: _anim.value, child: child),
      child: Text(
        widget.text,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScanResult {
  final String status;
  final int confidence;
  final String plantName;
  final List<String> tips;
  const _ScanResult({
    required this.status,
    required this.confidence,
    required this.plantName,
    required this.tips,
  });
}
