import 'package:flutter/material.dart';

/// Reusable SafeRoute app header — matches your HTML header exactly
class SafeHeader extends StatelessWidget {
  final String subtitle;
  const SafeHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF334155), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6)],
          ),
          padding: const EdgeInsets.all(7),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SAFEROUTE',
              style: TextStyle(fontSize: 8, color: Color(0xFF6B7280), letterSpacing: 3, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
          ],
        ),
      ],
    );
  }
}
