import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/document_models.dart';
import '../../data/models/ingredient_models.dart';
import '../../providers/app_providers.dart';
import '../../services/menu_catalog_import_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/menu_import_review_sheet.dart';

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
        title: const Text('Preparati e catalogo'),
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
            message: 'Carica i tuoi ingredienti (foto + giorni di scadenza) e registra quando li prepari.',
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final settings = await ref.read(settingsServiceProvider).load();
                            IngredientCatalogItem? item;
                            final catalog = await ref.read(haccpRepositoryProvider).getIngredientCatalog();
                            for (final c in catalog) {
                              if (c.id == b.ingredientId) {
                                item = c;
                                break;
                              }
                            }
                            final draft = LabelDraft(
                              productName: b.ingredientName,
                              lotCode: b.lotCode,
                              preparedAt: b.preparedAt,
                              useBy: b.expiresAt,
                              allergens: item?.allergens,
                              operatorName: b.operatorName,
                              storageHint: item?.storageHint ?? 'In frigo 0–4 °C',
                              copies: 1,
                            );
                            try {
                              await ref.read(thermalPrintServiceProvider).printLabel(
                                    draft,
                                    activityName: settings.activityName,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Etichetta inviata alla stampante')),
                                );
                              }
                            } catch (e) {
                              // Anteprima se stampante non connessa
                              final preview = await ref.read(thermalPrintServiceProvider).previewText(
                                    draft,
                                    activityName: settings.activityName,
                                  );
                              if (context.mounted) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Etichetta (anteprima)'),
                                    content: SingleChildScrollView(
                                      child: Text(preview, style: const TextStyle(fontFamily: 'monospace')),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Chiudi'),
                                      ),
                                      FilledButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          try {
                                            await ref.read(thermalPrintServiceProvider).printLabel(
                                                  draft,
                                                  activityName: settings.activityName,
                                                );
                                          } catch (err) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('$err')),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text('Riprova stampa'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Etichetta'),
                        ),
                        IconButton(
                          tooltip: 'Rimuovi',
                          onPressed: () async {
                            await ref.read(expiryNotificationServiceProvider).cancelBatch(b.id);
                            await ref.read(haccpRepositoryProvider).deletePreparedBatch(b.id);
                            ref.invalidate(preparedBatchesProvider);
                            ref.invalidate(dashboardProvider);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
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

class _CatalogTab extends ConsumerStatefulWidget {
  const _CatalogTab({required this.onPrepared});

  final VoidCallback onPrepared;

  @override
  ConsumerState<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<_CatalogTab> {
  bool _busy = false;

  Future<void> _importFromPhoto({required bool fromCamera}) async {
    setState(() => _busy = true);
    try {
      final scan = ref.read(documentScanServiceProvider);
      final path = fromCamera ? await scan.captureFromCamera() : await scan.pickFromGallery();
      if (path == null) return;
      final result = await ref.read(menuCatalogImportServiceProvider).importFromImagePath(path);
      if (!mounted) return;
      await _persistImport(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import foto fallito: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromPdf() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(menuCatalogImportServiceProvider).pickAndImportPdf();
      if (result == null || !mounted) return;
      await _persistImport(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import PDF fallito: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistImport(MenuImportResult result) async {
    final items = await showMenuImportReviewSheet(
      context: context,
      result: result,
      sourceTag: 'menu_import',
    );
    if (items == null || items.isEmpty) return;
    final repo = ref.read(haccpRepositoryProvider);
    for (final item in items) {
      await repo.upsertCustomIngredient(item);
    }
    ref.invalidate(ingredientCatalogProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} ingredienti aggiunti al catalogo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: categories.length + 1,
              itemBuilder: (context, cIndex) {
                if (cIndex == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Importa dal menu',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.tealDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Foto o PDF del menu: l\'app legge i nomi e tu scegli cosa salvare.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : () => _importFromPhoto(fromCamera: true),
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: const Text('Foto menu'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _importFromPhoto(fromCamera: false),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Galleria'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _importFromPdf,
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('PDF'),
                          ),
                        ],
                      ),
                      if (items.isEmpty) ...[
                        const SizedBox(height: 24),
                        const EmptyState(
                          icon: Icons.restaurant_menu,
                          title: 'Catalogo vuoto',
                          message: 'Importa il menu con foto o PDF, oppure registra i preparati a mano.',
                        ),
                      ],
                    ],
                  );
                }
                final cat = categories[cIndex - 1];
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
                            widget.onPrepared();
                          },
                          child: const Text('Preparo'),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  String _categoryLabel(String cat) {
    return switch (cat) {
      'custom' => 'I tuoi preparati',
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
