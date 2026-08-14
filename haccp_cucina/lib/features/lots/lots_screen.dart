import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/product_lot.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LotsScreen extends ConsumerWidget {
  const LotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotsAsync = ref.watch(lotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lotti e tracciabilità')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLotForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo lotto'),
      ),
      body: lotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (lots) {
          if (lots.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Nessun lotto registrato',
              message: 'Registra merci in ingresso con lotto, fornitore e scadenza.',
              cta: FilledButton(
                onPressed: () => _openLotForm(context, ref),
                child: const Text('Aggiungi lotto'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: lots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final lot = lots[index];
              final tone = lot.isExpired
                  ? StatusTone.danger
                  : lot.expiresSoon
                      ? StatusTone.warn
                      : StatusTone.ok;
              final status = lot.isExpired
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
                    Row(
                      children: [
                        if (!lot.opened)
                          TextButton.icon(
                            onPressed: () async {
                              await ref.read(haccpRepositoryProvider).markLotOpened(lot);
                              ref.invalidate(lotsProvider);
                              ref.invalidate(dashboardProvider);
                            },
                            icon: const Icon(Icons.lock_open, size: 18),
                            label: const Text('Segna aperto'),
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Elimina',
                          onPressed: () async {
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
            },
          );
        },
      ),
    );
  }

  Future<void> _openLotForm(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final lotCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'Frigo');
    final allergensCtrl = TextEditingController();
    DateTime? expiry;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Nuovo lotto in ingresso', style: Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Prodotto')),
                    const SizedBox(height: 10),
                    TextField(controller: lotCtrl, decoration: const InputDecoration(labelText: 'Codice lotto')),
                    const SizedBox(height: 10),
                    TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Fornitore')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Ubicazione'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: allergensCtrl,
                      decoration: const InputDecoration(labelText: 'Allergeni (opzionale)'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) setLocal(() => expiry = picked);
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        expiry == null
                            ? 'Seleziona scadenza'
                            : 'Scadenza ${DateFormat('dd/MM/yyyy').format(expiry!)}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || lotCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Prodotto e lotto sono obbligatori')),
                          );
                          return;
                        }
                        final lot = ProductLot(
                          id: const Uuid().v4(),
                          productName: nameCtrl.text.trim(),
                          lotCode: lotCtrl.text.trim(),
                          supplier: supplierCtrl.text.trim().isEmpty ? 'N/D' : supplierCtrl.text.trim(),
                          receivedAt: DateTime.now(),
                          expiryAt: expiry,
                          storageLocation:
                              locationCtrl.text.trim().isEmpty ? 'Magazzino' : locationCtrl.text.trim(),
                          allergens: allergensCtrl.text.trim().isEmpty ? null : allergensCtrl.text.trim(),
                        );
                        await ref.read(haccpRepositoryProvider).upsertLot(lot);
                        await ref.read(expiryNotificationServiceProvider).scheduleLotExpiry(lot);
                        ref.invalidate(lotsProvider);
                        ref.invalidate(dashboardProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Salva lotto'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
