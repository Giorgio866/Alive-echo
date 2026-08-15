import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/database/app_database.dart';
import '../data/models/ingredient_models.dart';
import '../data/models/product_lot.dart';
import '../data/models/temperature_models.dart';
import '../data/repositories/haccp_repository.dart';

class PdfExportService {
  final _day = DateFormat('dd/MM/yyyy');
  final _stamp = DateFormat('dd/MM/yyyy HH:mm');

  Future<Uint8List> buildHaccpReport({
    required String activityName,
    required String operatorName,
    required List<TemperaturePoint> points,
    required List<TemperatureReading> readings,
    required List<PreparedBatch> batches,
    required List<ProductLot> lots,
    int days = AppDatabase.temperatureRetentionDays,
  }) async {
    final doc = pw.Document();
    final byPoint = {for (final p in points) p.id: p.name};

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(activityName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Registro HACCP - ultimi $days giorni'),
          pw.Text('Generato il ${_stamp.format(DateTime.now())} - Operatore: $operatorName'),
          pw.SizedBox(height: 16),
          pw.Text('Temperature CCP', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (readings.isEmpty)
            pw.Text('Nessuna lettura nel periodo.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Data', 'Punto', '°C', 'Operatore', 'Esito'],
              data: readings
                  .map(
                    (r) => [
                      _stamp.format(r.recordedAt),
                      byPoint[r.pointId] ?? r.pointId,
                      r.valueC.toStringAsFixed(1),
                      r.operatorName,
                      r.outOfRange ? 'FUORI RANGE' : 'OK',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          pw.SizedBox(height: 20),
          pw.Text('Preparati / scadenze', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (batches.isEmpty)
            pw.Text('Nessun preparato registrato.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Prodotto', 'Prep.', 'Scadenza', 'Operatore', 'Stato'],
              data: batches
                  .map(
                    (b) => [
                      b.ingredientName,
                      _day.format(b.preparedAt),
                      _day.format(b.expiresAt),
                      b.operatorName,
                      b.isExpired ? 'SCADUTO' : (b.expiresSoon ? 'In scadenza' : 'OK'),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          pw.SizedBox(height: 20),
          pw.Text('Lotti in magazzino', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (lots.isEmpty)
            pw.Text('Nessun lotto.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Prodotto', 'Lotto', 'Scadenza', 'Ubicazione'],
              data: lots
                  .map(
                    (l) => [
                      l.productName,
                      l.lotCode,
                      l.effectiveExpiry != null ? _day.format(l.effectiveExpiry!) : '-',
                      l.storageLocation,
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Documento generato da HACCP Cucina. Conservare per ispezioni.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> shareReport(Uint8List bytes, {String filename = 'registro_haccp.pdf'}) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  Future<void> exportFromRepository({
    required HaccpRepository repo,
    required String activityName,
    required String operatorName,
  }) async {
    final points = await repo.getTemperaturePoints(activeOnly: false);
    final readings = await repo.getReadingsLastDays();
    final batches = await repo.getPreparedBatches(activeOnly: false);
    final lots = await repo.getLots();
    final bytes = await buildHaccpReport(
      activityName: activityName,
      operatorName: operatorName,
      points: points,
      readings: readings,
      batches: batches,
      lots: lots,
    );
    final name =
        'HACCP_${activityName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await shareReport(bytes, filename: name);
  }

  /// Anteprima su dispositivi senza share (test).
  Future<File?> writeTempFile(Uint8List bytes, String path) async {
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
