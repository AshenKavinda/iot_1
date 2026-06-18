import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/status_provider.dart';

class ManualOverrideCard extends StatelessWidget {
  const ManualOverrideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusProvider>(
      builder: (context, statusProv, _) {
        final status = statusProv.status;
        final isWellDry = status.sensorC == 1;
        final isTankFull = status.sensorA == 0 && status.sensorB == 0;
        final isDisabled = isWellDry || isTankFull;

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                title: const Text(
                  'Manual Override',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Force pump on/off remotely',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                secondary: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: status.manualOverride
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    color:
                        status.manualOverride ? Colors.green : Colors.grey,
                    size: 26,
                  ),
                ),
                value: status.manualOverride,
                onChanged: isDisabled
                    ? null
                    : (val) => _onToggle(context, statusProv, val),
              ),
              if (isWellDry)
                _InlineWarning(
                  '⚠️ Well is dry — manual override will be blocked by device',
                  Colors.orange.shade900,
                ),
              if (isTankFull)
                _InlineWarning(
                  '⚠️ Tank is already full — manual override will be blocked by device',
                  Colors.blue.shade900,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    StatusProvider provider,
    bool value,
  ) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Start Manual Override?'),
          content: const Text(
            'The pump will turn ON immediately. Safety gates '
            '(well dry / tank full) are still enforced by the device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Color(0xFF1565C0)),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await provider.setManualOverride(value);
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

class _InlineWarning extends StatelessWidget {
  final String message;
  final Color color;

  const _InlineWarning(this.message, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}
