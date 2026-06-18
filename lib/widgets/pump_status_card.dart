import 'package:flutter/material.dart';

import '../models/status_model.dart';

class PumpStatusCard extends StatelessWidget {
  final StatusModel status;

  const PumpStatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: status.pumpRunning
                  ? _PumpBadge(
                      key: const ValueKey('on'),
                      label: 'PUMP RUNNING',
                      icon: Icons.refresh,
                      color: Colors.green.shade700,
                      glowColor: Colors.green,
                    )
                  : _PumpBadge(
                      key: const ValueKey('off'),
                      label: 'PUMP OFF',
                      icon: Icons.power_off,
                      color: Colors.grey.shade700,
                      glowColor: Colors.transparent,
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              status.modeLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              status.stopReasonLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color glowColor;

  const _PumpBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: glowColor != Colors.transparent
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.4),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
