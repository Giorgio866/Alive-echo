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

  // Archivio mensile sul telefono PRIMA di qualsiasi cancellazione automatica
  try {
    final repo = container.read(haccpRepositoryProvider);
    // Forza apertura DB
    await repo.getTemperaturePoints();
    final archive = await container.read(monthlyArchiveServiceProvider).runIfNeeded(repo);
    if (archive != null) {
      // percorso disponibile in Impostazioni / Archivi
      debugPrint('Archivio mensile salvato: ${archive.pdfPath}');
    }

    final expiring = await repo.getExpiringBatches(withinHours: 24);
    final notifications = container.read(expiryNotificationServiceProvider);
    for (final batch in expiring) {
      await notifications.scheduleBatchExpiry(batch);
    }
  } catch (e, st) {
    debugPrint('Avvio archivio/notifiche: $e\n$st');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const HaccpApp(),
    ),
  );
}

class HaccpApp extends ConsumerWidget {
  const HaccpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'HACCP Cucina',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
