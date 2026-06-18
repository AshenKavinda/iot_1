import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/status_provider.dart';
import '../widgets/flow_metrics_row.dart';
import '../widgets/manual_override_card.dart';
import '../widgets/pump_status_card.dart';
import '../widgets/tank_level_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // Rebuild every second to update "X seconds ago" and offline check
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusProv = context.watch<StatusProvider>();
    final status = statusProv.status;

    final lastUpdated = statusProv.lastUpdated;
    final secondsAgo = lastUpdated != null
        ? DateTime.now().difference(lastUpdated).inSeconds
        : null;
    final isDeviceOffline =
        !statusProv.hasError && secondsAgo != null && secondsAgo > 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Tank Monitor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: statusProv.isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  : Icon(
                      statusProv.hasError || isDeviceOffline
                          ? Icons.wifi_off
                          : Icons.wifi,
                      key: ValueKey(statusProv.hasError || isDeviceOffline),
                      color: statusProv.hasError || isDeviceOffline
                          ? Colors.red
                          : Colors.green,
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Error / offline banners ──────────────────────
            if (statusProv.hasError)
              _Banner(
                message: '⚠️ Lost connection to device',
                color: Colors.red.shade900,
              ),
            if (isDeviceOffline)
              _Banner(
                message: '⚠️ Device may be offline',
                color: Colors.amber.shade900,
              ),

            // ── Tank + Well row ───────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Tank Level',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TankLevelWidget(
                            sensorA: status.sensorA,
                            sensorB: status.sensorB,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                  const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Well',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: status.sensorC == 0
                                ? _WellChip(
                                    key: const ValueKey('ok'),
                                    label: 'OK',
                                    icon: Icons.water_drop,
                                    bg: Colors.green.shade800,
                                  )
                                : _WellChip(
                                    key: const ValueKey('dry'),
                                    label: 'DRY ⚠️',
                                    icon: Icons.warning_amber,
                                    bg: Colors.red.shade800,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Pump status ───────────────────────────────────
            PumpStatusCard(status: status),

            const SizedBox(height: 12),

            // ── Flow metrics (only when pump running) ─────────
            if (status.pumpRunning) ...[
              FlowMetricsRow(status: status),
              const SizedBox(height: 12),
            ],

            // ── Manual override ───────────────────────────────
            const ManualOverrideCard(),

            const SizedBox(height: 16),

            // ── Last updated ──────────────────────────────────
            if (secondsAgo != null)
              Center(
                child: Text(
                  'Last updated: $secondsAgo second${secondsAgo == 1 ? '' : 's'} ago',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;

  const _Banner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _WellChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;

  const _WellChip({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
