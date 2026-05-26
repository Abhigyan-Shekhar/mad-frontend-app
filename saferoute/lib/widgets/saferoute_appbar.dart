import 'package:flutter/material.dart';

/// Reusable SliverAppBar matching the HTML header in every screen.
class SafeRouteAppBar extends StatelessWidget {
  final String subtitle;
  const SafeRouteAppBar({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) => SliverAppBar(
    pinned: true,
    backgroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 1,
    shadowColor: Colors.black12,
    toolbarHeight: 56,
    automaticallyImplyLeading: false,
    shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
    title: Row(children: [
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF334155), Color(0xFF0F172A)]),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(7),
        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SAFEROUTE', style: TextStyle(fontSize: 8, color: Color(0xFF6B7280), letterSpacing: 3, fontWeight: FontWeight.w700)),
        Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
      ]),
    ]),
  );
}
