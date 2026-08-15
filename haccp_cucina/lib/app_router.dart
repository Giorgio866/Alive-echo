import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cleaning/cleaning_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ingredients/ingredients_screen.dart';
import '../features/labels/labels_screen.dart';
import '../features/lots/lots_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/temperatures/temperature_history_screen.dart';
import '../features/temperatures/temperatures_screen.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _SettingsRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final goingOnboarding = state.matchedLocation == '/onboarding';
      final settings = ref.read(settingsProvider).value;
      if (settings == null) return null;
      if (!settings.onboardingCompleted && !goingOnboarding) return '/onboarding';
      if (settings.onboardingCompleted && goingOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/temperature', builder: (context, state) => const TemperaturesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cleaning', builder: (context, state) => const CleaningScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/lots', builder: (context, state) => const LotsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/more', builder: (context, state) => const MoreHubScreen()),
              GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
              GoRoute(path: '/labels', builder: (context, state) => const LabelsScreen()),
              GoRoute(path: '/ingredients', builder: (context, state) => const IngredientsScreen()),
              GoRoute(
                path: '/temperature-history',
                builder: (context, state) => const TemperatureHistoryScreen(),
              ),
              GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

class _SettingsRefresh extends ChangeNotifier {
  _SettingsRefresh(this.ref) {
    ref.listen(settingsProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.thermostat_outlined),
            selectedIcon: Icon(Icons.thermostat),
            label: 'Temp.',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined),
            selectedIcon: Icon(Icons.cleaning_services),
            label: 'Pulizie',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Lotti',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Altro',
          ),
        ],
      ),
    );
  }
}

class MoreHubScreen extends ConsumerWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Strumenti')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubTile(
            icon: Icons.restaurant_menu,
            title: 'Preparati Blue Eyes',
            subtitle: 'Ingredienti + etichetta in un tap',
            onTap: () => context.push('/ingredients'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Esporta PDF registro',
            subtitle: 'Temperature 30 gg, preparati e lotti',
            onTap: () async {
              final s = await ref.read(settingsServiceProvider).load();
              try {
                await ref.read(pdfExportServiceProvider).exportFromRepository(
                      repo: ref.read(haccpRepositoryProvider),
                      activityName: s.activityName,
                      operatorName: s.defaultOperator,
                    );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.history,
            title: 'Storico temperature 30 gg',
            subtitle: 'Archivio letture CCP',
            onTap: () => context.push('/temperature-history'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.document_scanner_outlined,
            title: 'Scansione documenti',
            subtitle: 'DDT, certificati, formazione',
            onTap: () => context.push('/documents'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.print_outlined,
            title: 'Etichette termiche',
            subtitle: 'Stampa ESC/POS via Bluetooth',
            onTap: () => context.push('/labels'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.settings_outlined,
            title: 'Impostazioni',
            subtitle: 'Locale, operatore, stampante',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 10),
          _HubTile(
            icon: Icons.tour_outlined,
            title: 'Rifai setup guidato',
            subtitle: 'Rinomina frigo e aggiungi ingredienti',
            onTap: () async {
              final current = await ref.read(settingsServiceProvider).load();
              await ref.read(settingsServiceProvider).save(
                    current.copyWith(onboardingCompleted: false),
                  );
              ref.invalidate(settingsProvider);
              if (context.mounted) context.go('/onboarding');
            },
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.tealDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slateMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
