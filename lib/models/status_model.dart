class StatusModel {
  final int sensorA;
  final int sensorB;
  final int sensorC;
  final bool pumpRunning;
  final bool autoFillActive;
  final bool manualOverride;
  final String stopReason;
  final int timestamp;
  final double flowRateLPM;
  final double sessionLitres;
  final double totalLitresSinceBoot;

  const StatusModel({
    required this.sensorA,
    required this.sensorB,
    required this.sensorC,
    required this.pumpRunning,
    required this.autoFillActive,
    required this.manualOverride,
    required this.stopReason,
    required this.timestamp,
    required this.flowRateLPM,
    required this.sessionLitres,
    required this.totalLitresSinceBoot,
  });

  factory StatusModel.fromMap(Map<dynamic, dynamic> map) {
    return StatusModel(
      sensorA: (map['sensorA'] as num?)?.toInt() ?? 1,
      sensorB: (map['sensorB'] as num?)?.toInt() ?? 1,
      sensorC: (map['sensorC'] as num?)?.toInt() ?? 1,
      pumpRunning: (map['pumpRunning'] as bool?) ?? false,
      autoFillActive: (map['autoFillActive'] as bool?) ?? false,
      manualOverride: (map['manualOverride'] as bool?) ?? false,
      stopReason: (map['stopReason'] as String?) ?? 'idle',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      flowRateLPM: (map['flowRateLPM'] as num?)?.toDouble() ?? 0.0,
      sessionLitres: (map['sessionLitres'] as num?)?.toDouble() ?? 0.0,
      totalLitresSinceBoot:
          (map['totalLitresSinceBoot'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get tankLevel {
    if (sensorA == 0 && sensorB == 0) return 'full';
    if (sensorA == 0 && sensorB == 1) return 'half';
    return 'empty';
  }

  String get stopReasonLabel {
    switch (stopReason) {
      case 'idle':
        return 'System idle';
      case 'filling':
        return 'Filling in progress';
      case 'tank_full':
        return 'Tank full — stopped automatically';
      case 'well_dry_during_fill':
        return 'Well ran dry — fill stopped';
      case 'well_dry_safety':
        return 'Safety: well dry — pump cut off';
      case 'tank_full_safety':
        return 'Safety: tank full — pump cut off';
      case 'manual':
        return 'Running on manual override';
      default:
        return stopReason;
    }
  }

  String get modeLabel {
    if (manualOverride) return 'Manual Override';
    if (autoFillActive) return 'Auto-Fill';
    return 'Idle';
  }

  static const StatusModel defaultValue = StatusModel(
    sensorA: 1,
    sensorB: 1,
    sensorC: 1,
    pumpRunning: false,
    autoFillActive: false,
    manualOverride: false,
    stopReason: 'idle',
    timestamp: 0,
    flowRateLPM: 0.0,
    sessionLitres: 0.0,
    totalLitresSinceBoot: 0.0,
  );
}
