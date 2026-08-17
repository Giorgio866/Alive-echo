import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class TemperatureHistoryScreen extends ConsumerWidget {
  const TemperatureHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(temperatureHistoryProvider);
    final pointsAsync = ref.watch(temperaturePointsProvider);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico temperature'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (readings) {
          final points = {
            for (final p in pointsAsync.value ?? const []) p.id: p.name,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Conservazione: ultimi ${AppDatabase.temperatureRetentionDays} giorni. '
                    'Ogni mese, prima di cancellare, salva un archivio PDF+JSON sul telefono '
                    '(Altro → Archivi mensili).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              Expanded(
                child: readings.isEmpty
                    ? const EmptyState(
                        icon: Icons.history,
                        title: 'Nessuna lettura ancora',
                        message: 'Le temperature registrate resteranno disponibili per almeno 30 giorni.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: readings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final r = readings[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: r.outOfRange
                                    ? AppColors.coral.withValues(alpha: 0.35)
                                    : AppColors.slate.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  r.outOfRange ? Icons.warning_amber : Icons.thermostat,
                                  color: r.outOfRange ? AppColors.coral : AppColors.teal,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        points[r.pointId] ?? r.pointId,
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                      Text(
                                        '${fmt.format(r.recordedAt)} · ${r.operatorName}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.slateMuted,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${r.valueC.toStringAsFixed(1)} °C',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: r.outOfRange ? AppColors.coral : AppColors.slate,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
