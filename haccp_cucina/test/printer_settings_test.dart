import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/data/models/document_models.dart';
import 'package:haccp_cucina/services/thermal_print_service.dart';

void main() {
  test('AppSettings network printer roundtrip', () {
    const s = AppSettings(
      activityName: 'Test',
      defaultOperator: 'Op',
      printerMode: 'network',
      printerAddress: '192.168.1.130',
      printerPort: 9100,
      printerName: 'Bridge cucina',
      onboardingCompleted: true,
    );
    final prefs = s.toPrefs();
    final loaded = AppSettings.fromPrefs(prefs);
    expect(loaded.printerMode, 'network');
    expect(loaded.printerAddress, '192.168.1.130');
    expect(loaded.printerPort, 9100);
    expect(loaded.hasPrinterConfigured, isTrue);

    final target = PrinterTarget.fromSettings(loaded);
    expect(target.type, PrinterConnectionType.network);
    expect(target.port, 9100);
    expect(target.displayLabel, 'Bridge cucina');
  });

  test('AppSettings legacy bluetooth address without mode', () {
    final loaded = AppSettings.fromPrefs({
      'activity_name': 'X',
      'default_operator': 'Y',
      'printer_address': 'AA:BB:CC:DD:EE:FF',
      'printer_name': 'BT Printer',
      'onboarding_completed': '1',
    });
    expect(loaded.printerMode, 'bluetooth');
    expect(PrinterTarget.fromSettings(loaded).type, PrinterConnectionType.bluetooth);
  });

  test('clearPrinter rimuove configurazione', () {
    const s = AppSettings(
      activityName: 'Test',
      defaultOperator: 'Op',
      printerMode: 'network',
      printerAddress: '192.168.1.130',
      printerPort: 9100,
    );
    final cleared = s.copyWith(clearPrinter: true);
    expect(cleared.hasPrinterConfigured, isFalse);
    expect(cleared.printerAddress, isNull);
  });
}
