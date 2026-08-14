import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class CleaningScreen extends ConsumerWidget {
  const CleaningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(cleaningTasksProvider);
    final doneAsync = ref.watch(cleaningDoneTodayProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pulizie e sanificazione')),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (tasks) {
          final done = doneAsync.value ?? {};
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.cleaning_services_outlined,
              title: 'Nessuna checklist',
              message: 'Definisci le attività di pulizia giornaliere e settimanali.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final completed = done.contains(task.id);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(task.title, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        StatusBadge(
                          label: completed ? 'Fatto oggi' : _freqLabel(task.frequency),
                          tone: completed ? StatusTone.ok : StatusTone.warn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${task.area} · ${task.instructions}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slateMuted,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: completed
                            ? null
                            : () async {
                                final op = settings.value?.defaultOperator ?? 'Operatore';
                                await ref.read(haccpRepositoryProvider).completeCleaningTask(
                                      taskId: task.id,
                                      operatorName: op,
                                    );
                                ref.invalidate(cleaningDoneTodayProvider);
                                ref.invalidate(dashboardProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Completata: ${task.title}')),
                                  );
                                }
                              },
                        child: Text(completed ? 'Completata' : 'Segna come fatta'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _freqLabel(String frequency) {
    return switch (frequency) {
      'weekly' => 'Settimanale',
      'monthly' => 'Mensile',
      _ => 'Giornaliera',
    };
  }
}
