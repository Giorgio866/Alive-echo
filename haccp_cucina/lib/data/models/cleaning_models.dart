class CleaningTask {
  final String id;
  final String title;
  final String area; // cucina, pizzeria, magazzino, servizi
  final String frequency; // daily, weekly, monthly
  final String instructions;
  final bool active;

  const CleaningTask({
    required this.id,
    required this.title,
    required this.area,
    required this.frequency,
    required this.instructions,
    this.active = true,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'area': area,
        'frequency': frequency,
        'instructions': instructions,
        'active': active ? 1 : 0,
      };

  factory CleaningTask.fromMap(Map<String, Object?> map) => CleaningTask(
        id: map['id']! as String,
        title: map['title']! as String,
        area: map['area']! as String,
        frequency: map['frequency']! as String,
        instructions: map['instructions']! as String,
        active: (map['active'] as int? ?? 1) == 1,
      );
}

class CleaningLog {
  final String id;
  final String taskId;
  final DateTime completedAt;
  final String operatorName;
  final String? note;

  const CleaningLog({
    required this.id,
    required this.taskId,
    required this.completedAt,
    required this.operatorName,
    this.note,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'completed_at': completedAt.toIso8601String(),
        'operator_name': operatorName,
        'note': note,
      };

  factory CleaningLog.fromMap(Map<String, Object?> map) => CleaningLog(
        id: map['id']! as String,
        taskId: map['task_id']! as String,
        completedAt: DateTime.parse(map['completed_at']! as String),
        operatorName: map['operator_name']! as String,
        note: map['note'] as String?,
      );
}
