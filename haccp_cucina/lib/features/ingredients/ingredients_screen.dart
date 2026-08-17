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
        title: const Text('Ingredienti e preparati'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '1. Catalogo'),
            Tab(text: '2. In uso'),
          ],
        ),
      ),
      body: Column(
        children: [
          Material(
            color: AppColors.tealSoft.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(
                'Qui inserisci gli ingredienti della pizza (foto menu/PDF o a mano). '
                'Poi tocca Preparo e stampa l\'etichetta.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CatalogTab(onPrepared: () => _tabs.animateTo(1)),
                _ActiveBatchesTab(onRegister: () => _tabs.animateTo(0)),
              ],
            ),
          ),
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
            message: 'Vai al Catalogo (passo 1), aggiungi ingredienti, poi tocca Preparo.',
            cta: FilledButton(onPressed: onRegister, child: const Text('Vai al catalogo ingredienti')),
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
                              copies: 1,
                            );
                            if ((b.lotCode ?? '').trim().isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Questo preparato non ha lotto: rifai Preparo scegliendo un lotto'),
                                  ),
                                );
                              }
                              return;
                            }
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

  Future<void> _importBlueEyesMenu() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingredienti Blue Eyes 2026'),
        content: const Text(
          'Importa solo gli ingredienti delle pizze e pinse (mozzarella, pomodoro, salumi…). '
          'Niente nomi dei piatti, dolci o bevande. Se c’era già il catalogo esempio, viene sostituito.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importa')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final n = await ref.read(haccpRepositoryProvider).importOptionalBlueEyesCatalog();
      ref.invalidate(ingredientCatalogProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Catalogo Blue Eyes 2026: $n voci')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import fallito: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addManualIngredient() async {
    final nameCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '3');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuovo ingrediente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giorni di scadenza'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salva')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final days = int.tryParse(daysCtrl.text.trim()) ?? 3;
    await ref.read(haccpRepositoryProvider).upsertCustomIngredient(
          IngredientCatalogItem(
            id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            category: 'custom',
            recommendedDays: days.clamp(1, 60),
            storageHint: 'In frigo 0-4 °C',
            source: 'manual',
          ),
        );
    ref.invalidate(ingredientCatalogProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name aggiunto al catalogo')),
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
                        'Passo 1 — inserisci gli ingredienti',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.tealDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Importa dal menu (foto/PDF): vengono letti solo gli ingredienti delle pizze, '
                        'non i nomi dei piatti. Poi tocca Preparo → etichetta.',
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
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _addManualIngredient,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('A mano'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _importBlueEyesMenu,
                            icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                            label: const Text('Ingredienti Blue Eyes'),
                          ),
                        ],
                      ),
                      if (items.isEmpty) ...[
                        const SizedBox(height: 24),
                        const EmptyState(
                          icon: Icons.restaurant_menu,
                          title: 'Qui vanno gli ingredienti',
                          message:
                              'Questo è il posto giusto: carica il menu o aggiungi i prodotti. '
                              'Dopo usa Preparo per registrare la preparazione e stampare l\'etichetta.',
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
                        isThreeLine: true,
                        trailing: FilledButton.tonal(
                          onPressed: () async {
                            final op = settings.value?.defaultOperator ?? 'Operatore';
                            final lots = await ref.read(haccpRepositoryProvider).getLots();
                            String? lotCode;
                            if (context.mounted && lots.isNotEmpty) {
                              lotCode = await showModalBottomSheet<String>(
                                context: context,
                                showDragHandle: true,
                                builder: (ctx) => SafeArea(
                                  child: ListView(
                                    children: [
                                      const ListTile(
                                        title: Text('Scegli il lotto per l\'etichetta'),
                                        subtitle: Text('Obbligatorio per stampare il numero di lotto'),
                                      ),
                                      ...lots.map(
                                        (l) => ListTile(
                                          title: Text(l.productName),
                                          subtitle: Text('Lotto ${l.lotCode}'),
                                          onTap: () => Navigator.pop(ctx, l.lotCode),
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.edit),
                                        title: const Text('Scrivi lotto a mano'),
                                        onTap: () => Navigator.pop(ctx, '__manual__'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (lotCode == '__manual__' && context.mounted) {
                                final ctrl = TextEditingController();
                                lotCode = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Numero di lotto'),
                                    content: TextField(
                                      controller: ctrl,
                                      decoration: const InputDecoration(labelText: 'Lotto'),
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } else if (context.mounted) {
                              final ctrl = TextEditingController();
                              lotCode = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Numero di lotto'),
                                  content: TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Lotto (obbligatorio sull\'etichetta)',
                                    ),
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            if (lotCode == null || lotCode.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Serve il numero di lotto per continuare')),
                                );
                              }
                              return;
                            }
                            final batch = await ref.read(haccpRepositoryProvider).registerPreparedBatch(
                                  ingredient: item,
                                  operatorName: op,
                                  lotCode: lotCode,
                                );
                            await ref.read(expiryNotificationServiceProvider).scheduleBatchExpiry(batch);
                            ref.invalidate(preparedBatchesProvider);
                            ref.invalidate(dashboardProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${item.name} · lotto $lotCode · scad. ${DateFormat('dd/MM').format(batch.expiresAt)}',
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
