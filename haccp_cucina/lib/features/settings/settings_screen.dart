import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document_models.dart';
import '../../providers/app_providers.dart';
import '../../services/home_assistant_service.dart';
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
  final _haUrlCtrl = TextEditingController(text: 'http://homeassistant.local:8123');
  final _haTokenCtrl = TextEditingController();

  List<ThermalPrinterDevice> _devices = [];
  bool _loadingDevices = false;
  bool _testingNetwork = false;
  bool _visionDownloading = false;
  VisionDownloadProgress? _visionProgress;
  String? _printerSummary;
  String _mode = 'network'; // bluetooth | network
  String _printerLanguage = 'escpos'; // escpos | tspl
  String _labelFormat = '50x30'; // 40x30 | 50x30 | 50x80
  bool _haTesting = false;
  bool _haTokenVisible = false;
  String? _haStatus;
  List<HaTemperatureSensor> _haSensors = [];

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
    _printerLanguage = s.printerLanguage;
    _labelFormat = s.labelFormat;
    if (s.homeAssistantUrl != null && s.homeAssistantUrl!.isNotEmpty) {
      _haUrlCtrl.text = s.homeAssistantUrl!;
    }
    if (s.homeAssistantToken != null) {
      _haTokenCtrl.text = s.homeAssistantToken!;
    }
    setState(() {
      _printerSummary = s.hasPrinterConfigured ? _describe(s) : null;
      _haStatus = s.hasHomeAssistantConfigured ? 'Configurato' : null;
    });
  }

  String _describe(AppSettings s) {
    final lang = s.usesTspl ? 'CLABEL/TSPL ${s.labelFormat}' : 'ESC/POS';
    if (s.printerMode == 'network') {
      final name = s.printerName ?? 'Rete';
      return '$name · ${s.printerAddress}:${s.printerPort ?? 9100} · $lang';
    }
    return '${s.printerName ?? 'Bluetooth'} · ${s.printerAddress} · $lang';
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    _operatorCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _networkNameCtrl.dispose();
    _haUrlCtrl.dispose();
    _haTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePrinterLanguage() async {
    final messenger = ScaffoldMessenger.of(context);
    final current = await ref.read(settingsServiceProvider).load();
    final updated = current.copyWith(
      printerLanguage: _mode == 'network' ? 'escpos' : _printerLanguage,
      labelFormat: _labelFormat,
    );
    await ref.read(settingsServiceProvider).save(updated);
    ref.invalidate(settingsProvider);
    if (!mounted) return;
    setState(() {
      _printerSummary = updated.hasPrinterConfigured ? _describe(updated) : _printerSummary;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          updated.usesTspl
              ? 'Modalità TSPL/CLABEL salvata (${updated.labelFormat})'
              : 'Modalità ESC/POS salvata',
        ),
      ),
    );
  }

  Future<void> _onLanguageChanged(String lang) async {
    setState(() => _printerLanguage = lang);
    final current = await ref.read(settingsServiceProvider).load();
    if (!current.hasPrinterConfigured) return;
    await _savePrinterLanguage();
  }

  Future<void> _onLabelFormatChanged(String format) async {
    setState(() => _labelFormat = format);
    final current = await ref.read(settingsServiceProvider).load();
    if (!current.hasPrinterConfigured || _printerLanguage != 'tspl') return;
    await _savePrinterLanguage();
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
        printerLanguage: 'escpos',
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

  Future<void> _testAndSaveHomeAssistant() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = _haUrlCtrl.text.trim();
    final token = _haTokenCtrl.text.trim();
    if (url.isEmpty || token.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Inserisci URL e token di Home Assistant')));
      return;
    }
    setState(() {
      _haTesting = true;
      _haStatus = 'Connessione…';
    });
    try {
      final sensors = await ref.read(homeAssistantServiceProvider).listTemperatureSensors(
            baseUrl: url,
            token: token,
          );
      final current = await ref.read(settingsServiceProvider).load();
      await ref.read(settingsServiceProvider).save(
            current.copyWith(
              homeAssistantUrl: HomeAssistantService.normalizeBaseUrl(url),
              homeAssistantToken: token,
            ),
          );
      ref.invalidate(settingsProvider);
      if (!mounted) return;
      setState(() {
        _haSensors = sensors;
        _haStatus = sensors.isEmpty
            ? 'Connesso, ma nessun sensore temperatura. In HA il device_class deve essere temperature.'
            : 'Connesso: ${sensors.length} sensori temperatura (Zigbee/MQTT)';
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Home Assistant OK · ${sensors.length} termometri')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _haStatus = '$e');
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _haTesting = false);
    }
  }

  Widget _haFridgeMapping() {
    final pointsAsync = ref.watch(temperaturePointsProvider);
    return pointsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('$e'),
      data: (points) {
        if (points.isEmpty) {
          return const Text('Nessun frigo in app: completa prima il setup temperature.');
        }
        return Column(
          children: [
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  value: () {
                    final id = point.haEntityId;
                    if (id == null || id.isEmpty) return '';
                    if (_haSensors.any((s) => s.entityId == id)) return id;
                    return id;
                  }(),
                  isExpanded: true,
                  decoration: InputDecoration(labelText: point.name),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('— non collegato —'),
                    ),
                    if (point.haEntityId != null &&
                        point.haEntityId!.isNotEmpty &&
                        !_haSensors.any((s) => s.entityId == point.haEntityId))
                      DropdownMenuItem<String>(
                        value: point.haEntityId,
                        child: Text('${point.haEntityId} (non in elenco)'),
                      ),
                    ..._haSensors.map(
                      (s) => DropdownMenuItem<String>(
                        value: s.entityId,
                        child: Text(
                          s.hasValue
                              ? '${s.name}  (${s.valueC!.toStringAsFixed(1)} °C)'
                              : '${s.name}  (n/d)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) async {
                    final entity = (v == null || v.isEmpty) ? null : v;
                    await ref.read(haccpRepositoryProvider).upsertTemperaturePoint(
                          point.copyWith(
                            haEntityId: entity,
                            clearHaEntity: entity == null,
                          ),
                        );
                    ref.invalidate(temperaturePointsProvider);
                  },
                ),
              ),
          ],
        );
      },
    );
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
          Text('Home Assistant / Zigbee', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Se i termometri Zigbee sono già in Home Assistant, collegali qui. '
            'Il telefono deve essere sulla stessa WiFi. '
            'Token: HA → il tuo profilo → Token di accesso a lunga durata.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _haUrlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL Home Assistant',
              hintText: 'http://192.168.1.10:8123',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _haTokenCtrl,
            obscureText: !_haTokenVisible,
            decoration: InputDecoration(
              labelText: 'Token di accesso',
              suffixIcon: IconButton(
                tooltip: _haTokenVisible ? 'Nascondi' : 'Mostra',
                onPressed: () => setState(() => _haTokenVisible = !_haTokenVisible),
                icon: Icon(_haTokenVisible ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          if (_haStatus != null) ...[
            const SizedBox(height: 8),
            Text(_haStatus!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _haTesting ? null : _testAndSaveHomeAssistant,
                icon: _haTesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sensors),
                label: Text(_haTesting ? 'Connessione…' : 'Prova e salva'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final current = await ref.read(settingsServiceProvider).load();
                  await ref.read(settingsServiceProvider).save(current.copyWith(clearHomeAssistant: true));
                  ref.invalidate(settingsProvider);
                  _haTokenCtrl.clear();
                  setState(() {
                    _haStatus = null;
                    _haSensors = [];
                  });
                },
                child: const Text('Scollega'),
              ),
            ],
          ),
          if (_haSensors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Collega ogni frigo a un sensore', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _haFridgeMapping(),
          ],
          const SizedBox(height: 28),
          Text('Stampante etichette', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Scegli tu: ESC/POS (stampanti scontrino) oppure TSPL/CLABEL (etichette adesive). '
            'Puoi cambiare in qualsiasi momento.',
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
          Text('Connessione', style: Theme.of(context).textTheme.titleMedium),
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
            onSelectionChanged: (v) => setState(() {
              _mode = v.first;
              if (_mode == 'network') _printerLanguage = 'escpos';
            }),
          ),
          const SizedBox(height: 16),
          Text('Tipo comandi (scegli tu)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            _mode == 'network'
                ? 'In WiFi/rete è disponibile solo ESC/POS.'
                : 'ESC/POS = scontrino 58 mm · TSPL = CLABEL / etichette adesive',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(
                value: 'escpos',
                label: Text('ESC/POS'),
                icon: Icon(Icons.receipt_long),
              ),
              ButtonSegment(
                value: 'tspl',
                label: const Text('TSPL'),
                icon: const Icon(Icons.label_outline),
                enabled: _mode == 'bluetooth',
              ),
            ],
            selected: {_printerLanguage},
            onSelectionChanged: (v) => _onLanguageChanged(v.first),
          ),
          if (_mode == 'bluetooth' && _printerLanguage == 'tspl') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _labelFormat,
              decoration: const InputDecoration(
                labelText: 'Formato etichetta CLABEL',
                helperText: '40×30 / 50×30 / 50×80 mm',
              ),
              items: const [
                DropdownMenuItem(value: '40x30', child: Text('40 × 30 mm')),
                DropdownMenuItem(value: '50x30', child: Text('50 × 30 mm')),
                DropdownMenuItem(value: '50x80', child: Text('50 × 80 mm')),
              ],
              onChanged: (v) {
                if (v != null) _onLabelFormatChanged(v);
              },
            ),
          ],
          if (_mode == 'bluetooth') ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _savePrinterLanguage,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salva tipo comandi'),
              ),
            ),
          ],
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
                  ? (_printerLanguage == 'tspl'
                      ? 'Accoppia la CLABEL in Bluetooth Android, poi selezionala qui. Linguaggio: TSPL.'
                      : 'Usa una stampante ESC/POS già accoppiata in Impostazioni Bluetooth Android.')
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
                    final updated = AppSettings(
                      activityName: current.activityName,
                      defaultOperator: current.defaultOperator,
                      onboardingCompleted: current.onboardingCompleted,
                      printerMode: 'bluetooth',
                      printerName: d.name,
                      printerAddress: d.address,
                      printerPort: null,
                      printerLanguage: _printerLanguage,
                      labelFormat: _labelFormat,
                    );
                    await ref.read(settingsServiceProvider).save(updated);
                    ref.invalidate(settingsProvider);
                    setState(() {
                      _mode = 'bluetooth';
                      _printerSummary = _describe(updated);
                    });
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _printerLanguage == 'tspl'
                              ? 'CLABEL collegata (${d.name}) · $_labelFormat'
                              : 'Connessa a ${d.name} (ESC/POS)',
                        ),
                      ),
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
