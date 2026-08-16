import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/ingredient_models.dart';
import '../../data/models/product_lot.dart';
import '../../providers/app_providers.dart';
import '../../services/lot_label_ocr_service.dart';
import '../../services/vision_label_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LotsScreen extends ConsumerStatefulWidget {
  const LotsScreen({super.key});

  @override
  ConsumerState<LotsScreen> createState() => _LotsScreenState();
}

enum _LotFilter { week, active, depleted }

class _LotsScreenState extends ConsumerState<LotsScreen> {
  _LotFilter _filter = _LotFilter.week;

  @override
  Widget build(BuildContext context) {
    final lotsAsync = ref.watch(lotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lotti e tracciabilità')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan_lot',
            onPressed: () => _openLotForm(context, ref, startWithScan: true),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scansiona lotto'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'manual_lot',
            backgroundColor: AppColors.surfaceElevated,
            foregroundColor: AppColors.tealDark,
            onPressed: () => _openLotForm(context, ref),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Manuale'),
          ),
        ],
      ),
      body: lotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (lots) {
          final week = lots.where((l) => !l.depleted && l.receivedThisWeek).toList();
          final active = lots.where((l) => !l.depleted).toList();
          final depleted = lots.where((l) => l.depleted).toList();
          final visible = switch (_filter) {
            _LotFilter.week => week,
            _LotFilter.active => active,
            _LotFilter.depleted => depleted,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordine a settimana: registra i lotti all\'arrivo, poi Esaurito quando finiscono. '
                      'Restano in archivio.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Settimana (${week.length})'),
                          selected: _filter == _LotFilter.week,
                          onSelected: (_) => setState(() => _filter = _LotFilter.week),
                        ),
                        ChoiceChip(
                          label: Text('Attivi (${active.length})'),
                          selected: _filter == _LotFilter.active,
                          onSelected: (_) => setState(() => _filter = _LotFilter.active),
                        ),
                        ChoiceChip(
                          label: Text('Esauriti (${depleted.length})'),
                          selected: _filter == _LotFilter.depleted,
                          onSelected: (_) => setState(() => _filter = _LotFilter.depleted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: _filter == _LotFilter.depleted
                            ? 'Nessun lotto esaurito'
                            : 'Nessun lotto in questa vista',
                        message: _filter == _LotFilter.week
                            ? 'Fotografa le etichette dei prodotti arrivati con l\'ordine di questa settimana.'
                            : 'Fotografa l\'etichetta: l\'app estrae prodotto, lotto, scadenza, fornitore e allergeni.',
                        cta: FilledButton.icon(
                          onPressed: () => _openLotForm(context, ref, startWithScan: true),
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scansiona etichetta'),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _LotCard(lot: visible[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openLotForm(
    BuildContext context,
    WidgetRef ref, {
    bool startWithScan = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LotFormSheet(startWithScan: startWithScan),
    );
  }
}

class _LotCard extends ConsumerWidget {
  const _LotCard({required this.lot});

  final ProductLot lot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = lot.depleted
        ? StatusTone.neutral
        : lot.isExpired
            ? StatusTone.danger
            : lot.expiresSoon
                ? StatusTone.warn
                : StatusTone.ok;
    final status = lot.depleted
        ? 'Esaurito'
        : lot.isExpired
            ? 'Scaduto'
            : lot.expiresSoon
                ? 'In scadenza'
                : lot.opened
                    ? 'Aperto'
                    : 'OK';
    final fmt = DateFormat('dd/MM/yyyy');
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
                child: Text(lot.productName, style: Theme.of(context).textTheme.titleMedium),
              ),
              StatusBadge(label: status, tone: tone),
            ],
          ),
          const SizedBox(height: 6),
          Text('Lotto ${lot.lotCode} · ${lot.supplier}'),
          Text(
            '${lot.storageLocation}'
            '${lot.effectiveExpiry != null ? ' · scad. ${fmt.format(lot.effectiveExpiry!)}' : ''}'
            '${lot.allergens != null && lot.allergens!.isNotEmpty ? ' · allergeni: ${lot.allergens}' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _printLotLabel(context, ref, lot),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Stampa etichetta'),
              ),
              if (!lot.opened && !lot.depleted)
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(haccpRepositoryProvider).markLotOpened(lot);
                    ref.invalidate(lotsProvider);
                    ref.invalidate(dashboardProvider);
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Segna aperto'),
                ),
              if (!lot.depleted)
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(expiryNotificationServiceProvider).cancelLot(lot.id);
                    await ref.read(haccpRepositoryProvider).markLotDepleted(lot);
                    ref.invalidate(lotsProvider);
                    ref.invalidate(dashboardProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${lot.productName} segnato esaurito')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Esaurito'),
                )
              else
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(haccpRepositoryProvider).restoreLot(lot);
                    await ref.read(expiryNotificationServiceProvider).scheduleLotExpiry(lot.copyWith(clearDepleted: true));
                    ref.invalidate(lotsProvider);
                    ref.invalidate(dashboardProvider);
                  },
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Ripristina'),
                ),
              IconButton(
                tooltip: 'Elimina',
                onPressed: () async {
                  await ref.read(expiryNotificationServiceProvider).cancelLot(lot.id);
                  await ref.read(haccpRepositoryProvider).deleteLot(lot.id);
                  ref.invalidate(lotsProvider);
                  ref.invalidate(dashboardProvider);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _printLotLabel(BuildContext context, WidgetRef ref, ProductLot lot) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = await ref.read(settingsServiceProvider).load();
    try {
      await ref.read(thermalPrintServiceProvider).printLotLabel(
            lot,
            activityName: settings.activityName,
            operatorName: settings.defaultOperator,
          );
      messenger.showSnackBar(
        SnackBar(content: Text('Etichetta stampata · lotto ${lot.lotCode}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _LotFormSheet extends ConsumerStatefulWidget {
  const _LotFormSheet({this.startWithScan = false});

  final bool startWithScan;

  @override
  ConsumerState<_LotFormSheet> createState() => _LotFormSheetState();
}

class _LotFormSheetState extends ConsumerState<_LotFormSheet> {
  final _nameCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(text: 'Frigo');
  final _allergensCtrl = TextEditingController();
  DateTime? _expiry;
  bool _scanning = false;
  bool _alsoAddToCatalog = true;
  bool _printAfterSave = true;
  List<String> _extractedIngredients = [];
  String? _ocrNote;

  @override
  void initState() {
    super.initState();
    if (widget.startWithScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanLabel());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lotCtrl.dispose();
    _supplierCtrl.dispose();
    _locationCtrl.dispose();
    _allergensCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanLabel() async {
    setState(() {
      _scanning = true;
      _ocrNote = null;
    });
    try {
      final path = await ref.read(documentScanServiceProvider).captureFromCamera();
      if (path == null) return;

      final visionReady = await ref.read(visionModelServiceProvider).isReady();
      LotLabelOcrResult result;
      if (visionReady) {
        setState(() => _ocrNote = 'OCR + Vision AI (SmolVLM2-2.2B)…');
        try {
          final ocr = await ref.read(lotLabelOcrServiceProvider).readFromFile(path);
          if (!mounted) return;
          setState(() => _ocrNote = 'Vision AI in lettura etichetta…');
          final vision = await ref.read(visionLabelServiceProvider).readLabelImage(
                path,
                ocrHint: ocr.rawText,
              );
          if (!mounted) return;
          result = VisionLabelService.mergeWithOcr(vision, ocr);
          _applyOcr(result, source: 'Vision AI SmolVLM2-2.2B + OCR');
          return;
        } catch (visionErr) {
          if (mounted) {
            setState(() => _ocrNote = 'Vision fallita ($visionErr). Provo OCR…');
          }
        }
      }
      result = await ref.read(lotLabelOcrServiceProvider).readFromFile(path);
      if (!mounted) return;
      _applyOcr(
        result,
        source: visionReady
            ? 'OCR (fallback dopo Vision)'
            : 'OCR (per migliore precisione: Impostazioni → Scarica Vision AI 2.2B)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _ocrNote = 'Scansione fallita: $e');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _applyOcr(LotLabelOcrResult result, {String source = 'OCR'}) {
    setState(() {
      if (result.productName != null) _nameCtrl.text = result.productName!;
      if (result.lotCode != null) _lotCtrl.text = result.lotCode!;
      if (result.supplier != null) _supplierCtrl.text = result.supplier!;
      if (result.allergens != null) _allergensCtrl.text = result.allergens!;
      if (result.expiryAt != null) _expiry = result.expiryAt;
      _extractedIngredients = List.of(result.ingredients);
      if (result.storageHint != null &&
          RegExp(r'frigo|refriger', caseSensitive: false).hasMatch(result.storageHint!)) {
        _locationCtrl.text = 'Frigo';
      }
      if (!result.hasUsefulData) {
        _ocrNote = 'Poco riconosciuto ($source). Riprova con più luce o completa a mano.';
      } else {
        final bits = <String>[];
        if (result.productName != null) bits.add('prodotto');
        if (result.lotCode != null) bits.add('lotto');
        if (result.expiryAt != null) bits.add('scadenza');
        if (result.supplier != null) bits.add('fornitore');
        if (result.allergens != null) bits.add('allergeni');
        if (result.ingredients.isNotEmpty) {
          bits.add('${result.ingredients.length} ingredienti');
        }
        _ocrNote = '$source → ${bits.join(', ')}. Controlla e salva.';
      }
    });
  }
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _lotCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prodotto e codice lotto sono obbligatori')),
      );
      return;
    }
    final lot = ProductLot(
      id: const Uuid().v4(),
      productName: _nameCtrl.text.trim(),
      lotCode: _lotCtrl.text.trim(),
      supplier: _supplierCtrl.text.trim().isEmpty ? 'N/D' : _supplierCtrl.text.trim(),
      receivedAt: DateTime.now(),
      expiryAt: _expiry,
      storageLocation: _locationCtrl.text.trim().isEmpty ? 'Magazzino' : _locationCtrl.text.trim(),
      allergens: _allergensCtrl.text.trim().isEmpty ? null : _allergensCtrl.text.trim(),
    );
    await ref.read(haccpRepositoryProvider).upsertLot(lot);
    await ref.read(expiryNotificationServiceProvider).scheduleLotExpiry(lot);

    if (_alsoAddToCatalog) {
      await ref.read(haccpRepositoryProvider).upsertCustomIngredient(
            IngredientCatalogItem(
              id: 'lot-ing-${lot.id}',
              name: lot.productName,
              category: 'custom',
              recommendedDays: 3,
              storageHint: 'In frigo 0-4 °C',
              allergens: lot.allergens,
              source: 'lot_scan',
            ),
          );
      for (final ing in _extractedIngredients) {
        await ref.read(haccpRepositoryProvider).upsertCustomIngredient(
              IngredientCatalogItem(
                id: 'ocr-ing-${ing.toLowerCase().hashCode}',
                name: ing,
                category: 'custom',
                recommendedDays: 3,
                storageHint: 'In frigo 0-4 °C',
                source: 'lot_ingredients_ocr',
              ),
            );
      }
      ref.invalidate(ingredientCatalogProvider);
    }

    ref.invalidate(lotsProvider);
    ref.invalidate(dashboardProvider);

    if (_printAfterSave && mounted) {
      final settings = await ref.read(settingsServiceProvider).load();
      try {
        await ref.read(thermalPrintServiceProvider).printLotLabel(
              lot,
              activityName: settings.activityName,
              operatorName: settings.defaultOperator,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lotto salvato. Stampa: $e')));
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _printAfterSave
                ? 'Lotto ${lot.lotCode} salvato e inviato in stampa'
                : 'Lotto ${lot.lotCode} salvato. Usa "Stampa etichetta" sulla scheda.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nuovo lotto in ingresso', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Scatta la foto all\'etichetta: compilazione automatica di prodotto, lotto, scadenza e altro.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _scanning ? null : _scanLabel,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: Text(_scanning ? 'Lettura etichetta…' : 'Scansiona etichetta (auto)'),
            ),
            if (_ocrNote != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_ocrNote!),
              ),
            ],
            const SizedBox(height: 12),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Prodotto')),
            const SizedBox(height: 10),
            TextField(controller: _lotCtrl, decoration: const InputDecoration(labelText: 'Codice lotto')),
            const SizedBox(height: 10),
            TextField(controller: _supplierCtrl, decoration: const InputDecoration(labelText: 'Fornitore')),
            const SizedBox(height: 10),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'Ubicazione'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _allergensCtrl,
              decoration: const InputDecoration(labelText: 'Allergeni (opzionale)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expiry ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => _expiry = picked);
              },
              icon: const Icon(Icons.event),
              label: Text(
                _expiry == null
                    ? 'Seleziona scadenza'
                    : 'Scadenza ${DateFormat('dd/MM/yyyy').format(_expiry!)}',
              ),
            ),
            if (_extractedIngredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ingredienti letti', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ing in List<String>.from(_extractedIngredients))
                    Chip(
                      label: Text(ing, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => setState(() => _extractedIngredients.remove(ing)),
                    ),
                ],
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aggiungi anche al catalogo ingredienti'),
              subtitle: Text(
                _extractedIngredients.isEmpty
                    ? 'Prodotto + eventuali ingredienti letti dall\'etichetta'
                    : 'Inclusi ${_extractedIngredients.length} ingredienti OCR: ${_extractedIngredients.take(4).join(", ")}${_extractedIngredients.length > 4 ? "…" : ""}',
              ),
              value: _alsoAddToCatalog,
              onChanged: (v) => setState(() => _alsoAddToCatalog = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stampa etichetta subito dopo il salvataggio'),
              subtitle: const Text('Con numero di lotto in evidenza'),
              value: _printAfterSave,
              onChanged: (v) => setState(() => _printAfterSave = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _scanning ? null : _save,
              child: Text(_printAfterSave ? 'Salva lotto e stampa' : 'Salva lotto'),
            ),
          ],
        ),
      ),
    );
  }
}
