class TemperaturePoint {
  final String id;
  final String name;
  final String zone; // frigo, freezer, abbattitore, forno, banco_caldo
  final double minC;
  final double maxC;
  final bool active;
  final String? photoPath;
  /// Entity Home Assistant, es. `sensor.frigo_1_temperature`.
  final String? haEntityId;

  const TemperaturePoint({
    required this.id,
    required this.name,
    required this.zone,
    required this.minC,
    required this.maxC,
    this.active = true,
    this.photoPath,
    this.haEntityId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'zone': zone,
        'min_c': minC,
        'max_c': maxC,
        'active': active ? 1 : 0,
        'photo_path': photoPath,
        'ha_entity_id': haEntityId,
      };

  factory TemperaturePoint.fromMap(Map<String, Object?> map) => TemperaturePoint(
        id: map['id']! as String,
        name: map['name']! as String,
        zone: map['zone']! as String,
        minC: (map['min_c']! as num).toDouble(),
        maxC: (map['max_c']! as num).toDouble(),
        active: (map['active'] as int? ?? 1) == 1,
        photoPath: map['photo_path'] as String?,
        haEntityId: map['ha_entity_id'] as String?,
      );

  TemperaturePoint copyWith({
    String? name,
    String? zone,
    double? minC,
    double? maxC,
    bool? active,
    String? photoPath,
    String? haEntityId,
    bool clearPhoto = false,
    bool clearHaEntity = false,
  }) =>
      TemperaturePoint(
        id: id,
        name: name ?? this.name,
        zone: zone ?? this.zone,
        minC: minC ?? this.minC,
        maxC: maxC ?? this.maxC,
        active: active ?? this.active,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        haEntityId: clearHaEntity ? null : (haEntityId ?? this.haEntityId),
      );
}

class TemperatureReading {
  final String id;
  final String pointId;
  final double valueC;
  final DateTime recordedAt;
  final String operatorName;
  final String? note;
  final bool outOfRange;
  final String? photoPath;

  const TemperatureReading({
    required this.id,
    required this.pointId,
    required this.valueC,
    required this.recordedAt,
    required this.operatorName,
    this.note,
    required this.outOfRange,
    this.photoPath,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'point_id': pointId,
        'value_c': valueC,
        'recorded_at': recordedAt.toIso8601String(),
        'operator_name': operatorName,
        'note': note,
        'out_of_range': outOfRange ? 1 : 0,
        'photo_path': photoPath,
      };

  factory TemperatureReading.fromMap(Map<String, Object?> map) => TemperatureReading(
        id: map['id']! as String,
        pointId: map['point_id']! as String,
        valueC: (map['value_c']! as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at']! as String),
        operatorName: map['operator_name']! as String,
        note: map['note'] as String?,
        outOfRange: (map['out_of_range'] as int? ?? 0) == 1,
        photoPath: map['photo_path'] as String?,
      );
}
