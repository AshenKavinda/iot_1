import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/session_model.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final int sessionNumber;

  const SessionCard({
    super.key,
    required this.session,
    required this.sessionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();
    final litresText = session.isComplete
        ? session.litresPumped.toStringAsFixed(1)
        : '—';

    return Card(
      color: style.bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: style.accentColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: style.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: style.accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Session #$sessionNumber',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypeChip(isManual: session.isManual),
                        ],
                      ),
                      if (session.hasTiming && session.isComplete)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            session.durationLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  style.accentColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      litresText,
                      style: TextStyle(
                        fontSize: session.isComplete ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: session.isComplete
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                    Text(
                      session.isComplete ? 'L pumped' : 'no data',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: Colors.white12),
            const SizedBox(height: 10),

            // ── Time info ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _InfoItem('Start', _formatMs(session.startMs)),
                ),
                Expanded(
                  child: _InfoItem(
                    'End',
                    session.isComplete ? _formatMs(session.endMs) : '—',
                  ),
                ),
                Expanded(
                  child: _InfoItem('Duration', session.durationLabel),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Result tags ──────────────────────────────────
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Tag(
                  label: session.startReasonLabel,
                  color: session.isManual
                      ? Colors.purple.shade400
                      : Colors.blue.shade600,
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 12,
                  color: Colors.white38,
                ),
                _Tag(
                  label: session.stopReasonLabel,
                  color: style.tagColor,
                  emoji: style.stopEmoji,
                ),
              ],
            ),

            if (!session.isComplete)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text(
                  'Session was interrupted or device restarted',
                  style: TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _CardStyle _resolveStyle() {
    if (!session.isComplete) {
      return _CardStyle(
        bgColor: Colors.white.withValues(alpha: 0.04),
        accentColor: Colors.grey.shade600,
        tagColor: Colors.grey.shade600,
        icon: Icons.pause_circle_outline,
        stopEmoji: null,
      );
    }
    if (session.isSuccess) {
      return _CardStyle(
        bgColor: Colors.green.withValues(alpha: 0.10),
        accentColor: Colors.green,
        tagColor: Colors.green.shade600,
        icon: Icons.check_circle_outline,
        stopEmoji: '✅',
      );
    }
    if (session.isWellDry) {
      return _CardStyle(
        bgColor: Colors.amber.withValues(alpha: 0.10),
        accentColor: Colors.amber,
        tagColor: Colors.amber.shade700,
        icon: Icons.warning_amber_outlined,
        stopEmoji: '⚠️',
      );
    }
    if (session.stopReason == 'manual_stopped') {
      return _CardStyle(
        bgColor: Colors.purple.withValues(alpha: 0.08),
        accentColor: Colors.purple.shade300,
        tagColor: Colors.purple.shade400,
        icon: Icons.stop_circle_outlined,
        stopEmoji: null,
      );
    }
    return _CardStyle(
      bgColor: Colors.white.withValues(alpha: 0.06),
      accentColor: Colors.grey.shade500,
      tagColor: Colors.grey.shade500,
      icon: Icons.help_outline,
      stopEmoji: null,
    );
  }

  String _formatMs(int ms) {
    if (ms <= 0) return '—';
    if (ms > 1000000000000) {
      return DateFormat('HH:mm:ss')
          .format(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    final d = Duration(milliseconds: ms);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _CardStyle {
  final Color bgColor;
  final Color accentColor;
  final Color tagColor;
  final IconData icon;
  final String? stopEmoji;

  const _CardStyle({
    required this.bgColor,
    required this.accentColor,
    required this.tagColor,
    required this.icon,
    required this.stopEmoji,
  });
}

class _TypeChip extends StatelessWidget {
  final bool isManual;
  const _TypeChip({required this.isManual});

  @override
  Widget build(BuildContext context) {
    final color = isManual ? Colors.purple.shade300 : Colors.blue.shade300;
    final bg = isManual
        ? Colors.purple.withValues(alpha: 0.2)
        : Colors.blue.withValues(alpha: 0.2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isManual ? 'MANUAL' : 'AUTO',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white38,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final String? emoji;

  const _Tag({required this.label, required this.color, this.emoji});

  @override
  Widget build(BuildContext context) {
    final display = emoji != null ? '$emoji $label' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        display,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
