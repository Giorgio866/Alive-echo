import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/document_models.dart';
import '../../data/models/temperature_models.dart';
import '../../providers/app_providers.dart';
import '../../services/home_assistant_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class TemperaturesScreen extends ConsumerWidget {
  const TemperaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(temperaturePointsProvider);
    final latestAsync = ref.watch(latestReadingsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperature CCP'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: () async {
              final s = settings.value ?? await ref.read(settingsServiceProvider).load();
              try {
                await ref.read(pdfExportServiceProvider).exportFromRepository(
                      repo: ref.read(haccpRepositoryProvider),
                      activityName: s.activityName,
                      operatorName: s.defaultOperator,
                    );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Storico 30 giorni',
            onPressed: () => context.push('/temperature-history'),
            icon: const Icon(Icons.history),
          ),
          if (settings.value?.hasHomeAssistantConfigured == true)
            IconButton(
              tooltip: 'Leggi da Home Assistant (Zigbee)',
              onPressed: () => _importFromHomeAssistant(
                context,
                ref,
                settings.value?.defaultOperator ?? 'Operatore',
              ),
              icon: const Icon(Icons.sensors),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'temp_photo',
            onPressed: () async {
              final points = pointsAsync.value ?? [];
              if (points.isEmpty) return;
              await _showReadingSheet(
                context,
                ref,
                points.first,
                settings.value?.defaultOperator ?? 'Operatore',
                startWithPhoto: true,
              );
            },
            icon: const Icon(Icons.photo_camera),
            label: const Text('Foto temperatura'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'temp_manual',
            onPressed: () async {
              final points = pointsAsync.value ?? [];
              if (points.isEmpty) return;
              await _showReadingSheet(
                context,
                ref,
                points.first,
                settings.value?.defaultOperator ?? 'Operatore',
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Manuale'),
          ),
        ],
      ),
      body: pointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (points) {
          final latest = latestAsync.value ?? {};
          if (points.isEmpty) {
            return const EmptyState(
              icon: Icons.thermostat,
              title: 'Nessun punto di misura',
              message: 'Completa il setup iniziale o aggiungi i frigoriferi.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
            itemCount: points.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _zigbeeHelpBanner(context, settings.value);
              }
              final point = points[index - 1];
              final reading = latest[point.id];
              final isToday = reading != null && _isToday(reading.recordedAt);
              final tone = reading == null || !isToday
                  ? StatusTone.warn
                  : reading.outOfRange
                      ? StatusTone.danger
                      : StatusTone.ok;
              final statusLabel = reading == null || !isToday
                  ? 'Da controllare'
                  : reading.outOfRange
                      ? 'Fuori range'
                      : 'OK oggi';

              return Material(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        onTap: () => _showReadingSheet(
                          context,
                          ref,
                          point,
                          settings.value?.defaultOperator ?? 'Operatore',
                        ),
                        onLongPress: () => _changeFridgePhoto(context, ref, point),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _changeFridgePhoto(context, ref, point),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: _fridgeThumb(point),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(point.name, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${point.zone == 'freezer' ? 'congelatore' : 'frigo'} · '
                                      '${point.minC.toStringAsFixed(0)} / ${point.maxC.toStringAsFixed(0)} °C'
                                      '${point.haEntityId != null ? ' · Zigbee' : ''}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.slateMuted,
                                          ),
                                    ),
                                    if (reading != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ultima: ${reading.valueC.toStringAsFixed(1)} °C · '
                                        '${DateFormat('HH:mm').format(reading.recordedAt)}'
                                        '${reading.photoPath != null ? ' · 📷' : ''}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              StatusBadge(label: statusLabel, tone: tone),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _abbinaSensore(context, ref, point),
                            icon: Icon(
                              (point.haEntityId ?? '').isEmpty ? Icons.link : Icons.sensors,
                              size: 18,
                            ),
                            label: Text(
                              (point.haEntityId ?? '').isEmpty ? 'Abbina Zigbee' : 'Cambia Zigbee',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _zigbeeHelpBanner(BuildContext context, AppSettings? settings) {
    final ha = settings?.hasHomeAssistantConfigured == true;
    return Material(
      color: AppColors.tealSoft,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ha
                  ? 'Zigbee con Nabu Casa (anche da 4G, non serve la stessa WiFi)'
                  : 'Termometri Zigbee: collega Home Assistant Cloud',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              ha
                  ? 'Su ogni frigo tocca Abbina Zigbee e scegli il sensore. '
                      'Poi l\'icona dei sensori in alto per scrivere le temperature HACCP.'
                  : 'Impostazioni → incolla l\'URL https://xxxx.ui.nabu.casa e il token, '
                      'poi Prova e salva. Non serve essere sulla stessa WiFi.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
            ),
            if (!ha)
              TextButton(
                onPressed: () => context.push('/settings'),
                child: const Text('Apri Impostazioni'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abbinaSensore(
    BuildContext context,
    WidgetRef ref,
    TemperaturePoint point,
  ) async {
    final settings = await ref.read(settingsServiceProvider).load();
    if (!settings.hasHomeAssistantConfigured) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prima: Impostazioni → URL Nabu Casa + token, poi Prova e salva'),
        ),
      );
      context.push('/settings');
      return;
    }

    final future = ref.read(homeAssistantServiceProvider).listTemperatureSensors(
          baseUrl: settings.homeAssistantUrl!,
          token: settings.homeAssistantToken!,
        );
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: FutureBuilder<List<HaTemperatureSensor>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Non raggiungo Home Assistant: ${snap.error}'),
                  );
                }
                final sensors = snap.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        'Abbina ${point.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Scegli il termometro Zigbee di questo frigo. '
                        'Nabu Casa funziona anche se il telefono non è sulla stessa WiFi.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slateMuted,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.link_off),
                            title: const Text('Non collegato'),
                            selected: (point.haEntityId ?? '').isEmpty,
                            onTap: () async {
                              await ref.read(haccpRepositoryProvider).upsertTemperaturePoint(
                                    point.copyWith(clearHaEntity: true),
                                  );
                              ref.invalidate(temperaturePointsProvider);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                          if (sensors.isEmpty)
                            const ListTile(
                              title: Text('Nessun termometro trovato'),
                              subtitle: Text(
                                'In Home Assistant il device_class deve essere temperature.',
                              ),
                            ),
                          ...sensors.map((s) {
                            final selected = s.entityId == point.haEntityId;
                            return ListTile(
                              leading: Icon(selected ? Icons.sensors : Icons.sensors_outlined),
                              title: Text(s.name),
                              subtitle: Text(
                                s.hasValue
                                    ? '${s.valueC!.toStringAsFixed(1)} °C · ${s.entityId}'
                                    : 'n/d · ${s.entityId}',
                              ),
                              selected: selected,
                              onTap: () async {
                                await ref.read(haccpRepositoryProvider).upsertTemperaturePoint(
                                      point.copyWith(haEntityId: s.entityId),
                                    );
                                ref.invalidate(temperaturePointsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${point.name} → ${s.name}')),
                                  );
                                }
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _fridgeThumb(TemperaturePoint point) {
    if (!kIsWeb && point.photoPath != null && File(point.photoPath!).existsSync()) {
      return Image.file(File(point.photoPath!), fit: BoxFit.cover);
    }
    return ColoredBox(
      color: AppColors.tealSoft,
      child: Icon(
        point.zone == 'freezer' ? Icons.ac_unit : Icons.kitchen_outlined,
        color: AppColors.tealDark,
      ),
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> _importFromHomeAssistant(
    BuildContext context,
    WidgetRef ref,
    String operatorName,
  ) async {
    final settings = await ref.read(settingsServiceProvider).load();
    if (!settings.hasHomeAssistantConfigured) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configura Home Assistant in Impostazioni')),
        );
      }
      return;
    }
    final points = await ref.read(haccpRepositoryProvider).getTemperaturePoints();
    final linked = points.where((p) => (p.haEntityId ?? '').isNotEmpty).toList();
    if (linked.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prima tocca Abbina Zigbee su ogni frigo, poi riprova'),
          ),
        );
      }
      return;
    }

    var ok = 0;
    var fail = 0;
    String? lastError;
    for (final point in linked) {
      try {
        final sensor = await ref.read(homeAssistantServiceProvider).getSensor(
              baseUrl: settings.homeAssistantUrl!,
              token: settings.homeAssistantToken!,
              entityId: point.haEntityId!,
            );
        if (!sensor.hasValue) {
          fail++;
          lastError = '${point.name}: non disponibile';
          continue;
        }
        await ref.read(haccpRepositoryProvider).addTemperatureReading(
              pointId: point.id,
              valueC: sensor.valueC!,
              operatorName: operatorName,
              note: 'Home Assistant Zigbee (${sensor.entityId})',
              minC: point.minC,
              maxC: point.maxC,
            );
        ok++;
      } catch (e) {
        fail++;
        lastError = '$e';
      }
    }
    ref.invalidate(dashboardProvider);
    ref.invalidate(latestReadingsProvider);
    ref.invalidate(temperatureHistoryProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fail == 0
              ? 'Importate $ok temperature da Home Assistant'
              : 'Importate $ok, errori $fail${lastError != null ? ' · $lastError' : ''}',
        ),
      ),
    );
  }

  Future<void> _changeFridgePhoto(BuildContext context, WidgetRef ref, TemperaturePoint point) async {
    final path = await ref.read(documentScanServiceProvider).captureFromCamera();
    if (path == null) return;
    await ref.read(haccpRepositoryProvider).upsertTemperaturePoint(point.copyWith(photoPath: path));
    ref.invalidate(temperaturePointsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto aggiornata: ${point.name}')),
      );
    }
  }

  Future<void> _showReadingSheet(
    BuildContext context,
    WidgetRef ref,
    TemperaturePoint point,
    String defaultOperator, {
    bool startWithPhoto = false,
  }) async {
    final valueCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final opCtrl = TextEditingController(text: defaultOperator);
    final points = await ref.read(haccpRepositoryProvider).getTemperaturePoints();
    var selected = point;
    String? proofPhoto;
    var ocrBusy = false;
    String? ocrHint;
    List<double> candidates = [];

    Future<void> runOcr(void Function(void Function()) setLocal) async {
      setLocal(() => ocrBusy = true);
      try {
        final path = await ref.read(documentScanServiceProvider).captureFromCamera();
        if (path == null) {
          setLocal(() => ocrBusy = false);
          return;
        }
        proofPhoto = path;
        final result = await ref.read(temperatureOcrServiceProvider).readFromFile(path);
        candidates = result.candidates;
        if (result.valueC != null) {
          valueCtrl.text = result.valueC!.toStringAsFixed(
            result.valueC! == result.valueC!.roundToDouble() ? 0 : 1,
          );
          ocrHint = 'Letto dalla foto: ${result.valueC!.toStringAsFixed(1)} °C (controlla e conferma)';
        } else {
          ocrHint = 'Foto salvata. Non ho letto un numero chiaro: inserisci °C a mano.';
        }
      } catch (e) {
        ocrHint = 'Foto salvata. OCR non disponibile: inserisci °C a mano.';
      } finally {
        setLocal(() => ocrBusy = false);
      }
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            if (startWithPhoto && proofPhoto == null && !ocrBusy && ocrHint == null) {
              // Avvia OCR al primo frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (proofPhoto == null && !ocrBusy) runOcr(setLocal);
              });
            }
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
                    Text('Registra temperatura', style: Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Scatta il display del termometro: l\'app legge i °C e salva la foto come prova.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.slateMuted),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TemperaturePoint>(
                      value: selected,
                      items: points
                          .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selected = v);
                      },
                      decoration: const InputDecoration(labelText: 'Frigo / congelatore'),
                    ),
                    const SizedBox(height: 12),
                    if (proofPhoto != null && !kIsWeb && File(proofPhoto!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(proofPhoto!), height: 140, fit: BoxFit.cover),
                      ),
                    if (ocrBusy) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 8),
                      const Text('Sto leggendo i °C dalla foto…', textAlign: TextAlign.center),
                    ],
                    if (ocrHint != null) ...[
                      const SizedBox(height: 8),
                      Text(ocrHint!, style: Theme.of(ctx).textTheme.bodySmall),
                    ],
                    if (candidates.length > 1) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: candidates.take(5).map((c) {
                          return ActionChip(
                            label: Text('${c.toStringAsFixed(1)} °C'),
                            onPressed: () {
                              valueCtrl.text = c.toStringAsFixed(c == c.roundToDouble() ? 0 : 1);
                              setLocal(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Valore °C',
                        helperText:
                            'Range: ${selected.minC.toStringAsFixed(0)} – ${selected.maxC.toStringAsFixed(0)} °C',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: opCtrl,
                      decoration: const InputDecoration(labelText: 'Operatore'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Nota / azione correttiva'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: ocrBusy ? null : () => runOcr(setLocal),
                      icon: Icon(proofPhoto == null ? Icons.photo_camera : Icons.cameraswitch),
                      label: Text(proofPhoto == null ? 'Scatta foto termometro' : 'Scatta di nuovo'),
                    ),
                    const SizedBox(height: 8),
                    if (selected.haEntityId != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final s = await ref.read(settingsServiceProvider).load();
                          if (!s.hasHomeAssistantConfigured) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Configura Home Assistant in Impostazioni')),
                              );
                            }
                            return;
                          }
                          try {
                            final sensor = await ref.read(homeAssistantServiceProvider).getSensor(
                                  baseUrl: s.homeAssistantUrl!,
                                  token: s.homeAssistantToken!,
                                  entityId: selected.haEntityId!,
                                );
                            if (!sensor.hasValue) {
                              throw StateError('Sensore ${sensor.name} non disponibile');
                            }
                            valueCtrl.text = sensor.valueC!.toStringAsFixed(1);
                            if (noteCtrl.text.trim().isEmpty) {
                              noteCtrl.text = 'Home Assistant Zigbee (${sensor.entityId})';
                            }
                            setLocal(() {});
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                        icon: const Icon(Icons.sensors),
                        label: const Text('Leggi da Zigbee / Home Assistant'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _abbinaSensore(context, ref, selected);
                        },
                        icon: const Icon(Icons.link),
                        label: const Text('Abbina Zigbee'),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final raw = valueCtrl.text.trim().replaceAll(',', '.');
                        final value = double.tryParse(raw);
                        if (value == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Inserisci o scatta una temperatura valida')),
                          );
                          return;
                        }
                        final reading = await ref.read(haccpRepositoryProvider).addTemperatureReading(
                              pointId: selected.id,
                              valueC: value,
                              operatorName:
                                  opCtrl.text.trim().isEmpty ? 'Operatore' : opCtrl.text.trim(),
                              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                              minC: selected.minC,
                              maxC: selected.maxC,
                              photoPath: proofPhoto,
                            );
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(latestReadingsProvider);
                        ref.invalidate(temperaturePointsProvider);
                        ref.invalidate(temperatureHistoryProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                reading.outOfRange
                                    ? 'FUORI RANGE ${value.toStringAsFixed(1)} °C'
                                        '${proofPhoto != null ? ' · foto salvata' : ''}'
                                    : 'Salvato ${value.toStringAsFixed(1)} °C'
                                        '${proofPhoto != null ? ' · foto salvata' : ''}',
                              ),
                              backgroundColor: reading.outOfRange ? AppColors.coral : AppColors.ok,
                            ),
                          );
                        }
                      },
                      child: const Text('Salva lettura'),
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
