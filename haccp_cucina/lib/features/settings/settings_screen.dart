import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_models.dart';
import '../../providers/app_providers.dart';
import '../../services/thermal_print_service.dart';
import '../../services/vision_model_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _activityCtrl = TextEditingController();
  final _operatorCtrl = TextEditingController();
  final _hostCtrl = TextEditingController(text: '192.168.1.130');
  final _portCtrl = TextEditingController(text: '9100');
  final _networkNameCtrl = TextEditingController(text: 'ESC/POS rete');

  List<ThermalPrinterDevice> _devices = [];
  bool _loadingDevices = false;
  bool _testingNetwork = false;
  bool _visionDownloading = false;
  VisionDownloadProgress? _visionProgress;
  String? _printerSummary;
  String _mode = 'network'; // bluetooth | network

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(settingsServiceProvider).load();
    _activityCtrl.text = s.activityName;
    _operatorCtrl.text = s.defaultOperator;
    if (s.printerMode == 'bluetooth' || s.printerMode == 'network') {
      _mode = s.printerMode!;
    }
    if (s.printerMode == 'network' && s.printerAddress != null) {
      _hostCtrl.text = s.printerAddress!;
      _portCtrl.text = '${s.printerPort ?? 9100}';
      if (s.printerName != null) _networkNameCtrl.text = s.printerName!;
    }
    setState(() {
      _printerSummary = s.hasPrinterConfigured
          ? _describe(s)
          : null;
    });
  }

  String _describe(AppSettings s) {
    if (s.printerMode == 'network') {
      final name = s.printerName ?? 'Rete';
      return '$name · ${s.printerAddress}:${s.printerPort ?? 9100}';
    }
    return '${s.printerName ?? 'Bluetooth'} · ${s.printerAddress}';
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    _operatorCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _networkNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _clearPrinter() async {
    final printer = ref.read(thermalPrintServiceProvider);
    await printer.disconnectBluetooth();
    final current = await ref.read(settingsServiceProvider).load();
    await ref.read(settingsServiceProvider).save(current.copyWith(clearPrinter: true));
    ref.invalidate(settingsProvider);
    setState(() {
      _printerSummary = null;
      _devices = [];
    });
  }

  Future<void> _saveNetworkPrinter({bool testFirst = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    if (host.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Inserisci IP o hostname')));
      return;
    }
    if (port < 1 || port > 65535) {
      messenger.showSnackBar(const SnackBar(content: Text('Porta non valida')));
      return;
    }

    setState(() => _testingNetwork = true);
    try {
      if (testFirst) {
        await ref.read(thermalPrintServiceProvider).testNetworkPrinter(host, port);
      }
      final current = await ref.read(settingsServiceProvider).load();
      final name = _networkNameCtrl.text.trim().isEmpty ? 'ESC/POS $host' : _networkNameCtrl.text.trim();
      final updated = current.copyWith(
        printerMode: 'network',
        printerAddress: host,
        printerPort: port,
        printerName: name,
      );
      await ref.read(settingsServiceProvider).save(updated);
      ref.invalidate(settingsProvider);
      setState(() {
        _mode = 'network';
        _printerSummary = _describe(updated);
      });
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            testFirst
                ? 'Stampante di rete OK e salvata ($host:$port)'
                : 'Stampante di rete salvata ($host:$port)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _testingNetwork = false);
    }
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
            child: const Text('Salva attività'),
          ),
          const SizedBox(height: 28),
          Text('Stampante etichette', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Scegli Bluetooth oppure WiFi/rete ESC/POS (IP + porta, anche tramite bridge Android).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 12),
          if (_printerSummary != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _mode == 'network' ? Icons.wifi : Icons.bluetooth,
                color: AppColors.teal,
              ),
              title: Text(_printerSummary!),
              subtitle: Text(_mode == 'network' ? 'WiFi / LAN / bridge' : 'Bluetooth'),
              trailing: IconButton(
                tooltip: 'Rimuovi stampante',
                icon: const Icon(Icons.link_off),
                onPressed: _clearPrinter,
              ),
            ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'network',
                label: Text('WiFi / rete'),
                icon: Icon(Icons.wifi),
              ),
              ButtonSegment(
                value: 'bluetooth',
                label: Text('Bluetooth'),
                icon: Icon(Icons.bluetooth),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 16),
          if (_mode == 'network') ...[
            TextField(
              controller: _networkNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome (opzionale)',
                hintText: 'Es. Stampante cucina / Bridge',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _hostCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'IP o hostname',
                hintText: '192.168.1.130',
                helperText: 'Es. stampante WiFi o telefono-bridge in LAN',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Porta',
                hintText: '9100',
                helperText: 'Di solito 9100 (raw ESC/POS)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testingNetwork ? null : () => _saveNetworkPrinter(testFirst: true),
                    icon: _testingNetwork
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: const Text('Test e salva'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _testingNetwork ? null : () => _saveNetworkPrinter(testFirst: false),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salva'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              printer.isSupported
                  ? 'Usa una stampante ESC/POS già accoppiata in Impostazioni Bluetooth Android.'
                  : 'Bluetooth disponibile sull\'app Android.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: !printer.isSupported
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _loadingDevices = true);
                      try {
                        final devices = await printer.bondedDevices();
                        setState(() => _devices = devices);
                        if (devices.isEmpty && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Nessuna stampante accoppiata. Accoppiala prima in Bluetooth Android.'),
                            ),
                          );
                        }
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
                    await printer.connectBluetooth(d);
                    final current = await ref.read(settingsServiceProvider).load();
                    final updated = current.copyWith(
                      printerMode: 'bluetooth',
                      printerName: d.name,
                      printerAddress: d.address,
                      printerPort: null,
                    );
                    // clear port explicitly
                    await ref.read(settingsServiceProvider).save(
                          AppSettings(
                            activityName: updated.activityName,
                            defaultOperator: updated.defaultOperator,
                            onboardingCompleted: updated.onboardingCompleted,
                            printerMode: 'bluetooth',
                            printerName: d.name,
                            printerAddress: d.address,
                            printerPort: null,
                          ),
                        );
                    ref.invalidate(settingsProvider);
                    setState(() {
                      _mode = 'bluetooth';
                      _printerSummary = '${d.name} · ${d.address}';
                    });
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
          ],
          const SizedBox(height: 28),
          Text('Vision AI on-device', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Scarica SmolVLM2-2.2B da Hugging Face (${VisionModelService.approxSizeLabel}). '
            'Modello molto più capace del 256M: legge etichette con visione + OCR. '
            'Serve WiFi una volta; poi funziona offline (su telefoni con ≥6 GB RAM).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 10),
          Consumer(
            builder: (context, ref, _) {
              final readyAsync = ref.watch(visionModelReadyProvider);
              return readyAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (ready) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          ready ? Icons.visibility : Icons.cloud_download_outlined,
                          color: AppColors.teal,
                        ),
                        title: Text(
                          ready
                              ? '${VisionModelService.displayName} pronto'
                              : 'Modello non scaricato',
                        ),
                        subtitle: Text(
                          ready
                              ? VisionModelService.modelId
                              : 'Tocca per scaricare da Hugging Face (${VisionModelService.approxSizeLabel})',
                        ),
                      ),
                      if (_visionProgress != null) ...[
                        LinearProgressIndicator(value: _visionProgress!.fraction == 0 ? null : _visionProgress!.fraction),
                        const SizedBox(height: 6),
                        Text(_visionProgress!.labelMb),
                        const SizedBox(height: 8),
                      ],
                      if (!ready)
                        FilledButton.icon(
                          onPressed: _visionDownloading ? null : _downloadVisionModel,
                          icon: _visionDownloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download),
                          label: Text(_visionDownloading ? 'Download…' : 'Scarica Vision AI 2.2B'),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(visionLabelServiceProvider).dispose();
                            await ref.read(visionModelServiceProvider).deleteModel();
                            ref.invalidate(visionModelReadyProvider);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Modello eliminato')),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Elimina modello'),
                        ),
                    ],
                  );
                },
              );
            },
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

  Future<void> _downloadVisionModel() async {
    setState(() {
      _visionDownloading = true;
      _visionProgress = null;
    });
    try {
      await ref.read(visionModelServiceProvider).ensureDownloaded(
            onProgress: (p) {
              if (mounted) setState(() => _visionProgress = p);
            },
          );
      ref.invalidate(visionModelReadyProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vision AI 2.2B installata. Usa Scansiona lotto.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download fallito: $e')));
    } finally {
      if (mounted) setState(() => _visionDownloading = false);
    }
  }
}
