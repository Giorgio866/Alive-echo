import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/document_models.dart';
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
  final _storageCtrl = TextEditingController(text: 'In frigo 0–4 °C');
  DateTime _preparedAt = DateTime.now();
  DateTime _useBy = DateTime.now().add(const Duration(days: 2));
  int _copies = 1;
  String _preview = '';

  @override
  void dispose() {
    _productCtrl.dispose();
    _lotCtrl.dispose();
    _allergensCtrl.dispose();
    _storageCtrl.dispose();
    super.dispose();
  }

  LabelDraft _draft(String operatorName) => LabelDraft(
        productName: _productCtrl.text.trim().isEmpty ? 'Prodotto' : _productCtrl.text.trim(),
        lotCode: _lotCtrl.text.trim().isEmpty ? null : _lotCtrl.text.trim(),
        preparedAt: _preparedAt,
        useBy: _useBy,
        allergens: _allergensCtrl.text.trim().isEmpty ? null : _allergensCtrl.text.trim(),
        operatorName: operatorName,
        storageHint: _storageCtrl.text.trim().isEmpty ? null : _storageCtrl.text.trim(),
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
            'Genera etichette HACCP per preparati, salse e semilavorati pizza.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slateMuted),
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
            decoration: const InputDecoration(labelText: 'Lotto (opzionale)'),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _allergensCtrl,
            decoration: const InputDecoration(labelText: 'Allergeni'),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _storageCtrl,
            decoration: const InputDecoration(labelText: 'Conservazione'),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _preparedAt,
                      firstDate: DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) {
                      setState(() => _preparedAt = d);
                      await _refreshPreview();
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text('Prep. ${DateFormat('dd/MM').format(_preparedAt)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _useBy,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (d != null) {
                      setState(() => _useBy = d);
                      await _refreshPreview();
                    }
                  },
                  icon: const Icon(Icons.event_busy),
                  label: Text('Scad. ${DateFormat('dd/MM').format(_useBy)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Copie'),
              Expanded(
                child: Slider(
                  value: _copies.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '$_copies',
                  onChanged: (v) {
                    setState(() => _copies = v.round());
                    _refreshPreview();
                  },
                ),
              ),
              Text('$_copies'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              _preview.isEmpty ? 'Anteprima etichetta…' : _preview,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE8E8E8),
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
                'La stampa ESC/POS è attiva su Android (Bluetooth o WiFi/rete). Qui puoi comunque preparare il layout.',
              ),
            )
          else
            Text(
              'Usa la stampante salvata in Impostazioni (Bluetooth oppure WiFi IP:porta / bridge).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final s = settings.value ?? await ref.read(settingsServiceProvider).load();
              try {
                await ref.read(thermalPrintServiceProvider).printLabel(
                      _draft(s.defaultOperator),
                      activityName: s.activityName,
                    );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Etichetta inviata alla stampante')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('$e')),
                );
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
