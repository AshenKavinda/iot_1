import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/flow_record_model.dart';

class FlowChartWidget extends StatelessWidget {
  final List<FlowRecordModel> records;

  const FlowChartWidget({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();

    // Take newest 20, reverse to chronological order for the chart
    final chartData = records.take(20).toList().reversed.toList();

    final spots = List.generate(
      chartData.length,
      (i) => FlSpot(i.toDouble(), chartData[i].flowRateLPM),
    );

    double maxY = 5.0;
    for (final r in chartData) {
      if (r.flowRateLPM > maxY) maxY = r.flowRateLPM;
    }
    maxY += 1.0;

    final double xMax = max(1.0, (chartData.length - 1).toDouble());
    final double labelInterval =
        chartData.length > 4 ? (chartData.length / 4).ceil().toDouble() : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Flow Rate (L/min)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: xMax,
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Colors.white12, strokeWidth: 1),
                getDrawingVerticalLine: (_) =>
                    const FlLine(color: Colors.white12, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.white12),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY / 4,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: labelInterval,
                    getTitlesWidget: (value, meta) {
                      final idx = value.round();
                      if (idx < 0 || idx >= chartData.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _formatTime(chartData[idx].epochMs),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int epochMs) {
    if (epochMs > 1000000000000) {
      final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    final d = Duration(milliseconds: epochMs);
    return '${d.inHours.toString().padLeft(2, '0')}:'
        '${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }
}
