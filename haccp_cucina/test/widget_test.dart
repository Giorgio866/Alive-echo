import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:haccp_cucina/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HaccpApp mostra la navigation bar', (tester) async {
    await initializeDateFormatting('it_IT');
    await tester.pumpWidget(const ProviderScope(child: HaccpApp()));
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Temp.'), findsOneWidget);
  });
}
