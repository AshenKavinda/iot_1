class SessionModel {
  final String id;
  final String startReason;
  final String? stopReason;
  final double litresPumped;
  final int startMs;
  final int endMs;
  final int duration;

  const SessionModel({
    required this.id,
    required this.startReason,
    required this.stopReason,
    required this.litresPumped,
    required this.startMs,
    required this.endMs,
    required this.duration,
  });

  factory SessionModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final fallbackMs = int.tryParse(id) ?? 0;
    return SessionModel(
      id: id,
      startReason: (map['startReason'] as String?) ?? 'auto_fill',
      stopReason: map['stopReason'] as String?,
      litresPumped: (map['litresPumped'] as num?)?.toDouble() ?? 0.0,
      startMs: (map['startMs'] as int?) ?? fallbackMs,
      endMs: (map['endMs'] as int?) ?? 0,
      duration: (map['duration'] as int?) ?? 0,
    );
  }

  int get epochMs => startMs > 0 ? startMs : (int.tryParse(id) ?? 0);

  bool get isComplete => stopReason != null;
  bool get isSuccess =>
      stopReason == 'tank_full' || stopReason == 'tank_full_safety';
  bool get isWellDry =>
      stopReason == 'well_dry_during_fill' || stopReason == 'well_dry_safety';
  bool get isManual => startReason == 'manual';
  bool get hasTiming => duration > 0 || endMs > 0;

  String get startReasonLabel {
    switch (startReason) {
      case 'auto_fill':
        return 'Auto-Fill';
      case 'manual':
        return 'Manual';
      default:
        return startReason;
    }
  }

  String get stopReasonLabel {
    if (!isComplete) return 'Interrupted';
    switch (stopReason) {
      case 'tank_full':
      case 'tank_full_safety':
        return 'Tank Full';
      case 'well_dry_during_fill':
      case 'well_dry_safety':
        return 'Well Ran Dry';
      case 'manual_stopped':
        return 'Stopped';
      default:
        return stopReason!;
    }
  }

  String get durationLabel {
    final ms = duration > 0
        ? duration
        : (endMs > 0 && startMs > 0 ? endMs - startMs : 0);
    if (ms <= 0) return '—';
    final d = Duration(milliseconds: ms);
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }
}
