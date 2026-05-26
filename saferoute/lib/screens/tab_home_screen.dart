import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/bbmp_service.dart';
import '../services/supabase_service.dart';
import '../widgets/safe_header.dart';

class TabHomeScreen extends StatefulWidget {
  const TabHomeScreen({super.key});

  @override
  State<TabHomeScreen> createState() => _TabHomeScreenState();
}

class _TabHomeScreenState extends State<TabHomeScreen> {
  Map<String, WardScore> _wardScores = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    try {
      final scores = await BbmpService.instance.getWardScores();
      if (mounted) setState(() { _wardScores = scores; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          // Sticky header matching your HTML header
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: Colors.black12,
            titleSpacing: 16,
            toolbarHeight: 56,
            shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            title: Row(children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF334155), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
                ),
                padding: const EdgeInsets.all(7),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('SAFEROUTE', style: TextStyle(fontSize: 8, color: Color(0xFF6B7280), letterSpacing: 3, fontWeight: FontWeight.w700)),
                Text('Your Safety Partner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
              ]),
            ]),
            actions: [
              if (_loading)
                const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E293B))))),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // ── Hero section ─────────────────────────────────
              // "Smart Navigation" tag
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: const [
                    Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF334155)),
                    SizedBox(width: 6),
                    Text('Smart Navigation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155), letterSpacing: 0.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Your safest route,\nevery time.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF111827), height: 1.15)),
              const SizedBox(height: 12),
              const Text('Navigate safely with intelligent routing that considers lighting, road quality, incidents, and emergency access.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6)),
              const SizedBox(height: 24),

              // CTA buttons
              _SlateButton(label: 'Get Started', icon: Icons.bolt_rounded, onTap: () {}),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Center(child: Text('Continue as Guest', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
              ),
              const SizedBox(height: 28),

              // ── Stats cards ───────────────────────────────────
              Row(children: [
                Expanded(child: _StatCard(icon: Icons.people_rounded, iconColor: const Color(0xFF2563EB), bgColor: const Color(0xFFEFF6FF), label: 'Users', value: '1.2K+')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.access_time_rounded, iconColor: const Color(0xFF059669), bgColor: const Color(0xFFECFDF5), label: 'Support', value: '24/7')),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(icon: Icons.shield_rounded, iconColor: const Color(0xFFD97706), bgColor: const Color(0xFFFFFBEB), label: 'Safety', value: 'Solo')),
              ]),
              const SizedBox(height: 24),

              // ── Live Monitoring card ──────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live indicator
                    Row(children: [
                      Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.5), blurRadius: 6)]),
                      ),
                      const SizedBox(width: 8),
                      const Text('Live Monitoring', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669), letterSpacing: 0.5)),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Sentinel Protocol Active', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                    const SizedBox(height: 6),
                    const Text('Your area has active lighting coverage, secure traffic flow, and reliable mobile network service.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
                    const SizedBox(height: 20),

                    // Mini Bengaluru map
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: const MapOptions(
                            initialCenter: LatLng(12.9716, 77.5946),
                            initialZoom: 12,
                            interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.saferoute.app',
                            ),
                            const CircleLayer(circles: [
                              CircleMarker(point: LatLng(12.9716, 77.5946), radius: 5, color: Color(0xFF10B981), borderColor: Colors.white, borderStrokeWidth: 2, useRadiusInMeter: false),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Safe route / Guardian row
                    Row(children: [
                      Expanded(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD1FAE5))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text('Safe Route', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                          SizedBox(height: 2),
                          Text('MG Road', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                        ]),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text('Guardian', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                          SizedBox(height: 2),
                          Text('Available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                        ]),
                      )),
                    ]),
                    const SizedBox(height: 16),
                    _SlateButton(label: 'Plan Your Journey', icon: Icons.chevron_right, onTap: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── SOS Deadzone Alert ────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCD34D), width: 2),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SOS Deadzone Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF78350F))),
                    SizedBox(height: 3),
                    Text('Get warned about areas with weak cell coverage before you start your journey.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4)),
                  ])),
                ]),
              ),

              // BBMP data footer
              if (_wardScores.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Live BBMP Data · ${_wardScores.length} wards tracked',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              ],

            ])),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String label, value;
  const _StatCard({required this.icon, required this.iconColor, required this.bgColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
    ]),
  );
}

class _SlateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SlateButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
