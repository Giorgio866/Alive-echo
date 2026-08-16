import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/menu_catalog_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = MenuCatalogImportService();

  test('parseMenuText extracts only pizza ingredients, not dish names', () {
    const text = '''
MENU
PIZZE
MARGHERITA € 7,50
Pomodoro, mozzarella
Marinara €6.00
Pomodoro, aglio, origano
Diavola 9,00
Pomodoro, mozzarella, salamino
ANTIPASTI
Bruschetta pomodoro
Mozzarella di bufala
Allergeni: glutine, latte
BEVANDE
Acqua 1 L € 3,00
''';
    final items = service.parseMenuText(text);
    final names = items.map((e) => e.name.toLowerCase()).toList();
    expect(names, contains('pomodoro'));
    expect(names, contains('mozzarella'));
    expect(names, contains('aglio'));
    expect(names, contains('origano'));
    expect(names, contains('salamino'));
    expect(names.any((n) => n.contains('margherita')), isFalse);
    expect(names.any((n) => n.contains('marinara')), isFalse);
    expect(names.any((n) => n.contains('diavola')), isFalse);
    expect(names.any((n) => n.contains('pizza')), isFalse);
    expect(names.any((n) => n.contains('bruschetta')), isFalse);
    expect(names.any((n) => n.contains('allergen')), isFalse);
    expect(names, isNot(contains('menu')));
    expect(names, isNot(contains('pizze')));
    expect(names.any((n) => n.contains('acqua')), isFalse);
    expect(items.every((e) => !e.isDish), isTrue);
  });

  test('parseMenuText keeps pinsa toppings and skips dish titles', () {
    const text = '''
PINSE ROMANE
ASSUNTA € 13,00
Pomodoro San Marzano doc, mozzarella doc, pancetta
BERGA (BIANCA) € 14,00
Mozzarella, verdure grigliate, carciofi
BEVANDE
Acqua 1 L € 3,00
TIRAMISÙ CLASSICO € 5,00
''';
    final items = service.parseMenuText(text);
    final names = items.map((e) => e.name.toLowerCase()).toList();
    expect(names, contains('mozzarella'));
    expect(names, contains('pancetta'));
    expect(names, contains('carciofi'));
    expect(names.any((n) => n.contains('assunta')), isFalse);
    expect(names.any((n) => n.contains('berga')), isFalse);
    expect(names.any((n) => n.contains('pinsa')), isFalse);
    expect(names.any((n) => n.contains('tiramisu') || n.contains('tiramisù')), isFalse);
    expect(names.any((n) => n.contains('acqua')), isFalse);
  });

  test('guessShelfDays uses food keywords', () {
    expect(service.guessShelfDays('Mozzarella'), 2);
    expect(service.guessShelfDays('Rucola fresca'), 1);
    expect(service.guessShelfDays('Salmone'), 1);
    expect(service.guessShelfDays('Prosciutto crudo'), 3);
  });
}
