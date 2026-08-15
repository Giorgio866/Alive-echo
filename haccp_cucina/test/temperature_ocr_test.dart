import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/temperature_ocr_service.dart';

void main() {
  group('TemperatureOcrService parsing', () {
    final service = TemperatureOcrService();

    test('estrae temperatura frigo tipica', () {
      // ignore: invalid_use_of_visible_for_testing_member
      final values = service.extractForTest('Temp 3.2 °C OK');
      expect(values.first, closeTo(3.2, 0.01));
    });

    test('estrae freezer negativo', () {
      final values = service.extractForTest('Display -18.5 C');
      expect(values.any((v) => (v + 18.5).abs() < 0.01), isTrue);
    });

    test('supporta virgola italiana', () {
      final values = service.extractForTest('2,4 gradi');
      expect(values.first, closeTo(2.4, 0.01));
    });
  });
}
