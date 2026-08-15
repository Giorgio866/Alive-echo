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
  /// `bluetooth` | `network` | null
  final String? printerMode;
  /// MAC Bluetooth oppure host/IP di rete.
  final String? printerAddress;
  final String? printerName;
  /// Porta TCP per stampanti di rete / bridge (default 9100).
  final int? printerPort;
  final bool onboardingCompleted;

  const AppSettings({
    required this.activityName,
    required this.defaultOperator,
    this.printerMode,
    this.printerAddress,
    this.printerName,
    this.printerPort,
    this.onboardingCompleted = false,
  });

  bool get hasPrinterConfigured =>
      printerAddress != null &&
      printerAddress!.trim().isNotEmpty &&
      (printerMode == 'bluetooth' || printerMode == 'network');

  AppSettings copyWith({
    String? activityName,
    String? defaultOperator,
    String? printerMode,
    String? printerAddress,
    String? printerName,
    int? printerPort,
    bool? onboardingCompleted,
    bool clearPrinter = false,
  }) =>
      AppSettings(
        activityName: activityName ?? this.activityName,
        defaultOperator: defaultOperator ?? this.defaultOperator,
        printerMode: clearPrinter ? null : (printerMode ?? this.printerMode),
        printerAddress: clearPrinter ? null : (printerAddress ?? this.printerAddress),
        printerName: clearPrinter ? null : (printerName ?? this.printerName),
        printerPort: clearPrinter ? null : (printerPort ?? this.printerPort),
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );

  Map<String, String?> toPrefs() => {
        'activity_name': activityName,
        'default_operator': defaultOperator,
        'printer_mode': printerMode,
        'printer_address': printerAddress,
        'printer_name': printerName,
        'printer_port': printerPort?.toString(),
        'onboarding_completed': onboardingCompleted ? '1' : '0',
      };

  factory AppSettings.fromPrefs(Map<String, String?> prefs) {
    final portRaw = prefs['printer_port'];
    final port = portRaw == null ? null : int.tryParse(portRaw);
    // Retrocompatibilità: se c'era solo address (MAC), assume Bluetooth.
    final mode = prefs['printer_mode'] ??
        (prefs['printer_address'] != null && prefs['printer_address']!.isNotEmpty
            ? 'bluetooth'
            : null);
    return AppSettings(
      activityName: prefs['activity_name'] ?? 'Pizzeria / Cucina',
      defaultOperator: prefs['default_operator'] ?? 'Operatore',
      printerMode: mode,
      printerAddress: prefs['printer_address'],
      printerName: prefs['printer_name'],
      printerPort: port,
      onboardingCompleted: prefs['onboarding_completed'] == '1',
    );
  }
}
