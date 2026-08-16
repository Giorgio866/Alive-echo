import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HaTemperatureSensor {
  const HaTemperatureSensor({
    required this.entityId,
    required this.name,
    this.valueC,
    this.lastUpdated,
    this.unavailable = false,
  });

  final String entityId;
  final String name;
  final double? valueC;
  final DateTime? lastUpdated;
  final bool unavailable;

  bool get hasValue => valueC != null && !unavailable;
}

/// Client REST Home Assistant per i sensori temperatura (Zigbee / MQTT / ecc.).
class HomeAssistantService {
  HomeAssistantService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static String normalizeBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Future<List<HaTemperatureSensor>> listTemperatureSensors({
    required String baseUrl,
    required String token,
  }) async {
    final url = '${normalizeBaseUrl(baseUrl)}/api/states';
    final json = await _getJson(url, token);
    if (json is! List) {
      throw StateError('Home Assistant ha risposto in un formato inatteso');
    }
    return parseStates(json);
  }

  Future<HaTemperatureSensor> getSensor({
    required String baseUrl,
    required String token,
    required String entityId,
  }) async {
    final id = entityId.trim();
    final url = '${normalizeBaseUrl(baseUrl)}/api/states/${Uri.encodeComponent(id)}';
    final json = await _getJson(url, token);
    if (json is! Map) {
      throw StateError('Sensore $id non trovato in Home Assistant');
    }
    final parsed = parseState(Map<String, dynamic>.from(json));
    if (parsed == null) {
      throw StateError('L\'entità $id non è un sensore di temperatura');
    }
    return parsed;
  }

  Future<dynamic> _getJson(String url, String token) async {
    late http.Response res;
    try {
      res = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${token.trim()}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
    } on FormatException {
      throw StateError('URL Home Assistant non valido');
    } catch (e) {
      throw StateError(
        'Non raggiungo Home Assistant. Controlla WiFi, URL e che il telefono sia in LAN. ($e)',
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw StateError('Token non valido. In HA: Profilo → Token di accesso a lunga durata.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Home Assistant ha risposto ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  @visibleForTesting
  static List<HaTemperatureSensor> parseStates(List<dynamic> states) {
    final out = <HaTemperatureSensor>[];
    for (final raw in states) {
      if (raw is! Map) continue;
      final parsed = parseState(Map<String, dynamic>.from(raw));
      if (parsed != null) out.add(parsed);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  @visibleForTesting
  static HaTemperatureSensor? parseState(Map<String, dynamic> map) {
    final entityId = (map['entity_id'] as String?)?.trim() ?? '';
    if (entityId.isEmpty) return null;
    if (!entityId.startsWith('sensor.') && !entityId.startsWith('climate.')) {
      return null;
    }
    if (entityId.contains('humidity') ||
        entityId.contains('battery') ||
        entityId.contains('pressure') ||
        entityId.contains('linkquality')) {
      return null;
    }

    final attrs = map['attributes'] is Map
        ? Map<String, dynamic>.from(map['attributes'] as Map)
        : <String, dynamic>{};
    final deviceClass = '${attrs['device_class'] ?? ''}'.toLowerCase();
    final unit = '${attrs['unit_of_measurement'] ?? ''}'.toLowerCase();
    final isTemp = deviceClass == 'temperature' ||
        unit.contains('°c') ||
        unit.contains('°f') ||
        unit == 'c' ||
        unit == 'f' ||
        unit == 'celsius' ||
        entityId.contains('temperature') ||
        entityId.contains('temp');
    if (!isTemp) return null;

    final friendly = (attrs['friendly_name'] as String?)?.trim();
    final name = (friendly != null && friendly.isNotEmpty) ? friendly : entityId;

    final stateRaw = '${map['state'] ?? ''}';
    final unavailable = {'unavailable', 'unknown', 'none', ''}.contains(stateRaw.toLowerCase());
    var value = unavailable ? null : double.tryParse(stateRaw.replaceAll(',', '.'));
    if (entityId.startsWith('climate.')) {
      final cur = attrs['current_temperature'];
      if (cur is num) value = cur.toDouble();
    }
    if (value != null && (unit.contains('°f') || unit == 'f')) {
      value = (value - 32) * 5 / 9;
    }

    DateTime? lastUpdated;
    final lu = map['last_updated'] as String? ?? map['last_changed'] as String?;
    if (lu != null) lastUpdated = DateTime.tryParse(lu);

    return HaTemperatureSensor(
      entityId: entityId,
      name: name,
      valueC: value,
      lastUpdated: lastUpdated,
      unavailable: unavailable || value == null,
    );
  }
}

