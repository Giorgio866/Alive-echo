import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../data/models/document_models.dart';
import 'settings_service.dart';

enum PrinterConnectionType { bluetooth, network }

class ThermalPrinterDevice {
  final String name;
  final String address;

  const ThermalPrinterDevice({required this.name, required this.address});
}

class PrinterTarget {
  final PrinterConnectionType type;
  final String address;
  final int port;
  final String? name;

  const PrinterTarget({
    required this.type,
    required this.address,
    this.port = 9100,
    this.name,
  });

  String get displayLabel {
    final label = name?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (type == PrinterConnectionType.network) return '$address:$port';
    return address;
  }

  factory PrinterTarget.fromSettings(AppSettings s) {
    final mode = s.printerMode;
    final address = s.printerAddress?.trim() ?? '';
    if (address.isEmpty || (mode != 'bluetooth' && mode != 'network')) {
      throw StateError('Nessuna stampante configurata. Vai in Impostazioni.');
    }
    return PrinterTarget(
      type: mode == 'network' ? PrinterConnectionType.network : PrinterConnectionType.bluetooth,
      address: address,
      port: s.printerPort ?? 9100,
      name: s.printerName,
    );
  }
}

/// Stampa etichette ESC/POS via Bluetooth oppure rete WiFi/LAN (TCP raw, tipicamente porta 9100).
class ThermalPrintService {
  ThermalPrintService({SettingsService? settings}) : _settings = settings ?? SettingsService();

  final SettingsService _settings;
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final _dayFmt = DateFormat('dd/MM/yyyy');

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isLinux);

  Future<bool> get isBluetoothConnected async {
    if (!isSupported || kIsWeb || !Platform.isAndroid) return false;
    return PrintBluetoothThermal.connectionStatus;
  }

  Future<PrinterTarget?> savedTarget() async {
    final s = await _settings.load();
    if (!s.hasPrinterConfigured) return null;
    try {
      return PrinterTarget.fromSettings(s);
    } catch (_) {
      return null;
    }
  }

  Future<List<ThermalPrinterDevice>> bondedDevices() async {
    if (!isSupported || !Platform.isAndroid) return const [];
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((d) => ThermalPrinterDevice(name: d.name, address: d.macAdress))
        .toList();
  }

  Future<void> connectBluetooth(ThermalPrinterDevice device) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('La stampa Bluetooth è disponibile solo su Android.');
    }
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.address);
    if (!ok) {
      throw StateError('Connessione Bluetooth fallita (${device.name}).');
    }
  }

  Future<void> disconnectBluetooth() async {
    if (!Platform.isAndroid) return;
    await PrintBluetoothThermal.disconnect;
  }

  /// Verifica raggiungibilità stampante di rete / bridge (TCP).
  Future<void> testNetworkPrinter(String host, int port) async {
    final socket = await Socket.connect(
      host.trim(),
      port,
      timeout: const Duration(seconds: 4),
    );
    await socket.close();
  }

  Future<void> _printViaNetwork(String host, int port, Uint8List bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host.trim(),
        port,
        timeout: const Duration(seconds: 5),
      );
      socket.add(bytes);
      await socket.flush();
    } on SocketException catch (e) {
      throw StateError(
        'Stampante di rete non raggiungibile ($host:$port). '
        'Verifica WiFi/bridge. Dettaglio: ${e.message}',
      );
    } finally {
      await socket?.close();
    }
  }

  Future<void> _printViaBluetooth(String mac, Uint8List bytes) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Bluetooth disponibile solo su Android.');
    }
    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    }
    if (!connected) {
      throw StateError('Connessione Bluetooth alla stampante fallita.');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw StateError('Invio stampa Bluetooth fallito.');
    }
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
    PrinterTarget? target,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Stampa non disponibile sul web.');
    }
    final resolved = target ?? PrinterTarget.fromSettings(await _settings.load());
    final bytes = await buildLabelBytes(draft, activityName: activityName);

    for (var i = 0; i < draft.copies; i++) {
      if (resolved.type == PrinterConnectionType.network) {
        await _printViaNetwork(resolved.address, resolved.port, bytes);
      } else {
        await _printViaBluetooth(resolved.address, bytes);
      }
    }
  }
}
