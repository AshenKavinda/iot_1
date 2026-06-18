class FlowRecordModel {
  final String id;
  final int sensorA;
  final int sensorB;
  final int sensorC;
  final bool pumpRunning;
  final double flowRateLPM;
  final double sessionLitres;
  final int epochMs;

  const FlowRecordModel({
    required this.id,
    required this.sensorA,
    required this.sensorB,
    required this.sensorC,
    required this.pumpRunning,
    required this.flowRateLPM,
    required this.sessionLitres,
    required this.epochMs,
  });

  factory FlowRecordModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return FlowRecordModel(
      id: id,
      sensorA: (map['sensorA'] as num?)?.toInt() ?? 0,
      sensorB: (map['sensorB'] as num?)?.toInt() ?? 0,
      sensorC: (map['sensorC'] as num?)?.toInt() ?? 1,
      pumpRunning: (map['pumpRunning'] as bool?) ?? false,
      flowRateLPM: (map['flowRateLPM'] as num?)?.toDouble() ?? 0.0,
      sessionLitres: (map['sessionLitres'] as num?)?.toDouble() ?? 0.0,
      epochMs: (map['epochMs'] as num?)?.toInt() ?? 0,
    );
  }
}
