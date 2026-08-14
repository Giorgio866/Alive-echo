import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../data/models/document_models.dart';

class ThermalPrinterDevice {
  final String name;
  final String address;

  const ThermalPrinterDevice({required this.name, required this.address});
}

/// Servizio di stampa etichette ESC/POS via Bluetooth (Android).
class ThermalPrintService {
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _dayFmt = DateFormat('dd/MM/yyyy');

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> get isConnected async {
    if (!isSupported) return false;
    return PrintBluetoothThermal.connectionStatus;
  }

  Future<List<ThermalPrinterDevice>> bondedDevices() async {
    if (!isSupported) return const [];
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((d) => ThermalPrinterDevice(name: d.name, address: d.macAdress))
        .toList();
  }

  Future<void> connect(ThermalPrinterDevice device) async {
    if (!isSupported) {
      throw UnsupportedError('La stampa Bluetooth è disponibile solo su Android.');
    }
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.address);
    if (!ok) {
      throw StateError('Connessione alla stampante fallita (${device.name}).');
    }
  }

  Future<void> disconnect() async {
    if (!isSupported) return;
    await PrintBluetoothThermal.disconnect;
  }

  Future<Uint8List> buildLabelBytes(LabelDraft draft, {String activityName = 'HACCP'}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(generator.reset());
    bytes.addAll(generator.text(
      activityName.toUpperCase(),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(generator.text(
      'ETICHETTA ALIMENTARE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      draft.productName,
      styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    ));
    if (draft.lotCode != null && draft.lotCode!.isNotEmpty) {
      bytes.addAll(generator.text('Lotto: ${draft.lotCode}'));
    }
    bytes.addAll(generator.text('Prep.: ${_dateFmt.format(draft.preparedAt)}'));
    bytes.addAll(generator.text(
      'Scadenza: ${_dayFmt.format(draft.useBy)}',
      styles: const PosStyles(bold: true),
    ));
    if (draft.storageHint != null && draft.storageHint!.isNotEmpty) {
      bytes.addAll(generator.text('Conservazione: ${draft.storageHint}'));
    }
    if (draft.allergens != null && draft.allergens!.isNotEmpty) {
      bytes.addAll(generator.text('Allergeni: ${draft.allergens}'));
    }
    if (draft.operatorName != null && draft.operatorName!.isNotEmpty) {
      bytes.addAll(generator.text('Operatore: ${draft.operatorName}'));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'HACCP • Non rimuovere',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());
    return Uint8List.fromList(bytes);
  }

  Future<String> previewText(LabelDraft draft, {String activityName = 'HACCP'}) async {
    final buf = StringBuffer()
      ..writeln(activityName.toUpperCase())
      ..writeln('ETICHETTA ALIMENTARE')
      ..writeln('------------------------------')
      ..writeln(draft.productName);
    if (draft.lotCode != null && draft.lotCode!.isNotEmpty) {
      buf.writeln('Lotto: ${draft.lotCode}');
    }
    buf
      ..writeln('Prep.: ${_dateFmt.format(draft.preparedAt)}')
      ..writeln('Scadenza: ${_dayFmt.format(draft.useBy)}');
    if (draft.storageHint != null && draft.storageHint!.isNotEmpty) {
      buf.writeln('Conservazione: ${draft.storageHint}');
    }
    if (draft.allergens != null && draft.allergens!.isNotEmpty) {
      buf.writeln('Allergeni: ${draft.allergens}');
    }
    if (draft.operatorName != null && draft.operatorName!.isNotEmpty) {
      buf.writeln('Operatore: ${draft.operatorName}');
    }
    buf
      ..writeln('------------------------------')
      ..writeln('HACCP • Non rimuovere');
    return buf.toString();
  }

  Future<void> printLabel(
    LabelDraft draft, {
    required String activityName,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Collega un dispositivo Android con stampante termica Bluetooth.');
    }
    final connected = await isConnected;
    if (!connected) {
      throw StateError('Nessuna stampante connessa. Vai in Impostazioni e collega la stampante.');
    }
    final bytes = await buildLabelBytes(draft, activityName: activityName);
    for (var i = 0; i < draft.copies; i++) {
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) {
        throw StateError('Invio stampa fallito (copia ${i + 1}).');
      }
    }
  }
}
