import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/services/menu_catalog_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = MenuCatalogImportService();

  test('parseMenuText extracts dishes and skips prices/headers', () {
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
    expect(names, contains('pizza margherita'));
    expect(names, contains('pizza marinara'));
    expect(names, contains('pizza diavola'));
    expect(names, contains('pomodoro'));
    expect(names, contains('mozzarella'));
    expect(names, contains('bruschetta pomodoro'));
    expect(names, contains('mozzarella di bufala'));
    expect(names.any((n) => n.contains('allergen')), isFalse);
    expect(names, isNot(contains('menu')));
    expect(names, isNot(contains('pizze')));
    expect(names.any((n) => n.contains('acqua')), isFalse);

    final margherita = items.firstWhere((e) => e.name.toLowerCase() == 'pizza margherita');
    expect(margherita.isDish, isTrue);
    expect(margherita.storageHint.toLowerCase(), contains('pomodoro'));
    expect(margherita.category, 'pizza');
  });

  test('parseMenuText keeps pinsa dishes with recipe, not only toppings', () {
    const text = '''
PINSE ROMANE
ASSUNTA € 13,00
Pomodoro San Marzano doc, mozzarella doc, pancetta
BERGA (BIANCA) € 14,00
Mozzarella, verdure grigliate, carciofi
BEVANDE
Acqua 1 L € 3,00
''';
    final items = service.parseMenuText(text);
    final names = items.map((e) => e.name.toLowerCase()).toList();
    expect(names, contains('pinsa assunta'));
    expect(names, contains('pinsa berga (bianca)'));
    expect(names, contains('mozzarella'));
    expect(names.any((n) => n.contains('acqua')), isFalse);
    final assunta = items.firstWhere((e) => e.name.toLowerCase() == 'pinsa assunta');
    expect(assunta.isDish, isTrue);
    expect(assunta.category, 'pinsa');
    expect(assunta.storageHint.toLowerCase(), contains('san marzano'));
  });

  test('guessShelfDays uses food keywords', () {
    expect(service.guessShelfDays('Mozzarella'), 2);
    expect(service.guessShelfDays('Rucola fresca'), 1);
    expect(service.guessShelfDays('Salmone'), 1);
    expect(service.guessShelfDays('Prosciutto crudo'), 3);
  });
}
