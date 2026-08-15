import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/document_models.dart';

class SettingsService {
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings.fromPrefs({
      'activity_name': prefs.getString('activity_name'),
      'default_operator': prefs.getString('default_operator'),
      'printer_address': prefs.getString('printer_address'),
      'printer_name': prefs.getString('printer_name'),
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
  }

  Future<bool> isOnboardingCompleted() async {
    final s = await load();
    return s.onboardingCompleted;
  }
}
