class ProductLot {
  final String id;
  final String productName;
  final String lotCode;
  final String supplier;
  final DateTime receivedAt;
  final DateTime? expiryAt;
  final String storageLocation;
  final String? allergens;
  final double? quantity;
  final String? unit;
  final String? notes;
  final bool opened;
  final DateTime? openedAt;
  final DateTime? useByAfterOpen;
  /// Lotto finito in settimana: resta in archivio, esce dalla lista attiva.
  final bool depleted;
  final DateTime? depletedAt;

  const ProductLot({
    required this.id,
    required this.productName,
    required this.lotCode,
    required this.supplier,
    required this.receivedAt,
    this.expiryAt,
    required this.storageLocation,
    this.allergens,
    this.quantity,
    this.unit,
    this.notes,
    this.opened = false,
    this.openedAt,
    this.useByAfterOpen,
    this.depleted = false,
    this.depletedAt,
  });

  bool get receivedThisWeek {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(start.year, start.month, start.day);
    return !receivedAt.isBefore(weekStart);
  }

  bool get isExpired {
    final limit = effectiveExpiry;
    if (limit == null) return false;
    return DateTime.now().isAfter(limit);
  }

  bool get expiresSoon {
    final limit = effectiveExpiry;
    if (limit == null) return false;
    final days = limit.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 3;
  }

  DateTime? get effectiveExpiry {
    if (opened && useByAfterOpen != null) {
      if (expiryAt == null) return useByAfterOpen;
      return useByAfterOpen!.isBefore(expiryAt!) ? useByAfterOpen : expiryAt;
    }
    return expiryAt;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'product_name': productName,
        'lot_code': lotCode,
        'supplier': supplier,
        'received_at': receivedAt.toIso8601String(),
        'expiry_at': expiryAt?.toIso8601String(),
        'storage_location': storageLocation,
        'allergens': allergens,
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
        'opened': opened ? 1 : 0,
        'opened_at': openedAt?.toIso8601String(),
        'use_by_after_open': useByAfterOpen?.toIso8601String(),
        'depleted': depleted ? 1 : 0,
        'depleted_at': depletedAt?.toIso8601String(),
      };

  factory ProductLot.fromMap(Map<String, Object?> map) => ProductLot(
        id: map['id']! as String,
        productName: map['product_name']! as String,
        lotCode: map['lot_code']! as String,
        supplier: map['supplier']! as String,
        receivedAt: DateTime.parse(map['received_at']! as String),
        expiryAt: map['expiry_at'] != null
            ? DateTime.parse(map['expiry_at']! as String)
            : null,
        storageLocation: map['storage_location']! as String,
        allergens: map['allergens'] as String?,
        quantity: (map['quantity'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
        notes: map['notes'] as String?,
        opened: (map['opened'] as int? ?? 0) == 1,
        openedAt: map['opened_at'] != null
            ? DateTime.parse(map['opened_at']! as String)
            : null,
        useByAfterOpen: map['use_by_after_open'] != null
            ? DateTime.parse(map['use_by_after_open']! as String)
            : null,
        depleted: (map['depleted'] as int? ?? 0) == 1,
        depletedAt: map['depleted_at'] != null
            ? DateTime.parse(map['depleted_at']! as String)
            : null,
      );

  ProductLot copyWith({
    String? productName,
    String? lotCode,
    String? supplier,
    DateTime? receivedAt,
    DateTime? expiryAt,
    String? storageLocation,
    String? allergens,
    double? quantity,
    String? unit,
    String? notes,
    bool? opened,
    DateTime? openedAt,
    DateTime? useByAfterOpen,
    bool? depleted,
    DateTime? depletedAt,
    bool clearDepleted = false,
  }) =>
      ProductLot(
        id: id,
        productName: productName ?? this.productName,
        lotCode: lotCode ?? this.lotCode,
        supplier: supplier ?? this.supplier,
        receivedAt: receivedAt ?? this.receivedAt,
        expiryAt: expiryAt ?? this.expiryAt,
        storageLocation: storageLocation ?? this.storageLocation,
        allergens: allergens ?? this.allergens,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        notes: notes ?? this.notes,
        opened: opened ?? this.opened,
        openedAt: openedAt ?? this.openedAt,
        useByAfterOpen: useByAfterOpen ?? this.useByAfterOpen,
        depleted: clearDepleted ? false : (depleted ?? this.depleted),
        depletedAt: clearDepleted ? null : (depletedAt ?? this.depletedAt),
      );
}
