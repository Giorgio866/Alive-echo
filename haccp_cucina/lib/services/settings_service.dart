import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/document_models.dart';

class SettingsService {
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings.fromPrefs({
      'activity_name': prefs.getString('activity_name'),
      'default_operator': prefs.getString('default_operator'),
      'printer_mode': prefs.getString('printer_mode'),
      'printer_address': prefs.getString('printer_address'),
      'printer_name': prefs.getString('printer_name'),
      'printer_port': prefs.getString('printer_port'),
      'printer_language': prefs.getString('printer_language'),
      'label_format': prefs.getString('label_format'),
      'onboarding_completed': prefs.getString('onboarding_completed'),
    });
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activity_name', settings.activityName);
    await prefs.setString('default_operator', settings.defaultOperator);
    await prefs.setString(
      'onboarding_completed',
      settings.onboardingCompleted ? '1' : '0',
    );
    await prefs.setString('printer_language', settings.printerLanguage);
    await prefs.setString('label_format', settings.labelFormat);

    if (settings.printerMode != null) {
      await prefs.setString('printer_mode', settings.printerMode!);
    } else {
      await prefs.remove('printer_mode');
    }
    if (settings.printerAddress != null) {
      await prefs.setString('printer_address', settings.printerAddress!);
    } else {
      await prefs.remove('printer_address');
    }
    if (settings.printerName != null) {
      await prefs.setString('printer_name', settings.printerName!);
    } else {
      await prefs.remove('printer_name');
    }
    if (settings.printerPort != null) {
      await prefs.setString('printer_port', settings.printerPort!.toString());
    } else {
      await prefs.remove('printer_port');
    }
  }

  Future<bool> isOnboardingCompleted() async {
    final s = await load();
    return s.onboardingCompleted;
  }
}
