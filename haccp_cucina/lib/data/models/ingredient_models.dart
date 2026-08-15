/// Catalogo ingredienti / preparati Blue Eyes con shelf-life HACCP consigliata
/// (giorni in frigo dopo apertura o preparazione).
class IngredientCatalogItem {
  final String id;
  final String name;
  final String category;
  final int recommendedDays;
  final String storageHint;
  final String? allergens;
  final String source; // menu pizza / base / preparato / custom
  final String? photoPath;

  const IngredientCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.recommendedDays,
    required this.storageHint,
    this.allergens,
    this.source = 'menu',
    this.photoPath,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'recommended_days': recommendedDays,
        'storage_hint': storageHint,
        'allergens': allergens,
        'source': source,
        'photo_path': photoPath,
      };

  factory IngredientCatalogItem.fromMap(Map<String, Object?> map) => IngredientCatalogItem(
        id: map['id']! as String,
        name: map['name']! as String,
        category: map['category']! as String,
        recommendedDays: map['recommended_days']! as int,
        storageHint: map['storage_hint']! as String,
        allergens: map['allergens'] as String?,
        source: map['source'] as String? ?? 'menu',
        photoPath: map['photo_path'] as String?,
      );
}

class PreparedBatch {
  final String id;
  final String ingredientId;
  final String ingredientName;
  final DateTime preparedAt;
  final DateTime expiresAt;
  final String operatorName;
  final String? lotCode;
  final String? note;
  final bool notified;

  const PreparedBatch({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.preparedAt,
    required this.expiresAt,
    required this.operatorName,
    this.lotCode,
    this.note,
    this.notified = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get expiresSoon {
    final hours = expiresAt.difference(DateTime.now()).inHours;
    return hours >= 0 && hours <= 24;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ingredient_id': ingredientId,
        'ingredient_name': ingredientName,
        'prepared_at': preparedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'operator_name': operatorName,
        'lot_code': lotCode,
        'note': note,
        'notified': notified ? 1 : 0,
      };

  factory PreparedBatch.fromMap(Map<String, Object?> map) => PreparedBatch(
        id: map['id']! as String,
        ingredientId: map['ingredient_id']! as String,
        ingredientName: map['ingredient_name']! as String,
        preparedAt: DateTime.parse(map['prepared_at']! as String),
        expiresAt: DateTime.parse(map['expires_at']! as String),
        operatorName: map['operator_name']! as String,
        lotCode: map['lot_code'] as String?,
        note: map['note'] as String?,
        notified: (map['notified'] as int? ?? 0) == 1,
      );

  PreparedBatch copyWith({bool? notified}) => PreparedBatch(
        id: id,
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        preparedAt: preparedAt,
        expiresAt: expiresAt,
        operatorName: operatorName,
        lotCode: lotCode,
        note: note,
        notified: notified ?? this.notified,
      );
}

/// Ingredienti estratti dal menu Blue Eyes 2026 + basi tipiche pizzeria.
List<IngredientCatalogItem> blueEyesIngredientCatalog() {
  IngredientCatalogItem i(
    String id,
    String name,
    String category,
    int days, {
    String storage = 'In frigo 0–4 °C',
    String? allergens,
  }) =>
      IngredientCatalogItem(
        id: id,
        name: name,
        category: category,
        recommendedDays: days,
        storageHint: storage,
        allergens: allergens,
        source: 'blue_eyes_menu',
      );

  return [
    // Impasti
    i('imp_classico', 'Impasto classico (48h)', 'impasto', 2, allergens: 'Glutine'),
    i('imp_integrale', 'Impasto integrale (72h)', 'impasto', 2, allergens: 'Glutine'),
    i('imp_napoli', 'Impasto Napoli / biga', 'impasto', 2, allergens: 'Glutine'),
    i('imp_pinsa', 'Impasto Pinsa (frumento, riso, soia)', 'impasto', 2, allergens: 'Glutine, Soia'),
    i('imp_sglutine', 'Impasto senza glutine', 'impasto', 2, allergens: 'Latte'),
    i('imp_baby', 'Impasto Baby', 'impasto', 2, allergens: 'Glutine'),

    // Basi e salse
    i('pomodoro', 'Pomodoro / salsa pomodoro', 'salsa', 3, allergens: null),
    i('pom_san_marzano', 'Pomodoro San Marzano DOC', 'salsa', 3),
    i('crema_calabrese', 'Crema calabrese piccante', 'salsa', 3),
    i('crema_zucca', 'Crema di zucca', 'salsa', 3),
    i('salsa_yogurt', 'Salsa yogurt', 'salsa', 2, allergens: 'Latte'),
    i('olio_limone', 'Olio aromatizzato al limone', 'condimento', 7),
    i('miele', 'Miele', 'condimento', 30, storage: 'Temperatura ambiente / fresco'),

    // Latticini
    i('mozzarella', 'Mozzarella', 'latticini', 2, allergens: 'Latte'),
    i('mozzarella_doc', 'Mozzarella DOC', 'latticini', 2, allergens: 'Latte'),
    i('bufala', 'Mozzarella di bufala / Bufala DOC', 'latticini', 2, allergens: 'Latte'),
    i('stracciatella', 'Stracciatella di bufala', 'latticini', 2, allergens: 'Latte'),
    i('ricotta', 'Ricotta (anche cornicione)', 'latticini', 2, allergens: 'Latte'),
    i('grana', 'Grana / scaglie di grana', 'latticini', 5, allergens: 'Latte'),
    i('gorgonzola', 'Gorgonzola', 'latticini', 4, allergens: 'Latte'),
    i('provola', 'Provola / provola affumicata', 'latticini', 4, allergens: 'Latte'),
    i('scamorza', 'Scamorza', 'latticini', 4, allergens: 'Latte'),
    i('brie', 'Brie', 'latticini', 3, allergens: 'Latte'),
    i('philadelphia', 'Philadelphia', 'latticini', 3, allergens: 'Latte'),
    i('stracchino', 'Stracchino', 'latticini', 2, allergens: 'Latte'),
    i('formaggi_misti', 'Formaggi misti', 'latticini', 3, allergens: 'Latte'),

    // Salumi e carni
    i('pancetta', 'Pancetta', 'salumi', 3),
    i('pancetta_pepe', 'Pancetta al pepe', 'salumi', 3),
    i('pancetta_giovanna', 'Pancetta stufata al miele (Giovanna)', 'salumi', 3),
    i('prosciutto_cotto', 'Prosciutto cotto', 'salumi', 3),
    i('prosciutto_crudo', 'Prosciutto crudo', 'salumi', 4),
    i('speck', 'Speck', 'salumi', 4),
    i('salamino', 'Salamino / salame piccante', 'salumi', 4),
    i('salsiccia', 'Salsiccia', 'salumi', 2),
    i('wurstel', 'Wurstel', 'salumi', 3),
    i('black_angus', 'Carpaccio Black Angus', 'carni', 1),
    i('kebab', 'Kebab Halal', 'carni', 2),

    // Verdure
    i('pomodorini', 'Pomodorini', 'verdure', 2),
    i('rucola', 'Rucola / misticanza', 'verdure', 1),
    i('cipolle', 'Cipolle', 'verdure', 3),
    i('cipolle_caramellate', 'Cipolle caramellate / agrodolce', 'preparato', 3),
    i('funghi', 'Funghi', 'verdure', 2),
    i('porcini', 'Funghi porcini', 'verdure', 2),
    i('carciofi', 'Carciofi', 'verdure', 2),
    i('zucchine', 'Zucchine / zucchine grigliate', 'verdure', 2),
    i('melanzane', 'Melanzane', 'verdure', 2),
    i('peperoni', 'Peperoni', 'verdure', 2),
    i('verdure_grigliate', 'Verdure grigliate miste', 'preparato', 2),
    i('patate_forno', 'Patate al forno', 'preparato', 2),
    i('patatine', 'Patatine fritte', 'preparato', 1),
    i('basilico', 'Basilico', 'verdure', 1),
    i('aglio', 'Aglio', 'condimento', 7),
    i('origano', 'Origano', 'condimento', 180, storage: 'Secco / ambiente'),
    i('olive', 'Olive / olive taggiasche', 'condimento', 7),
    i('capperi', 'Capperi', 'condimento', 14),

    // Pesce
    i('tonno', 'Tonno', 'pesce', 1, allergens: 'Pesce'),
    i('salmone', 'Salmone', 'pesce', 1, allergens: 'Pesce'),
    i('acciughe', 'Acciughe (Cantabrico)', 'pesce', 3, allergens: 'Pesce'),
    i('gamberetti', 'Gamberetti', 'pesce', 1, allergens: 'Crostacei'),

    // Extra
    i('uovo', 'Uovo sbattuto (Carbonara)', 'uova', 1, allergens: 'Uova'),
    i('noci', 'Noci', 'frutta_secca', 14, allergens: 'Frutta a guscio'),
    i('pistacchi', 'Granella di pistacchi', 'frutta_secca', 14, allergens: 'Frutta a guscio'),
    i('taralli', 'Taralli croccanti', 'extra', 14, allergens: 'Glutine'),
    i('sale_affumicato', 'Sale affumicato', 'condimento', 365, storage: 'Ambiente'),
    i('nutella', 'Nutella (calzone)', 'extra', 30, allergens: 'Latte, Soia', storage: 'Ambiente / fresco'),
  ];
}
