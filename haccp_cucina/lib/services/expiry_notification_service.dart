import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/ingredient_models.dart';
import '../data/models/product_lot.dart';

/// Notifiche locali per scadenze preparati e lotti.
class ExpiryNotificationService {
  ExpiryNotificationService();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(settings: initSettings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'haccp_scadenze',
          'Scadenze HACCP',
          description: 'Allarmi scadenza preparati e lotti',
          importance: Importance.high,
        ),
      );
    }
    _ready = true;
  }

  Future<void> scheduleBatchExpiry(PreparedBatch batch) async {
    if (!_ready || kIsWeb) return;
    if (!Platform.isAndroid) return;

    final warnAt = batch.expiresAt.subtract(const Duration(hours: 12));
    final when = warnAt.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(seconds: 15))
        : warnAt;

    final id = batch.id.hashCode & 0x7fffffff;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'haccp_scadenze',
          'Scadenze HACCP',
          channelDescription: 'Allarmi scadenza preparati e lotti',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Scadenza: ${batch.ingredientName}',
      body: 'Usare entro ${_fmt(batch.expiresAt)}. Preparato da ${batch.operatorName}.',
    );

    final expireId = (id + 1) & 0x7fffffff;
    if (batch.expiresAt.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        id: expireId,
        scheduledDate: tz.TZDateTime.from(batch.expiresAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'haccp_scadenze',
            'Scadenze HACCP',
            channelDescription: 'Allarmi scadenza preparati e lotti',
            importance: Importance.max,
            priority: Priority.max,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'SCADUTO: ${batch.ingredientName}',
        body: 'Rimuovere dal banco / etichettare come non utilizzabile.',
      );
    }
  }

  Future<void> scheduleLotExpiry(ProductLot lot) async {
    if (!_ready || kIsWeb) return;
    if (!Platform.isAndroid) return;
    final limit = lot.effectiveExpiry;
    if (limit == null) return;
    final warnAt = limit.subtract(const Duration(days: 1));
    final when = warnAt.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(seconds: 15))
        : DateTime(warnAt.year, warnAt.month, warnAt.day, 9);

    final id = ('lot-${lot.id}').hashCode & 0x7fffffff;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'haccp_scadenze',
          'Scadenze HACCP',
          channelDescription: 'Allarmi scadenza preparati e lotti',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Lotto in scadenza: ${lot.productName}',
      body: 'Lotto ${lot.lotCode} · scad. ${_fmt(limit)}',
    );
  }

  Future<void> cancelBatch(String batchId) async {
    if (!_ready) return;
    final id = batchId.hashCode & 0x7fffffff;
    await _plugin.cancel(id: id);
    await _plugin.cancel(id: (id + 1) & 0x7fffffff);
  }

  Future<void> showImmediateAlert({required String title, required String body}) async {
    if (!_ready || kIsWeb) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'haccp_scadenze',
          'Scadenze HACCP',
          channelDescription: 'Allarmi scadenza preparati e lotti',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
