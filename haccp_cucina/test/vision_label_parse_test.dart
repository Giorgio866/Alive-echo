import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/lot_label_ocr_service.dart';
import 'package:haccp_cucina/services/vision_label_service.dart';

void main() {
  test('parseModelJson legge JSON SmolVLM stile Tastasal', () {
    const raw = '''
```json
{
  "productName": "TASTASAL AL NATURALE",
  "lotCode": "L6071318005",
  "expiryAt": "2026-08-02",
  "supplier": "Salumificio",
  "allergens": "Nessuno (senza glutine/latte)",
  "ingredients": ["carne di suino", "sale", "aromi"]
}
```
''';
    final r = VisionLabelService.parseModelJson(raw);
    expect(r.productName, 'TASTASAL AL NATURALE');
    expect(r.lotCode, 'L6071318005');
    expect(r.expiryAt, DateTime(2026, 8, 2));
    expect(r.allergens, contains('senza'));
    expect(r.ingredients, contains('sale'));
  });

  test('parseModelJson tollera testo senza JSON', () {
    final r = VisionLabelService.parseModelJson('nessun dato');
    expect(r.productName, isNull);
    expect(r.lotCode, isNull);
  });

  test('mergeWithOcr preferisce lotto OCR se Vision inventa ATTE', () {
    final vision = VisionLabelService.parseModelJson(
      '{"productName":"TASTASAL","lotCode":"ATTE","expiryAt":"2026-08-02","allergens":"Nessuno (senza glutine/latte)","ingredients":["sale"]}',
    );
    const ocr = LotLabelOcrResult(
      productName: 'TASTASAL AL NATURALE',
      lotCode: 'L6071318005',
      allergens: 'Glutine, Latte',
      rawText: 'LOTTO L6071318005 SENZA GLUTINE',
    );
    final m = VisionLabelService.mergeWithOcr(vision, ocr);
    expect(m.lotCode, 'L6071318005');
    expect(m.productName, 'TASTASAL');
    expect(m.allergens, contains('Nessuno'));
    expect(m.expiryAt, DateTime(2026, 8, 2));
  });
}
