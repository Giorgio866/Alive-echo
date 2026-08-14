class DocumentRecord {
  final String id;
  final String title;
  final String category; // ddt, certificato, formazione, analisi, altro
  final String filePath;
  final DateTime scannedAt;
  final String? relatedLotId;
  final String? notes;
  final String? supplier;

  const DocumentRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.filePath,
    required this.scannedAt,
    this.relatedLotId,
    this.notes,
    this.supplier,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'file_path': filePath,
        'scanned_at': scannedAt.toIso8601String(),
        'related_lot_id': relatedLotId,
        'notes': notes,
        'supplier': supplier,
      };

  factory DocumentRecord.fromMap(Map<String, Object?> map) => DocumentRecord(
        id: map['id']! as String,
        title: map['title']! as String,
        category: map['category']! as String,
        filePath: map['file_path']! as String,
        scannedAt: DateTime.parse(map['scanned_at']! as String),
        relatedLotId: map['related_lot_id'] as String?,
        notes: map['notes'] as String?,
        supplier: map['supplier'] as String?,
      );
}

class LabelDraft {
  final String productName;
  final String? lotCode;
  final DateTime preparedAt;
  final DateTime useBy;
  final String? allergens;
  final String? operatorName;
  final String? storageHint;
  final int copies;

  const LabelDraft({
    required this.productName,
    this.lotCode,
    required this.preparedAt,
    required this.useBy,
    this.allergens,
    this.operatorName,
    this.storageHint,
    this.copies = 1,
  });
}

class AppSettings {
  final String activityName;
  final String defaultOperator;
  final String? printerAddress;
  final String? printerName;

  const AppSettings({
    required this.activityName,
    required this.defaultOperator,
    this.printerAddress,
    this.printerName,
  });

  AppSettings copyWith({
    String? activityName,
    String? defaultOperator,
    String? printerAddress,
    String? printerName,
  }) =>
      AppSettings(
        activityName: activityName ?? this.activityName,
        defaultOperator: defaultOperator ?? this.defaultOperator,
        printerAddress: printerAddress ?? this.printerAddress,
        printerName: printerName ?? this.printerName,
      );

  Map<String, String?> toPrefs() => {
        'activity_name': activityName,
        'default_operator': defaultOperator,
        'printer_address': printerAddress,
        'printer_name': printerName,
      };

  factory AppSettings.fromPrefs(Map<String, String?> prefs) => AppSettings(
        activityName: prefs['activity_name'] ?? 'Pizzeria / Cucina',
        defaultOperator: prefs['default_operator'] ?? 'Operatore',
        printerAddress: prefs['printer_address'],
        printerName: prefs['printer_name'],
      );
}
