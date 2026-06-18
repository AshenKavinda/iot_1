import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/flow_record_model.dart';
import '../models/session_model.dart';
import '../providers/history_provider.dart';
import '../widgets/flow_chart_widget.dart';
import '../widgets/session_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt_outlined), text: 'Sessions'),
              Tab(icon: Icon(Icons.show_chart), text: 'Flow Log'),
            ],
          ),
        ),
        body: Consumer<HistoryProvider>(
          builder: (context, histProv, _) {
            if (histProv.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '⚠️ Lost connection to device',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }
            return TabBarView(
              children: [
                _SessionsTab(sessions: histProv.sessions),
                _FlowLogTab(records: histProv.flowRecords),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Sessions tab ────────────────────────────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  final List<SessionModel> sessions;

  const _SessionsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No fill sessions recorded yet.',
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // sessions are sorted newest-first; session #1 = oldest (index sessions.length-1)
    final total = sessions.length;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => SessionCard(
        session: sessions[index],
        sessionNumber: total - index, // newest shown as #total, oldest as #1
      ),
    );
  }
}

// ── Flow log tab ────────────────────────────────────────────────────────────

class _FlowLogTab extends StatelessWidget {
  final List<FlowRecordModel> records;

  const _FlowLogTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No flow data recorded yet.',
              style: TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Chart section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FlowChartWidget(records: records),
              ),
            ),
          ),
        ),

        // Divider label
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white38,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),

        // Flow record list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _FlowRecordRow(record: records[index]),
              childCount: records.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowRecordRow extends StatelessWidget {
  final FlowRecordModel record;

  const _FlowRecordRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Time
            SizedBox(
              width: 70,
              child: Text(
                _formatTime(record.epochMs),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),

            // Flow rate
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${record.flowRateLPM.toStringAsFixed(1)} L/min',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Session: ${record.sessionLitres.toStringAsFixed(1)} L',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

            // Pump chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: record.pumpRunning
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record.pumpRunning ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: record.pumpRunning ? Colors.green : Colors.grey,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Sensor A B C dots
            Row(
              children: [
                _SensorDot('A', record.sensorA == 1),
                const SizedBox(width: 4),
                _SensorDot('B', record.sensorB == 1),
                const SizedBox(width: 4),
                _SensorDot('C', record.sensorC == 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int epochMs) {
    if (epochMs > 1000000000000) {
      return DateFormat('HH:mm:ss')
          .format(DateTime.fromMillisecondsSinceEpoch(epochMs));
    }
    final d = Duration(milliseconds: epochMs);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _SensorDot extends StatelessWidget {
  final String label;
  final bool active;

  const _SensorDot(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: active ? Colors.green : Colors.red.shade400,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.white38),
        ),
      ],
    );
  }
}
