import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/document_models.dart';
import '../../data/models/product_lot.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  final _productCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  final _allergensCtrl = TextEditingController();
  DateTime _preparedAt = DateTime.now();
  DateTime _useBy = DateTime.now().add(const Duration(days: 2));
  int _copies = 1;
  String _preview = '';
  String? _selectedLotId;

  @override
  void dispose() {
    _productCtrl.dispose();
    _lotCtrl.dispose();
    _allergensCtrl.dispose();
    super.dispose();
  }

  LabelDraft _draft(String operatorName) => LabelDraft(
        productName: _productCtrl.text.trim().isEmpty ? 'Prodotto' : _productCtrl.text.trim(),
        lotCode: _lotCtrl.text.trim(),
        preparedAt: _preparedAt,
        useBy: _useBy,
        allergens: _allergensCtrl.text.trim().isEmpty ? null : _allergensCtrl.text.trim(),
        operatorName: operatorName,
        copies: _copies,
      );

  Future<void> _refreshPreview() async {
    final settings = await ref.read(settingsServiceProvider).load();
    final text = await ref.read(thermalPrintServiceProvider).previewText(
          _draft(settings.defaultOperator),
          activityName: settings.activityName,
        );
    setState(() => _preview = text);
  }

  Future<void> _pickFromLots() async {
    final lots = await ref.read(haccpRepositoryProvider).getLots();
    if (!mounted) return;
    if (lots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun lotto: scansiona un prodotto in Lotti')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<ProductLot>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Seleziona lotto da stampare', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...lots.map(
              (l) => ListTile(
                title: Text(l.productName),
                subtitle: Text(
                  'Lotto ${l.lotCode}'
                  '${l.effectiveExpiry != null ? ' · scad. ${DateFormat('dd/MM/yyyy').format(l.effectiveExpiry!)}' : ''}',
                ),
                onTap: () => Navigator.pop(ctx, l),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    setState(() {
      _selectedLotId = chosen.id;
      _productCtrl.text = chosen.productName;
      _lotCtrl.text = chosen.lotCode;
      if (chosen.allergens != null) _allergensCtrl.text = chosen.allergens!;
      _preparedAt = chosen.openedAt ?? chosen.receivedAt;
      if (chosen.effectiveExpiry != null) _useBy = chosen.effectiveExpiry!;
    });
    await _refreshPreview();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final printer = ref.watch(thermalPrintServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Etichette termiche')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'L\'etichetta include sempre il numero di lotto. Puoi scegliere un lotto già scansionato.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _pickFromLots,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(_selectedLotId == null ? 'Seleziona lotto salvato' : 'Cambia lotto selezionato'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _productCtrl,
            decoration: const InputDecoration(labelText: 'Nome prodotto / preparato'),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _lotCtrl,
            decoration: const InputDecoration(
              labelText: 'Numero di lotto (obbligatorio)',
              helperText: 'Comparirà in evidenza sull\'etichetta',
            ),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _allergensCtrl,
            decoration: const InputDecoration(labelText: 'Allergeni'),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _preparedAt,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setState(() => _preparedAt = picked);
                      await _refreshPreview();
                    }
                  },
                  child: Text('Prep. ${DateFormat('dd/MM').format(_preparedAt)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _useBy,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _useBy = picked);
                      await _refreshPreview();
                    }
                  },
                  child: Text('Scad. ${DateFormat('dd/MM').format(_useBy)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Copie'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _copies > 1
                    ? () {
                        setState(() => _copies--);
                        _refreshPreview();
                      }
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_copies', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                onPressed: () {
                  setState(() => _copies++);
                  _refreshPreview();
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Anteprima', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate.withValues(alpha: 0.12)),
            ),
            child: Text(
              _preview.isEmpty ? '…' : _preview,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          if (!printer.isSupported)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'La stampa ESC/POS è attiva su Android (Bluetooth o WiFi/rete).',
              ),
            )
          else
            Text(
              'Stampante da Impostazioni (Bluetooth o WiFi IP:porta).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (_lotCtrl.text.trim().isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Inserisci il numero di lotto oppure seleziona un lotto')),
                );
                return;
              }
              final s = settings.value ?? await ref.read(settingsServiceProvider).load();
              try {
                await ref.read(thermalPrintServiceProvider).printLabel(
                      _draft(s.defaultOperator),
                      activityName: s.activityName,
                    );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Etichetta inviata (con lotto)')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            icon: const Icon(Icons.print),
            label: const Text('Stampa etichetta'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _refreshPreview(),
            child: const Text('Aggiorna anteprima'),
          ),
        ],
      ),
    );
  }
}
