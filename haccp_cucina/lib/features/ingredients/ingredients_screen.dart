import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/ingredient_models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparati Blue Eyes'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'In uso'),
            Tab(text: 'Catalogo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ActiveBatchesTab(onRegister: () => _tabs.animateTo(1)),
          _CatalogTab(onPrepared: () => _tabs.animateTo(0)),
        ],
      ),
    );
  }
}

class _ActiveBatchesTab extends ConsumerWidget {
  const _ActiveBatchesTab({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(preparedBatchesProvider);
    final fmt = DateFormat('dd/MM HH:mm');

    return batchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (batches) {
        if (batches.isEmpty) {
          return EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Nessun preparato attivo',
            message: 'Registra un ingrediente dal catalogo Blue Eyes: la scadenza sarà calcolata automaticamente.',
            cta: FilledButton(onPressed: onRegister, child: const Text('Apri catalogo')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: batches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final b = batches[index];
            final tone = b.isExpired
                ? StatusTone.danger
                : b.expiresSoon
                    ? StatusTone.warn
                    : StatusTone.ok;
            final label = b.isExpired
                ? 'Scaduto'
                : b.expiresSoon
                    ? 'Scade entro 24h'
                    : 'OK';
            return Container(
              padding: const EdgeInsets.all(14),
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
                        child: Text(b.ingredientName, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      StatusBadge(label: label, tone: tone),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Prep. ${fmt.format(b.preparedAt)} · scad. ${fmt.format(b.expiresAt)}'),
                  Text(
                    'Operatore: ${b.operatorName}'
                    '${b.lotCode != null ? ' · lotto ${b.lotCode}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Rimuovi',
                      onPressed: () async {
                        await ref.read(expiryNotificationServiceProvider).cancelBatch(b.id);
                        await ref.read(haccpRepositoryProvider).deletePreparedBatch(b.id);
                        ref.invalidate(preparedBatchesProvider);
                        ref.invalidate(dashboardProvider);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CatalogTab extends ConsumerWidget {
  const _CatalogTab({required this.onPrepared});

  final VoidCallback onPrepared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(ingredientCatalogProvider);
    final settings = ref.watch(settingsProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        final grouped = <String, List<IngredientCatalogItem>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.category, () => []).add(item);
        }
        final categories = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: categories.length,
          itemBuilder: (context, cIndex) {
            final cat = categories[cIndex];
            final list = grouped[cat]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Text(
                    _categoryLabel(cat),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.tealDark),
                  ),
                ),
                ...list.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(
                      'Scadenza consigliata: ${item.recommendedDays} gg · ${item.storageHint}'
                      '${item.allergens != null ? '\nAllergeni: ${item.allergens}' : ''}',
                    ),
                    isThreeLine: item.allergens != null,
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final op = settings.value?.defaultOperator ?? 'Operatore';
                        final batch = await ref.read(haccpRepositoryProvider).registerPreparedBatch(
                              ingredient: item,
                              operatorName: op,
                            );
                        await ref.read(expiryNotificationServiceProvider).scheduleBatchExpiry(batch);
                        ref.invalidate(preparedBatchesProvider);
                        ref.invalidate(dashboardProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${item.name}: scadenza ${DateFormat('dd/MM').format(batch.expiresAt)} · notifica attiva',
                              ),
                            ),
                          );
                        }
                        onPrepared();
                      },
                      child: const Text('Preparo'),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  String _categoryLabel(String cat) {
    return switch (cat) {
      'impasto' => 'Impasti',
      'salsa' => 'Salse e basi',
      'latticini' => 'Latticini',
      'salumi' => 'Salumi',
      'carni' => 'Carni',
      'verdure' => 'Verdure',
      'preparato' => 'Preparati cucina',
      'pesce' => 'Pesce e crostacei',
      'condimento' => 'Condimenti',
      'uova' => 'Uova',
      'frutta_secca' => 'Frutta a guscio',
      'extra' => 'Extra',
      _ => cat,
    };
  }
}
