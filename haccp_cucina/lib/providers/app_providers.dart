import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/cleaning_models.dart';
import '../data/models/document_models.dart';
import '../data/models/ingredient_models.dart';
import '../data/models/product_lot.dart';
import '../data/models/temperature_models.dart';
import '../data/repositories/haccp_repository.dart';
import '../services/document_scan_service.dart';
import '../services/expiry_notification_service.dart';
import '../services/home_assistant_service.dart';
import '../services/lot_label_ocr_service.dart';
import '../services/menu_catalog_import_service.dart';
import '../services/monthly_archive_service.dart';
import '../services/pdf_export_service.dart';
import '../services/settings_service.dart';
import '../services/temperature_ocr_service.dart';
import '../services/thermal_print_service.dart';
import '../services/vision_label_service.dart';
import '../services/vision_model_service.dart';

final haccpRepositoryProvider = Provider<HaccpRepository>((ref) {
  return HaccpRepository();
});

final documentScanServiceProvider = Provider<DocumentScanService>((ref) {
  return DocumentScanService();
});

final thermalPrintServiceProvider = Provider<ThermalPrintService>((ref) {
  return ThermalPrintService(settings: ref.watch(settingsServiceProvider));
});

final homeAssistantServiceProvider = Provider<HomeAssistantService>((ref) {
  return HomeAssistantService();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final expiryNotificationServiceProvider = Provider<ExpiryNotificationService>((ref) {
  return ExpiryNotificationService();
});

final temperatureOcrServiceProvider = Provider<TemperatureOcrService>((ref) {
  final service = TemperatureOcrService();
  ref.onDispose(service.dispose);
  return service;
});

final menuCatalogImportServiceProvider = Provider<MenuCatalogImportService>((ref) {
  final service = MenuCatalogImportService();
  ref.onDispose(service.dispose);
  return service;
});

final lotLabelOcrServiceProvider = Provider<LotLabelOcrService>((ref) {
  final service = LotLabelOcrService();
  ref.onDispose(service.dispose);
  return service;
});

final visionModelServiceProvider = Provider<VisionModelService>((ref) {
  final service = VisionModelService();
  ref.onDispose(service.dispose);
  return service;
});

final visionLabelServiceProvider = Provider<VisionLabelService>((ref) {
  final service = VisionLabelService(models: ref.watch(visionModelServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

final visionModelReadyProvider = FutureProvider<bool>((ref) async {
  return ref.watch(visionModelServiceProvider).isReady();
});

final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService();
});

final monthlyArchiveServiceProvider = Provider<MonthlyArchiveService>((ref) {
  return MonthlyArchiveService(
    pdfExport: ref.watch(pdfExportServiceProvider),
    settings: ref.watch(settingsServiceProvider),
  );
});

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsServiceProvider).load();
});

final dashboardProvider = FutureProvider<DashboardSnapshot>((ref) async {
  return ref.watch(haccpRepositoryProvider).getDashboardSnapshot();
});

final temperaturePointsProvider = FutureProvider<List<TemperaturePoint>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getTemperaturePoints();
});

final latestReadingsProvider = FutureProvider<Map<String, TemperatureReading?>>((ref) async {
  return ref.watch(haccpRepositoryProvider).latestReadingByPoint();
});

final temperatureHistoryProvider = FutureProvider<List<TemperatureReading>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getReadingsLastDays();
});

final cleaningTasksProvider = FutureProvider<List<CleaningTask>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getCleaningTasks();
});

final cleaningDoneTodayProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getTaskIdsCompletedToday();
});

final lotsProvider = FutureProvider<List<ProductLot>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getLots();
});

final documentsProvider = FutureProvider<List<DocumentRecord>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getDocuments();
});

final ingredientCatalogProvider = FutureProvider<List<IngredientCatalogItem>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getIngredientCatalog();
});

final preparedBatchesProvider = FutureProvider<List<PreparedBatch>>((ref) async {
  return ref.watch(haccpRepositoryProvider).getPreparedBatches();
});
