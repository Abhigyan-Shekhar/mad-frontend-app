import 'package:flutter/material.dart';
import '../services/bbmp_service.dart';
import '../widgets/saferoute_appbar.dart';

class TabSafetyScoreScreen extends StatefulWidget {
  const TabSafetyScoreScreen({super.key});

  @override
  State<TabSafetyScoreScreen> createState() => _TabSafetyScoreScreenState();
}

class _TabSafetyScoreScreenState extends State<TabSafetyScoreScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, WardScore> _wardScores = {};
  WardScore? _selected;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut);
    _loadScores();
  }

  Future<void> _loadScores() async {
    try {
      final scores = await BbmpService.instance.getWardScores();
      if (mounted) {
        // Default: pick MG Road or first ward
        final key = scores.keys.firstWhere(
          (k) => k.toLowerCase().contains('mg road') || k.toLowerCase().contains('shivajinagar'),
          orElse: () => scores.keys.first,
        );
        setState(() {
          _wardScores = scores;
          _selected = scores[key];
          _loading = false;
        });
        _progressCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _selected?.safetyScore ?? 78.0;
    final wardName = _selected?.wardName ?? 'MG Road';
    final road = _selected?.roadGrievances ?? 9;
    final light = _selected?.lightGrievances ?? 7;
    final total = _selected?.totalGrievances ?? 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          const SafeRouteAppBar(subtitle: 'Safety Score'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Ward picker ───────────────────────────────────
              if (_wardScores.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selected?.wardName,
                      hint: const Text('Select Ward'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      items: _wardScores.keys.map((w) => DropdownMenuItem(value: w, child: Text(w, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (w) {
                        if (w == null) return;
                        setState(() => _selected = _wardScores[w]);
                        _progressCtrl.forward(from: 0);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Safety score card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    const Text('ROUTE SAFETY SCORE', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), letterSpacing: 2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    // Circular indicator
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: AnimatedBuilder(
                        animation: _progressAnim,
                        builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: _progressAnim.value * (score / 100),
                                strokeWidth: 10,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  score >= 70 ? const Color(0xFF10B981) : score >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                                ),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              score.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: score >= 70 ? const Color(0xFF059669) : score >= 50 ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loading ? 'Loading ward data...' : 'Safety data for $wardName corridor',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    // Meta row matching your HTML grid
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetaItem(label: 'Updated', value: '2m ago'),
                          _vDivider(),
                          _MetaItem(label: 'Area', value: wardName.split(' ').first),
                          _vDivider(),
                          _MetaItem(label: 'Scope', value: 'Live'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Coverage status bar ────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('COVERAGE STATUS', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Expanded(child: Text('Route Indexed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                      Text('${score.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    ]),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value * (score / 100),
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Metrics grid: Potholes / Lights / Incidents ────
              Row(children: [
                Expanded(child: _MetricCard(icon: Icons.warning_amber_rounded, iconBg: const Color(0xFFFFF7ED), iconColor: const Color(0xFFEA580C), label: 'Potholes', value: road.toString(), progress: (road / 30).clamp(0, 1).toDouble(), barColor: const Color(0xFFF97316))),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(icon: Icons.bolt_rounded, iconBg: const Color(0xFFFFFBEB), iconColor: const Color(0xFFD97706), label: 'Lights', value: light.toString(), progress: (light / 30).clamp(0, 1).toDouble(), barColor: const Color(0xFFF59E0B))),
                const SizedBox(width: 10),
                Expanded(child: _MetricCard(icon: Icons.shield_rounded, iconBg: const Color(0xFFFFF1F2), iconColor: const Color(0xFFE11D48), label: 'Issues', value: total.toString(), progress: (total / 50).clamp(0, 1).toDouble(), barColor: const Color(0xFFEF4444))),
              ]),
              const SizedBox(height: 16),

              // ── Alert cards ────────────────────────────────────
              _AlertCard(
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFCD34D),
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFB45309),
                icon: Icons.warning_amber_rounded,
                title: 'Route Forecast',
                body: 'Church Street predicts slow traffic. Expect delays in this corridor.',
              ),
              const SizedBox(height: 12),
              _AlertCard(
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                iconBg: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                icon: Icons.info_outline_rounded,
                title: 'Recommendation',
                body: 'Choose the route with stronger lighting for better safety.',
              ),
              const SizedBox(height: 16),

              // ── Route visualization (dark card matching HTML) ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Route Visualization', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 14),
                    // Dark map-like background with route line
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: CustomPaint(painter: _RoutePainter(color: const Color(0xFF10B981))),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: SizedBox(height: 46,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('View Route', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: SizedBox(height: 46,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Share', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                        ),
                      )),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Last 7 days stats ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LAST 7 DAYS', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    _StatsRow('Potholes Reported', '+$road', const Color(0xFF2563EB)),
                    const SizedBox(height: 10),
                    _StatsRow('Lights Active', '${((100 - light) * 0.73).toStringAsFixed(0)}%', const Color(0xFF111827)),
                    const SizedBox(height: 10),
                    _StatsRow('Total Grievances', '$total', const Color(0xFF111827)),
                  ],
                ),
              ),

            ])),
          ),
        ],
      ),
    );
  }
}

Widget _vDivider() => Container(height: 30, width: 1, color: const Color(0xFFE5E7EB));
Widget _StatsRow(String label, String value, Color valueColor) => Row(
  children: [
    Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
  ],
);

class _MetaItem extends StatelessWidget {
  final String label, value;
  const _MetaItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
  ]);
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor, barColor;
  final String label, value;
  final double progress;
  const _MetricCard({required this.icon, required this.iconBg, required this.iconColor, required this.label, required this.value, required this.progress, required this.barColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: Column(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress, minHeight: 6,
          backgroundColor: const Color(0xFFE5E7EB),
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    ]),
  );
}

class _AlertCard extends StatelessWidget {
  final Color bgColor, borderColor, iconBg, iconColor;
  final IconData icon;
  final String title, body;
  const _AlertCard({required this.bgColor, required this.borderColor, required this.iconBg, required this.iconColor, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor, width: 2)),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 3),
        Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4)),
      ])),
    ]),
  );
}

class _RoutePainter extends CustomPainter {
  final Color color;
  const _RoutePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.82)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.6, size.width * 0.42, size.height * 0.52)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.4, size.width * 0.72, size.height * 0.32)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.22, size.width * 0.9, size.height * 0.2);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Dots along the route
    for (final p in [
      Offset(size.width * 0.12, size.height * 0.82),
      Offset(size.width * 0.42, size.height * 0.52),
      Offset(size.width * 0.72, size.height * 0.32),
      Offset(size.width * 0.9, size.height * 0.2),
    ]) {
      canvas.drawCircle(p, 6, Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawCircle(p, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// _AppBar removed — now using SafeRouteAppBar from widgets/saferoute_appbar.dart
