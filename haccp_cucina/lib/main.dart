import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_router.dart';
import 'providers/app_providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  final container = ProviderContainer();
  await container.read(expiryNotificationServiceProvider).init();

  // Allarmi immediati per preparati già in scadenza
  try {
    final repo = container.read(haccpRepositoryProvider);
    final expiring = await repo.getExpiringBatches(withinHours: 24);
    final notifications = container.read(expiryNotificationServiceProvider);
    for (final batch in expiring) {
      await notifications.scheduleBatchExpiry(batch);
    }
  } catch (_) {
    // DB potrebbe non essere pronto su alcune piattaforme di test
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HaccpApp(),
    ),
  );
}

class HaccpApp extends StatelessWidget {
  const HaccpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HACCP Cucina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
