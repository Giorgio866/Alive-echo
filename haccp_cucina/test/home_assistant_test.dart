import 'package:flutter_test/flutter_test.dart';
import 'package:haccp_cucina/data/models/document_models.dart';
import 'package:haccp_cucina/data/models/temperature_models.dart';
import 'package:haccp_cucina/services/home_assistant_service.dart';

void main() {
  test('normalizeBaseUrl aggiunge http e toglie slash finale', () {
    expect(HomeAssistantService.normalizeBaseUrl('192.168.1.10:8123'), 'http://192.168.1.10:8123');
    expect(HomeAssistantService.normalizeBaseUrl('http://ha.local:8123/'), 'http://ha.local:8123');
    expect(
      HomeAssistantService.normalizeBaseUrl('https://xxx.ui.nabu.casa'),
      'https://xxx.ui.nabu.casa',
    );
  });

  test('parseStates tiene solo sensori temperatura Zigbee', () {
    final sensors = HomeAssistantService.parseStates([
      {
        'entity_id': 'sensor.frigo_1_temperature',
        'state': '3.4',
        'attributes': {
          'friendly_name': 'Frigo 1',
          'device_class': 'temperature',
          'unit_of_measurement': '°C',
        },
      },
      {
        'entity_id': 'sensor.frigo_1_humidity',
        'state': '80',
        'attributes': {'device_class': 'humidity', 'unit_of_measurement': '%'},
      },
      {
        'entity_id': 'light.cucina',
        'state': 'on',
        'attributes': {'friendly_name': 'Luce'},
      },
      {
        'entity_id': 'sensor.freezer_temp',
        'state': 'unavailable',
        'attributes': {'device_class': 'temperature', 'unit_of_measurement': '°C'},
      },
    ]);
    expect(sensors.map((e) => e.entityId).toSet(), {
      'sensor.freezer_temp',
      'sensor.frigo_1_temperature',
    });
    final frigo = sensors.firstWhere((e) => e.entityId.endsWith('_temperature'));
    expect(frigo.valueC, 3.4);
    expect(frigo.name, 'Frigo 1');
    expect(frigo.hasValue, isTrue);
    expect(sensors.firstWhere((e) => e.entityId.contains('freezer')).unavailable, isTrue);
  });

  test('parseState converte Fahrenheit', () {
    final s = HomeAssistantService.parseState({
      'entity_id': 'sensor.probe_temp',
      'state': '35.6',
      'attributes': {'device_class': 'temperature', 'unit_of_measurement': '°F'},
    });
    expect(s, isNotNull);
    expect(s!.valueC, closeTo(2.0, 0.05));
  });

  test('AppSettings Home Assistant roundtrip', () {
    const s = AppSettings(
      activityName: 'Test',
      defaultOperator: 'Op',
      homeAssistantUrl: 'http://192.168.1.10:8123',
      homeAssistantToken: 'token-abc',
      onboardingCompleted: true,
    );
    expect(s.hasHomeAssistantConfigured, isTrue);
    final loaded = AppSettings.fromPrefs(s.toPrefs());
    expect(loaded.homeAssistantUrl, 'http://192.168.1.10:8123');
    expect(loaded.homeAssistantToken, 'token-abc');
    expect(loaded.copyWith(clearHomeAssistant: true).hasHomeAssistantConfigured, isFalse);
  });

  test('TemperaturePoint ha_entity_id roundtrip', () {
    const p = TemperaturePoint(
      id: 'f1',
      name: 'Frigo 1',
      zone: 'frigo',
      minC: 0,
      maxC: 4,
      haEntityId: 'sensor.frigo_1_temperature',
    );
    final copy = TemperaturePoint.fromMap(p.toMap());
    expect(copy.haEntityId, 'sensor.frigo_1_temperature');
    expect(copy.copyWith(clearHaEntity: true).haEntityId, isNull);
  });
}
