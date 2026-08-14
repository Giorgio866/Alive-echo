import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider);
    final dateLabel = DateFormat("EEEE d MMMM", 'it_IT').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: dash.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (snap) {
            final activity = settings.value?.activityName ?? 'HACCP Cucina';
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
                ref.invalidate(settingsProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: AppColors.tealDark,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Registro HACCP · ${dateLabel[0].toUpperCase()}${dateLabel.substring(1)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.slateMuted,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Controlli cucina e pizzeria in un unico posto.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        MetricTile(
                          label: 'Temperature da fare',
                          value: '${snap.missingTemperatureChecks}',
                          icon: Icons.thermostat,
                          alert: snap.missingTemperatureChecks > 0,
                          onTap: () => context.go('/temperature'),
                        ),
                        MetricTile(
                          label: 'Fuori range oggi',
                          value: '${snap.outOfRangeAlerts}',
                          icon: Icons.warning_amber_rounded,
                          alert: snap.outOfRangeAlerts > 0,
                          onTap: () => context.go('/temperature'),
                        ),
                        MetricTile(
                          label: 'Pulizie in sospeso',
                          value: '${snap.pendingCleaningTasks}',
                          icon: Icons.cleaning_services_outlined,
                          alert: snap.pendingCleaningTasks > 0,
                          onTap: () => context.go('/cleaning'),
                        ),
                        MetricTile(
                          label: 'Lotti in scadenza',
                          value: '${snap.expiringLots}',
                          icon: Icons.inventory_2_outlined,
                          alert: snap.expiringLots > 0,
                          onTap: () => context.go('/lots'),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: SectionHeader(
                        title: 'Azioni rapide',
                        subtitle: 'Flussi tipici di servizio e apertura.',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 112,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _QuickAction(
                            icon: Icons.thermostat_auto,
                            label: 'Registra\ntemperatura',
                            onTap: () => context.go('/temperature'),
                          ),
                          _QuickAction(
                            icon: Icons.restaurant_menu,
                            label: 'Preparato\nBlue Eyes',
                            onTap: () => context.go('/ingredients'),
                          ),
                          _QuickAction(
                            icon: Icons.document_scanner_outlined,
                            label: 'Scansiona\ndocumento',
                            onTap: () => context.go('/documents'),
                          ),
                          _QuickAction(
                            icon: Icons.print_outlined,
                            label: 'Stampa\netichetta',
                            onTap: () => context.go('/labels'),
                          ),
                          _QuickAction(
                            icon: Icons.add_box_outlined,
                            label: 'Nuovo\nlotto',
                            onTap: () => context.go('/lots'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: SectionHeader(
                        title: 'Documenti archiviati',
                        subtitle: '${snap.documentCount} file nel registro',
                        action: TextButton(
                          onPressed: () => context.go('/documents'),
                          child: const Text('Apri'),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0B6E6A), Color(0xFF116466)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, color: Colors.white, size: 36),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tracciabilità pronta per ispezione',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Temperature, pulizie, lotti e DDT restano sul dispositivo.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.teal),
                const Spacer(),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(height: 1.15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
