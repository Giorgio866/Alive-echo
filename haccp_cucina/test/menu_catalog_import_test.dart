import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/menu_catalog_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = MenuCatalogImportService();

  test('parseMenuText extracts dishes and skips prices/headers', () {
    const text = '''
MENU
PIZZE
Margherita ................ 7,50
Marinara €6.00
Diavola 9,00
ANTIPASTI
Bruschetta pomodoro
Mozzarella di bufala
Allergeni: glutine, latte
''';
    final items = service.parseMenuText(text);
    final names = items.map((e) => e.name.toLowerCase()).toList();
    expect(names, contains('margherita'));
    expect(names, contains('marinara'));
    expect(names, contains('diavola'));
    expect(names, contains('bruschetta pomodoro'));
    expect(names, contains('mozzarella di bufala'));
    expect(names.any((n) => n.contains('allergen')), isFalse);
    expect(names, isNot(contains('menu')));
    expect(names, isNot(contains('pizze')));
  });

  test('guessShelfDays uses food keywords', () {
    expect(service.guessShelfDays('Mozzarella'), 2);
    expect(service.guessShelfDays('Rucola fresca'), 1);
    expect(service.guessShelfDays('Salmone'), 1);
    expect(service.guessShelfDays('Prosciutto crudo'), 3);
  });
}
