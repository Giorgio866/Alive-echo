import 'dart:convert';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../data/models/document_models.dart';
import '../data/models/product_lot.dart';
import 'settings_service.dart';

enum PrinterConnectionType { bluetooth, network }

class ThermalPrinterDevice {
  final String name;
  final String address;

  const ThermalPrinterDevice({required this.name, required this.address});
}

class LabelSizeMm {
  final int widthMm;
  final int heightMm;
  final String id;

  const LabelSizeMm(this.id, this.widthMm, this.heightMm);

  static const fortyByThirty = LabelSizeMm('40x30', 40, 30);
  static const fiftyByThirty = LabelSizeMm('50x30', 50, 30);
  static const fiftyByEighty = LabelSizeMm('50x80', 50, 80);

  static LabelSizeMm fromId(String? id) {
    switch (id) {
      case '40x30':
        return fortyByThirty;
      case '50x80':
        return fiftyByEighty;
      case '50x30':
      default:
        return fiftyByThirty;
    }
  }
}

class PrinterTarget {
  final PrinterConnectionType type;
  final String address;
  final int port;
  final String? name;
  /// `escpos` | `tspl`
  final String language;
  final LabelSizeMm labelSize;

  const PrinterTarget({
    required this.type,
    required this.address,
    this.port = 9100,
    this.name,
    this.language = 'escpos',
    this.labelSize = LabelSizeMm.fiftyByThirty,
  });

  String get displayLabel {
    final label = name?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (type == PrinterConnectionType.network) return '$address:$port';
    return address;
  }

  bool get usesTspl => language == 'tspl';

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
      language: s.printerLanguage,
      labelSize: LabelSizeMm.fromId(s.labelFormat),
    );
  }
}

/// Stampa etichette:
/// - ESC/POS via Bluetooth o rete (scontrini 58 mm)
/// - TSPL via Bluetooth (etichette CLABEL / TSC, es. 40x30 / 50x30 / 50x80)
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

  Future<Uint8List> buildLabelBytes(
    LabelDraft draft, {
    String activityName = 'HACCP',
    String language = 'escpos',
    LabelSizeMm labelSize = LabelSizeMm.fiftyByThirty,
  }) async {
    if (language == 'tspl') {
      return buildTsplLabelBytes(draft, activityName: activityName, labelSize: labelSize);
    }
    return _buildEscPosLabelBytes(draft, activityName: activityName);
  }

  Future<Uint8List> _buildEscPosLabelBytes(LabelDraft draft, {required String activityName}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    final lot = (draft.lotCode ?? '').trim().isEmpty ? 'N/D' : draft.lotCode!.trim();

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
    bytes.addAll(generator.text(
      'LOTTO: $lot',
      styles: const PosStyles(bold: true, height: PosTextSize.size2),
    ));
    bytes.addAll(generator.text('Prep.: ${_dateFmt.format(draft.preparedAt)}'));
    bytes.addAll(generator.text(
      'Scadenza: ${_dayFmt.format(draft.useBy)}',
      styles: const PosStyles(bold: true),
    ));
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

  /// Comandi TSPL/TSPL2 per stampanti etichette (CLABEL 221B e simili).
  /// Inviabili via Bluetooth SPP come byte grezzi (stesso canale di ESC/POS).
  Uint8List buildTsplLabelBytes(
    LabelDraft draft, {
    String activityName = 'HACCP',
    LabelSizeMm labelSize = LabelSizeMm.fiftyByThirty,
  }) {
    final lot = (draft.lotCode ?? '').trim().isEmpty ? 'N/D' : draft.lotCode!.trim();
    final w = labelSize.widthMm;
    final h = labelSize.heightMm;
    // 203 dpi ≈ 8 dots/mm
    final maxChars = (w <= 40) ? 18 : 22;
    final compact = h <= 30;

    final lines = <String>[
      _clip(_asciiSafe(activityName.toUpperCase()), maxChars),
      _clip(_asciiSafe(draft.productName), maxChars),
      _clip('LOTTO: ${_asciiSafe(lot)}', maxChars),
      _clip('Prep ${_dateFmt.format(draft.preparedAt)}', maxChars),
      _clip('Scad ${_dayFmt.format(draft.useBy)}', maxChars),
    ];
    if (!compact && draft.allergens != null && draft.allergens!.trim().isNotEmpty) {
      lines.add(_clip('All ${_asciiSafe(draft.allergens!)}', maxChars));
    }
    if (!compact && draft.operatorName != null && draft.operatorName!.trim().isNotEmpty) {
      lines.add(_clip('Op ${_asciiSafe(draft.operatorName!)}', maxChars));
    }

    // Passo verticale in dots: font "2" ~20px, lascia margine.
    final step = compact ? 28 : 36;
    var y = 12;
    final buf = StringBuffer()
      ..writeln('SIZE $w mm,$h mm')
      ..writeln('GAP 2 mm,0 mm')
      ..writeln('DIRECTION 1')
      ..writeln('REFERENCE 0,0')
      ..writeln('CLS')
      ..writeln('CODEPAGE 1252');

    for (var i = 0; i < lines.length; i++) {
      final font = i <= 1 ? '3' : '2';
      final mul = (i == 1 && !compact) ? 1 : 1;
      buf.writeln('TEXT 16,$y,"$font",0,$mul,$mul,"${_tsplEscape(lines[i])}"');
      y += step;
      if (y > (h * 8) - 24) break;
    }
    buf.writeln('PRINT 1,1');
    return Uint8List.fromList(ascii.encode(buf.toString()));
  }

  static String _tsplEscape(String s) => s.replaceAll('"', "'").replaceAll('\r', ' ').replaceAll('\n', ' ');

  static String _clip(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}.';
  }

  /// Evita caratteri non supportati dai font bitmap TSPL economici.
  static String _asciiSafe(String input) {
    const map = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ä': 'A',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Ö': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'ç': 'c', 'Ç': 'C', 'ñ': 'n', 'Ñ': 'N',
      '°': 'o', '€': 'EUR', '•': '-', '–': '-', '—': '-',
    };
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(map[ch] ?? (rune < 128 ? ch : '?'));
    }
    return buf.toString();
  }

  Future<String> previewText(LabelDraft draft, {String activityName = 'HACCP'}) async {
    final lot = (draft.lotCode ?? '').trim().isEmpty ? 'N/D' : draft.lotCode!.trim();
    final buf = StringBuffer()
      ..writeln(activityName.toUpperCase())
      ..writeln('ETICHETTA ALIMENTARE')
      ..writeln('------------------------------')
      ..writeln(draft.productName)
      ..writeln('LOTTO: $lot')
      ..writeln('Prep.: ${_dateFmt.format(draft.preparedAt)}')
      ..writeln('Scadenza: ${_dayFmt.format(draft.useBy)}');
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
    final bytes = await buildLabelBytes(
      draft,
      activityName: activityName,
      language: resolved.language,
      labelSize: resolved.labelSize,
    );

    for (var i = 0; i < draft.copies; i++) {
      if (resolved.type == PrinterConnectionType.network) {
        if (resolved.usesTspl) {
          throw StateError(
            'CLABEL/TSPL è supportata via Bluetooth. '
            'Per la rete usa una stampante ESC/POS oppure collega la CLABEL in Bluetooth.',
          );
        }
        await _printViaNetwork(resolved.address, resolved.port, bytes);
      } else {
        await _printViaBluetooth(resolved.address, bytes);
      }
    }
  }

  /// Etichetta da lotto merce in ingresso (foto prodotto arrivato).
  Future<void> printLotLabel(
    ProductLot lot, {
    required String activityName,
    String? operatorName,
    int copies = 1,
    DateTime? preparedAt,
  }) async {
    final now = preparedAt ?? DateTime.now();
    final useBy = lot.effectiveExpiry ?? now.add(const Duration(days: 3));
    await printLabel(
      LabelDraft(
        productName: lot.productName,
        lotCode: lot.lotCode,
        preparedAt: lot.openedAt ?? lot.receivedAt,
        useBy: useBy,
        allergens: lot.allergens,
        operatorName: operatorName,
        copies: copies,
      ),
      activityName: activityName,
    );
  }
}
