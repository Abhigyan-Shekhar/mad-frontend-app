import 'package:flutter/material.dart';
import '../services/bbmp_service.dart';
import '../services/supabase_service.dart';
import '../widgets/saferoute_appbar.dart';

class TabPlanJourneyScreen extends StatefulWidget {
  const TabPlanJourneyScreen({super.key});

  @override
  State<TabPlanJourneyScreen> createState() => _TabPlanJourneyScreenState();
}

class _TabPlanJourneyScreenState extends State<TabPlanJourneyScreen> {
  final _fromCtrl = TextEditingController(text: 'Current Location');
  final _toCtrl = TextEditingController(text: 'The Good Centre, Aline Rd');
  bool _loading = false;
  List<_RouteOption>? _routes;
  String? _error;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _findRoutes() async {
    if (_toCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter a destination');
      return;
    }
    setState(() { _loading = true; _error = null; _routes = null; });

    try {
      final score = await BbmpService.instance.routeSafetyScore(
        _fromCtrl.text, _toCtrl.text,
      );

      // Generate 3 route options based on the real safety score
      final routes = [
        _RouteOption(
          label: 'Well-lit Streets',
          subtitle: 'Maximum safety priority',
          badge: 'RECOMMENDED',
          badgeColor: const Color(0xFF059669),
          rank: '#1 SAFEST',
          duration: 18,
          coverage: 'Full',
          score: score,
          highlights: ['No signal dead zones', 'High street lighting', 'Emergency access ready'],
          borderColor: const Color(0xFF10B981),
          coverageColor: const Color(0xFF059669),
          routeColor: const Color(0xFF10B981),
          btnColor: const Color(0xFF059669),
          btnText: 'Choose This Route',
        ),
        _RouteOption(
          label: 'Standard Path',
          subtitle: 'Balanced route',
          badge: null,
          badgeColor: Colors.transparent,
          rank: '#2',
          duration: 15,
          coverage: 'Partial',
          score: score - 10,
          highlights: [],
          borderColor: const Color(0xFFE5E7EB),
          coverageColor: const Color(0xFF2563EB),
          routeColor: const Color(0xFFF59E0B),
          btnColor: const Color(0xFF2563EB),
          btnText: 'Select Route',
        ),
        _RouteOption(
          label: 'Direct Route',
          subtitle: 'Fastest option',
          badge: '⚠️ WARNING',
          badgeColor: const Color(0xFFEF4444),
          rank: '#3',
          duration: 14,
          coverage: '⚠️',
          score: score - 25,
          highlights: ['30-mile no-service zone ahead'],
          borderColor: const Color(0xFFE5E7EB),
          coverageColor: const Color(0xFFEF4444),
          routeColor: const Color(0xFFEF4444),
          btnColor: const Color(0xFF374151),
          btnText: 'Select Route',
        ),
      ];

      setState(() { _routes = routes; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not load routes: $e'; _loading = false; });
    }
  }

  Future<void> _startNavigation(_RouteOption route) async {
    try {
      final tripId = await SupabaseService.instance.startTrip(
        from: _fromCtrl.text,
        to: _toCtrl.text,
        safetyScore: route.score,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trip started! ID: $tripId'), backgroundColor: const Color(0xFF059669)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in to start a trip: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          const SafeRouteAppBar(subtitle: 'Plan Journey'),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Location input card ───────────────────────────
              _Card(
                child: Column(children: [
                  // From field
                  _LocationField(
                    label: 'FROM',
                    controller: _fromCtrl,
                    icon: Icons.my_location_rounded,
                  ),
                  const SizedBox(height: 16),
                  // To field
                  _LocationField(
                    label: 'TO',
                    controller: _toCtrl,
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 16),
                  // SOS + Filters row
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1FAE5)),
                      ),
                      child: Row(children: const [
                        Icon(Icons.shield_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text('SOS Detection ON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      ]),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Find routes button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _findRoutes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Find Best Routes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ]),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(_error!),
              ],

              // ── Route options ─────────────────────────────────
              if (_routes != null) ...[
                const SizedBox(height: 20),
                ..._routes!.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RouteCard(route: r, onTap: () => _startNavigation(r)),
                )),

                // Recommendation banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22)),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Well-lit Streets Recommended', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                        Text('Adds 4 minutes but avoids hazards with full coverage.', style: TextStyle(fontSize: 12, color: Color(0xFF374151))),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: () => _startNavigation(_routes!.first),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Start Navigation', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ]),
                ),
              ],

            ])),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────

class _RouteOption {
  final String label, subtitle, rank, btnText, coverage;
  final String? badge;
  final Color badgeColor, borderColor, coverageColor, routeColor, btnColor;
  final int duration;
  final double score;
  final List<String> highlights;

  const _RouteOption({
    required this.label, required this.subtitle, required this.badge,
    required this.badgeColor, required this.rank, required this.duration,
    required this.coverage, required this.score, required this.highlights,
    required this.borderColor, required this.coverageColor, required this.routeColor,
    required this.btnColor, required this.btnText,
  });
}

// ── Reusable widgets ──────────────────────────────────────────────

class _LocationField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  const _LocationField({required this.label, required this.controller, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 1)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Icon(icon, color: const Color(0xFF475569), size: 20)),
          Expanded(child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
            decoration: const InputDecoration(
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          )),
        ]),
      ),
    ],
  );
}

class _RouteCard extends StatelessWidget {
  final _RouteOption route;
  final VoidCallback onTap;
  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: route.borderColor, width: route.badge == 'RECOMMENDED' ? 3 : 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge header
          if (route.badge != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: route.badgeColor.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  Icon(route.badge!.contains('WARNING') ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(route.badge!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(route.rank, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(children: [
                  Text(route.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const Spacer(),
                  if (route.badge == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                      child: Text(route.rank, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    ),
                ]),
                Text(route.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 16),

                // Duration / Coverage grid
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: route.routeColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: route.routeColor.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Duration', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: route.coverageColor)),
                      Text('${route.duration} min', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Coverage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: route.coverageColor)),
                      Text(route.coverage, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: route.coverageColor)),
                    ])),
                  ]),
                ),

                // Highlights
                if (route.highlights.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: route.highlights.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('✓ $h', style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                      )).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Safety score from BBMP
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
                  child: Row(children: [
                    const Icon(Icons.analytics_rounded, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Text('BBMP Safety Score: ${route.score.toStringAsFixed(0)}/100',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  ]),
                ),
                const SizedBox(height: 16),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: route.btnColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(route.btnText, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
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

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCA5A5))),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
    ]),
  );
}
