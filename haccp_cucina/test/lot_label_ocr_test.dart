import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/lot_label_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = LotLabelOcrService();

  test('Tastasal reale: lotto L607..., scadenza 02/08/26, no allergeni inventati', () {
    // Testo tipico OCR da etichetta Tastasal (anche un po' sporco)
    const text = '''
TASTASAL AL NATURALE
Impasto carneo fresco di suino
INGREDIENTI
carne suina, sale, destrosio, saccarosio. Aromi e spezie. Antiossidante: E300.
Carne origine: ITALIA
SENZA GLUTINE E DERIVATI DEL LATTE
Da consumarsi previa completa cottura
Da consumare entro il: 02 08 26
Confezionato il: 13 07 26
LOTTO n. L6071318005
Prodotto nello stabilimento di Via Buozzi, 1 - Marmirolo (MN)
Conservare in frigorifero a temperatura da 0° a 4°C
''';
    final r = service.parseLabelText(text);
    expect(r.productName?.toUpperCase(), contains('TASTASAL'));
    expect(r.lotCode, 'L6071318005');
    expect(r.expiryAt, DateTime(2026, 8, 2));
    expect(r.lotCode, isNot(equals('ATTE')));
    expect(r.allergens?.toLowerCase() ?? '', isNot(contains('glutine, latte')));
    expect(r.allergens?.toLowerCase(), anyOf(contains('nessuno'), isNull));
    expect(r.ingredients.map((e) => e.toLowerCase()), contains('carne suina'));
    expect(r.ingredients.map((e) => e.toLowerCase()), contains('sale'));
    expect(r.supplier?.toLowerCase() ?? '', contains('buozzi'));
  });

  test('non prende ATTE da LATTE come lotto', () {
    const text = '''
Impasto carneo fresco di suino - Ingredienti n
SENZA GLUTINE E DERIVATI DEL LATTE
LOTTO n. L6071318005
''';
    final r = service.parseLabelText(text);
    expect(r.lotCode, 'L6071318005');
    expect(r.lotCode, isNot(equals('ATTE')));
  });

  test('estrae lotto e allergeni espliciti mozzarella', () {
    const text = '''
Mozzarella Fior di Latte
Lotto: AB12345
Scadenza: 28/08/2026
Produttore: Caseificio Rossi
Allergeni: latte
Conservare in frigo 0-4 °C
''';
    final r = service.parseLabelText(text);
    expect(r.productName?.toLowerCase(), contains('mozzarella'));
    expect(r.lotCode, 'AB12345');
    expect(r.expiryAt, DateTime(2026, 8, 28));
    expect(r.allergens?.toLowerCase(), contains('latte'));
  });

  test('estrae ingredienti singoli dalla riga Ingredienti', () {
    const text = '''
Salsa pomodoro
Lotto: SP991234
Ingredienti: pomodoro, basilico, olio EVO, aglio, sale
Allergeni: nessuno
Scadenza: 01/09/2026
''';
    final r = service.parseLabelText(text);
    expect(r.ingredients.map((e) => e.toLowerCase()), containsAll(['pomodoro', 'basilico', 'aglio']));
    expect(r.lotCode, 'SP991234');
  });
}
