import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_models.dart';
import '../../providers/app_providers.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _activityCtrl = TextEditingController();
  final _operatorCtrl = TextEditingController();
  List<ThermalPrinterDevice> _devices = [];
  bool _loadingDevices = false;
  String? _connectedLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(settingsServiceProvider).load();
    _activityCtrl.text = s.activityName;
    _operatorCtrl.text = s.defaultOperator;
    final printer = ref.read(thermalPrintServiceProvider);
    final connected = await printer.isConnected;
    setState(() {
      _connectedLabel = connected
          ? (s.printerName ?? s.printerAddress ?? 'Connessa')
          : s.printerName;
    });
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    _operatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(thermalPrintServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Attività', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _activityCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome locale / cucina',
              hintText: 'Es. Pizzeria Da Giorgio',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _operatorCtrl,
            decoration: const InputDecoration(labelText: 'Operatore predefinito'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final current = await ref.read(settingsServiceProvider).load();
              await ref.read(settingsServiceProvider).save(
                    current.copyWith(
                      activityName: _activityCtrl.text.trim().isEmpty
                          ? 'Pizzeria / Cucina'
                          : _activityCtrl.text.trim(),
                      defaultOperator: _operatorCtrl.text.trim().isEmpty
                          ? 'Operatore'
                          : _operatorCtrl.text.trim(),
                    ),
                  );
              ref.invalidate(settingsProvider);
              ref.invalidate(dashboardProvider);
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Impostazioni salvate')),
              );
            },
            child: const Text('Salva'),
          ),
          const SizedBox(height: 28),
          Text('Stampante termica Bluetooth', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            printer.isSupported
                ? 'Associa una stampante ESC/POS già accoppiata nelle impostazioni Bluetooth di Android.'
                : 'Disponibile sull\'app Android. Su questa piattaforma puoi solo configurare i dati attività.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 12),
          if (_connectedLabel != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.print, color: AppColors.teal),
              title: Text(_connectedLabel!),
              subtitle: const Text('Stampante memorizzata / connessa'),
              trailing: IconButton(
                icon: const Icon(Icons.link_off),
                onPressed: () async {
                  await printer.disconnect();
                  final current = await ref.read(settingsServiceProvider).load();
                  await ref.read(settingsServiceProvider).save(
                        AppSettings(
                          activityName: current.activityName,
                          defaultOperator: current.defaultOperator,
                        ),
                      );
                  ref.invalidate(settingsProvider);
                  setState(() => _connectedLabel = null);
                },
              ),
            ),
          OutlinedButton.icon(
            onPressed: !printer.isSupported
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _loadingDevices = true);
                    try {
                      final devices = await printer.bondedDevices();
                      setState(() => _devices = devices);
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('$e')));
                    } finally {
                      if (mounted) setState(() => _loadingDevices = false);
                    }
                  },
            icon: _loadingDevices
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: const Text('Cerca stampanti accoppiate'),
          ),
          const SizedBox(height: 8),
          ..._devices.map(
            (d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bluetooth),
              title: Text(d.name),
              subtitle: Text(d.address),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await printer.connect(d);
                  final current = await ref.read(settingsServiceProvider).load();
                  await ref.read(settingsServiceProvider).save(
                        current.copyWith(
                          printerName: d.name,
                          printerAddress: d.address,
                        ),
                      );
                  ref.invalidate(settingsProvider);
                  setState(() => _connectedLabel = d.name);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Connessa a ${d.name}')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
          ),
          const SizedBox(height: 28),
          Text('Informazioni', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'HACCP Cucina è un registro operativo offline per temperature CCP, '
            'checklist di sanificazione, tracciabilità lotti, scansione documenti e stampa etichette.',
          ),
        ],
      ),
    );
  }
}
