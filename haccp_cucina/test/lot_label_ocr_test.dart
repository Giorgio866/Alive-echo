import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/lot_label_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = LotLabelOcrService();

  test('estrae lotto, scadenza, prodotto e allergeni da etichetta', () {
    const text = '''
Mozzarella Fior di Latte
Lotto: AB12-345
Scadenza: 28/08/2026
Produttore: Caseificio Rossi
Allergeni: latte
Conservare in frigo 0-4 °C
''';
    final r = service.parseLabelText(text);
    expect(r.productName?.toLowerCase(), contains('mozzarella'));
    expect(r.lotCode, 'AB12-345');
    expect(r.expiryAt, DateTime(2026, 8, 28));
    expect(r.supplier?.toLowerCase(), contains('caseificio'));
    expect(r.allergens?.toLowerCase(), contains('latte'));
    expect(r.hasUsefulData, isTrue);
  });

  test('riconosce LOT e data con punti', () {
    const text = 'Prosciutto cotto\nLOT XYZ789\nScad. 15.09.2026';
    final r = service.parseLabelText(text);
    expect(r.lotCode, 'XYZ789');
    expect(r.expiryAt, DateTime(2026, 9, 15));
  });
}
