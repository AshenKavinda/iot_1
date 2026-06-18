import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Device Info section ───────────────────────────
          _SectionHeader('Device & Firebase'),
          _InfoCard(items: const [
            _InfoItem(
              icon: Icons.cloud_outlined,
              label: 'Firebase Project',
              value: 'iot-2026-tharuka',
            ),
            _InfoItem(
              icon: Icons.link,
              label: 'Database URL',
              value: 'iot-2026-tharuka-default-rtdb',
            ),
            _InfoItem(
              icon: Icons.memory,
              label: 'Device',
              value: 'ESP8266 NodeMCU',
            ),
          ]),

          const SizedBox(height: 16),

          // ── Sensor config section ─────────────────────────
          _SectionHeader('Sensor Configuration'),
          _InfoCard(items: const [
            _InfoItem(
              icon: Icons.update,
              label: 'Sensor Update Interval',
              value: '2 seconds',
            ),
            _InfoItem(
              icon: Icons.history_toggle_off,
              label: 'History Write Interval',
              value: '20 seconds',
            ),
            _InfoItem(
              icon: Icons.speed,
              label: 'Flow Calibration',
              value: '7.5 pulses / L/min',
            ),
          ]),

          const SizedBox(height: 16),

          // ── Sensor pin reference ──────────────────────────
          _SectionHeader('Pin Mapping'),
          _InfoCard(items: const [
            _InfoItem(
              icon: Icons.sensors,
              label: 'Sensor A — Tank LOW  (D1 / GPIO5)',
              value: '1 = water detected',
            ),
            _InfoItem(
              icon: Icons.sensors,
              label: 'Sensor B — Tank HIGH (D2 / GPIO4)',
              value: '1 = water detected',
            ),
            _InfoItem(
              icon: Icons.sensors,
              label: 'Sensor C — Well LOW  (D5 / GPIO14)',
              value: '1 = well has water',
            ),
            _InfoItem(
              icon: Icons.water,
              label: 'Flow Sensor YF-S201  (D6 / GPIO12)',
              value: 'Pulse counting ISR',
            ),
            _InfoItem(
              icon: Icons.electrical_services,
              label: 'Relay (Pump)         (D7 / GPIO13)',
              value: 'HIGH = pump ON',
            ),
          ]),

          const SizedBox(height: 24),

          // ── Danger zone ───────────────────────────────────
          _SectionHeader('Danger Zone'),
          Card(
            color: Colors.red.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Clear History',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Permanently deletes all flow logs and fill sessions from the database.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Consumer<HistoryProvider>(
                    builder: (context, histProv, _) {
                      return OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Clear All History'),
                        onPressed: () =>
                            _confirmClear(context, histProv),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryProvider histProv,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently delete all flow logs and fill sessions '
          'from the database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await histProv.clearHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History cleared successfully')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update — check your connection'),
          ),
        );
      }
    }
  }
}

// ── Shared layout widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white38,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, color: Colors.white12, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1565C0)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
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
