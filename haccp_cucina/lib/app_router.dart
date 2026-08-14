import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/cleaning/cleaning_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/home/home_screen.dart';
import '../features/labels/labels_screen.dart';
import '../features/lots/lots_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/temperatures/temperatures_screen.dart';
import '../theme/app_theme.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ],
        ),
      ],
    ),
  ],
);

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

class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Strumenti')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
